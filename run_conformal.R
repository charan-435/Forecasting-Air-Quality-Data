# WaveCatBoost conformal intervals (paper §II-C).
# Split conformal + 1-step walk-forward on PM2.5, 7-day window, all sensors.

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
if (!file.exists("R/load_all.R")) stop("Run from the project root.")
source("R/load_all.R")

packed <- {
  p <- file.path(PROC_DIR, "series.rds")
  if (file.exists(p)) readRDS(p) else {
    raw <- load_raw_datasets(include_new = FALSE)
    list(raw = raw, series = prepare_all_series(raw))
  }
}
series <- packed$series
sh <- ensure_new_dataset()
if (!is.null(sh$hourly)) {
  for (p in POLLUTANTS) {
    if (!p %in% names(sh$hourly)) next
    series[[paste(NEW_SENSOR, p, sep = "_")]] <- prepare_series(sh$hourly, p, NEW_SENSOR)
  }
}

hp <- if (file.exists(file.path(RES_DIR, "hparams.rds"))) {
  readRDS(file.path(RES_DIR, "hparams.rds"))
} else {
  list(params = default_tree_params(), J = 5L)
}
params <- hp$params
params$nrounds <- min(params$nrounds %||% 120L, 120L)
J_use <- min(as.integer(hp$J %||% 5L), 5L)

conf_path <- file.path(RES_DIR, "conformal.rds")
conf_out <- if (file.exists(conf_path)) readRDS(conf_path) else list()

sensors <- intersect(SENSORS, unique(vapply(series, `[[`, character(1), "sensor")))
for (sensor in sensors) {
  s <- series[[paste(sensor, "PM2.5", sep = "_")]]
  if (is.null(s)) next
  message("Conformal 1-step: ", sensor, " PM2.5 7d")
  z <- tryCatch(
    conformal_wavecatboost_1step(s, params, J_use),
    error = function(e) {
      message("  ERROR: ", e$message)
      NULL
    }
  )
  if (is.null(z)) next
  conf_out[[sensor]] <- z
  message("  kappa=", z$kappa,
          " cal_cov=", round(z$coverage_cal, 3),
          " test_cov=", round(z$coverage_test, 3),
          " width=", round(z$width, 2))
  saveRDS(conf_out, conf_path)
}
saveRDS(conf_out, conf_path)
message("Wrote ", conf_path)
