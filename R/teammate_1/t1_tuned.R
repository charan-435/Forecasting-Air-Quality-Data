# T1-Tuned: component-wise hyperparameter search with a FIXED architecture map.
# Reuses T1 loaders, splits, MinMax, lags, reconstruction, and scoring.
# Does not recompute MODWT, does not write original results/ or T2, does not
# change T1 model identities (D1/D2 LightGBM, D3 DLinear, D4 CatBoost,
# D5 SARIMA, S5 DLinear).

T1_TUNED_MAP <- c(
  D1 = "lgb",
  D2 = "lgb",
  D3 = "dlinear",
  D4 = "catboost",
  D5 = "sarima",
  S5 = "dlinear"
)

t1_tuned_out_dir <- function() file.path(RES_DIR, "teammate_1", "tuned")
t1_tuned_plot_dir <- function() file.path(t1_tuned_out_dir(), "plots")
t1_tuned_cache_path <- function() file.path(t1_tuned_out_dir(), "_job_cache.rds")

t1_tuned_dir_create <- function() {
  dir.create(t1_tuned_out_dir(), recursive = TRUE, showWarnings = FALSE)
  dir.create(t1_tuned_plot_dir(), recursive = TRUE, showWarnings = FALSE)
  t1_tuned_out_dir()
}

t1_tuned_assert <- function(path) {
  t1_assert_output_dir(path)
  invisible(path)
}

t1_tuned_mapping <- function() {
  stopifnot(identical(names(T1_TUNED_MAP), T1_COMPONENTS))
  T1_TUNED_MAP
}

# ---- search spaces --------------------------------------------------------
# DLinear in this repo is OLS + causal MA. It has no learning rate, epochs,
# batch size, weight decay, or dropout. Only `p` (lag window) and `kernel`.

t1_tuned_frozen_tree_params <- function() {
  hp <- t1_load_tree_params()$params
  list(
    p = as.integer(hp$p %||% 24L),
    nrounds = as.integer(hp$nrounds %||% 160L),
    max_depth = as.integer(hp$max_depth %||% 6L),
    eta = as.numeric(hp$eta %||% 0.05),
    early_stopping = as.integer(hp$early_stopping %||% 30L),
    val_hours = as.integer(hp$val_hours %||% VAL_HOURS),
    lgb_leaves = as.integer(hp$lgb_leaves %||% 31L),
    min_child_samples = 20L,
    feature_fraction = 0.8,
    lambda_l1 = 0,
    lambda_l2 = 0,
    l2_leaf_reg = 3,
    random_strength = 1,
    bagging_temperature = 1,
    is_frozen = TRUE
  )
}

t1_tuned_lgb_clamp_leaves <- function(max_depth, num_leaves) {
  d <- as.integer(max_depth)
  nl <- as.integer(num_leaves)
  if (is.finite(d) && d > 0L) nl <- min(nl, as.integer(2^d))
  max(2L, nl)
}

