# WaveCatBoost conformal intervals (paper §II-C) with a true forecast
# calibration window — not in-sample fitted residuals.

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
source("R/load_all.R")

packed <- readRDS(file.path(PROC_DIR, "series.rds"))
series <- packed$series
hp <- readRDS(file.path(RES_DIR, "hparams.rds"))
params <- hp$params
params$nrounds <- min(params$nrounds, 120L)
J_use <- min(as.integer(hp$J), 5L)

conf_out <- list()
for (sensor in SENSORS) {
  s <- series[[paste(sensor, "PM2.5", sep = "_")]]
  h <- HORIZONS[["7d"]]
  split <- chrono_split(s$y, s$times, h)
  ntr <- length(split$y_train)
  cal_h <- min(168L, max(48L, floor(ntr / 8)))
  y_pre <- split$y_train[seq_len(ntr - cal_h)]
  y_cal <- split$y_train[(ntr - cal_h + 1):ntr]

  sc_pre <- minmax_fit(y_pre)
  message("Calibration forecast: ", sensor, " PM2.5, ", cal_h, " hours")
  fit_cal <- fit_and_forecast(
    "wavecatboost", minmax_apply(y_pre, sc_pre), h = cal_h,
    params = params, J = J_use
  )
  yhat_cal <- minmax_invert(fit_cal$yhat, sc_pre)

  sc <- minmax_fit(split$y_train)
  message("Test forecast: ", sensor, " PM2.5 7d")
  fit <- fit_and_forecast(
    "wavecatboost", minmax_apply(split$y_train, sc), h = h,
    params = params, J = J_use
  )
  yhat_test <- minmax_invert(fit$yhat, sc)

  kappas <- unique(c(24L, 168L, as.integer(cal_h)))
  cands <- lapply(kappas, function(k) {
    conformal_from_residuals(y_cal, yhat_cal, yhat_test, alpha = 0.05, kappa = k)
  })
  covs <- vapply(cands, `[[`, numeric(1), "coverage_cal")
  best <- cands[[which.min(abs(covs - 0.95))]]
  conf_out[[sensor]] <- list(
    sensor = sensor, pollutant = "PM2.5", horizon = "7d",
    t_test = split$t_test, y_test = split$y_test, yhat = yhat_test,
    lower = best$lower, upper = best$upper,
    cq = best$cq, kappa = best$kappa,
    coverage_cal = best$coverage_cal,
    coverage_test = interval_coverage(split$y_test, best$lower, best$upper),
    width = interval_width(best$lower, best$upper),
    alert = alert_from_interval("PM2.5", best$lower, best$upper, yhat_test)
  )
  message("  kappa=", best$kappa,
          " cal_cov=", round(best$coverage_cal, 3),
          " test_cov=", round(conf_out[[sensor]]$coverage_test, 3))
}
saveRDS(conf_out, file.path(RES_DIR, "conformal.rds"))
message("Wrote results/conformal.rds")
