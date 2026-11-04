# WaveCatBoost filter ablation: Haar vs D4 vs LA8 (1-day).
# Appends/updates rows in results/filter_scores.{rds,csv} and filter_cache.rds.
#
# Usage (project root):
#   "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" run_filter_ablation_catboost.R

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

source("R/load_all.R")

filter_cache_path <- file.path(RES_DIR, "filter_cache.rds")
filter_score_path <- file.path(RES_DIR, "filter_scores.rds")
hparam_path <- file.path(RES_DIR, "hparams.rds")

load_cache <- function(path) {
  if (file.exists(path)) readRDS(path) else list()
}
save_cache <- function(obj, path) saveRDS(obj, path)

message("Loading data...")
raw <- load_raw_datasets(include_new = FALSE)
series <- prepare_all_series(raw)

if (file.exists(hparam_path)) {
  hp <- readRDS(hparam_path)
  params <- hp$params
  J_use <- hp$J
  message("Hparams: ", hp$reason)
} else {
  params <- default_tree_params()
  J_use <- choose_J(series[["CPCB_PM2.5"]]$y)$J_elbow
  message("Using default tree params; J=", J_use)
}

FILTER_METHODS    <- c("wavecatboost")
FILTER_FAMILIES   <- c("haar", "d4", "la8")
FILTER_POLLUTANTS <- POLLUTANTS  # PM2.5, NO2, O3, CO, SO2, PM10
FILTER_HORIZONS   <- HORIZONS["1d"]

fcache <- load_cache(filter_cache_path)

filter_jobs <- list()
for (s in series) {
  if (!s$pollutant %in% FILTER_POLLUTANTS) next
  for (hn in names(FILTER_HORIZONS)) {
    h <- FILTER_HORIZONS[[hn]]
    if (h >= length(s$y)) next
    for (m in FILTER_METHODS) {
      for (filt in FILTER_FAMILIES) {
        key <- paste(s$sensor, s$pollutant, hn, m, filt, sep = "|")
        filter_jobs[[key]] <- list(
          sensor = s$sensor, pollutant = s$pollutant,
          horizon = hn, h = h, method = m, filter = filt,
          series = s, key = key
        )
      }
    }
  }
}

message("WaveCatBoost filter jobs: ", length(filter_jobs),
        " | already cached: ", sum(names(filter_jobs) %in% names(fcache)))

for (job in filter_jobs) {
  if (job$key %in% names(fcache) && !isTRUE(fcache[[job$key]]$error)) {
    message("Skip cached ", job$key)
    next
  }
  s      <- job$series
  split  <- chrono_split(s$y, s$times, job$h)
  sc     <- minmax_fit(split$y_train)
  ytr    <- minmax_apply(split$y_train, sc)

  message(sprintf("[%s] FILTER %s | %s %s %s h=%s",
                  format(Sys.time(), "%H:%M:%S"),
                  toupper(job$filter),
                  job$sensor, job$pollutant, job$method, job$horizon))
  t0  <- proc.time()[3]
  out <- tryCatch(
    fit_and_forecast(job$method, ytr, h = job$h,
                     params = params, J = J_use, filter = job$filter),
    error = function(e) { message("  ERROR: ", e$message); NULL }
  )
  elapsed <- proc.time()[3] - t0
  message(sprintf("  elapsed %.1fs", elapsed))

  if (is.null(out)) {
    fcache[[job$key]] <- list(error = TRUE, key = job$key)
    save_cache(fcache, filter_cache_path)
    next
  }

  yhat   <- minmax_invert(out$yhat, sc)
  sc_tbl <- score_forecast(split$y_train, split$y_test, yhat)

  fcache[[job$key]] <- list(
    error     = FALSE,
    sensor    = job$sensor,
    pollutant = job$pollutant,
    horizon   = job$horizon,
    method    = job$method,
    filter    = job$filter,
    y_test    = split$y_test,
    t_test    = split$t_test,
    yhat      = yhat,
    scores    = sc_tbl,
    elapsed   = elapsed
  )
  save_cache(fcache, filter_cache_path)
}

filter_scores <- dplyr::bind_rows(lapply(fcache, function(z) {
  if (isTRUE(z$error) || is.null(z$scores)) return(NULL)
  dplyr::bind_cols(
    tibble::tibble(
      sensor    = z$sensor,
      pollutant = z$pollutant,
      horizon   = z$horizon,
      method    = z$method,
      filter    = z$filter,
      elapsed   = z$elapsed
    ),
    z$scores
  )
}))

saveRDS(filter_scores, filter_score_path)
readr::write_csv(filter_scores, file.path(RES_DIR, "filter_scores.csv"))
message("Filter scores written. Rows: ", nrow(filter_scores))
print(filter_scores %>%
        dplyr::filter(method == "wavecatboost", horizon == "1d") %>%
        dplyr::select(sensor, pollutant, filter, MASE, MAE, RMSE) %>%
        dplyr::arrange(sensor, pollutant, filter))
message("Done.")