t1_tuned_sample_tbl <- function(grid, n, seed, frozen_row, valid_fn = NULL) {
  g <- expand.grid(grid, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  if (is.function(valid_fn)) {
    keep <- vapply(seq_len(nrow(g)), function(i) isTRUE(valid_fn(g[i, ])), logical(1))
    g <- g[keep, , drop = FALSE]
  }
  if ("lgb_leaves" %in% names(g) && "max_depth" %in% names(g)) {
    g$lgb_leaves <- mapply(t1_tuned_lgb_clamp_leaves, g$max_depth, g$lgb_leaves)
    g <- unique(g)
  }
  set.seed(as.integer(seed))
  n_take <- min(as.integer(n), nrow(g))
  pick <- if (n_take > 0L) g[sample.int(nrow(g), n_take), , drop = FALSE] else g[0, ]
  pick$is_frozen <- FALSE
  frozen_row$is_frozen <- TRUE
  extra <- setdiff(names(pick), names(frozen_row))
  for (nm in extra) frozen_row[[nm]] <- pick[[nm]][1]
  extra_f <- setdiff(names(frozen_row), names(pick))
  for (nm in extra_f) pick[[nm]] <- frozen_row[[nm]]
  out <- rbind(frozen_row[names(pick)], pick)
  out$trial_id <- seq_len(nrow(out)) - 1L
  rownames(out) <- NULL
  out
}

t1_tuned_lgb_candidates <- function(n, seed, frozen) {
  grid <- list(
    lgb_leaves = c(15L, 31L, 50L, 63L),
    max_depth = c(3L, 5L, 6L, 7L, -1L),
    eta = c(0.01, 0.03, 0.05, 0.08),
    nrounds = c(100L, 160L, 200L, 400L, 600L),
    min_child_samples = c(10L, 20L, 30L, 50L),
    feature_fraction = c(0.7, 0.8, 0.9, 1.0),
    lambda_l1 = c(0, 0.1, 1),
    lambda_l2 = c(0, 0.1, 1)
  )
  frozen_row <- data.frame(
    lgb_leaves = as.integer(frozen$lgb_leaves),
    max_depth = as.integer(frozen$max_depth),
    eta = as.numeric(frozen$eta),
    nrounds = as.integer(frozen$nrounds),
    min_child_samples = as.integer(frozen$min_child_samples),
    feature_fraction = as.numeric(frozen$feature_fraction),
    lambda_l1 = as.numeric(frozen$lambda_l1),
    lambda_l2 = as.numeric(frozen$lambda_l2),
    stringsAsFactors = FALSE
  )
  t1_tuned_sample_tbl(grid, n, seed, frozen_row)
}

t1_tuned_cat_candidates <- function(n, seed, frozen) {
  grid <- list(
    max_depth = c(4L, 6L, 8L, 10L),
    eta = c(0.01, 0.03, 0.05, 0.08),
    nrounds = c(160L, 200L, 400L, 600L, 800L),
    l2_leaf_reg = c(1, 3, 5, 7, 9),
    random_strength = c(0, 1, 10),
    bagging_temperature = c(0, 1, 5)
  )
  frozen_row <- data.frame(
    max_depth = as.integer(frozen$max_depth),
    eta = as.numeric(frozen$eta),
    nrounds = as.integer(frozen$nrounds),
    l2_leaf_reg = as.numeric(frozen$l2_leaf_reg),
    random_strength = as.numeric(frozen$random_strength),
    bagging_temperature = as.numeric(frozen$bagging_temperature),
    stringsAsFactors = FALSE
  )
  t1_tuned_sample_tbl(grid, n, seed, frozen_row)
}

t1_tuned_dlinear_candidates <- function(smoke = FALSE, frozen_p = 24L,
                                        frozen_kernel = 25L) {
  if (isTRUE(smoke)) {
    ps <- as.integer(frozen_p)
    ks <- unique(as.integer(c(frozen_kernel, 13L)))
  } else {
    ps <- c(12L, 24L, 48L, 72L)
    ks <- c(7L, 13L, 25L, 49L)
  }
  g <- expand.grid(p = ps, kernel = ks, KEEP.OUT.ATTRS = FALSE)
  g$is_frozen <- g$p == as.integer(frozen_p) & g$kernel == as.integer(frozen_kernel)
  if (!any(g$is_frozen)) {
    g <- rbind(data.frame(p = as.integer(frozen_p), kernel = as.integer(frozen_kernel),
                          is_frozen = TRUE), g)
  }
  g <- g[order(-g$is_frozen, g$p, g$kernel), , drop = FALSE]
  g$trial_id <- seq_len(nrow(g)) - 1L
  rownames(g) <- NULL
  g
}

t1_tuned_sarima_candidates <- function(smoke = FALSE) {
  specs <- list(
    list(trial_id = 0L, id = "t1_frozen_auto_nons", kind = "auto",
         seasonal = FALSE, max.p = 3L, max.q = 1L, max.d = 1L,
         max.P = 0L, max.Q = 0L, max.D = 0L, is_frozen = TRUE)
  )
  if (isTRUE(smoke)) return(specs)
  specs <- c(specs, list(
    list(trial_id = 1L, id = "auto_seasonal", kind = "auto",
         seasonal = TRUE, max.p = 3L, max.q = 3L, max.d = 1L,
         max.P = 1L, max.Q = 1L, max.D = 1L, is_frozen = FALSE)
  ))
  k <- 2L
  for (p in 0:3) for (d in 0:1) for (q in 0:2) {
    specs[[length(specs) + 1L]] <- list(
      trial_id = k, id = sprintf("nons_%s%s%s", p, d, q), kind = "fixed",
      order = c(p, d, q), seasonal = FALSE, is_frozen = FALSE
    )
    k <- k + 1L
  }
  seas <- list(c(1L, 0L, 0L), c(0L, 1L, 0L), c(0L, 0L, 1L),
               c(1L, 0L, 1L), c(1L, 1L, 0L), c(0L, 1L, 1L))
  bases <- list(c(1L, 0L, 1L), c(2L, 0L, 1L), c(3L, 0L, 1L), c(1L, 1L, 1L))
  for (ord in bases) for (so in seas) {
    specs[[length(specs) + 1L]] <- list(
      trial_id = k,
      id = sprintf("s_%s%s%s_%s%s%s", ord[1], ord[2], ord[3], so[1], so[2], so[3]),
      kind = "fixed", order = as.integer(ord),
      seasonal = list(order = as.integer(so), period = as.integer(SEASONALITY)),
      is_frozen = FALSE
    )
    k <- k + 1L
  }
  specs
}

t1_tuned_budget <- function(mode = "cpcb") {
  mode <- tolower(mode)
  if (mode %in% c("smoke", "quick")) {
    list(mode = "smoke", sensors = "CPCB", pollutants = "PM2.5",
         horizons = "1d", lgb_n = 2L, cat_n = 1L, smoke_spaces = TRUE)
  } else if (mode %in% c("full")) {
    list(mode = "full", sensors = SENSORS_PAPER, pollutants = "PM2.5",
         horizons = names(HORIZONS), lgb_n = 24L, cat_n = 10L,
         smoke_spaces = FALSE)
  } else {
    list(mode = "cpcb", sensors = "CPCB", pollutants = "PM2.5",
         horizons = "1d", lgb_n = 24L, cat_n = 10L, smoke_spaces = FALSE)
  }
}

# ---- extra-parameter fitters (reuse supervised_from_series / split_val) --

t1_tuned_fit_lgb <- function(y_train, params) {
  sup <- supervised_from_series(y_train, params$p)
  sp <- split_val(sup$X, sup$y, params$val_hours)
  dtr <- lightgbm::lgb.Dataset(sp$X_tr, label = sp$y_tr)
  dva <- lightgbm::lgb.Dataset.create.valid(dtr, sp$X_va, label = sp$y_va)
  model <- lightgbm::lgb.train(
    params = list(
      objective = "regression",
      metric = "l2",
      learning_rate = params$eta,
      num_leaves = as.integer(params$lgb_leaves),
      max_depth = as.integer(params$max_depth),
      min_data_in_leaf = as.integer(params$min_child_samples %||% 20L),
      feature_fraction = as.numeric(params$feature_fraction %||% 0.8),
      bagging_fraction = 0.8,
      bagging_freq = 1,
      lambda_l1 = as.numeric(params$lambda_l1 %||% 0),
      lambda_l2 = as.numeric(params$lambda_l2 %||% 0),
      verbosity = -1
    ),
    data = dtr,
    nrounds = as.integer(params$nrounds),
    valids = list(eval = dva),
    early_stopping_rounds = as.integer(params$early_stopping %||% 30L),
    verbose = -1
  )
  list(model = model, p = params$p, family = "lgb")
}

t1_tuned_fit_cat <- function(y_train, params,
                             catboost_ok = isTRUE(get0("CATBOOST_AVAILABLE",
                                                       ifnotfound = FALSE))) {
  if (!catboost_ok) {
    stop("T1-Tuned D4 requires CatBoost; CATBOOST_AVAILABLE is FALSE.")
  }
  sup <- supervised_from_series(y_train, params$p)
  sp <- split_val(sup$X, sup$y, params$val_hours)
  pool_tr <- catboost::catboost.load_pool(sp$X_tr, label = sp$y_tr)
  pool_va <- catboost::catboost.load_pool(sp$X_va, label = sp$y_va)
  model <- catboost::catboost.train(
    pool_tr, pool_va,
    params = list(
      loss_function = "RMSE",
      iterations = as.integer(params$nrounds),
      depth = as.integer(params$max_depth),
      learning_rate = as.numeric(params$eta),
      l2_leaf_reg = as.numeric(params$l2_leaf_reg %||% 3),
      random_strength = as.numeric(params$random_strength %||% 1),
      bagging_temperature = as.numeric(params$bagging_temperature %||% 1),
      boosting_type = "Ordered",
      od_type = "Iter",
      od_wait = as.integer(params$early_stopping %||% 30L),
      random_seed = T1_SEED,
      verbose = 0,
      allow_writing_files = FALSE,
      thread_count = 1
    )
  )
  list(model = model, p = params$p, family = "cat", fallback = FALSE)
}

t1_tuned_fit_sarima <- function(y, spec) {
  yts <- stats::ts(as.numeric(y), frequency = SEASONALITY)
  if (identical(spec$kind, "auto")) {
    return(forecast::auto.arima(
      yts, stepwise = TRUE, approximation = TRUE,
      seasonal = isTRUE(spec$seasonal),
      max.p = spec$max.p %||% 3L, max.q = spec$max.q %||% 1L,
      max.d = spec$max.d %||% 1L,
      max.P = spec$max.P %||% 0L, max.Q = spec$max.Q %||% 0L,
      max.D = spec$max.D %||% 0L, trace = FALSE
    ))
  }
  seas <- spec$seasonal
  if (is.null(seas) || isFALSE(seas)) {
    forecast::Arima(yts, order = as.integer(spec$order), seasonal = FALSE)
  } else {
    forecast::Arima(yts, order = as.integer(spec$order), seasonal = seas)
  }
}

t1_tuned_params_from_row <- function(model_id, row, frozen) {
  p <- as.list(frozen)
  p$p <- as.integer(frozen$p)
  nms <- names(row)
  for (nm in nms) {
    if (nm %in% c("trial_id", "is_frozen", "id", "kind")) next
    p[[nm]] <- row[[nm]]
  }
  if (identical(model_id, "dlinear")) {
    p$p <- as.integer(row$p)
    p$kernel <- as.integer(row$kernel)
  }
  p$is_frozen <- isTRUE(row$is_frozen)
  p$trial_id <- as.integer(row$trial_id %||% NA_integer_)
  p
}

t1_tuned_hparams_json <- function(model_id, params, extra = list()) {
  if (identical(model_id, "lgb")) {
    hp <- list(
      p = params$p, nrounds = params$nrounds, max_depth = params$max_depth,
      eta = params$eta, lgb_leaves = params$lgb_leaves,
      min_child_samples = params$min_child_samples,
      feature_fraction = params$feature_fraction,
      lambda_l1 = params$lambda_l1, lambda_l2 = params$lambda_l2,
      early_stopping = params$early_stopping, val_hours = params$val_hours,
      trial_id = params$trial_id, is_frozen = isTRUE(params$is_frozen)
    )
  } else if (identical(model_id, "catboost")) {
    hp <- list(
      p = params$p, nrounds = params$nrounds, max_depth = params$max_depth,
      eta = params$eta, l2_leaf_reg = params$l2_leaf_reg,
      random_strength = params$random_strength,
      bagging_temperature = params$bagging_temperature,
      early_stopping = params$early_stopping, val_hours = params$val_hours,
      trial_id = params$trial_id, is_frozen = isTRUE(params$is_frozen)
    )
  } else if (identical(model_id, "dlinear")) {
    hp <- list(
      p = extra$p %||% params$p, kernel = extra$kernel %||% params$kernel,
      trend = "causal_moving_average", seasonal = "ols_linear",
      note = "OLS DLinear: no lr/epochs/batch/dropout",
      trial_id = params$trial_id, is_frozen = isTRUE(params$is_frozen)
    )
  } else if (identical(model_id, "sarima")) {
    hp <- extra
    hp$trial_id <- params$trial_id
    hp$is_frozen <- isTRUE(params$is_frozen)
  } else {
    hp <- as.list(params)
  }
  jsonlite::toJSON(hp, auto_unbox = TRUE, null = "null")
}

t1_tuned_fit_forecast <- function(model_id, y_hist, h, params, sarima_spec = NULL) {
  y_hist <- t1_drop_leading_na(y_hist)
  p_lag <- as.integer(params$p %||% 24L)
  if (length(y_hist) < max(48L, p_lag + 8L)) {
    stop("Not enough finite history for tuned ", model_id)
  }
  invisible(t1_independent_lags(y_hist, p_lag))

  scaler <- NULL
  y_work <- y_hist
  if (t1_tree_uses_minmax(model_id)) {
    scaler <- minmax_fit(y_hist)
    y_work <- minmax_apply(y_hist, scaler)
  }

  extra <- list()
  t0 <- proc.time()[["elapsed"]]
  if (identical(model_id, "lgb")) {
    fit <- t1_tuned_fit_lgb(y_work, params)
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- recursive_tree_forecast(fit, y_work, h)
    t_pred <- proc.time()[["elapsed"]] - t1
  } else if (identical(model_id, "catboost")) {
    fit <- t1_tuned_fit_cat(y_work, params)
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- recursive_tree_forecast(fit, y_work, h)
    t_pred <- proc.time()[["elapsed"]] - t1
  } else if (identical(model_id, "dlinear")) {
    set.seed(T1_SEED)
    k <- as.integer(params$kernel %||% 25L)
    fit <- t1_fit_dlinear(y_work, p = p_lag, kernel = k)
    extra$kernel <- k
    extra$p <- p_lag
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- t1_forecast_dlinear(fit, y_work, h)
    t_pred <- proc.time()[["elapsed"]] - t1
  } else if (identical(model_id, "sarima")) {
    set.seed(T1_SEED)
    spec <- sarima_spec %||% list(kind = "auto", seasonal = FALSE,
                                  max.p = 3L, max.q = 1L, max.d = 1L)
    fit <- t1_tuned_fit_sarima(y_hist, spec)
    extra$arimaorder <- tryCatch(as.numeric(forecast::arimaorder(fit)),
                                 error = function(e) NA_real_)
    extra$spec_id <- spec$id %||% NA_character_
    extra$seasonal <- !isFALSE(spec$seasonal) && !is.null(spec$seasonal)
    extra$kind <- spec$kind
    t_train <- proc.time()[["elapsed"]] - t0
    t1 <- proc.time()[["elapsed"]]
    yhat_s <- forecast_arima_obj(fit, h)
    t_pred <- proc.time()[["elapsed"]] - t1
    scaler <- NULL
  } else {
    stop("T1-Tuned mapping forbids model_id=", model_id)
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
    hyperparams = t1_tuned_hparams_json(model_id, params, extra),
    extra = extra
  )
}

t1_tuned_select_hparams <- function(trials_df) {
  val <- trials_df
  if ("stage" %in% names(val)) {
    val <- val[val$stage %in% c("validation", "val"), , drop = FALSE]
  }
  if (!nrow(val)) stop("No validation trials; refusing to select on test.")
  if ("stage" %in% names(val) && any(val$stage %in% c("test", "holdout"))) {
    stop("Trial table contains test rows.")
  }
  val$val_MASE <- ifelse(is.finite(val$MASE), val$MASE, Inf)
  val$val_MAE <- ifelse(is.finite(val$MAE), val$MAE, Inf)
  val$is_frozen <- as.logical(val$is_frozen)
  val$is_frozen[is.na(val$is_frozen)] <- FALSE
  val %>%
    dplyr::group_by(.data$sensor, .data$pollutant, .data$horizon, .data$component) %>%
    dplyr::arrange(.data$val_MASE, .data$val_MAE, dplyr::desc(.data$is_frozen),
                   .data$trial_id, .by_group = TRUE) %>%
    dplyr::slice(1L) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(selected_on = "validation", used_test = FALSE)
}

t1_tuned_load_cache <- function() {
  path <- t1_tuned_cache_path()
  if (file.exists(path)) readRDS(path) else list()
}

t1_tuned_save_cache <- function(cache) {
  t1_tuned_dir_create()
  t1_tuned_assert(t1_tuned_cache_path())
  saveRDS(cache, t1_tuned_cache_path())
}

t1_tuned_trial_key <- function(sensor, pollutant, horizon, component, trial_id) {
  paste(sensor, pollutant, horizon, component, "trial", trial_id, sep = "|")
}

t1_tuned_candidates_for <- function(model_id, budget, frozen, seed_offset) {
  if (identical(model_id, "lgb")) {
    t1_tuned_lgb_candidates(budget$lgb_n, T1_SEED + seed_offset, frozen)
  } else if (identical(model_id, "catboost")) {
    t1_tuned_cat_candidates(budget$cat_n, T1_SEED + seed_offset, frozen)
  } else if (identical(model_id, "dlinear")) {
    t1_tuned_dlinear_candidates(budget$smoke_spaces, frozen$p, 25L)
  } else if (identical(model_id, "sarima")) {
    t1_tuned_sarima_candidates(budget$smoke_spaces)
  } else {
    stop("No T1-Tuned search space for ", model_id)
  }
}

t1_tuned_row_as_params <- function(model_id, cand, frozen) {
  if (identical(model_id, "sarima")) {
    p <- as.list(frozen)
    p$trial_id <- cand$trial_id
    p$is_frozen <- isTRUE(cand$is_frozen)
    return(list(params = p, spec = cand))
  }
  if (is.data.frame(cand) && nrow(cand) == 1L) cand <- as.list(cand)
  list(params = t1_tuned_params_from_row(model_id, cand, frozen), spec = NULL)
}

t1_tuned_eval_trial <- function(aligned, series_obj, sensor, pollutant, horizon,
                                component, model_id, params, sarima_spec,
                                stage, params_source) {
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
  ran <- t1_tuned_fit_forecast(model_id, y_hist, h_fc, params, sarima_spec)
  metrics <- t1_score_row(
    model_id, component, horizon, stage, sensor, pollutant,
    y_hist, y_true, ran$yhat, ran$train_time_sec, ran$pred_time_sec,
    ran$model_complexity, ran$complexity_note, ran$hyperparams, params_source
  )
  metrics$trial_id <- as.integer(params$trial_id %||% NA_integer_)
  metrics$is_frozen <- isTRUE(params$is_frozen)
  list(
    metrics = metrics,
    yhat = as.numeric(ran$yhat),
    y_true = as.numeric(y_true),
    times = times_out,
    hyperparams = ran$hyperparams,
    extra = ran$extra
  )
}

t1_tuned_search_component <- function(aligned, series_obj, sensor, pollutant,
                                      horizon, component, budget, frozen,
                                      cache, params_source) {
  map <- t1_tuned_mapping()
  model_id <- unname(map[[component]])
  seed_offset <- match(component, T1_COMPONENTS)
  cands <- t1_tuned_candidates_for(model_id, budget, frozen, seed_offset)
  n_cand <- if (is.data.frame(cands)) nrow(cands) else length(cands)
  trial_rows <- list()
  for (i in seq_len(n_cand)) {
    cand <- if (is.data.frame(cands)) cands[i, , drop = FALSE] else cands[[i]]
    packed <- t1_tuned_row_as_params(model_id, cand, frozen)
    tid <- as.integer(packed$params$trial_id %||% (i - 1L))
    packed$params$trial_id <- tid
    key <- t1_tuned_trial_key(sensor, pollutant, horizon, component, tid)
    message("T1-Tuned ", sensor, " ", pollutant, " ", horizon, " ", component,
            " ", model_id, " trial ", tid, "/", n_cand - 1L,
            if (isTRUE(packed$params$is_frozen)) " [frozen]" else "")
    if (is.null(cache[[key]])) {
      rec <- tryCatch(
        t1_tuned_eval_trial(aligned, series_obj, sensor, pollutant, horizon,
                            component, model_id, packed$params, packed$spec,
                            "val", params_source),
        error = function(e) {
          warning("T1-Tuned trial failed ", component, " #", tid, ": ", e$message)
          NULL
        }
      )
      if (is.null(rec)) next
      cache[[key]] <- rec
      t1_tuned_save_cache(cache)
    }
    rec <- cache[[key]]
    rec$metrics$stage <- "validation"
    rec$metrics$hyperparameters <- as.character(rec$metrics$hyperparameters)
    trial_rows[[length(trial_rows) + 1L]] <- rec$metrics
  }
  trials <- dplyr::bind_rows(trial_rows)
  if (!nrow(trials)) stop("No successful validation trials for ", component)
  selected <- t1_tuned_select_hparams(trials)
  list(cache = cache, trials = trials, selected = selected, model_id = model_id)
}

t1_tuned_run <- function(mode = "cpcb") {
  budget <- t1_tuned_budget(mode)
  t1_tuned_dir_create()
  frozen <- t1_tuned_frozen_tree_params()
  params_source <- paste0(
    "T1-Tuned validation-MASE search; frozen baseline from ",
    t1_load_tree_params()$source
  )
  message("T1-Tuned mode=", budget$mode,
          " sensors=", paste(budget$sensors, collapse = ","),
          " horizons=", paste(budget$horizons, collapse = ","),
          " map=", paste(names(T1_TUNED_MAP), T1_TUNED_MAP, sep = "=", collapse = ", "))

  series_all <- t1_load_prepared_series()
  cache <- t1_tuned_load_cache()
  all_trials <- list()
  selected_rows <- list()
  metric_rows <- list()
  pred_store <- list()

  for (sensor in budget$sensors) {
    for (pollutant in budget$pollutants) {
      skey <- paste(sensor, pollutant, sep = "_")
      if (!skey %in% names(series_all)) {
        warning("Missing prepared series ", skey, "; skip.")
        next
      }
      series_obj <- series_all[[skey]]
      decomp <- t1_load_stored_components(sensor, pollutant)
      aligned <- t1_align_components(series_obj, decomp)

      for (horizon in budget$horizons) {
        for (comp in T1_COMPONENTS) {
          searched <- t1_tuned_search_component(
            aligned, series_obj, sensor, pollutant, horizon, comp,
            budget, frozen, cache, params_source
          )
          cache <- searched$cache
          all_trials[[length(all_trials) + 1L]] <- searched$trials
          sel <- searched$selected
          selected_rows[[length(selected_rows) + 1L]] <- sel

          packed_params <- NULL
          packed_spec <- NULL
          model_id <- searched$model_id
          tid <- as.integer(sel$trial_id[1])
          cands <- t1_tuned_candidates_for(
            model_id, budget, frozen, match(comp, T1_COMPONENTS)
          )
          if (is.data.frame(cands)) {
            hit <- cands$trial_id == tid
            packed <- t1_tuned_row_as_params(model_id, cands[hit, , drop = FALSE], frozen)
          } else {
            spec <- cands[[which(vapply(cands, function(z) z$trial_id, integer(1)) == tid)]]
            packed <- t1_tuned_row_as_params(model_id, spec, frozen)
          }
          packed$params$trial_id <- tid
          packed$params$is_frozen <- isTRUE(sel$is_frozen[1])

          message("T1-Tuned TEST ", sensor, " ", pollutant, " ", horizon, " ",
                  comp, " ", model_id, " trial ", tid)
          rec <- tryCatch(
            t1_tuned_eval_trial(
              aligned, series_obj, sensor, pollutant, horizon, comp,
              model_id, packed$params, packed$spec, "test", params_source
            ),
            error = function(e) {
              warning("T1-Tuned TEST failed ", comp, ": ", e$message)
              NULL
            }
          )
          if (is.null(rec)) next
          rec$metrics$stage <- "test"
          rec$metrics$hyperparameters <- as.character(rec$metrics$hyperparameters)
          job <- t1_job_key(sensor, pollutant, horizon, comp, model_id, "test")
          cache[[job]] <- rec
          t1_tuned_save_cache(cache)
          metric_rows[[job]] <- rec$metrics
          pred_store[[job]] <- rec[c("yhat", "y_true", "times", "hyperparams")]
        }
      }
    }
  }

  trials <- dplyr::bind_rows(all_trials)
  selected <- dplyr::bind_rows(selected_rows)
  test_metrics <- dplyr::bind_rows(metric_rows)
  val_sel <- selected
  val_sel$stage <- "validation"
  metrics <- dplyr::bind_rows(val_sel, test_metrics)
  if ("hyperparameters" %in% names(metrics)) {
    metrics$hyperparameters <- as.character(metrics$hyperparameters)
  }

  best <- selected %>%
    dplyr::mutate(
      model_id = unname(T1_TUNED_MAP[as.character(.data$component)]),
      model = t1_model_label(.data$model_id),
      mean_val_MASE = .data$MASE,
      mean_val_MAE = .data$MAE,
      n_horizons = 1L,
      selected_on = "validation",
      used_test = FALSE
    )

  cfg <- list(
    mode = budget$mode,
    sensors = budget$sensors,
    pollutants = budget$pollutants,
    horizons = budget$horizons,
    models = unique(unname(T1_TUNED_MAP)),
    components = T1_COMPONENTS,
    params = frozen,
    params_source = params_source,
    mapping = as.list(T1_TUNED_MAP),
    lgb_n = budget$lgb_n,
    cat_n = budget$cat_n
  )
  hetero <- t1_build_heterogeneous(cache, best, series_all, cfg)
  recon <- t1_build_reconstructed(hetero, series_all)

  t1_tuned_write_outputs(metrics, pred_store, best, hetero, recon, trials, cfg)
  t1_tuned_write_plots(metrics, best, recon, trials)
  t1_tuned_write_report(metrics, best, recon, trials, cfg)
  invisible(list(metrics = metrics, best = best, recon = recon,
                 trials = trials, cfg = cfg))
}

t1_tuned_t1_recon_mase <- function(sensor, pollutant, horizon) {
  path <- file.path(RES_DIR, "teammate_1", "reconstructed_predictions.rds")
  if (!file.exists(path)) return(NA_real_)
  rec <- readRDS(path)
  id <- paste(sensor, pollutant, horizon, sep = "|")
  if (!id %in% names(rec)) return(NA_real_)
  as.numeric(rec[[id]]$metrics$MASE)
}

t1_tuned_write_outputs <- function(metrics, pred_store, best, hetero, recon,
                                   trials, cfg) {
  t1_tuned_dir_create()
  paths <- c(
    file.path(t1_tuned_out_dir(), "component_metrics.csv"),
    file.path(t1_tuned_out_dir(), "selected_hparams.csv"),
    file.path(t1_tuned_out_dir(), "tuning_trials.csv"),
    file.path(t1_tuned_out_dir(), "component_predictions.rds"),
    file.path(t1_tuned_out_dir(), "heterogeneous_predictions.rds"),
    file.path(t1_tuned_out_dir(), "reconstructed_predictions.rds"),
    file.path(t1_tuned_out_dir(), "best_models.csv")
  )
  lapply(paths, t1_tuned_assert)
  readr::write_csv(metrics, paths[[1]])
  readr::write_csv(best, paths[[2]])
  readr::write_csv(best, paths[[7]])
  if (nrow(trials)) readr::write_csv(trials, paths[[3]])
  saveRDS(pred_store, paths[[4]])
  saveRDS(hetero, paths[[5]])
  saveRDS(recon, paths[[6]])
  saveRDS(cfg, file.path(t1_tuned_out_dir(), "_run_config.rds"))
  message("Wrote T1-Tuned outputs under ", t1_tuned_out_dir())
}

# ---- candidate comparison (reporting only; does not tune or re-select) ----

t1_tuned_field <- function(metrics, field) {
  if (is.null(metrics)) return(NA)
  value <- NULL
  if (is.data.frame(metrics)) {
    if (!nrow(metrics) || !field %in% names(metrics)) return(NA)
    value <- metrics[[field]][[1]]
  } else if (is.list(metrics)) {
    if (is.null(metrics[[field]])) return(NA)
    value <- metrics[[field]]
    if (length(value) > 1L) value <- value[[1]]
  } else {
    return(NA)
  }
  if (length(value) == 0L || is.null(value)) return(NA)
  if (is.factor(value)) value <- as.character(value)
  value
}

t1_tuned_mase_label <- function(x, digits = 3L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.finite(x), formatC(x, format = "f", digits = digits), "N/A")
}

