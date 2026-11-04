# Section 10.4: conformalized quantile regression vs paper residual PI
# and split conformal. PM2.5, 7-day, CPCB / ID1 / SHILLONG.
#
#   "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" run_conformal_ext.R

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
sh <- ensure_new_dataset(force = FALSE)
if (!is.null(sh$hourly)) {
  for (p in intersect(POLLUTANTS, names(sh$hourly))) {
    if (sum(is.finite(sh$hourly[[p]])) < 2L) next
    series[[paste(NEW_SENSOR, p, sep = "_")]] <-
      prepare_series(sh$hourly, p, NEW_SENSOR)
  }
}

hp <- if (file.exists(file.path(RES_DIR, "hparams.rds"))) {
  readRDS(file.path(RES_DIR, "hparams.rds"))
} else {
  list(params = default_tree_params())
}
params <- hp$params
params$nrounds <- min(params$nrounds %||% 120L, 120L)

out_path <- file.path(RES_DIR, "conformal_ext.rds")
out <- if (file.exists(out_path)) readRDS(out_path) else list()
if (is.null(out$cqr)) out$cqr <- list()

sensors <- c("CPCB", "ID1", NEW_SENSOR)
for (sensor in sensors) {
  s <- series[[paste(sensor, "PM2.5", sep = "_")]]
  if (is.null(s)) {
    message("Skip ", sensor, ": no PM2.5 series")
    next
  }
  cached <- out$cqr[[sensor]]
  if (!is.null(cached) && !isTRUE(cached$error) && !is.null(cached$yhat)) {
    message("Skip cached CQR ", sensor)
    next
  }
  message("CQR 1-step: ", sensor, " PM2.5 7d")
  z <- tryCatch(
    conformal_cqr_1step(s, params),
    error = function(e) {
      message("  ERROR: ", e$message)
      list(error = TRUE, message = e$message, sensor = sensor)
    }
  )
  out$cqr[[sensor]] <- z
  if (!isTRUE(z$error)) {
    message("  cal_cov=", round(z$coverage_cal, 3),
            " test_cov=", round(z$coverage_test, 3),
            " width=", round(z$width, 2),
            " qhat=", round(z$qhat, 2))
  }
  saveRDS(out, out_path)
}

rows <- list()
for (sensor in names(out$cqr)) {
  z <- out$cqr[[sensor]]
  if (isTRUE(z$error) || is.null(z$coverage_test)) next
  rows[[length(rows) + 1L]] <- tibble::tibble(
    sensor = sensor, pollutant = "PM2.5", horizon = "7d",
    method = "CQR (LightGBM quantiles)",
    protocol = z$protocol,
    coverage = z$coverage_test, width = z$width, qhat = z$qhat
  )
}
out$scores <- dplyr::bind_rows(rows)
saveRDS(out, out_path)
message("Wrote ", out_path)
if (nrow(out$scores)) print(out$scores)
