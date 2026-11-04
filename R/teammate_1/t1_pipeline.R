# Frequency-specific model selection (T1).
# Isolated from original WaveCatBoost / T2. Loads stored Haar J=5 MRA only.

T1_COMPONENTS <- c("D1", "D2", "D3", "D4", "D5", "S5")
T1_METHOD_ID <- "mra_haar_J5"
T1_SCALE <- "raw"
T1_VALIDITY <- "basic"
T1_SEED <- 7L
T1_FORECAST_STRATEGY <- "recursive_hstep"
T1_SPLIT_ID <- "chrono_split_tvt"
T1_DECOMP_ID <- "mra_haar_J5__raw"

t1_out_dir <- function() file.path(RES_DIR, "teammate_1")
t1_plot_dir <- function() file.path(t1_out_dir(), "plots")
t1_cache_path <- function() file.path(t1_out_dir(), "_job_cache.rds")

t1_forbidden_write_paths <- function() {
  c(
    file.path(RES_DIR, "forecast_cache.rds"),
    file.path(RES_DIR, "scores.rds"),
    file.path(RES_DIR, "scores.csv"),
    file.path(RES_DIR, "hparams.rds"),
    file.path(RES_DIR, "conformal.rds"),
    file.path(RES_DIR, "conformal_ext.rds"),
    file.path(RES_DIR, "teammate_2")
  )
}

t1_assert_output_dir <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  allowed <- normalizePath(t1_out_dir(), winslash = "/", mustWork = FALSE)
  if (!startsWith(tolower(path), tolower(allowed))) {
    stop("T1 may only write under results/teammate_1/. Refused: ", path)
  }
  invisible(path)
}

t1_dir_create <- function() {
  dir.create(t1_out_dir(), recursive = TRUE, showWarnings = FALSE)
  dir.create(t1_plot_dir(), recursive = TRUE, showWarnings = FALSE)
  t1_out_dir()
}

# ---- frozen tree hyperparameters (never silently replaced) ----------------

t1_load_tree_params <- function() {
  hp_path <- file.path(RES_DIR, "hparams.rds")
  if (file.exists(hp_path)) {
    hp <- readRDS(hp_path)
    params <- hp$params
    if (is.null(params$p)) params <- default_tree_params()
    params$nrounds <- max(as.integer(params$nrounds %||% 120L), 120L)
    list(
      params = params,
      source = as.character(hp$reason %||% "results/hparams.rds"),
      J = min(as.integer(hp$J %||% 5L), 5L),
      path = hp_path
    )
  } else {
    list(
      params = default_tree_params(),
      source = "default_tree_params() because results/hparams.rds is missing",
      J = 5L,
      path = NA_character_
    )
  }
}

t1_model_ids <- function() {
  c("lgb" = "LightGBM", "xgb" = "XGBoost", "catboost" = "CatBoost",
    "sarima" = "SARIMA", "dlinear" = "DLinear")
}

t1_model_label <- function(id) {
  labs <- t1_model_ids()
  unname(labs[id] %||% id)
}

# ---- stored decomposition (read-only) -------------------------------------

t1_decomp_parquet_path <- function(station, variable,
                                   method_id = T1_METHOD_ID,
                                   scale = T1_SCALE) {
  decomp_parquet_path(method_full_id(method_id, scale), station, variable)
}

t1_file_fingerprint <- function(path) {
  info <- file.info(path)
  list(
    path = path,
    size = unname(info$size),
    mtime = unname(info$mtime),
    md5 = unname(tools::md5sum(path))
  )
}

t1_load_stored_components <- function(station, variable,
                                      method_id = T1_METHOD_ID,
                                      scale = T1_SCALE) {
  path <- t1_decomp_parquet_path(station, variable, method_id, scale)
  if (!file.exists(path)) {
    stop("Stored decomposition missing (T1 must not recompute): ", path)
  }
  before <- t1_file_fingerprint(path)
  df <- get_decomp(station, variable, method_id, scale, validity = T1_VALIDITY)
  after <- t1_file_fingerprint(path)
  if (!identical(before$md5, after$md5) || !identical(before$size, after$size)) {
    stop("get_decomp mutated the stored parquet: ", path)
  }
  missing <- setdiff(T1_COMPONENTS, names(df))
  if (length(missing)) {
    stop("Stored decomposition is missing components: ",
         paste(missing, collapse = ", "))
  }
  flag <- paste0("valid_", T1_VALIDITY)
  df$t1_valid <- if (flag %in% names(df)) as.logical(df[[flag]]) else TRUE
  attr(df, "t1_source_path") <- path
  attr(df, "t1_source_md5") <- before$md5
  attr(df, "t1_method_id") <- method_id
  attr(df, "t1_scale") <- scale
  df
}

t1_load_prepared_series <- function() {
  path <- file.path(PROC_DIR, "series.rds")
  if (!file.exists(path)) {
    stop("Need data/processed/series.rds from the original pipeline; ",
         "T1 will not re-run preprocessing.")
  }
  obj <- readRDS(path)
  series <- if (is.list(obj) && !is.null(obj$series)) obj$series else obj
  series
}

t1_hour_key <- function(times, tz = NULL) {
  times <- as.POSIXct(times)
  if (is.null(tz)) {
    format(times, "%Y-%m-%d %H")
  } else {
    format(lubridate::with_tz(times, tz), "%Y-%m-%d %H", tz = tz)
  }
}