t1_tuned_read_original_metrics <- function() {
  path <- file.path(t1_out_dir(), "component_metrics.csv")
  if (!file.exists(path)) return(NULL)
  # "1d" must stay a horizon label. Default guessing reads it as the number 1.
  readr::read_csv(
    path, show_col_types = FALSE,
    col_types = readr::cols(
      horizon = readr::col_character(),
      stage = readr::col_character(),
      component = readr::col_character(),
      model = readr::col_character(),
      model_id = readr::col_character(),
      sensor = readr::col_character(),
      pollutant = readr::col_character(),
      MASE = readr::col_double(),
      .default = readr::col_guess()
    )
  )
}

t1_tuned_committed_scores <- function() {
  empty <- tibble::tibble(
    sensor = character(), pollutant = character(), horizon = character(),
    component = character(), model_id = character(),
    tuned_validation_MASE = numeric(), tuned_test_MASE = numeric()
  )
  rows <- list()
  metrics_path <- file.path(t1_tuned_out_dir(), "component_metrics.csv")
  if (file.exists(metrics_path)) {
    met <- readr::read_csv(metrics_path, show_col_types = FALSE)
    if (nrow(met) && all(c("stage", "MASE", "component", "model_id") %in% names(met))) {
      keys <- c("sensor", "pollutant", "horizon", "component", "model_id")
      val <- met[met$stage %in% c("validation", "val"), , drop = FALSE]
      te <- met[met$stage == "test", , drop = FALSE]
      if (nrow(val) || nrow(te)) {
        both <- dplyr::full_join(
          val %>% dplyr::select(dplyr::all_of(keys), tuned_validation_MASE = "MASE"),
          te %>% dplyr::select(dplyr::all_of(keys), tuned_test_MASE = "MASE"),
          by = keys
        )
        rows[[length(rows) + 1L]] <- both
      }
    }
  }
  official <- dplyr::bind_rows(rows)
  cache <- t1_tuned_load_cache()
  cache_rows <- list()
  for (key in names(cache)) {
    rec <- cache[[key]]
    stage <- as.character(t1_tuned_field(rec$metrics, "stage"))
    if (!identical(stage, "test")) next
    sensor <- as.character(t1_tuned_field(rec$metrics, "sensor"))
    pollutant <- as.character(t1_tuned_field(rec$metrics, "pollutant"))
    horizon <- as.character(t1_tuned_field(rec$metrics, "horizon"))
    component <- as.character(t1_tuned_field(rec$metrics, "component"))
    model_id <- as.character(t1_tuned_field(rec$metrics, "model_id"))
    trial_id <- t1_tuned_field(rec$metrics, "trial_id")
    val_mase <- NA_real_
    if (!is.na(sensor) && !is.na(trial_id)) {
      vkey <- t1_tuned_trial_key(sensor, pollutant, horizon, component, trial_id)
      if (!is.null(cache[[vkey]])) {
        val_mase <- suppressWarnings(as.numeric(
          t1_tuned_field(cache[[vkey]]$metrics, "MASE")
        ))
      }
    }
    cache_rows[[length(cache_rows) + 1L]] <- tibble::tibble(
      sensor = sensor, pollutant = pollutant, horizon = horizon,
      component = component, model_id = model_id,
      tuned_validation_MASE = val_mase,
      tuned_test_MASE = suppressWarnings(as.numeric(
        t1_tuned_field(rec$metrics, "MASE")
      ))
    )
  }
  cached <- dplyr::bind_rows(cache_rows)
  if (!nrow(official)) return(if (nrow(cached)) cached else empty)
  if (!nrow(cached)) return(official)
  # Written component_metrics.csv is the committed run. Cache fills components
  # that the writer has not emitted yet. Neither source re-ranks trials.
  official$src_key <- paste(official$sensor, official$pollutant, official$horizon,
                            official$component, official$model_id, sep = "|")
  cached$src_key <- paste(cached$sensor, cached$pollutant, cached$horizon,
                          cached$component, cached$model_id, sep = "|")
  extra <- cached[!cached$src_key %in% official$src_key, , drop = FALSE]
  dplyr::bind_rows(official, extra) %>%
    dplyr::select(-"src_key")
}

