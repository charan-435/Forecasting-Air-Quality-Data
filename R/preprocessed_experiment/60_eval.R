# Phase 4-5: metrics, baselines, paired comparisons and plots.

# MASE denominators from the TRAINING block only, seasonal period `season`.
pe_mase_scale <- function(x, hours, season) {
  hours <- hours[hours > season]
  mean(abs(x[hours] - x[hours - season]), na.rm = TRUE)
}

pe_metrics <- function(pred, actual, scale) {
  e <- pred - actual
  data.frame(n = length(e), MAE = mean(abs(e)), RMSE = sqrt(mean(e^2)), MASE = mean(abs(e)) / scale)
}

# Persistence (= seasonal naive when h = season), train-mean and hour-of-day climatology.
# Fitted on the training block for validation and on train + validation for test.
pe_baselines <- function(md, block) {
  h <- md$h
  idx <- if (block == "val") md$sets$eval_val else md$sets$eval_test
  hours <- if (block == "val") md$train_hours else md$trainval_hours
  fit_y <- if (md$dataset == "clean") md$truth else md$input[, md$cfg$target]
  hod_fit <- lubridate::hour(md$times[hours])
  hod_mean <- tapply(fit_y[hours], hod_fit, mean, na.rm = TRUE)
  tgt_hod <- as.character(lubridate::hour(md$times[idx + h]))
  data.frame(origin = md$times[idx], target_time = md$times[idx + h], actual = md$truth[idx + h],
             persistence = md$input[idx, md$cfg$target],
             train_mean = mean(fit_y[hours], na.rm = TRUE),
             hour_of_day = as.numeric(hod_mean[tgt_hod]))
}

# ---- paired comparison --------------------------------------------------------

pe_block_boot_idx <- function(n, L, B, seed) {
  set.seed(seed)
  nb <- ceiling(n / L)
  lapply(seq_len(B), function(b) {
    st <- sample.int(max(1L, n - L + 1L), nb, replace = TRUE)
    as.vector(unlist(lapply(st, function(s) s:min(n, s + L - 1L))))[seq_len(n)]
  })
}

pe_dm <- function(d, lag, h) {
  n <- length(d)
  dc <- d - mean(d)
  v <- sum(dc^2) / n
  for (k in seq_len(min(lag, n - 1L))) v <- v + 2 * (1 - k / (lag + 1)) * sum(dc[(k + 1):n] * dc[1:(n - k)]) / n
  if (!is.finite(v) || v <= 0) return(c(stat = NA, p = NA))
  stat <- mean(d) / sqrt(v / n)
  stat <- stat * sqrt((n + 1 - 2 * h + h * (h - 1) / n) / n)   # Harvey et al. (1997)
  c(stat = stat, p = 2 * stats::pt(-abs(stat), df = n - 1))
}

# A minus B on identical targets (rows aligned by target_time).
pe_paired <- function(eA, eB, scale, cfg, label_a, label_b, block) {
  n <- length(eA)
  bi <- pe_block_boot_idx(n, as.integer(cfg$comparison$block_length),
                          as.integer(cfg$comparison$bootstrap_reps), cfg$seed)
  stat <- function(ii) c(mae_diff = mean(abs(eA[ii])) - mean(abs(eB[ii])),
                         mae_ratio = mean(abs(eA[ii])) / mean(abs(eB[ii])),
                         rmse_diff = sqrt(mean(eA[ii]^2)) - sqrt(mean(eB[ii]^2)),
                         rmse_ratio = sqrt(mean(eA[ii]^2)) / sqrt(mean(eB[ii]^2)))
  pt <- stat(seq_len(n))
  bs <- do.call(rbind, lapply(bi, stat))
  ci <- apply(bs, 2, stats::quantile, c(0.025, 0.975))
  dm_abs <- pe_dm(abs(eA) - abs(eB), as.integer(cfg$comparison$dm_lag), as.integer(cfg$forecast$horizon_h))
  dm_sq <- pe_dm(eA^2 - eB^2, as.integer(cfg$comparison$dm_lag), as.integer(cfg$forecast$horizon_h))
  data.frame(
    block = block, A = label_a, B = label_b, n = n,
    MAE_A = mean(abs(eA)), MAE_B = mean(abs(eB)),
    MAE_diff = pt[["mae_diff"]], MAE_diff_lo = ci[1, "mae_diff"], MAE_diff_hi = ci[2, "mae_diff"],
    MAE_ratio = pt[["mae_ratio"]], MAE_ratio_lo = ci[1, "mae_ratio"], MAE_ratio_hi = ci[2, "mae_ratio"],
    RMSE_A = sqrt(mean(eA^2)), RMSE_B = sqrt(mean(eB^2)),
    RMSE_diff = pt[["rmse_diff"]], RMSE_diff_lo = ci[1, "rmse_diff"], RMSE_diff_hi = ci[2, "rmse_diff"],
    RMSE_ratio = pt[["rmse_ratio"]], RMSE_ratio_lo = ci[1, "rmse_ratio"], RMSE_ratio_hi = ci[2, "rmse_ratio"],
    MASE_diff = pt[["mae_diff"]] / scale,
    DM_abs_stat = dm_abs[["stat"]], DM_abs_p = dm_abs[["p"]],
    DM_sq_stat = dm_sq[["stat"]], DM_sq_p = dm_sq[["p"]],
    verdict = ifelse(ci[2, "mae_diff"] < 0, "A better (CI < 0)",
                     ifelse(ci[1, "mae_diff"] > 0, "B better (CI > 0)", "no clear difference")))
}