t1_match_timestamps <- function(series_times, decomp_times) {
  attempts <- list(
    native = match(t1_hour_key(series_times), t1_hour_key(decomp_times)),
    utc = match(t1_hour_key(series_times, "UTC"), t1_hour_key(decomp_times, "UTC")),
    ist = match(t1_hour_key(series_times, "Asia/Kolkata"),
                t1_hour_key(decomp_times, "Asia/Kolkata")),
    series_utc_decomp_ist = match(t1_hour_key(series_times, "UTC"),
                                  t1_hour_key(decomp_times, "Asia/Kolkata")),
    series_ist_decomp_utc = match(t1_hour_key(series_times, "Asia/Kolkata"),
                                  t1_hour_key(decomp_times, "UTC"))
  )
  n_hit <- vapply(attempts, function(z) sum(!is.na(z)), integer(1))
  attempts[[which.max(n_hit)]]
}

t1_align_components <- function(series_obj, decomp_df) {
  times <- series_obj$times
  y <- as.numeric(series_obj$y)
  n <- length(y)
  out <- tibble::tibble(timestamp = times, y = y)
  idx <- t1_match_timestamps(times, decomp_df$timestamp)
  for (nm in T1_COMPONENTS) {
    vec <- rep(NA_real_, n)
    hit <- !is.na(idx)
    raw <- as.numeric(decomp_df[[nm]])
    vec[hit] <- raw[idx[hit]]
    valid <- rep(FALSE, n)
    if ("t1_valid" %in% names(decomp_df)) {
      valid[hit] <- isTRUE(decomp_df$t1_valid[idx[hit]]) |
        decomp_df$t1_valid[idx[hit]] %in% TRUE
    } else {
      valid[hit] <- is.finite(vec[hit])
    }
    vec[!valid] <- NA_real_
    out[[nm]] <- vec
  }
  recon <- rowSums(as.matrix(out[, T1_COMPONENTS]), na.rm = FALSE)
  out$recon_stored <- recon
  n_ok <- sum(stats::complete.cases(out[, T1_COMPONENTS]))
  if (n_ok < 500L) {
    stop("Aligned stored components have only ", n_ok,
         " complete rows; refusing to proceed (timestamp mismatch?).")
  }
  out
}

t1_independent_lags <- function(y, p) {
  y <- as.numeric(y)
  X <- make_lags(y, p)
  if (is.null(colnames(X)) || !all(grepl("^lag[0-9]+$", colnames(X)))) {
    stop("Independent lag matrix must use lag1..lagp names only.")
  }
  extra <- setdiff(colnames(X), paste0("lag", seq_len(ncol(X))))
  if (length(extra)) stop("Unexpected lag columns: ", paste(extra, collapse = ","))
  attr(X, "t1_n_features") <- ncol(X)
  attr(X, "t1_feature_names") <- colnames(X)
  attr(X, "t1_source_is_univariate") <- TRUE
  X
}

# ---- DLinear (OLS, causal moving average; not added to R/06_models.R) -----

t1_causal_ma <- function(y, kernel = 25L) {
  y <- as.numeric(y)
  k <- max(3L, as.integer(kernel))
  n <- length(y)
  trend <- rep(NA_real_, n)
  csum <- c(0, cumsum(ifelse(is.finite(y), y, 0)))
  cfin <- c(0, cumsum(as.integer(is.finite(y))))
  for (t in seq_len(n)) {
    lo <- max(1L, t - k + 1L)
    nf <- cfin[t + 1L] - cfin[lo]
    if (nf < 1L) next
    trend[t] <- (csum[t + 1L] - csum[lo]) / nf
  }
  trend
}

t1_ols_fit <- function(X, y) {
  keep <- is.finite(y) & rowSums(!is.finite(X)) == 0
  if (sum(keep) < ncol(X) + 2L) return(NULL)
  coef <- tryCatch(
    qr.solve(cbind(1, X[keep, , drop = FALSE]), y[keep]),
    error = function(e) NULL
  )
  if (is.null(coef) || !all(is.finite(coef))) return(NULL)
  as.numeric(coef)
}

t1_dlinear_tune_grid <- function(smoke = FALSE) {
  if (isTRUE(smoke)) return(list(kernel = 25L, p = NA_integer_))
  list(kernel = c(13L, 25L), p = NA_integer_)
}

t1_fit_dlinear <- function(y, p = 24L, kernel = 25L) {
  y <- as.numeric(y)
  p <- as.integer(p)
  kernel <- as.integer(kernel)
  trend <- t1_causal_ma(y, kernel)
  seas <- y - trend
  n <- length(y)
  if (n <= p + 2L) {
    return(list(
      family = "dlinear", p = p, kernel = kernel,
      coef_trend = c(0, rep(1 / p, p)),
      coef_seas = c(0, rep(1 / p, p)),
      fallback = TRUE
    ))
  }
  X_tr <- matrix(NA_real_, n - p, p)
  X_se <- matrix(NA_real_, n - p, p)
  y_tr <- trend[(p + 1L):n]
  y_se <- seas[(p + 1L):n]
  for (k in seq_len(p)) {
    X_tr[, k] <- trend[(p + 1L - k):(n - k)]
    X_se[, k] <- seas[(p + 1L - k):(n - k)]
  }
  ct <- t1_ols_fit(X_tr, y_tr)
  cs <- t1_ols_fit(X_se, y_se)
  if (is.null(ct)) ct <- c(mean(y_tr, na.rm = TRUE), rep(0, p))
  if (is.null(cs)) cs <- c(mean(y_se, na.rm = TRUE), rep(0, p))
  list(
    family = "dlinear", p = p, kernel = kernel,
    coef_trend = ct, coef_seas = cs, fallback = FALSE
  )
}

