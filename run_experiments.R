# Heavy bake-off. Writes results/*.rds so analysis.Rmd can load them.
# Resume-safe: each (sensor, pollutant, horizon, method) is cached.
#
# Usage (from the project root):
#   "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" run_experiments.R
#   "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" run_experiments.R quick

args <- commandArgs(trailingOnly = TRUE)
QUICK <- any(tolower(args) %in% c("quick", "--quick", "-q"))

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run this script from the project root.")

source("R/load_all.R")

cache_path <- file.path(RES_DIR, "forecast_cache.rds")
score_path <- file.path(RES_DIR, "scores.rds")
hparam_path <- file.path(RES_DIR, "hparams.rds")
series_path <- file.path(PROC_DIR, "series.rds")
conformal_path <- file.path(RES_DIR, "conformal.rds")
eda_path <- file.path(RES_DIR, "eda_summary.rds")

METHODS_PLAIN <- c("snaive", "sarima", "xgb", "lgb", "catboost")
METHODS_WAVE <- c("wavesarima", "wavexgb", "wavelgb", "wavecatboost")
METHODS <- c(METHODS_PLAIN, METHODS_WAVE)

if (QUICK) {
  message("QUICK mode: 1-day horizon only, LightGBM family + snaive/sarima.")
  METHODS <- c("snaive", "sarima", "lgb", "wavelgb")
}

load_cache <- function(path) {
  if (file.exists(path)) readRDS(path) else list()
}

save_cache <- function(obj, path) {
  saveRDS(obj, path)
}

# ---- 1. Data --------------------------------------------------------------
message("Loading raw datasets...")
raw <- load_raw_datasets()
series <- prepare_all_series(raw)
saveRDS(list(raw = raw, series = series), series_path)

# EDA summaries used by the Rmd even before a full knit.
eda <- lapply(series, function(s) {
  y <- s$y
  adf_p <- tryCatch(tseries::adf.test(y, alternative = "stationary")$p.value, error = function(e) NA)
  kpss_p <- tryCatch(urca::ur.kpss(y)@teststat, error = function(e) NA)
  jpick <- choose_J(y)
  tibble::tibble(
    sensor = s$sensor, pollutant = s$pollutant, n = length(y),
    n_missing_raw = s$n_missing,
    mean = mean(y), sd = sd(y), min = min(y), max = max(y),
    adf_p = adf_p, J_paper = jpick$J_paper, J_elbow = jpick$J_elbow
  )
})
eda_df <- dplyr::bind_rows(eda)
saveRDS(eda_df, eda_path)
print(eda_df)

# ---- 2. Hyperparameters on CPCB PM2.5 ------------------------------------
pm_key <- "CPCB_PM2.5"
J_elbow <- choose_J(series[[pm_key]]$y)$J_elbow
if (file.exists(hparam_path)) {
  hp <- readRDS(hparam_path)
  message("Loaded cached hyperparameters: ", hp$reason)
} else if (QUICK) {
  hp <- list(
    params = default_tree_params(),
    J = J_elbow,
    grid_lgb = NULL,
    grid_wave = NULL,
    reason = paste("QUICK defaults p=24, depth=6, eta=0.08, J=", J_elbow)
  )
  saveRDS(hp, hparam_path)
} else {
  hp <- tryCatch(
    choose_hparams(series[[pm_key]], J_elbow),
    error = function(e) {
      message("Hparam search failed (", e$message, "); using defaults.")
      list(
        params = default_tree_params(),
        J = J_elbow,
        grid_lgb = NULL,
        grid_wave = NULL,
        reason = paste("Defaults p=24, depth=6, eta=0.08, J=", J_elbow,
                       "(grid failed:", e$message, ")")
      )
    }
  )
  saveRDS(hp, hparam_path)
}
# Cap J at 5 (32-hour scale): extra Haar levels are extra CatBoost models and
# were ~4x slower in a J=9 trial, with little extra daily-cycle information.
if (hp$J > 5L) {
  hp$reason <- paste0(hp$reason, " Modelling cap: J=", hp$J, " -> 5.")
  hp$J <- 5L
}
message(hp$reason)
params <- hp$params
params$nrounds <- min(params$nrounds, 120L)
J_use <- hp$J

# ---- 3. Bake-off ----------------------------------------------------------
cache <- load_cache(cache_path)
horizons_use <- if (QUICK) HORIZONS["1d"] else HORIZONS

# PM2.5 first (used in conformal + hparams), then 1-day for every pollutant, then the rest.
job_rank <- function(pollutant, horizon) {
  p_rank <- if (identical(pollutant, "PM2.5")) 0 else 1
  h_rank <- match(horizon, c("1d", "7d", "14d", "31d"), nomatch = 9)
  p_rank * 10 + h_rank
}
jobs <- list()
for (s in series) {
  for (hn in names(horizons_use)) {
    h <- horizons_use[[hn]]
    if (h >= length(s$y)) next
    for (m in METHODS) {
      key <- paste(s$sensor, s$pollutant, hn, m, sep = "|")
      jobs[[key]] <- list(sensor = s$sensor, pollutant = s$pollutant,
                          horizon = hn, h = h, method = m, series = s, key = key,
                          rank = job_rank(s$pollutant, hn))
    }
  }
}
jobs <- jobs[order(vapply(jobs, `[[`, numeric(1), "rank"))]

message("Jobs: ", length(jobs), " | already cached: ",
        sum(names(jobs) %in% names(cache)))

