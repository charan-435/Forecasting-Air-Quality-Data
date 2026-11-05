# Small time-based grid on PM2.5 CPCB (1-day horizon). Chosen values are
# reused for the full bake-off. We never peek at the test window.

grid_search_tree <- function(y_train, method = "lgb",
                             p_grid = c(24L, 48L),
                             depth_grid = c(4L, 6L),
                             eta_grid = c(0.05, 0.1),
                             J_grid = NULL,
                             val_h = 24L) {
  n <- length(y_train)
  y_fit <- y_train[seq_len(n - val_h)]
  y_val <- y_train[(n - val_h + 1):n]
  rows <- list()
  idx <- 1L
  for (p in p_grid) for (d in depth_grid) for (eta in eta_grid) {
    pr <- default_tree_params()
    pr$p <- as.integer(p)
    pr$max_depth <- as.integer(d)
    pr$eta <- eta
    pr$nrounds <- 150L
    if (is.null(J_grid)) {
      fc <- tryCatch(
        fit_and_forecast(method, y_fit, h = val_h, params = pr),
        error = function(e) NULL
      )
      if (is.null(fc)) next
      rows[[idx]] <- tibble::tibble(
        method = method, p = p, max_depth = d, eta = eta, J = NA_integer_,
        val_MASE = mase(y_fit, y_val, fc$yhat)
      )
      idx <- idx + 1L
    } else {
      for (J in J_grid) {
        fc <- tryCatch(
          fit_and_forecast(method, y_fit, h = val_h, params = pr, J = J),
          error = function(e) NULL
        )
        if (is.null(fc)) next
        rows[[idx]] <- tibble::tibble(
          method = method, p = p, max_depth = d, eta = eta, J = as.integer(J),
          val_MASE = mase(y_fit, y_val, fc$yhat)
        )
        idx <- idx + 1L
      }
    }
  }
  dplyr::bind_rows(rows) %>% dplyr::arrange(.data$val_MASE)
}

choose_hparams <- function(series_pm25_cpcb, J_elbow) {
  y <- series_pm25_cpcb$y
  h <- HORIZONS[["1d"]]
  split <- chrono_split(y, series_pm25_cpcb$times, h)
  # Trees on min-max scale (as in the bake-off).
  sc <- minmax_fit(split$y_train)
  ytr <- minmax_apply(split$y_train, sc)

  message("Grid: LightGBM lags/depth/lr on CPCB PM2.5 (train only)...")
  g_lgb <- grid_search_tree(ytr, "lgb")
  best <- g_lgb[1, ]

  message("Grid: WaveLGBM J in {elbow, paper} with best lag/depth...")
  g_wave <- grid_search_tree(
    ytr, "wavelgb",
    p_grid = best$p, depth_grid = best$max_depth, eta_grid = best$eta,
    J_grid = unique(c(J_elbow, max(3L, floor(log(length(ytr))))))
  )

  params <- default_tree_params()
  params$p <- as.integer(best$p)
  params$max_depth <- as.integer(best$max_depth)
  params$eta <- best$eta
  J <- if (nrow(g_wave)) as.integer(g_wave$J[1]) else as.integer(J_elbow)

  list(
    params = params,
    J = J,
    grid_lgb = g_lgb,
    grid_wave = g_wave,
    reason = sprintf(
      "Chosen p=%s, depth=%s, eta=%s from LGBM time-based CV (val MASE=%.3f). J=%s from WaveLGBM CV.",
      params$p, params$max_depth, params$eta, best$val_MASE, J
    )
  )
}