t1_dlinear_one_step <- function(fit, y) {
  y <- as.numeric(y)
  p <- fit$p
  if (length(y) < p) y <- c(rep(y[1], p - length(y)), y)
  trend <- t1_causal_ma(y, fit$kernel)
  seas <- y - trend
  lag_t <- rev(tail(trend, p))
  lag_s <- rev(tail(seas, p))
  lag_t[!is.finite(lag_t)] <- 0
  lag_s[!is.finite(lag_s)] <- 0
  tr <- fit$coef_trend[1] + sum(fit$coef_trend[-1] * lag_t)
  se <- fit$coef_seas[1] + sum(fit$coef_seas[-1] * lag_s)
  out <- tr + se
  if (!is.finite(out)) out <- tail(y[is.finite(y)], 1)
  out
}

t1_forecast_dlinear <- function(fit, y_hist, h) {
  y <- as.numeric(y_hist)
  fc <- numeric(h)
  for (i in seq_len(h)) {
    fc[i] <- t1_dlinear_one_step(fit, y)
    y <- c(y, fc[i])
  }
  fc
}

t1_tune_dlinear <- function(y_train, y_val, p, kernel_grid, h) {
  h_val <- min(as.integer(h), length(y_val))
  scores <- lapply(as.integer(kernel_grid), function(k) {
    set.seed(T1_SEED)
    fit <- t1_fit_dlinear(y_train, p = p, kernel = k)
    yhat <- t1_forecast_dlinear(fit, y_train, h_val)
    mae_k <- mae(y_val[seq_len(h_val)], yhat)
    list(kernel = k, mae = mae_k, fit = fit, yhat = yhat)
  })
  maes <- vapply(scores, `[[`, numeric(1), "mae")
  best <- scores[[which.min(maes)]]
  best$grid <- as.integer(kernel_grid)
  best$selection_split <- "validation"
  best
}

# ---- fit / forecast wrappers (reuse original implementations) -------------

t1_drop_leading_na <- function(y) {
  y <- as.numeric(y)
  ok <- which(is.finite(y))
  if (!length(ok)) return(numeric())
  y[min(ok):length(y)]
}

t1_fit_sarima_component <- function(y) {
  # Same call as wave_fit_sarima() in R/06_models.R (seasonal = FALSE).
  forecast::auto.arima(
    stats::ts(as.numeric(y), frequency = SEASONALITY),
    stepwise = TRUE, approximation = TRUE, seasonal = FALSE,
    max.p = 3, max.q = 1, max.d = 1, trace = FALSE
  )
}

t1_tree_uses_minmax <- function(model_id) {
  model_id %in% c("lgb", "xgb", "catboost", "dlinear")
}

t1_complexity <- function(model_id, fit, params, extra = list()) {
  p <- as.integer(params$p %||% extra$p %||% 24L)
  if (model_id %in% c("lgb", "xgb", "catboost")) {
    nr <- as.integer(params$nrounds %||% 120L)
    dp <- as.integer(params$max_depth %||% 6L)
    return(list(
      model_complexity = as.numeric(nr * dp * p),
      complexity_note = sprintf("nrounds=%s * depth=%s * p=%s", nr, dp, p)
    ))
  }
  if (identical(model_id, "dlinear")) {
    k <- as.integer(extra$kernel %||% fit$kernel %||% 25L)
    return(list(
      model_complexity = as.numeric(2L * (p + 1L) + k),
      complexity_note = sprintf("2*(p+1)+kernel = 2*(%s+1)+%s", p, k)
    ))
  }
  if (identical(model_id, "sarima") && !is.null(fit$arma)) {
    ord <- forecast::arimaorder(fit)
    val <- sum(as.numeric(ord), na.rm = TRUE)
    return(list(
      model_complexity = val,
      complexity_note = paste(names(ord), ord, sep = "=", collapse = ",")
    ))
  }
  list(model_complexity = NA_real_, complexity_note = NA_character_)
}

t1_hparams_json <- function(model_id, params, extra = list()) {
  hp <- list(
    p = params$p,
    nrounds = params$nrounds,
    max_depth = params$max_depth,
    eta = params$eta,
    early_stopping = params$early_stopping,
    val_hours = params$val_hours,
    lgb_leaves = params$lgb_leaves
  )
  hp <- hp[!vapply(hp, is.null, logical(1))]
  if (identical(model_id, "dlinear")) {
    hp <- list(
      p = extra$p %||% params$p,
      kernel = extra$kernel,
      trend = "causal_moving_average",
      seasonal = "ols_linear",
      tune = "validation_only_kernel_grid"
    )
  }
  if (identical(model_id, "sarima")) {
    hp <- list(
      seasonal = FALSE,
      stepwise = TRUE,
      approximation = TRUE,
      max.p = 3, max.q = 1, max.d = 1,
      source = "wave_fit_sarima"
    )
    if (!is.null(extra$arimaorder)) hp$arimaorder <- extra$arimaorder
  }
  jsonlite::toJSON(hp, auto_unbox = TRUE)
}

t1_random_seed <- function(model_id) {
  if (model_id %in% c("catboost", "dlinear", "sarima")) T1_SEED else NA_integer_
}

