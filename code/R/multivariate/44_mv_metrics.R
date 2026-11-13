# Metrics for the multivariate pipeline (Phase 1). UNMASKED: every sample counts.
# MASE follows code/R/core/08_metrics.R: seasonal-naive (lag `season`) MAE of a training
# series as the denominator.

mv_mase_scale <- function(y_series, season = 24L) {
  y <- as.numeric(y_series)
  if (length(y) <= season) stop("series too short for seasonal scale")
  s <- mean(abs(diff(y, lag = season)))
  if (!is.finite(s) || s <= 0) stop("seasonal-naive scale is not positive")
  s
}

# Scale from the contiguous PM2.5 series inside a block (or a union of blocks).
mv_block_scale <- function(cfg, panel, blocks = "train", target = cfg$target) {
  bl <- mv_blocks(cfg, panel$times)
  i0 <- min(bl$start_idx[bl$block %in% blocks]); i1 <- max(bl$end_idx[bl$block %in% blocks])
  y <- panel$X[i0:i1, target]
  list(scale = mv_mase_scale(y, as.integer(cfg$metrics$season)),
       n_hours = length(y), n_pairs = length(y) - as.integer(cfg$metrics$season),
       from = mv_fmt_ts(panel$times[i0]), to = mv_fmt_ts(panel$times[i1]),
       blocks = paste(blocks, collapse = "+"))
}

mv_point_metrics <- function(y, yhat, scale) {
  e <- as.numeric(yhat) - as.numeric(y)
  c(MAE = mean(abs(e)), RMSE = sqrt(mean(e^2)), MASE = mean(abs(e)) / scale)
}

# Moving-block bootstrap over the time-ordered samples (hourly origins).
# Blocks of `block` consecutive samples are drawn with replacement until n
# samples are collected. Returns percentile intervals.
mv_mbb_index <- function(n, block, reps, seed) {
  block <- min(as.integer(block), n)
  starts_max <- n - block + 1L
  k <- ceiling(n / block)
  set.seed(seed)
  lapply(seq_len(reps), function(r) {
    st <- sample.int(starts_max, k, replace = TRUE)
    idx <- as.vector(unlist(lapply(st, function(s) s:(s + block - 1L))))
    idx[seq_len(n)]
  })
}

mv_bootstrap_metrics <- function(y, yhat, scale, block, reps, seed, level = 0.95) {
  ix <- mv_mbb_index(length(y), block, reps, seed)
  m <- t(vapply(ix, function(i) mv_point_metrics(y[i], yhat[i], scale), numeric(3)))
  a <- (1 - level) / 2
  ci <- apply(m, 2, stats::quantile, probs = c(a, 1 - a), names = FALSE)
  list(lo = ci[1, ], hi = ci[2, ])
}

# Paired comparison of two forecasts on the same samples: ratio of MAEs (a / b)
# and difference of MAEs (a - b), same resampled indices for both.
mv_bootstrap_paired <- function(y, yhat_a, yhat_b, block, reps, seed, level = 0.95) {
  ix <- mv_mbb_index(length(y), block, reps, seed)
  d <- t(vapply(ix, function(i) {
    ma <- mean(abs(yhat_a[i] - y[i])); mb <- mean(abs(yhat_b[i] - y[i]))
    c(ratio = ma / mb, diff = ma - mb)
  }, numeric(2)))
  a <- (1 - level) / 2
  ma <- mean(abs(yhat_a - y)); mb <- mean(abs(yhat_b - y))
  data.frame(mae_ratio = ma / mb,
             mae_ratio_lo = stats::quantile(d[, "ratio"], a, names = FALSE),
             mae_ratio_hi = stats::quantile(d[, "ratio"], 1 - a, names = FALSE),
             mae_diff = ma - mb,
             mae_diff_lo = stats::quantile(d[, "diff"], a, names = FALSE),
             mae_diff_hi = stats::quantile(d[, "diff"], 1 - a, names = FALSE),
             p_ratio_lt_1 = mean(d[, "ratio"] < 1))
}

# Score one fitted run. This is the only place test labels are read.
mv_score <- function(cfg, ds, run, scale_train, scale_refit) {
  bs <- cfg$metrics$bootstrap
  rows <- list()
  for (b in c("train", "validation", "test")) {
    y <- ds$blocks[[b]]$y
    yhat <- run$pred[[b]]
    sc <- scale_train$scale   # one primary denominator for every block
    pm <- mv_point_metrics(y, yhat, sc)
    ci <- if (b == "train") list(lo = rep(NA_real_, 3), hi = rep(NA_real_, 3)) else
      mv_bootstrap_metrics(y, yhat, sc, bs$block_h, bs$reps, bs$seed, bs$level)
    rows[[b]] <- data.frame(
      design = ds$design, family = run$family, horizon_h = ds$h, block = b,
      fitted_on = if (b == "test") "train+validation (frozen iterations)" else "train",
      n = length(y), MAE = pm[["MAE"]], MAE_lo = ci$lo[1], MAE_hi = ci$hi[1],
      RMSE = pm[["RMSE"]], RMSE_lo = ci$lo[2], RMSE_hi = ci$hi[2],
      MASE = pm[["MASE"]], MASE_lo = ci$lo[3], MASE_hi = ci$hi[3],
      mase_scale = sc, mase_scale_source = scale_train$blocks,
      MASE_refit_scale = if (b == "test") pm[["MAE"]] / scale_refit$scale else NA_real_,
      best_iter = run$best_iter, iterations_run = run$iterations_run,
      early_stopped = run$early_stopped, seed = run$seed,
      quality_mask = "none (UNMASKED)", stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