t1_tuned_candidate_comparison <- function() {
  orig <- t1_tuned_read_original_metrics()
  if (is.null(orig) || !nrow(orig)) return(tibble::tibble())
  need <- c("sensor", "pollutant", "horizon", "component", "model",
            "model_id", "stage", "MASE")
  miss <- setdiff(need, names(orig))
  if (length(miss)) {
    stop("Original T1 component_metrics.csv is missing columns: ",
         paste(miss, collapse = ", "))
  }
  keys <- c("sensor", "pollutant", "horizon", "component", "model", "model_id")
  val <- orig[orig$stage %in% c("validation", "val"), , drop = FALSE]
  te <- orig[orig$stage == "test", , drop = FALSE]
  if (any(duplicated(val[, keys, drop = FALSE]))) {
    stop("Duplicate original validation rows; refusing to average scores.")
  }
  if (any(duplicated(te[, keys, drop = FALSE]))) {
    stop("Duplicate original test rows; refusing to average scores.")
  }
  cmp <- dplyr::full_join(
    val %>% dplyr::select(dplyr::all_of(keys), original_validation_MASE = "MASE"),
    te %>% dplyr::select(dplyr::all_of(keys), original_test_MASE = "MASE"),
    by = keys
  )
  map <- t1_tuned_mapping()
  cmp$mapped_model_id <- unname(map[as.character(cmp$component)])
  cmp$is_frozen_assignment <- !is.na(cmp$mapped_model_id) &
    cmp$model_id == cmp$mapped_model_id
  cmp$tuned_validation_MASE <- NA_real_
  cmp$tuned_test_MASE <- NA_real_
  tuned <- t1_tuned_committed_scores()
  if (nrow(tuned)) {
    cmp$join_key <- paste(cmp$sensor, cmp$pollutant, cmp$horizon,
                          cmp$component, cmp$model_id, sep = "|")
    tuned$join_key <- paste(tuned$sensor, tuned$pollutant, tuned$horizon,
                            tuned$component, tuned$model_id, sep = "|")
    hit <- match(cmp$join_key, tuned$join_key)
    use <- cmp$is_frozen_assignment & !is.na(hit)
    cmp$tuned_validation_MASE[use] <- tuned$tuned_validation_MASE[hit[use]]
    cmp$tuned_test_MASE[use] <- tuned$tuned_test_MASE[hit[use]]
    cmp$join_key <- NULL
  }
  model_levels <- unique(c(unname(t1_model_ids()), as.character(cmp$model)))
  comp_levels <- unique(c(T1_COMPONENTS, as.character(cmp$component)))
  cmp$component <- factor(as.character(cmp$component), levels = comp_levels)
  cmp$model <- factor(as.character(cmp$model), levels = model_levels)
  cmp %>%
    dplyr::arrange(.data$sensor, .data$pollutant, .data$horizon,
                   .data$component, .data$model)
}