t1_fit_forecast_component <- function(model_id, y_hist, h, params,
                                      dlinear_kernel = 25L) {
  y_hist <- t1_drop_leading_na(y_hist)
  if (length(y_hist) < max(48L, as.integer(params$p) + 8L)) {
    stop("Not enough finite history for ", model_id)
  }
  # Confirm lag features would be univariate if this model uses lags.
  invisible(t1_independent_lags(y_hist, params$p))

  scaler <- NULL
  y_work <- y_hist
  if (t1_tree_uses_minmax(model_id)) {
    scaler <- minmax_fit(y_hist)
    y_work <- minmax_apply(y_hist, scaler)
  }

  t0 <- proc.time()[["elapsed"]]
  extra <- list()
  if (identical(model_id, "lgb")) {
    fit <- fit_lgb(y_work, params)
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- recursive_tree_forecast(fit, y_work, h)
    t_pred <- proc.time()[["elapsed"]] - t1
  } else if (identical(model_id, "xgb")) {
    fit <- fit_xgb(y_work, params)
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- recursive_tree_forecast(fit, y_work, h)
    t_pred <- proc.time()[["elapsed"]] - t1
  } else if (identical(model_id, "catboost")) {
    fit <- fit_cat(y_work, params)
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- recursive_tree_forecast(fit, y_work, h)
    t_pred <- proc.time()[["elapsed"]] - t1
  } else if (identical(model_id, "dlinear")) {
    set.seed(T1_SEED)
    fit <- t1_fit_dlinear(y_work, p = params$p, kernel = dlinear_kernel)
    extra$kernel <- dlinear_kernel
    extra$p <- params$p
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- t1_forecast_dlinear(fit, y_work, h)
    t_pred <- proc.time()[["elapsed"]] - t1
  } else if (identical(model_id, "sarima")) {
    set.seed(T1_SEED)
    fit <- t1_fit_sarima_component(y_hist)
    extra$arimaorder <- as.numeric(forecast::arimaorder(fit))
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- forecast_arima_obj(fit, h)
    t_pred <- proc.time()[["elapsed"]] - t1
    scaler <- NULL
  } else {
    stop("Unknown T1 model: ", model_id)
  }

  yhat <- if (is.null(scaler)) as.numeric(yhat_s) else minmax_invert(yhat_s, scaler)
  cx <- t1_complexity(model_id, fit, params, extra)
  list(
    yhat = as.numeric(yhat),
    fit = fit,
    train_time_sec = as.numeric(t_train),
    pred_time_sec = as.numeric(t_pred),
    model_complexity = cx$model_complexity,
    complexity_note = cx$complexity_note,
    hyperparams = t1_hparams_json(model_id, params, extra),
    extra = extra
  )
}

# ---- splits (must match shared chrono_split_tvt) --------------------------

t1_split_y <- function(series_obj, h) {
  chrono_split_tvt(series_obj$y, series_obj$times, as.integer(h), VAL_HOURS)
}

t1_component_split <- function(aligned, component, sp) {
  x <- as.numeric(aligned[[component]])
  list(
    train = x[seq_len(sp$n_train)],
    val = x[(sp$n_train + 1L):(sp$n_train + sp$n_val)],
    test = x[(sp$n_train + sp$n_val + 1L):length(x)],
    fit = x[seq_len(sp$n_train + sp$n_val)],
    t_train = sp$t_train,
    t_val = sp$t_val,
    t_test = sp$t_test
  )
}

t1_job_key <- function(sensor, pollutant, horizon, component, model_id, stage) {
  paste(sensor, pollutant, horizon, component, model_id, stage, sep = "|")
}

t1_load_cache <- function() {
  path <- t1_cache_path()
  if (file.exists(path)) readRDS(path) else list()
}

t1_save_cache <- function(cache) {
  t1_dir_create()
  t1_assert_output_dir(t1_cache_path())
  saveRDS(cache, t1_cache_path())
}

t1_score_row <- function(model_id, component, horizon, stage, sensor, pollutant,
                         y_train, y_true, yhat, train_time, pred_time,
                         complexity, complexity_note, hyperparams, params_source) {
  h_use <- min(length(y_true), length(yhat))
  y_true <- as.numeric(y_true)[seq_len(h_use)]
  yhat <- as.numeric(yhat)[seq_len(h_use)]
  y_train_mase <- as.numeric(y_train)[is.finite(y_train)]
  ok <- is.finite(y_true) & is.finite(yhat)
  n_eval <- sum(ok)
  if (n_eval < 1L || length(y_train_mase) < (SEASONALITY + 2L)) {
    sc <- tibble::tibble(MASE = NA_real_, MAE = NA_real_, RMSE = NA_real_)
  } else {
    sc <- score_forecast(y_train_mase, y_true[ok], yhat[ok])
  }
  tibble::tibble(
    model = t1_model_label(model_id),
    model_id = model_id,
    component = component,
    horizon = horizon,
    horizon_hours = as.integer(HORIZONS[[horizon]]),
    forecast_strategy = T1_FORECAST_STRATEGY,
    stage = stage,
    n_eval = n_eval,
    MAE = sc$MAE,
    RMSE = sc$RMSE,
    MASE = sc$MASE,
    training_time_sec = train_time,
    prediction_time_sec = pred_time,
    model_complexity = complexity,
    complexity_note = complexity_note,
    hyperparameters = as.character(hyperparams),
    random_seed = t1_random_seed(model_id),
    dataset = paste(sensor, pollutant, sep = "_"),
    sensor = sensor,
    pollutant = pollutant,
    split_id = T1_SPLIT_ID,
    decomp_id = T1_DECOMP_ID,
    validity = T1_VALIDITY,
    params_source = params_source
  )
}

