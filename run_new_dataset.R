# Paper preprocess + bake-off for SHILLONG, then 7-day conformal on all sensors.
#
#   Rscript run_new_dataset.R
#   Rscript run_new_dataset.R quick     # 1-day, snaive/lgb/wavelgb only
#   Rscript run_new_dataset.R conformal # conformal only (assumes SHILLONG exists)

args <- commandArgs(trailingOnly = TRUE)
QUICK <- any(tolower(args) %in% c("quick", "--quick", "-q"))
CONF_ONLY <- any(tolower(args) %in% c("conformal", "--conformal"))

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")
source("R/load_all.R")

cache_path <- file.path(RES_DIR, "forecast_cache.rds")
score_path <- file.path(RES_DIR, "scores.rds")
hparam_path <- file.path(RES_DIR, "hparams.rds")

load_cache <- function(path) if (file.exists(path)) readRDS(path) else list()
save_cache <- function(obj, path) saveRDS(obj, path)

# ---- 1. Paper preprocess for SHILLONG ------------------------------------
message("=== SHILLONG paper preprocess (15-min → hourly) ===")
sh <- ensure_new_dataset(force = FALSE)
if (is.null(sh$hourly)) stop("Could not build SHILLONG hourly series.")
if (!is.null(sh$meta)) {
  message("n_15min=", sh$meta$n_15min, " n_hourly=", sh$meta$n_hourly,
          " from_cache=", sh$from_cache)
}

raw_paper <- load_raw_datasets(include_new = FALSE)
series <- prepare_all_series(raw_paper)
for (p in POLLUTANTS) {
  if (!p %in% names(sh$hourly)) next
  series[[paste(NEW_SENSOR, p, sep = "_")]] <- prepare_series(sh$hourly, p, NEW_SENSOR)
}

if (file.exists(hparam_path)) {
  hp <- readRDS(hparam_path)
} else {
  hp <- list(params = default_tree_params(), J = 5L,
             reason = "defaults p=24, depth=6, eta=0.08, J=5")
}
if (!is.null(hp$J) && hp$J > 5L) hp$J <- 5L
params <- hp$params
params$nrounds <- min(params$nrounds %||% 120L, 120L)
J_use <- min(as.integer(hp$J %||% 5L), 5L)

if (!CONF_ONLY) {
  METHODS <- if (QUICK) {
    c("snaive", "lgb", "wavelgb")
  } else {
    c("snaive", "sarima", "lgb", "catboost", "wavelgb", "wavecatboost")
  }
  POLS <- FOUR_POLLUTANTS
  HNS <- if (QUICK) "1d" else c("1d", "7d")

  cache <- load_cache(cache_path)
  jobs <- list()
  for (p in POLS) {
    s <- series[[paste(NEW_SENSOR, p, sep = "_")]]
    if (is.null(s)) next
    for (hn in HNS) {
      # 7-day only for PM2.5 (conformal + comparison); 1-day for four pollutants.
      if (identical(hn, "7d") && !identical(p, "PM2.5")) next
      h <- HORIZONS[[hn]]
      if (h >= length(s$y)) next
      for (m in METHODS) {
        key <- paste(NEW_SENSOR, p, hn, m, sep = "|")
        jobs[[key]] <- list(sensor = NEW_SENSOR, pollutant = p, horizon = hn,
                            h = h, method = m, series = s, key = key)
      }
    }
  }
  message("SHILLONG jobs: ", length(jobs), " | cached: ",
          sum(names(jobs) %in% names(cache)))

  n_done <- 0L
  for (job in jobs) {
    if (job$key %in% names(cache) && !isTRUE(cache[[job$key]]$error)) next
    s <- job$series
    split <- chrono_split(s$y, s$times, job$h)
    use_scale <- job$method %in% c("xgb", "lgb", "catboost",
                                   "wavexgb", "wavelgb", "wavecatboost")
    if (use_scale) {
      sc <- minmax_fit(split$y_train)
      ytr <- minmax_apply(split$y_train, sc)
    } else {
      sc <- NULL
      ytr <- split$y_train
    }
    message(sprintf("[%s] %s %s %s h=%s",
                    format(Sys.time(), "%H:%M:%S"), job$sensor, job$pollutant,
                    job$method, job$horizon))
    t0 <- proc.time()[3]
    out <- tryCatch(
      fit_and_forecast(job$method, ytr, h = job$h, params = params, J = J_use),
      error = function(e) {
        message("  ERROR: ", e$message)
        NULL
      }
    )
    elapsed <- proc.time()[3] - t0
    if (is.null(out)) {
      cache[[job$key]] <- list(error = TRUE, key = job$key)
      save_cache(cache, cache_path)
      next
    }
    yhat <- out$yhat
    if (use_scale) yhat <- minmax_invert(yhat, sc)
    sc_tbl <- score_forecast(split$y_train, split$y_test, yhat)
    cache[[job$key]] <- list(
      error = FALSE,
      sensor = job$sensor,
      pollutant = job$pollutant,
      horizon = job$horizon,
      method = job$method,
      y_test = split$y_test,
      t_test = split$t_test,
      yhat = yhat,
      components = out$components,
      scores = sc_tbl,
      elapsed = elapsed,
      fallback = isTRUE(out$fit$fallback)
    )
    n_done <- n_done + 1L
    save_cache(cache, cache_path)
  }

  scores <- dplyr::bind_rows(lapply(cache, function(z) {
    if (isTRUE(z$error) || is.null(z$scores)) return(NULL)
    dplyr::bind_cols(
      tibble::tibble(sensor = z$sensor, pollutant = z$pollutant,
                     horizon = z$horizon, method = z$method, elapsed = z$elapsed),
      z$scores
    )
  }))
  saveRDS(scores, score_path)
  readr::write_csv(scores, file.path(RES_DIR, "scores.csv"))
  message("Score rows: ", nrow(scores))
}

# ---- 2. Conformal on CPCB, ID1, SHILLONG ---------------------------------
message("=== 7-day conformal (walk-forward 1-step) ===")
conf_path <- file.path(RES_DIR, "conformal.rds")
conf_out <- if (file.exists(conf_path)) readRDS(conf_path) else list()
for (sensor in SENSORS) {
  s <- series[[paste(sensor, "PM2.5", sep = "_")]]
  if (is.null(s)) next
  if (!is.null(conf_out[[sensor]]) &&
      identical(conf_out[[sensor]]$protocol, "walkforward_1step_split_conformal")) {
    message("Conformal already done for ", sensor)
    next
  }
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
message("Done.")
