# Weighted conformal prediction intervals (paper §II-C), plus a simple alert rule.
# CS_t = |Y_t - Yhat_t| / U_t
# CQ_t = (1-alpha) quantile of CS in a trailing window of length kappa
# PI_t = Yhat_t ± CQ_t * U_t

rolling_mae <- function(err, win) {
  e <- abs(as.numeric(err))
  n <- length(e)
  u <- numeric(n)
  for (i in seq_len(n)) {
    lo <- max(1L, i - win + 1L)
    u[i] <- mean(e[lo:i], na.rm = TRUE)
  }
  pmax(u, .Machine$double.eps)
}

.robust_u <- function(u_cal, err, y_cal, k) {
  u_star <- tail(u_cal, 1)
  y_tail <- tail(as.numeric(y_cal), k)
  degenerate <- !is.finite(u_star) || u_star < 1e-8 ||
    (sum(is.finite(y_tail)) > 2 && stats::sd(y_tail, na.rm = TRUE) < 1e-6)
  if (degenerate) {
    u_star <- max(stats::median(u_cal, na.rm = TRUE),
                  mean(abs(err), na.rm = TRUE),
                  .Machine$double.eps)
  }
  u_star
}

conformal_from_residuals <- function(y_cal, yhat_cal, yhat_test,
                                     alpha = 0.05, kappa = 168L, u_win = 24L,
                                     y_test = NULL, clip_nonneg = TRUE) {
  err <- as.numeric(y_cal) - as.numeric(yhat_cal)
  u_cal <- rolling_mae(err, u_win)
  cs <- abs(err) / pmax(u_cal, .Machine$double.eps)
  n <- length(cs)
  k <- min(as.integer(kappa), n)
  cq <- as.numeric(stats::quantile(cs[(n - k + 1):n], probs = 1 - alpha,
                                   na.rm = TRUE, names = FALSE))
  u_star <- .robust_u(u_cal, err, y_cal, k)
  h <- length(yhat_test)

  # 1-step historical: after each test hour is observed, U can update.
  # Deployed multi-step (y_test = NULL): copy the robust calibration scale.
  if (!is.null(y_test) && length(y_test) == h) {
    u_test <- numeric(h)
    err_all <- err
    for (i in seq_len(h)) {
      u_all <- rolling_mae(err_all, u_win)
      ui <- tail(u_all, 1)
      if (!is.finite(ui) || ui < 1e-8) ui <- u_star
      u_test[i] <- ui
      err_all <- c(err_all, as.numeric(y_test[i]) - as.numeric(yhat_test[i]))
    }
  } else {
    u_test <- rep(u_star, h)
  }

  half <- cq * u_test
  lower <- as.numeric(yhat_test) - half
  upper <- as.numeric(yhat_test) + half
  if (isTRUE(clip_nonneg)) lower <- pmax(0, lower)
  list(
    lower = lower,
    upper = upper,
    cq = cq,
    alpha = alpha,
    kappa = k,
    u_test = u_test,
    u_star = u_star,
    coverage_cal = mean(abs(err) <= cq * u_cal, na.rm = TRUE)
  )
}

tree_insample <- function(fit, y_train) {
  sup <- supervised_from_series(y_train, fit$p)
  yhat <- vapply(seq_len(nrow(sup$X)), function(i) {
    predict_tree_row(fit, sup$X[i, , drop = FALSE])
  }, numeric(1))
  list(y = sup$y, yhat = yhat)
}

wave_insample <- function(wave_fit, y_train) {
  filt <- if (!is.null(wave_fit$filter)) wave_fit$filter else "haar"
  mra <- generic_mra(y_train, wave_fit$J, filter = filt)
  comps <- c(mra$D, list(S = mra$S))
  parts <- lapply(names(comps), function(nm) {
    fit <- wave_fit$models[[nm]]
    if (!is.null(fit$p)) tree_insample(fit, comps[[nm]])
    else list(y = comps[[nm]], yhat = as.numeric(stats::fitted(fit)))
  })
  lens <- vapply(parts, function(z) length(z$yhat), integer(1))
  L <- min(lens)
  yhat <- Reduce(`+`, lapply(parts, function(z) tail(z$yhat, L)))
  list(y = tail(as.numeric(y_train), L), yhat = yhat)
}