t1_run_one_job <- function(aligned, series_obj, sensor, pollutant, horizon,
                           component, model_id, params, params_source,
                           stage, cache, dlinear_kernel = 25L,
                           save_every = TRUE) {
  h <- as.integer(HORIZONS[[horizon]])
  sp <- t1_split_y(series_obj, h)
  cs <- t1_component_split(aligned, component, sp)
  if (identical(stage, "val")) {
    y_hist <- cs$train
    y_true <- cs$val
    h_fc <- min(h, length(y_true))
    y_true <- y_true[seq_len(h_fc)]
    times_out <- cs$t_val[seq_len(h_fc)]
  } else if (identical(stage, "test")) {
    y_hist <- cs$fit
    y_true <- cs$test
    h_fc <- h
    times_out <- cs$t_test
  } else {
    stop("stage must be val or test")
  }
  key <- t1_job_key(sensor, pollutant, horizon, component, model_id, stage)
  if (!is.null(cache[[key]])) {
    rec <- cache[[key]]
    rec$y_true <- as.numeric(y_true)
    rec$times <- times_out
    rec$n_true <- length(y_true)
    rec$metrics <- t1_score_row(
      model_id, component, horizon, stage, sensor, pollutant,
      y_hist, y_true, rec$yhat, rec$metrics$training_time_sec,
      rec$metrics$prediction_time_sec, rec$metrics$model_complexity,
      rec$metrics$complexity_note, rec$hyperparams %||% rec$metrics$hyperparameters,
      params_source
    )
    cache[[key]] <- rec
    return(cache)
  }

  ran <- t1_fit_forecast_component(model_id, y_hist, h_fc, params, dlinear_kernel)
  metrics <- t1_score_row(
    model_id, component, horizon, stage, sensor, pollutant,
    y_hist, y_true, ran$yhat, ran$train_time_sec, ran$pred_time_sec,
    ran$model_complexity, ran$complexity_note, ran$hyperparams, params_source
  )
  cache[[key]] <- list(
    metrics = metrics,
    yhat = as.numeric(ran$yhat),
    y_true = as.numeric(y_true),
    times = times_out,
    hyperparams = ran$hyperparams,
    extra = ran$extra,
    n_train = length(y_hist),
    n_true = length(y_true)
  )
  if (isTRUE(save_every)) t1_save_cache(cache)
  cache
}

t1_select_best <- function(metrics_df) {
  val <- metrics_df[metrics_df$stage == "validation" | metrics_df$stage == "val", ]
  if (!nrow(val)) stop("No validation metrics; refusing to select on test.")
  if (any(val$stage %in% c("test", "holdout"))) {
    stop("Validation table contains test rows.")
  }
  val %>%
    dplyr::group_by(.data$sensor, .data$pollutant, .data$component, .data$model_id, .data$model) %>%
    dplyr::summarise(
      mean_val_MASE = mean(.data$MASE, na.rm = TRUE),
      mean_val_MAE = mean(.data$MAE, na.rm = TRUE),
      n_horizons = dplyr::n(),
      hyperparameters = dplyr::first(.data$hyperparameters),
      random_seed = dplyr::first(.data$random_seed),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      mean_val_MASE = ifelse(is.finite(.data$mean_val_MASE), .data$mean_val_MASE, Inf)
    ) %>%
    dplyr::group_by(.data$sensor, .data$pollutant, .data$component) %>%
    dplyr::arrange(.data$mean_val_MASE, .data$mean_val_MAE, .by_group = TRUE) %>%
    dplyr::slice(1L) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(selected_on = "validation", used_test = FALSE)
}

t1_baselines_from_scores <- function(sensor, pollutant, horizon) {
  path <- file.path(RES_DIR, "scores.csv")
  if (!file.exists(path)) return(tibble::tibble())
  sc <- readr::read_csv(
    path, show_col_types = FALSE,
    col_types = readr::cols(
      sensor = readr::col_character(),
      pollutant = readr::col_character(),
      horizon = readr::col_character(),
      method = readr::col_character(),
      .default = readr::col_double()
    )
  )
  sc$horizon <- as.character(sc$horizon)
  sc <- sc[sc$sensor == sensor & sc$pollutant == pollutant, , drop = FALSE]
  h <- as.character(horizon)
  if (h %in% sc$horizon) {
    sc <- sc[sc$horizon == h, , drop = FALSE]
  } else if (gsub("d$", "", h) %in% sc$horizon) {
    sc <- sc[sc$horizon == gsub("d$", "", h), , drop = FALSE]
    sc$horizon <- h
  } else {
    sc <- sc[0, , drop = FALSE]
  }
  tibble::as_tibble(sc)
}

t1_default_config <- function(mode = "full") {
  mode <- tolower(mode)
  hp <- t1_load_tree_params()
  list(
    mode = mode,
    sensors = if (identical(mode, "smoke")) "CPCB" else SENSORS_PAPER,
    pollutants = "PM2.5",
    horizons = if (identical(mode, "smoke")) "1d" else names(HORIZONS),
    models = names(t1_model_ids()),
    components = T1_COMPONENTS,
    params = hp$params,
    params_source = hp$source,
    dlinear_kernels = if (identical(mode, "smoke")) 25L else c(13L, 25L),
    skip_sarima = FALSE
  )
}

