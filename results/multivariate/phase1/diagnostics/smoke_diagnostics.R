# DIAGNOSTIC ONLY. Not part of the pipeline and never used for fitting or
# selection. Primary Phase 1 metrics stay UNMASKED (SMOKE_RESULTS.csv).
#   Rscript results/multivariate/phase1/diagnostics/smoke_diagnostics.R
# 1. Seasonal-naive reference for h = 24 (forecast of t+24 is the value at t).
# 2. Error split by whether the target hour is a Phase 0 constant-fill hour,
#    using results/multivariate/phase0/proposed_quality_mask_cpcb.csv.

if (!file.exists("R/40_mv_data.R")) stop("Run from the project root.")
for (f in c("R/40_mv_data.R", "R/44_mv_metrics.R")) sys.source(f, envir = .GlobalEnv)
cfg <- mv_cfg()
panel <- mv_load_panel(cfg)
out <- file.path(cfg$output_dir, "diagnostics")
pr <- utils::read.csv(file.path(cfg$output_dir, "SMOKE_PREDICTIONS.csv"), stringsAsFactors = FALSE)
scale <- mv_block_scale(cfg, panel, "train")$scale

mask_path <- file.path("results", "multivariate", "phase0", "proposed_quality_mask_cpcb.csv")
fill_ts <- if (file.exists(mask_path)) {
  m <- utils::read.csv(mask_path, stringsAsFactors = FALSE)
  m$timestamp[as.logical(m$is_constant_fill)]
} else character(0)

ts_chr <- mv_fmt_ts(panel$times)
rows <- list()
for (b in c("validation", "test")) {
  for (d in unique(pr$design)) {
    s <- pr[pr$design == d & pr$block == b & pr$horizon_h == 24, ]
    f <- s$target %in% fill_ts
    for (grp in c("all", "constant_fill_target", "other_target")) {
      k <- switch(grp, all = rep(TRUE, nrow(s)), constant_fill_target = f, other_target = !f)
      if (!any(k)) next
      pm <- mv_point_metrics(s$y[k], s$yhat[k], scale)
      rows[[length(rows) + 1L]] <- data.frame(block = b, forecast = paste0(d, " LightGBM"), targets = grp,
                                              n = sum(k), MAE = pm[["MAE"]], RMSE = pm[["RMSE"]],
                                              MASE = pm[["MASE"]], stringsAsFactors = FALSE)
    }
  }
  s <- pr[pr$design == pr$design[1] & pr$block == b & pr$horizon_h == 24, ]
  yhat_sn <- panel$X[match(s$origin, ts_chr), cfg$target]    # value at origin = y(t+24-24)
  f <- s$target %in% fill_ts
  for (grp in c("all", "constant_fill_target", "other_target")) {
    k <- switch(grp, all = rep(TRUE, nrow(s)), constant_fill_target = f, other_target = !f)
    if (!any(k)) next
    pm <- mv_point_metrics(s$y[k], yhat_sn[k], scale)
    rows[[length(rows) + 1L]] <- data.frame(block = b, forecast = "seasonal naive (lag 24)", targets = grp,
                                            n = sum(k), MAE = pm[["MAE"]], RMSE = pm[["RMSE"]],
                                            MASE = pm[["MASE"]], stringsAsFactors = FALSE)
  }
}
res <- do.call(rbind, rows)
res$note <- "DIAGNOSTIC ONLY; primary metrics are UNMASKED"
utils::write.csv(res, file.path(out, "SMOKE_DIAGNOSTICS.csv"), row.names = FALSE)
print(res, digits = 4)