n_done <- 0L
for (job in jobs) {
  if (job$key %in% names(cache)) next
  s <- job$series
  split <- chrono_split(s$y, s$times, job$h)
  # Trees + wave-trees: min-max on train only. SARIMA / snaive: original scale.
  use_scale <- job$method %in% c("xgb", "lgb", "catboost", "wavexgb", "wavelgb", "wavecatboost")
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
    scores = sc_tbl,
    elapsed = elapsed,
    fallback = isTRUE(out$fit$fallback)
  )
  n_done <- n_done + 1L
  if (n_done %% 2L == 0L) save_cache(cache, cache_path)
  if (n_done %% 10L == 0L) {
    tmp <- dplyr::bind_rows(lapply(cache, function(z) {
      if (isTRUE(z$error) || is.null(z$scores)) return(NULL)
      dplyr::bind_cols(
        tibble::tibble(sensor = z$sensor, pollutant = z$pollutant,
                       horizon = z$horizon, method = z$method, elapsed = z$elapsed),
        z$scores
      )
    }))
    saveRDS(tmp, score_path)
    readr::write_csv(tmp, file.path(RES_DIR, "scores.csv"))
  }
}

save_cache(cache, cache_path)

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
message("Score table:")
print(scores)

# ---- 4. Conformal intervals for WaveCatBoost, both sensors, PM2.5, 7d ----
# Prefer the dedicated run_conformal.R output (hold-out calibration).
if (file.exists(conformal_path)) {
  message("Conformal results already present; skipping refit.")
  conf_out <- readRDS(conformal_path)
} else conf_out <- list()
if (!file.exists(conformal_path)) {
for (sensor in SENSORS) {
  key_fc <- paste(sensor, "PM2.5", "7d", "wavecatboost", sep = "|")
  s <- series[[paste(sensor, "PM2.5", sep = "_")]]
  if (is.null(s)) next
  h <- HORIZONS[["7d"]]
  split <- chrono_split(s$y, s$times, h)
  sc <- minmax_fit(split$y_train)
  ytr <- minmax_apply(split$y_train, sc)
  message("Conformal: refitting WaveCatBoost for ", sensor, " PM2.5 7d ...")
  fit <- tryCatch(
    fit_and_forecast("wavecatboost", ytr, h = h, params = params, J = J_use),
    error = function(e) NULL
  )
  if (is.null(fit)) next
  ins <- tryCatch(wave_insample(fit$fit, ytr), error = function(e) NULL)
  yhat_test <- minmax_invert(fit$yhat, sc)
  if (is.null(ins)) {
    # Fallback: use last 14d of train vs snaive as a crude calibration
    cal_h <- min(168L, floor(length(split$y_train) / 5))
    yhat_cal <- forecast_snaive(split$y_train[seq_len(length(split$y_train) - cal_h)], cal_h)
    y_cal <- tail(split$y_train, cal_h)
  } else {
    y_cal <- minmax_invert(ins$y, sc)
    yhat_cal <- minmax_invert(ins$yhat, sc)
  }
  # Pick kappa by calibration coverage closest to 95%.
  kappas <- c(24L, 168L, 336L)
  cands <- lapply(kappas, function(k) { 
    conformal_from_residuals(y_cal, yhat_cal, yhat_test, alpha = 0.05, kappa = k)
  })
  covs <- vapply(cands, `[[`, numeric(1), "coverage_cal")
  best <- cands[[which.min(abs(covs - 0.95))]]
  cov_test <- interval_coverage(split$y_test, best$lower, best$upper)
  conf_out[[sensor]] <- list(
    sensor = sensor, pollutant = "PM2.5", horizon = "7d",
    t_test = split$t_test, y_test = split$y_test, yhat = yhat_test,
    lower = best$lower, upper = best$upper,
    cq = best$cq, kappa = best$kappa,
    coverage_cal = best$coverage_cal, coverage_test = cov_test,
    width = interval_width(best$lower, best$upper),
    alert = alert_from_interval("PM2.5", best$lower, best$upper, yhat_test)
  )
}
saveRDS(conf_out, conformal_path)
}

message("Done. Cached ", length(cache), " forecasts.")


# ---- 5. Filter ablation: Haar vs D4 vs LA8 on WaveLGB --------------------
# We use WaveLGB (fastest wave model) to compare filter families.
# Scope: PM2.5 + NO2 on both sensors, 1-day and 7-day horizons.
# Results land in results/filter_scores.rds (separate from the main scores).

message("=== Filter ablation: Haar / D4 / LA8 ===")

filter_cache_path <- file.path(RES_DIR, "filter_cache.rds")
filter_score_path <- file.path(RES_DIR, "filter_scores.rds")

FILTER_METHODS    <- c("wavelgb")          # fastest wave method
FILTER_FAMILIES   <- c("haar", "d4", "la8")
FILTER_POLLUTANTS <- c("PM2.5", "NO2")     # 2 representative pollutants
FILTER_HORIZONS   <- if (QUICK) HORIZONS["1d"] else HORIZONS[c("1d", "7d")]

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

message("Filter jobs: ", length(filter_jobs),
        " | already cached: ", sum(names(filter_jobs) %in% names(fcache)))

for (job in filter_jobs) {
  if (job$key %in% names(fcache)) next
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

  if (is.null(out)) {
    fcache[[job$key]] <- list(error = TRUE, key = job$key)
    save_cache(fcache, filter_cache_path)
    next
  }

  yhat    <- minmax_invert(out$yhat, sc)
  sc_tbl  <- score_forecast(split$y_train, split$y_test, yhat)

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
message("Filter ablation done. Rows: ", nrow(filter_scores))
print(filter_scores)

message("All done.")