t1_run <- function(mode = "smoke") {
  cfg <- t1_default_config(mode)
  t1_dir_create()
  message("T1 mode=", cfg$mode,
          " sensors=", paste(cfg$sensors, collapse = ","),
          " horizons=", paste(cfg$horizons, collapse = ","),
          " params: ", cfg$params_source)
  series_all <- t1_load_prepared_series()
  cache <- t1_load_cache()
  metric_rows <- list()
  pred_store <- list()

  for (sensor in cfg$sensors) {
    for (pollutant in cfg$pollutants) {
      key <- paste(sensor, pollutant, sep = "_")
      if (!key %in% names(series_all)) {
        warning("Missing prepared series ", key, "; skip.")
        next
      }
      series_obj <- series_all[[key]]
      decomp <- t1_load_stored_components(sensor, pollutant)
      aligned <- t1_align_components(series_obj, decomp)

      for (horizon in cfg$horizons) {
        h <- as.integer(HORIZONS[[horizon]])
        sp <- t1_split_y(series_obj, h)
        dlin_kernel_by_comp <- list()

        for (comp in cfg$components) {
          cs <- t1_component_split(aligned, comp, sp)
          # Validation-only DLinear kernel pick (never uses test).
          if ("dlinear" %in% cfg$models) {
            tun <- t1_tune_dlinear(
              t1_drop_leading_na(cs$train), cs$val,
              p = cfg$params$p, kernel_grid = cfg$dlinear_kernels, h = h
            )
            dlin_kernel_by_comp[[comp]] <- tun$kernel
          }

          for (mid in cfg$models) {
            if (identical(mid, "sarima") && isTRUE(cfg$skip_sarima)) next
            k_use <- dlin_kernel_by_comp[[comp]] %||% 25L
            message("T1 ", sensor, " ", pollutant, " ", horizon, " ",
                    comp, " ", mid, " val")
            cache <- tryCatch(
              t1_run_one_job(aligned, series_obj, sensor, pollutant, horizon,
                             comp, mid, cfg$params, cfg$params_source,
                             "val", cache, dlinear_kernel = k_use),
              error = function(e) {
                warning("VAL failed ", sensor, "/", horizon, "/", comp, "/",
                        mid, ": ", e$message)
                cache
              }
            )
            message("T1 ", sensor, " ", pollutant, " ", horizon, " ",
                    comp, " ", mid, " test")
            cache <- tryCatch(
              t1_run_one_job(aligned, series_obj, sensor, pollutant, horizon,
                             comp, mid, cfg$params, cfg$params_source,
                             "test", cache, dlinear_kernel = k_use),
              error = function(e) {
                warning("TEST failed ", sensor, "/", horizon, "/", comp, "/",
                        mid, ": ", e$message)
                cache
              }
            )
          }
        }
      }
    }
  }

  keys <- names(cache)
  for (k in keys) {
    rec <- cache[[k]]
    if (is.null(rec$metrics)) next
    metric_rows[[k]] <- rec$metrics
    pred_store[[k]] <- rec[c("yhat", "y_true", "times", "hyperparams")]
  }
  metrics <- dplyr::bind_rows(lapply(metric_rows, function(x) {
    x$hyperparameters <- as.character(x$hyperparameters)
    x
  }))
  if (!nrow(metrics)) stop("T1 produced no metrics. Check stored decomp and series.rds.")
  metrics$stage <- dplyr::recode(metrics$stage, val = "validation", test = "test")

  best <- t1_select_best(metrics)
  hetero <- t1_build_heterogeneous(cache, best, series_all, cfg)
  recon <- t1_build_reconstructed(hetero, series_all)

  t1_write_outputs(metrics, pred_store, best, hetero, recon, cfg)
  t1_write_plots(metrics, best, recon)
  t1_write_report(metrics, best, recon, cfg)
  invisible(list(metrics = metrics, best = best, recon = recon, cfg = cfg))
}

t1_build_heterogeneous <- function(cache, best, series_all, cfg) {
  out <- list()
  for (i in seq_len(nrow(best))) {
    b <- best[i, ]
    for (horizon in cfg$horizons) {
      key <- t1_job_key(b$sensor, b$pollutant, horizon, b$component,
                        b$model_id, "test")
      rec <- cache[[key]]
      if (is.null(rec)) next
      id <- paste(b$sensor, b$pollutant, horizon, sep = "|")
      if (is.null(out[[id]])) {
        h <- as.integer(HORIZONS[[horizon]])
        skey <- paste(b$sensor, b$pollutant, sep = "_")
        sp <- t1_split_y(series_all[[skey]], h)
        out[[id]] <- list(
          sensor = b$sensor, pollutant = b$pollutant, horizon = horizon,
          times = rec$times, y_true = rec$y_true,
          y_level = as.numeric(sp$y_test),
          components = list(), selected = list()
        )
      }
      out[[id]]$components[[b$component]] <- rec$yhat
      out[[id]]$selected[[b$component]] <- b$model_id
    }
  }
  out
}

