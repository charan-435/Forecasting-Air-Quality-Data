# B2 multivariate feature generation from stored Haar MRA components.
# 6 pollutants × 6 components × 24 lags = 864 features.
# No future values; no recompute of MODWT.

b2_load_panel <- function(sensor = B2_SENSOR, pollutants = B2_POLLUTANTS) {
  series_all <- t1_load_prepared_series()
  skey <- paste(sensor, B2_TARGET_POLLUTANT, sep = "_")
  if (!skey %in% names(series_all)) stop("Missing series ", skey)
  target_series <- series_all[[skey]]
  # Use PM2.5 timestamps as master grid.
  master <- tibble::tibble(
    timestamp = target_series$times,
    y_pm25 = as.numeric(target_series$y)
  )
  audit <- list()
  for (pol in pollutants) {
    decomp <- t1_load_stored_components(sensor, pol, B2_METHOD_ID, B2_SCALE)
    idx <- t1_match_timestamps(master$timestamp, decomp$timestamp)
    hit <- !is.na(idx)
    valid <- rep(FALSE, nrow(master))
    if ("t1_valid" %in% names(decomp)) {
      valid[hit] <- decomp$t1_valid[idx[hit]] %in% TRUE
    } else {
      valid[hit] <- TRUE
    }
    for (comp in B2_COMPONENTS) {
      col <- paste0(pol, "__", comp)
      vec <- rep(NA_real_, nrow(master))
      raw <- as.numeric(decomp[[comp]])
      vec[hit] <- raw[idx[hit]]
      vec[!valid] <- NA_real_
      master[[col]] <- vec
    }
    audit[[pol]] <- list(
      n_decomp = nrow(decomp),
      n_complete6 = sum(stats::complete.cases(decomp[, B2_COMPONENTS])),
      n_aligned_finite = sum(hit & valid),
      md5 = attr(decomp, "t1_source_md5"),
      path = attr(decomp, "t1_source_path")
    )
  }
  # All-36 finite mask (warmup / missing handled by NA, never imputed).
  feat_cols <- as.character(unlist(lapply(pollutants, function(pol) {
    paste0(pol, "__", B2_COMPONENTS)
  })))
  master$all36_ok <- stats::complete.cases(master[, feat_cols, drop = FALSE])
  attr(master, "b2_audit") <- audit
  attr(master, "b2_feature_cols") <- feat_cols
  attr(master, "b2_sensor") <- sensor
  master
}

b2_stage_vector <- function(n, sp) {
  stage <- rep(NA_character_, n)
  stage[seq_len(sp$n_train)] <- "train"
  stage[(sp$n_train + 1L):(sp$n_train + sp$n_val)] <- "validation"
  stage[(sp$n_train + sp$n_val + 1L):n] <- "test"
  stage
}

# Build one row of 864 lags at origin index `t` (1-based).
# lag1 = value at t, lag2 = value at t-1, ..., lag24 = value at t-23.
# For predicting y[t+h], origin is t.
b2_row_at_origin <- function(panel, t, p = B2_P) {
  if (t < p) return(NULL)
  feat_cols <- attr(panel, "b2_feature_cols")
  # Need all36_ok on [t-p+1, t]
  win <- (t - p + 1L):t
  if (any(!panel$all36_ok[win])) return(NULL)
  vals <- numeric(0)
  nms <- character(0)
  for (pol in B2_POLLUTANTS) {
    for (comp in B2_COMPONENTS) {
      col <- paste0(pol, "__", comp)
      series <- panel[[col]]
      # lag k = series[t - k + 1]
      lags <- series[t:(t - p + 1L)]
      if (any(!is.finite(lags))) return(NULL)
      vals <- c(vals, lags)
      nms <- c(nms, paste0(pol, "__", comp, "__lag", seq_len(p)))
    }
  }
  names(vals) <- nms
  vals
}

b2_build_supervised <- function(panel, target_comp, h,
                                stage_filter = c("train", "validation", "test"),
                                p = B2_P) {
  h <- as.integer(h)
  n <- nrow(panel)
  sp <- chrono_split_tvt(panel$y_pm25, panel$timestamp, h, VAL_HOURS)
  stage <- b2_stage_vector(n, sp)
  target_col <- paste0(B2_TARGET_POLLUTANT, "__", target_comp)
  y_comp <- panel[[target_col]]

  rows_X <- list()
  rows_meta <- list()
  fn <- b2_feature_names(p)
  stopifnot(length(fn) == B2_N_FEATURES)

  # Candidate origins: need t >= p and t+h <= n
  for (t in p:(n - h)) {
    tgt_idx <- t + h
    st_tgt <- stage[tgt_idx]
    if (is.na(st_tgt) || !(st_tgt %in% stage_filter)) next
    # Train: origin AND target must both be in train.
    if (identical(st_tgt, "train") && !identical(stage[t], "train")) next
    # Val/test: target in block; origin may be in previous block.
    if (!is.finite(y_comp[tgt_idx])) next
    if (!is.finite(panel$y_pm25[tgt_idx]) && identical(target_comp, "recon")) next
    feat <- b2_row_at_origin(panel, t, p)
    if (is.null(feat)) next
    if (!identical(names(feat), fn)) {
      stop("Feature ordering mismatch at t=", t)
    }
    rows_X[[length(rows_X) + 1L]] <- feat
    rows_meta[[length(rows_meta) + 1L]] <- tibble::tibble(
      origin_idx = t,
      target_idx = tgt_idx,
      origin_time = panel$timestamp[t],
      target_time = panel$timestamp[tgt_idx],
      stage = st_tgt,
      y = y_comp[tgt_idx],
      y_pm25 = panel$y_pm25[tgt_idx],
      target_component = target_comp,
      horizon_hours = h
    )
  }
  if (!length(rows_X)) {
    return(list(
      X = matrix(NA_real_, 0, length(fn), dimnames = list(NULL, fn)),
      meta = tibble::tibble(),
      feature_names = fn,
      sp = sp, stage = stage
    ))
  }
  X <- do.call(rbind, rows_X)
  colnames(X) <- fn
  meta <- dplyr::bind_rows(rows_meta)
  list(X = X, meta = meta, feature_names = fn, sp = sp, stage = stage,
       n_features = ncol(X))
}

b2_scale_fit <- function(X_train) {
  mu <- apply(X_train, 2, function(z) {
    z <- z[is.finite(z)]
    if (!length(z)) 0 else mean(z)
  })
  sdv <- apply(X_train, 2, function(z) {
    z <- z[is.finite(z)]
    if (length(z) < 2L) 1 else stats::sd(z)
  })
  sdv[!is.finite(sdv) | sdv < 1e-12] <- 1
  list(center = mu, scale = sdv)
}

b2_scale_apply <- function(X, fit) {
  sweep(sweep(X, 2, fit$center, `-`), 2, fit$scale, `/`)
}

b2_target_scaler_fit <- function(y) {
  minmax_fit(y)
}

b2_audit_panel_table <- function(panel) {
  audit <- attr(panel, "b2_audit")
  dplyr::bind_rows(lapply(names(audit), function(pol) {
    a <- audit[[pol]]
    tibble::tibble(
      sensor = B2_SENSOR, pollutant = pol,
      decomp_id = B2_DECOMP_ID, validity = B2_VALIDITY,
      n_decomp_rows = a$n_decomp, n_complete6 = a$n_complete6,
      n_aligned_finite = a$n_aligned_finite,
      md5 = a$md5, path = a$path
    )
  }))
}
