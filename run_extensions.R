# Fourier vs Haar vs D4 vs LA8 vs EMD, same WaveLGB head.
# Writes results/extension_scores.rds so analysis.Rmd can load them.
#
# Usage (project root):
#   "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" run_extensions.R

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run this script from the project root.")

source("R/load_all.R")

series_path <- file.path(PROC_DIR, "series.rds")
hparam_path <- file.path(RES_DIR, "hparams.rds")
ext_cache_path <- file.path(RES_DIR, "extension_cache.rds")
ext_score_path <- file.path(RES_DIR, "extension_scores.rds")

if (file.exists(series_path)) {
  series <- readRDS(series_path)$series
} else {
  series <- prepare_all_series(load_raw_datasets())
}

if (file.exists(hparam_path)) {
  hp <- readRDS(hparam_path)
} else {
  hp <- list(params = default_tree_params(), J = 5L)
}
params <- hp$params
params$nrounds <- min(params$nrounds %||% 120L, 120L)
J_use <- min(as.integer(hp$J %||% 5L), 5L)

load_cache <- function(path) if (file.exists(path)) readRDS(path) else list()
save_cache <- function(obj, path) saveRDS(obj, path)

# Reuse Haar/D4/LA8 rows already computed by run_experiments.R.
filter_score_path <- file.path(RES_DIR, "filter_scores.rds")
filter_scores <- if (file.exists(filter_score_path)) readRDS(filter_score_path) else NULL

DECOMPS <- c("haar", "d4", "la8", "fourier")
POLLS   <- c("PM2.5", "NO2")
HORIZ   <- HORIZONS["1d"]
SENS    <- SENSORS

# EMD on ~8k hourly points is slow; set to c("CPCB_PM2.5") to score it.
# The Rmd still shows EMD on a 500-hour window.
EMD_KEYS <- character(0)

cache <- load_cache(ext_cache_path)

# Seed Haar / D4 / LA8 from the existing filter ablation so we do not refit them.
if (!is.null(filter_scores) && nrow(filter_scores) && file.exists(file.path(RES_DIR, "filter_cache.rds"))) {
  fcache <- load_cache(file.path(RES_DIR, "filter_cache.rds"))
  for (nm in names(fcache)) {
    if (!nm %in% names(cache)) cache[[nm]] <- fcache[[nm]]
  }
}

jobs <- list()
for (s in series) {
  if (!s$pollutant %in% POLLS) next
  if (!s$sensor %in% SENS) next
  for (hn in names(HORIZ)) {
    h <- HORIZ[[hn]]
    if (h >= length(s$y)) next
    for (filt in DECOMPS) {
      key <- paste(s$sensor, s$pollutant, hn, "wavelgb", filt, sep = "|")
      jobs[[key]] <- list(
        sensor = s$sensor, pollutant = s$pollutant, horizon = hn,
        h = h, filter = filt, series = s, key = key
      )
    }
    emd_key_s <- paste(s$sensor, s$pollutant, sep = "_")
    if (emd_key_s %in% EMD_KEYS && requireNamespace("EMD", quietly = TRUE)) {
      key <- paste(s$sensor, s$pollutant, hn, "wavelgb", "emd", sep = "|")
      jobs[[key]] <- list(
        sensor = s$sensor, pollutant = s$pollutant, horizon = hn,
        h = h, filter = "emd", series = s, key = key
      )
    }
  }
}

message("Extension jobs: ", length(jobs),
        " | already cached: ", sum(names(jobs) %in% names(cache)))

for (job in jobs) {
  if (job$key %in% names(cache)) next
  s     <- job$series
  split <- chrono_split(s$y, s$times, job$h)
  sc    <- minmax_fit(split$y_train)
  ytr   <- minmax_apply(split$y_train, sc)

  message(sprintf("[%s] %s | %s %s h=%s",
                  format(Sys.time(), "%H:%M:%S"),
                  toupper(job$filter),
                  job$sensor, job$pollutant, job$horizon))
  t0  <- proc.time()[3]
  out <- tryCatch(
    fit_and_forecast("wavelgb", ytr, h = job$h,
                     params = params, J = J_use, filter = job$filter),
    error = function(e) { message("  ERROR: ", e$message); NULL }
  )
  elapsed <- proc.time()[3] - t0
  if (is.null(out)) {
    cache[[job$key]] <- list(error = TRUE, key = job$key)
    save_cache(cache, ext_cache_path)
    next
  }
  yhat   <- minmax_invert(out$yhat, sc)
  sc_tbl <- score_forecast(split$y_train, split$y_test, yhat)
  cache[[job$key]] <- list(
    error = FALSE, sensor = job$sensor, pollutant = job$pollutant,
    horizon = job$horizon, method = "wavelgb", filter = job$filter,
    y_test = split$y_test, t_test = split$t_test, yhat = yhat,
    scores = sc_tbl, elapsed = elapsed
  )
  save_cache(cache, ext_cache_path)
}

ext_scores <- dplyr::bind_rows(lapply(cache, function(z) {
  if (isTRUE(z$error) || is.null(z$scores)) return(NULL)
  dplyr::bind_cols(
    tibble::tibble(
      sensor = z$sensor, pollutant = z$pollutant, horizon = z$horizon,
      method = z$method, filter = z$filter, elapsed = z$elapsed
    ),
    z$scores
  )
}))

# If the dedicated cache is thin, fold in filter_scores so the Rmd still has Haar/D4/LA8.
if (!is.null(filter_scores) && nrow(filter_scores)) {
  have <- paste(ext_scores$sensor, ext_scores$pollutant, ext_scores$horizon,
                ext_scores$filter, sep = "|")
  extra <- filter_scores %>%
    dplyr::mutate(key = paste(sensor, pollutant, horizon, filter, sep = "|")) %>%
    dplyr::filter(!.data$key %in% have) %>%
    dplyr::select(-"key")
  ext_scores <- dplyr::bind_rows(ext_scores, extra)
}

saveRDS(ext_scores, ext_score_path)
readr::write_csv(ext_scores, file.path(RES_DIR, "extension_scores.csv"))
message("Extension scores:")
print(ext_scores)
message("Wrote ", ext_score_path)