t1_build_reconstructed <- function(hetero, series_all) {
  lapply(hetero, function(item) {
    missing <- setdiff(T1_COMPONENTS, names(item$components))
    if (length(missing)) {
      warning("Reconstruction missing components: ", paste(missing, collapse = ","))
    }
    mats <- lapply(T1_COMPONENTS, function(nm) item$components[[nm]])
    n <- min(vapply(mats[!vapply(mats, is.null, logical(1))], length, integer(1)))
    yhat <- Reduce(`+`, lapply(mats, function(z) {
      if (is.null(z)) rep(0, n) else z[seq_len(n)]
    }))
    yhat_clip <- clip_impossible(yhat, item$pollutant)
    skey <- paste(item$sensor, item$pollutant, sep = "_")
    y_true <- as.numeric(item$y_level)[seq_len(n)]
    y_fit <- series_all[[skey]]$y
    h <- as.integer(HORIZONS[[item$horizon]])
    sp <- chrono_split_tvt(y_fit, series_all[[skey]]$times, h)
    sc <- score_forecast(sp$y_fit, y_true, yhat_clip)
    baselines <- t1_baselines_from_scores(item$sensor, item$pollutant, item$horizon)
    item$yhat <- yhat
    item$yhat_clip <- yhat_clip
    item$y_true_level <- y_true
    item$n_components_used <- sum(!vapply(item$components[T1_COMPONENTS], is.null, logical(1)))
    item$metrics <- sc
    item$baselines <- baselines
    item$used_all_six <- identical(sort(names(item$components)), sort(T1_COMPONENTS))
    item
  })
}

t1_write_outputs <- function(metrics, pred_store, best, hetero, recon, cfg) {
  t1_dir_create()
  mpath <- file.path(t1_out_dir(), "component_metrics.csv")
  bpath <- file.path(t1_out_dir(), "best_models.csv")
  ppath <- file.path(t1_out_dir(), "component_predictions.rds")
  hpath <- file.path(t1_out_dir(), "heterogeneous_predictions.rds")
  rpath <- file.path(t1_out_dir(), "reconstructed_predictions.rds")
  lapply(c(mpath, bpath, ppath, hpath, rpath), t1_assert_output_dir)
  readr::write_csv(metrics, mpath)
  readr::write_csv(best, bpath)
  saveRDS(pred_store, ppath)
  saveRDS(hetero, hpath)
  saveRDS(recon, rpath)
  saveRDS(cfg, file.path(t1_out_dir(), "_run_config.rds"))
  message("Wrote T1 outputs under ", t1_out_dir())
}

t1_write_plots <- function(metrics, best, recon) {
  t1_dir_create()
  val <- dplyr::filter(metrics, .data$stage == "validation")
  if (nrow(val)) {
    p1 <- ggplot2::ggplot(val, ggplot2::aes(.data$component, .data$model,
                                            fill = .data$MASE)) +
      ggplot2::geom_tile() +
      ggplot2::facet_wrap(~horizon) +
      ggplot2::scale_fill_viridis_c(option = "C") +
      ggplot2::labs(title = "T1 validation MASE (model selection)",
                    x = "Component", y = "Model") +
      ggplot2::theme_minimal(base_size = 11)
    ggplot2::ggsave(file.path(t1_plot_dir(), "val_mase_heatmap.png"),
                    p1, width = 9, height = 5, dpi = 120)
  }
  te <- dplyr::filter(metrics, .data$stage == "test")
  if (nrow(te)) {
    p2 <- ggplot2::ggplot(te, ggplot2::aes(.data$component, .data$MASE,
                                           colour = .data$model)) +
      ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.4)) +
      ggplot2::facet_wrap(~horizon, scales = "free_y") +
      ggplot2::labs(title = "T1 independent component test MASE",
                    x = "Component", y = "MASE") +
      ggplot2::theme_minimal(base_size = 11)
    ggplot2::ggsave(file.path(t1_plot_dir(), "test_component_mase.png"),
                    p2, width = 9, height = 5, dpi = 120)
  }
  recon_rows <- dplyr::bind_rows(lapply(names(recon), function(nm) {
    item <- recon[[nm]]
    tibble::tibble(
      sensor = item$sensor, pollutant = item$pollutant, horizon = item$horizon,
      method = "T1_heterogeneous",
      MASE = item$metrics$MASE, MAE = item$metrics$MAE, RMSE = item$metrics$RMSE
    )
  }))
  base_rows <- dplyr::bind_rows(lapply(recon, function(item) {
    if (is.null(item$baselines) || !nrow(item$baselines)) return(NULL)
    item$baselines %>%
      dplyr::filter(.data$method %in% c("wavecatboost", "wavelgb", "wavexgb",
                                        "catboost", "lgb", "xgb", "snaive",
                                        "sarima")) %>%
      dplyr::select(.data$sensor, .data$pollutant, .data$horizon,
                    .data$method, .data$MASE, .data$MAE, .data$RMSE)
  }))
  cmp <- dplyr::bind_rows(recon_rows, base_rows)
  if (nrow(recon_rows)) {
    cmp <- dplyr::filter(cmp, .data$horizon %in% unique(recon_rows$horizon))
  }
  if (nrow(cmp)) {
    p3 <- ggplot2::ggplot(cmp, ggplot2::aes(.data$method, .data$MASE,
                                            fill = .data$method)) +
      ggplot2::geom_col() +
      ggplot2::facet_grid(sensor ~ horizon, scales = "free_y") +
      ggplot2::coord_flip() +
      ggplot2::labs(title = "Reconstructed T1 vs original bake-off",
                    x = NULL, y = "MASE") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(legend.position = "none")
    ggplot2::ggsave(file.path(t1_plot_dir(), "reconstruction_vs_baselines.png"),
                    p3, width = 10, height = 6, dpi = 120)
  }
  # 1d actual vs reconstructed if present
  one <- recon[grepl("\\|1d$", names(recon))]
  if (length(one)) {
    item <- one[[1]]
    df <- tibble::tibble(
      t = item$times[seq_along(item$yhat_clip)],
      actual = item$y_true_level,
      t1 = item$yhat_clip
    )
    p4 <- ggplot2::ggplot(df, ggplot2::aes(.data$t)) +
      ggplot2::geom_line(ggplot2::aes(y = .data$actual, colour = "actual")) +
      ggplot2::geom_line(ggplot2::aes(y = .data$t1, colour = "T1 hetero")) +
      ggplot2::labs(title = paste("T1 reconstructed", item$sensor, item$pollutant,
                                  item$horizon),
                    x = NULL, y = item$pollutant, colour = NULL) +
      ggplot2::theme_minimal(base_size = 11)
    ggplot2::ggsave(file.path(t1_plot_dir(), "reconstructed_1d_overlay.png"),
                    p4, width = 9, height = 4, dpi = 120)
  }
  invisible(TRUE)
}