t1_tuned_candidate_section <- function(cmp) {
  if (!nrow(cmp)) {
    return(c(
      "## Component-wise model comparison",
      "",
      "Original T1 `component_metrics.csv` was not available. No candidate or tuned scores were invented.",
      ""
    ))
  }
  blocks <- c(
    "## Component-wise model comparison",
    "",
    "Original validation and test MASE are read from `results/teammate_1/component_metrics.csv`.",
    "That file is the T1 model-selection experiment. These columns are not retuned, and this table does not change the frozen component-to-model map.",
    "",
    "Tuned validation and test MASE are filled only for the frozen assignment of that component, and only when T1-Tuned has already stored the validation-selected configuration and its later test evaluation.",
    "Every other candidate was not tuned, so its tuned cells are N/A.",
    "A frozen assignment with no stored test evaluation is also N/A.",
    "Model selection stays on validation MASE. Test MASE is shown after the fact and is not a selection input.",
    "",
    "Markdown scores are rounded to 3 decimals. `candidate_comparison.csv` keeps the stored values.",
    ""
  )
  groups <- unique(paste(cmp$sensor, cmp$pollutant, cmp$horizon, sep = " | "))
  for (g in groups) {
    sub <- cmp[paste(cmp$sensor, cmp$pollutant, cmp$horizon, sep = " | ") == g, , drop = FALSE]
    blocks <- c(
      blocks,
      sprintf("### %s", g),
      "",
      "| Component | Model | Original Validation MASE | Original Test MASE | Tuned Validation MASE | Tuned Test MASE |",
      "|---|---|---:|---:|---:|---:|"
    )
    row_lines <- vapply(seq_len(nrow(sub)), function(i) {
      sprintf("| %s | %s | %s | %s | %s | %s |",
              as.character(sub$component[i]), as.character(sub$model[i]),
              t1_tuned_mase_label(sub$original_validation_MASE[i]),
              t1_tuned_mase_label(sub$original_test_MASE[i]),
              t1_tuned_mase_label(sub$tuned_validation_MASE[i]),
              t1_tuned_mase_label(sub$tuned_test_MASE[i]))
    }, character(1))
    blocks <- c(blocks, row_lines, "")
  }
  c(
    blocks,
    "The validation heatmap uses the original T1 scores only: components are rows and candidate models are columns.",
    "File: `plots/original_val_mase_heatmap.png`. Tuned scores are not drawn on it.",
    ""
  )
}