# Split conformal on 1-step walk-forward WaveCatBoost (paper §II-C).
# Train on y[1:n_fit]; calibrate on the next cal_h hours; test is the last h hours.
conformal_wavecatboost_1step <- function(s, params, J,
                                         h = HORIZONS[["7d"]],
                                         cal_h = 168L,
                                         alpha = 0.05) {
  y <- as.numeric(s$y)
  times <- s$times
  n <- length(y)
  h <- as.integer(h)
  cal_h <- as.integer(min(cal_h, max(48L, floor((n - h) / 6))))
  if (n <= h + cal_h + 200L) {
    cal_h <- max(48L, min(cal_h, floor((n - h) / 5)))
  }
  n_test_start <- n - h + 1L
  n_cal_start <- n_test_start - cal_h
  n_fit <- n_cal_start - 1L
  if (n_fit < 400L) stop("Series too short for split conformal.")

  y_fit <- y[seq_len(n_fit)]
  sc <- minmax_fit(y_fit)
  y_fit_n <- minmax_apply(y_fit, sc)
  message("  fit WaveCatBoost on ", n_fit, " h  |  cal ", cal_h, "  |  test ", h)
  wf <- wave_fit_components(y_fit_n, J, fit_cat, params, filter = "haar")

  y_n <- minmax_apply(y, sc)
  yhat_cal_n <- wave_walkforward_1step(wf, y_n, n_fit, cal_h)
  yhat_test_n <- wave_walkforward_1step(wf, y_n, n_fit + cal_h, h)
  yhat_cal <- minmax_invert(yhat_cal_n, sc)
  yhat_test <- minmax_invert(yhat_test_n, sc)
  y_cal <- y[n_cal_start:(n_cal_start + cal_h - 1L)]
  y_test <- y[n_test_start:n]

  kappas <- unique(c(24L, 168L, as.integer(cal_h)))
  cands <- lapply(kappas, function(k) {
    conformal_from_residuals(y_cal, yhat_cal, yhat_test,
                             alpha = alpha, kappa = k, y_test = y_test)
  })
  covs <- vapply(cands, `[[`, numeric(1), "coverage_cal")
  best <- cands[[which.min(abs(covs - (1 - alpha)))]]
  list(
    sensor = s$sensor, pollutant = s$pollutant, horizon = "7d",
    protocol = "walkforward_1step_split_conformal",
    t_test = times[n_test_start:n],
    y_test = y_test,
    yhat = yhat_test,
    lower = best$lower,
    upper = best$upper,
    cq = best$cq, kappa = best$kappa, u_star = best$u_star,
    coverage_cal = best$coverage_cal,
    coverage_test = interval_coverage(y_test, best$lower, best$upper),
    width = interval_width(best$lower, best$upper),
    n_fit = n_fit, cal_h = cal_h,
    components = NULL
  )
}

interval_coverage <- function(y, lo, hi) {
  mean(y >= lo & y <= hi, na.rm = TRUE)
}

interval_width <- function(lo, hi) {
  mean(hi - lo, na.rm = TRUE)
}

# Extra decision rule (not in the paper): mean of the lower PI bound vs WHO / NAAQS.
alert_from_interval <- function(pollutant, lower, upper, yhat) {
  thr <- ALERT_THRESHOLDS[[pollutant]]
  if (is.null(thr)) {
    return(tibble::tibble(rule = character(), threshold = numeric(),
                          mean_lower = NA_real_, exceedance_likely = logical()))
  }
  ml <- mean(lower, na.rm = TRUE)
  tibble::tibble(
    rule = c("WHO_24h", "NAAQS_24h"),
    threshold = c(thr$who, thr$naaqs),
    unit = thr$unit,
    mean_forecast = mean(yhat, na.rm = TRUE),
    mean_lower = ml,
    exceedance_likely = c(ml > thr$who, ml > thr$naaqs)
  )
}