t1_fmt <- function(x, d = 3) {
  ifelse(is.finite(x), format(round(x, d), nsmall = d), "NA")
}

t1_write_report <- function(metrics, best, recon, cfg) {
  path <- file.path(t1_out_dir(), "report.md")
  t1_assert_output_dir(path)
  val <- dplyr::filter(metrics, .data$stage == "validation")
  te <- dplyr::filter(metrics, .data$stage == "test")
  recon_lines <- vapply(names(recon), function(nm) {
    item <- recon[[nm]]
    wc <- NA_real_
    if (!is.null(item$baselines) && nrow(item$baselines)) {
      hit <- item$baselines$method == "wavecatboost"
      if (any(hit)) wc <- item$baselines$MASE[hit][1]
    }
    sprintf("- `%s`: T1 reconstructed MASE=%s MAE=%s RMSE=%s | WaveCatBoost MASE=%s | all six components=%s",
            nm, t1_fmt(item$metrics$MASE), t1_fmt(item$metrics$MAE),
            t1_fmt(item$metrics$RMSE), t1_fmt(wc),
            isTRUE(item$used_all_six))
  }, character(1))
  best_lines <- apply(best, 1, function(r) {
    sprintf("- %s %s %s -> **%s** (mean val MASE=%s)",
            r[["sensor"]], r[["pollutant"]], r[["component"]],
            r[["model"]], t1_fmt(as.numeric(r[["mean_val_MASE"]])))
  })
  md <- c(
    "# T1 Frequency-specific model selection",
    "",
    "Independent per-component forecasts of stored Haar MODWT/MRA bands **D1–D5** and **S5**.",
    "Cross-frequency features are out of scope (T2). Original WaveCatBoost is not modified.",
    "",
    "## Frozen pipeline",
    "",
    sprintf("- Decomposition: stored `%s` via `get_decomp()` (never recomputed).", T1_DECOMP_ID),
    "- Preprocess / imputation / MinMax helpers: original `R/03_preprocess.R`.",
    sprintf("- Splits: `%s` with nested last-h test windows and val_hours=%s.", T1_SPLIT_ID, VAL_HOURS),
    sprintf("- Horizons (hours): %s.", paste(unlist(HORIZONS), collapse = ", ")),
    "- Forecast origin: end of train (val stage) or end of train+val (test stage).",
    "- Leakage control: recursive h-step; lags from the target component only.",
    sprintf("- Tree hyperparameters source: %s.", cfg$params_source),
    "- Component SARIMA: same `auto.arima(..., seasonal=FALSE, max.p=3, max.q=1, max.d=1)` call as `wave_fit_sarima()`.",
    "- DLinear: causal moving-average + two OLS linear maps (Zeng et al. 2023 structure, no Torch). Kernel chosen on validation only.",
    "- Reconstruction: `Y_hat = D1_hat + D2_hat + D3_hat + D4_hat + D5_hat + S5_hat`.",
    "- Outputs written only under `results/teammate_1/`.",
    "",
    "## Run configuration",
    "",
    sprintf("- Mode: `%s`", cfg$mode),
    sprintf("- Sensors: %s", paste(cfg$sensors, collapse = ", ")),
    sprintf("- Pollutants: %s", paste(cfg$pollutants, collapse = ", ")),
    sprintf("- Horizons: %s", paste(cfg$horizons, collapse = ", ")),
    sprintf("- Models: %s", paste(t1_model_label(cfg$models), collapse = ", ")),
    sprintf("- Random seed recorded: %s (CatBoost/DLinear/SARIMA). XGBoost/LightGBM match original unseeded fitters.", T1_SEED),
    "",
    "## Heterogeneous selection (validation only)",
    "",
    "Best model per component = lowest mean validation MASE across the horizons in this run.",
    "Test metrics were stored for comparison but **were not read by `t1_select_best()`**.",
    "",
    best_lines,
    "",
    "## Reconstructed PM2.5 vs original bake-off",
    "",
    recon_lines,
    "",
    "## Metric files",
    "",
    "- `component_metrics.csv`",
    "- `component_predictions.rds`",
    "- `best_models.csv`",
    "- `heterogeneous_predictions.rds`",
    "- `reconstructed_predictions.rds`",
    "- `plots/`",
    "",
    sprintf("- Validation rows: %s. Test rows: %s.", nrow(val), nrow(te)),
    "",
    "## Tests actually executed",
    "",
    "See `tests_executed.md`. Safeguard suite: `Rscript tests/teammate_1/run_all.R`.",
    "This report is filled from a real `run_teammate_1.R` run, not placeholder numbers.",
    "",
    "## What this run is not",
    "",
    "- Not a recompute of MODWT.",
    "- Not T2 cross-frequency modelling.",
    "- Not a replacement of original `results/scores.csv` / WaveCatBoost.",
    ""
  )
  writeLines(md, path)
  path
}