t1_tuned_plot_original_val_heatmap <- function(cmp) {
  if (!nrow(cmp)) return(invisible(FALSE))
  df <- cmp[is.finite(cmp$original_validation_MASE), , drop = FALSE]
  if (!nrow(df)) return(invisible(FALSE))
  t1_tuned_dir_create()
  comp_levels <- unique(c(T1_COMPONENTS, as.character(df$component)))
  model_levels <- unique(c(unname(t1_model_ids()), as.character(df$model)))
  df$component <- factor(as.character(df$component), levels = comp_levels)
  df$model <- factor(as.character(df$model), levels = model_levels)
  df$panel <- paste(df$sensor, df$pollutant, df$horizon, sep = " | ")
  p <- ggplot2::ggplot(df, ggplot2::aes(.data$model, .data$component,
                                        fill = .data$original_validation_MASE)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.4) +
    ggplot2::geom_text(ggplot2::aes(label = t1_tuned_mase_label(.data$original_validation_MASE)),
                       size = 3) +
    ggplot2::scale_y_discrete(limits = rev(comp_levels)) +
    ggplot2::scale_fill_viridis_c(option = "C", name = "Val MASE") +
    ggplot2::facet_wrap(~panel) +
    ggplot2::labs(
      title = "Original T1 validation MASE",
      subtitle = "Candidate models from the T1 selection run. Tuned scores are not shown.",
      x = "Candidate model", y = "Component"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
                   axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
  path <- file.path(t1_tuned_plot_dir(), "original_val_mase_heatmap.png")
  t1_tuned_assert(path)
  ggplot2::ggsave(path, p, width = 9, height = 5.5, dpi = 120)
  invisible(path)
}

t1_tuned_write_candidate_comparison <- function() {
  cmp <- t1_tuned_candidate_comparison()
  t1_tuned_dir_create()
  csv_path <- file.path(t1_tuned_out_dir(), "candidate_comparison.csv")
  md_path <- file.path(t1_tuned_out_dir(), "candidate_comparison.md")
  t1_tuned_assert(csv_path)
  t1_tuned_assert(md_path)
  if (!nrow(cmp)) {
    writeLines(c(
      "# Component-wise model comparison",
      "",
      "Original T1 `component_metrics.csv` was not available. No scores were invented.",
      ""
    ), md_path)
    return(invisible(cmp))
  }
  disp <- tibble::tibble(
    Sensor = as.character(cmp$sensor),
    Pollutant = as.character(cmp$pollutant),
    Horizon = as.character(cmp$horizon),
    Component = as.character(cmp$component),
    Model = as.character(cmp$model),
    `Original Validation MASE` = t1_tuned_mase_label(cmp$original_validation_MASE, 10L),
    `Original Test MASE` = t1_tuned_mase_label(cmp$original_test_MASE, 10L),
    `Tuned Validation MASE` = t1_tuned_mase_label(cmp$tuned_validation_MASE, 10L),
    `Tuned Test MASE` = t1_tuned_mase_label(cmp$tuned_test_MASE, 10L)
  )
  names(disp) <- c(
    "Sensor", "Pollutant", "Horizon", "Component", "Model",
    "Original Validation MASE", "Original Test MASE",
    "Tuned Validation MASE", "Tuned Test MASE"
  )
  readr::write_csv(disp, csv_path)
  writeLines(c(
    "# Component-wise model comparison",
    "",
    "Reporting only. The hyperparameter search is unchanged, and original T1 result files are not overwritten.",
    "",
    t1_tuned_candidate_section(cmp)
  ), md_path)
  t1_tuned_plot_original_val_heatmap(cmp)
  invisible(cmp)
}

t1_tuned_write_plots <- function(metrics, best, recon, trials) {
  t1_tuned_dir_create()
  tryCatch(
    t1_tuned_plot_original_val_heatmap(t1_tuned_candidate_comparison()),
    error = function(e) warning("Original validation heatmap skipped: ", e$message)
  )
  if (nrow(trials) && "MASE" %in% names(trials)) {
    p1 <- ggplot2::ggplot(trials, ggplot2::aes(.data$trial_id, .data$MASE,
                                               colour = .data$is_frozen)) +
      ggplot2::geom_point() +
      ggplot2::facet_wrap(~component, scales = "free_y") +
      ggplot2::labs(title = "T1-Tuned validation MASE by trial",
                    x = "trial_id (0 = frozen T1)", y = "Val MASE") +
      ggplot2::theme_minimal(base_size = 11)
    ggplot2::ggsave(file.path(t1_tuned_plot_dir(), "val_mase_trials.png"),
                    p1, width = 10, height = 6, dpi = 120)
  }
  te <- dplyr::filter(metrics, .data$stage == "test")
  if (nrow(te)) {
    p2 <- ggplot2::ggplot(te, ggplot2::aes(.data$component, .data$MASE,
                                           fill = .data$model)) +
      ggplot2::geom_col() +
      ggplot2::labs(title = "T1-Tuned selected models, test MASE",
                    x = "Component", y = "Test MASE") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(legend.position = "bottom")
    ggplot2::ggsave(file.path(t1_tuned_plot_dir(), "test_component_mase.png"),
                    p2, width = 8, height = 4.5, dpi = 120)
  }
  recon_rows <- dplyr::bind_rows(lapply(names(recon), function(nm) {
    item <- recon[[nm]]
    t1m <- t1_tuned_t1_recon_mase(item$sensor, item$pollutant, item$horizon)
    dplyr::bind_rows(
      tibble::tibble(sensor = item$sensor, pollutant = item$pollutant,
                     horizon = item$horizon, method = "T1_tuned",
                     MASE = item$metrics$MASE),
      tibble::tibble(sensor = item$sensor, pollutant = item$pollutant,
                     horizon = item$horizon, method = "T1_untuned",
                     MASE = t1m)
    )
  }))
  base_rows <- dplyr::bind_rows(lapply(recon, function(item) {
    if (is.null(item$baselines) || !nrow(item$baselines)) return(NULL)
    item$baselines %>%
      dplyr::filter(.data$method %in% c("wavecatboost", "lgb", "catboost",
                                        "snaive", "sarima")) %>%
      dplyr::select("sensor", "pollutant", "horizon", "method", "MASE")
  }))
  cmp <- dplyr::bind_rows(recon_rows, base_rows)
  if (nrow(recon_rows)) {
    cmp <- dplyr::filter(cmp, .data$horizon %in% unique(recon_rows$horizon))
  }
  cmp <- dplyr::filter(cmp, is.finite(.data$MASE))
  if (nrow(cmp)) {
    p3 <- ggplot2::ggplot(cmp, ggplot2::aes(.data$method, .data$MASE,
                                            fill = .data$method)) +
      ggplot2::geom_col() +
      ggplot2::coord_flip() +
      ggplot2::facet_grid(sensor ~ horizon, scales = "free_y") +
      ggplot2::labs(title = "T1-Tuned reconstructed vs T1 and bake-off",
                    x = NULL, y = "MASE") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(legend.position = "none")
    ggplot2::ggsave(file.path(t1_tuned_plot_dir(), "reconstruction_vs_baselines.png"),
                    p3, width = 9, height = 5, dpi = 120)
  }
  one <- recon[grepl("\\|1d$", names(recon))]
  if (length(one)) {
    item <- one[[1]]
    df <- tibble::tibble(
      t = item$times[seq_along(item$yhat_clip)],
      actual = item$y_true_level,
      tuned = item$yhat_clip
    )
    p4 <- ggplot2::ggplot(df, ggplot2::aes(.data$t)) +
      ggplot2::geom_line(ggplot2::aes(y = .data$actual, colour = "actual")) +
      ggplot2::geom_line(ggplot2::aes(y = .data$tuned, colour = "T1-Tuned")) +
      ggplot2::labs(title = paste("T1-Tuned reconstructed", item$sensor,
                                  item$pollutant, item$horizon),
                    x = NULL, y = item$pollutant, colour = NULL) +
      ggplot2::theme_minimal(base_size = 11)
    ggplot2::ggsave(file.path(t1_tuned_plot_dir(), "reconstructed_1d_overlay.png"),
                    p4, width = 9, height = 4, dpi = 120)
  }
  invisible(TRUE)
}

t1_tuned_write_report <- function(metrics, best, recon, trials, cfg) {
  path <- file.path(t1_tuned_out_dir(), "report.md")
  t1_tuned_assert(path)
  cmp <- tryCatch(
    t1_tuned_write_candidate_comparison(),
    error = function(e) {
      warning("Candidate comparison was not written: ", e$message)
      tibble::tibble()
    }
  )
  map_lines <- sprintf("- %s → **%s** (architecture frozen from T1; not re-selected)",
                       names(T1_TUNED_MAP), t1_model_label(unname(T1_TUNED_MAP)))
  sel_lines <- apply(best, 1, function(r) {
    sprintf("- %s %s %s / %s: trial %s frozen=%s val MASE=%s hparams=%s",
            r[["sensor"]], r[["pollutant"]], r[["component"]], r[["model"]],
            r[["trial_id"]], r[["is_frozen"]],
            t1_fmt(as.numeric(r[["MASE"]] %||% r[["mean_val_MASE"]])),
            as.character(r[["hyperparameters"]]))
  })
  recon_lines <- vapply(names(recon), function(nm) {
    item <- recon[[nm]]
    wc <- NA_real_
    lgb <- NA_real_
    if (!is.null(item$baselines) && nrow(item$baselines)) {
      if (any(item$baselines$method == "wavecatboost")) {
        wc <- item$baselines$MASE[item$baselines$method == "wavecatboost"][1]
      }
      if (any(item$baselines$method == "lgb")) {
        lgb <- item$baselines$MASE[item$baselines$method == "lgb"][1]
      }
    }
    t1m <- t1_tuned_t1_recon_mase(item$sensor, item$pollutant, item$horizon)
    sprintf("- `%s`: T1-Tuned MASE=%s MAE=%s RMSE=%s | T1-untuned MASE=%s | WaveCatBoost MASE=%s | raw LightGBM MASE=%s | all six=%s",
            nm, t1_fmt(item$metrics$MASE), t1_fmt(item$metrics$MAE),
            t1_fmt(item$metrics$RMSE), t1_fmt(t1m), t1_fmt(wc), t1_fmt(lgb),
            isTRUE(item$used_all_six))
  }, character(1))
  md <- c(
    "# T1-Tuned — component-wise hyperparameter optimization",
    "",
    "Architecture map is **frozen** from the T1 CPCB PM2.5 1d validation selection.",
    "Only hyperparameters are searched. Test metrics are stored after selection and are not used to pick trials.",
    "",
    "## Frozen pipeline (reused, not duplicated)",
    "",
    sprintf("- Series: `data/processed/series.rds` via `t1_load_prepared_series()`."),
    sprintf("- Decomposition: stored `%s` via `t1_load_stored_components()` / `get_decomp()`.", T1_DECOMP_ID),
    sprintf("- Splits: `chrono_split_tvt` (`t1_split_y`), val_hours=%s.", VAL_HOURS),
    "- Scaling: train-window `minmax_fit` / `minmax_apply` / `minmax_invert` for trees and DLinear; SARIMA native scale.",
    "- Inputs: `t1_independent_lags` / `make_lags` on the target component only.",
    "- Forecast: `recursive_tree_forecast` (trees), `t1_forecast_dlinear`, `forecast_arima_obj`.",
    "- Reconstruction: `Y_hat = D1_hat + D2_hat + D3_hat + D4_hat + D5_hat + S5_hat` via `t1_build_reconstructed()`.",
    "- Metrics: `score_forecast` (MASE/MAE/RMSE).",
    "- Outputs only under `results/teammate_1/tuned/`. Original T1 files are not overwritten.",
    "",
    "## Frozen architecture map",
    "",
    map_lines,
    "",
    "## Search protocol",
    "",
    "- Objective: validation MASE of the component forecast (not reconstructed Y, not test).",
    "- Frozen T1 hyperparameters are always trial 0 and win ties.",
    sprintf("- LightGBM random trials (plus frozen): %s. Space: num_leaves, max_depth, eta, nrounds, min_child_samples, feature_fraction, lambda_l1/l2. `p` stays 24.", cfg$lgb_n),
    sprintf("- CatBoost random trials (plus frozen): %s. Space: depth, eta, iterations, l2_leaf_reg, random_strength, bagging_temperature.", cfg$cat_n),
    "- DLinear: exhaustive `p` × `kernel` only (OLS implementation has no lr/epochs/batch/dropout).",
    "- SARIMA: T1 frozen auto.arima (nonseasonal) + seasonal auto.arima + bounded (p,d,q) and a small seasonal subset at period 24.",
    "- Early stopping uses the original inner `split_val` tail of the current history window.",
    "",
    "## Run configuration",
    "",
    sprintf("- Mode: `%s`", cfg$mode),
    sprintf("- Sensors: %s", paste(cfg$sensors, collapse = ", ")),
    sprintf("- Horizons: %s", paste(cfg$horizons, collapse = ", ")),
    sprintf("- Validation trials recorded: %s", nrow(trials)),
    "",
    "## Selected hyperparameters (validation only)",
    "",
    sel_lines,
    "",
    "## Reconstructed PM2.5",
    "",
    recon_lines,
    "",
    t1_tuned_candidate_section(cmp),
    "## Files",
    "",
    "- `candidate_comparison.csv`",
    "- `candidate_comparison.md`",
    "- `plots/original_val_mase_heatmap.png`",
    "- `tuning_trials.csv`",
    "- `selected_hparams.csv` / `best_models.csv`",
    "- `component_metrics.csv`",
    "- `component_predictions.rds`",
    "- `heterogeneous_predictions.rds`",
    "- `reconstructed_predictions.rds`",
    "- `plots/`",
    "",
    "This report is filled from a real `run_teammate_1_tuned.R` run, not placeholder numbers.",
    "See `tests_executed.md` for tests that were actually run.",
    ""
  )
  writeLines(md, path)
  path
}
