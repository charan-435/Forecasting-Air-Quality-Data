# Point-forecast models. Recursive 1-step iteration out to horizon h.
# Tree models share the same lag-p design matrix. AR/SARIMA use original scale.

# Null-coalescing helper (avoids importing magrittr for one operator).
`%||%` <- function(a, b) if (!is.null(a)) a else b

default_tree_params <- function() {
  list(
    p = 24L,
    nrounds = 120L,
    max_depth = 6L,
    eta = 0.08,
    early_stopping = 30L,
    val_hours = 14L * 24L,
    lgb_leaves = 31L
  )
}

split_val <- function(X, y, val_hours) {
  n <- nrow(X)
  v <- min(val_hours, max(24L, floor(n * 0.15)))
  list(
    X_tr = X[seq_len(n - v), , drop = FALSE],
    y_tr = y[seq_len(n - v)],
    X_va = X[(n - v + 1):n, , drop = FALSE],
    y_va = y[(n - v + 1):n]
  )
}

# ---- Seasonal naive -------------------------------------------------------

forecast_snaive <- function(y_train, h, season = SEASONALITY) {
  as.numeric(forecast::snaive(stats::ts(y_train, frequency = season), h = h)$mean)
}

# ---- AR / SARIMA ----------------------------------------------------------

fit_ar <- function(y_train, p) {
  stats::arima(y_train, order = c(p, 0, 0), method = "CSS")
}

forecast_arima_obj <- function(fit, h) {
  as.numeric(forecast::forecast(fit, h = h)$mean)
}

fit_sarima_auto <- function(y_train, season = SEASONALITY) {
  forecast::auto.arima(
    stats::ts(y_train, frequency = season),
    stepwise = TRUE, approximation = TRUE, seasonal = TRUE,
    max.p = 3, max.q = 3, max.P = 1, max.Q = 1, max.d = 1, max.D = 1,
    trace = FALSE
  )
}

# ---- XGBoost --------------------------------------------------------------

fit_xgb <- function(y_train, params = default_tree_params()) {
  sup <- supervised_from_series(y_train, params$p)
  sp  <- split_val(sup$X, sup$y, params$val_hours)
  dtr <- xgboost::xgb.DMatrix(sp$X_tr, label = sp$y_tr)
  dva <- xgboost::xgb.DMatrix(sp$X_va, label = sp$y_va)
  watch <- list(train = dtr, eval = dva)
  model <- xgboost::xgb.train(
    params = list(
      objective = "reg:squarederror",
      max_depth = params$max_depth,
      eta = params$eta,
      subsample = 0.8,
      colsample_bytree = 0.8,
      nthread = 1
    ),
    data = dtr,
    nrounds = params$nrounds,
    watchlist = watch,
    early_stopping_rounds = params$early_stopping,
    verbose = 0
  )
  list(model = model, p = params$p, family = "xgb")
}

predict_xgb_row <- function(fit, row) {
  as.numeric(predict(fit$model, xgboost::xgb.DMatrix(row)))
}

# ---- LightGBM -------------------------------------------------------------

fit_lgb <- function(y_train, params = default_tree_params()) {
  sup <- supervised_from_series(y_train, params$p)
  sp  <- split_val(sup$X, sup$y, params$val_hours)
  dtr <- lightgbm::lgb.Dataset(sp$X_tr, label = sp$y_tr)
  dva <- lightgbm::lgb.Dataset.create.valid(dtr, sp$X_va, label = sp$y_va)
  model <- lightgbm::lgb.train(
    params = list(
      objective = "regression",
      metric = "l2",
      learning_rate = params$eta,
      num_leaves = params$lgb_leaves,
      max_depth = params$max_depth,
      feature_fraction = 0.8,
      bagging_fraction = 0.8,
      bagging_freq = 1,
      verbosity = -1
    ),
    data = dtr,
    nrounds = params$nrounds,
    valids = list(eval = dva),
    early_stopping_rounds = params$early_stopping,
    verbose = -1
  )
  list(model = model, p = params$p, family = "lgb")
}

predict_lgb_row <- function(fit, row) {
  as.numeric(predict(fit$model, row))
}

# ---- CatBoost (Ordered) or XGBoost fallback -------------------------------

fit_cat <- function(y_train, params = default_tree_params(),
                    catboost_ok = isTRUE(get0("CATBOOST_AVAILABLE",
                                              ifnotfound = FALSE))) {
  if (!catboost_ok) {
    out <- fit_xgb(y_train, params)
    out$family   <- "cat_fallback_xgb"
    out$fallback <- TRUE
    return(out)
  }
  sup      <- supervised_from_series(y_train, params$p)
  sp       <- split_val(sup$X, sup$y, params$val_hours)
  pool_tr  <- catboost::catboost.load_pool(sp$X_tr, label = sp$y_tr)
  pool_va  <- catboost::catboost.load_pool(sp$X_va, label = sp$y_va)
  model    <- catboost::catboost.train(
    pool_tr, pool_va,
    params = list(
      loss_function      = "RMSE",
      iterations         = params$nrounds,
      depth              = params$max_depth,
      learning_rate      = params$eta,
      boosting_type      = "Ordered",
      od_type            = "Iter",
      od_wait            = params$early_stopping,
      random_seed        = 7,
      verbose            = 0,
      allow_writing_files = FALSE,
      thread_count       = 1
    )
  )
  list(model = model, p = params$p, family = "cat", fallback = FALSE)
}

predict_cat_row <- function(fit, row) {
  if (identical(fit$family, "cat")) {
    pool <- catboost::catboost.load_pool(row)
    return(as.numeric(catboost::catboost.predict(fit$model, pool)))
  }
  predict_xgb_row(fit, row)
}

predict_tree_row <- function(fit, row) {
  switch(fit$family,
    xgb              = predict_xgb_row(fit, row),
    lgb              = predict_lgb_row(fit, row),
    cat              = predict_cat_row(fit, row),
    cat_fallback_xgb = predict_xgb_row(fit, row),
    stop("Unknown tree family: ", fit$family)
  )
}

recursive_tree_forecast <- function(fit, y_hist, h) {
  y  <- as.numeric(y_hist)
  p  <- fit$p
  fc <- numeric(h)
  for (i in seq_len(h)) {
    row   <- last_lag_row(y, p)
    fc[i] <- predict_tree_row(fit, row)
    y     <- c(y, fc[i])
  }
  fc
}

# ---- Wave hybrids: one model per MRA component, then sum ------------------
# filter: "haar" (paper default), "d4", "la8"  — passed to generic_mra().

wave_fit_components <- function(y_train, J, fitter, params, filter = "haar") {
  mra    <- generic_mra(y_train, J, filter = filter)
  comps  <- c(mra$D, list(S = mra$S))
  models <- lapply(comps, function(comp) fitter(comp, params))
  list(models = models, J = J, names = names(comps), filter = filter)
}

wave_forecast_components <- function(wave_fit, y_train, h, fitter_kind = "tree") {
  filt  <- wave_fit$filter %||% "haar"
  mra   <- generic_mra(y_train, wave_fit$J, filter = filt)
  comps <- c(mra$D, list(S = mra$S))
  fc    <- vector("list", length(comps))
  names(fc) <- names(comps)
  for (nm in names(comps)) {
    if (fitter_kind == "tree") {
      fc[[nm]] <- recursive_tree_forecast(wave_fit$models[[nm]], comps[[nm]], h)
    } else {
      fc[[nm]] <- forecast_arima_obj(wave_fit$models[[nm]], h)
    }
  }
  list(components = fc, yhat = mra_forecast_sum(fc))
}

wave_fit_sarima <- function(y_train, J, filter = "haar") {
  mra    <- generic_mra(y_train, J, filter = filter)
  comps  <- c(mra$D, list(S = mra$S))
  models <- lapply(comps, function(comp) {
    # Detail series are closer to stationary; still use auto.arima.
    forecast::auto.arima(
      stats::ts(comp, frequency = SEASONALITY),
      stepwise = TRUE, approximation = TRUE, seasonal = FALSE,
      max.p = 3, max.q = 1, max.d = 1, trace = FALSE
    )
  })
  list(models = models, J = J, names = names(comps), family = "wave_sarima",
       filter = filter)
}

# ---- One-shot dispatcher --------------------------------------------------

fit_and_forecast <- function(method, y_train, h,
                              params = default_tree_params(),
                              J = 5L,
                              filter = "haar") {
  method <- tolower(method)
  if (method == "snaive") {
    return(list(yhat = forecast_snaive(y_train, h), method = method))
  }
  if (method == "ar") {
    fit <- fit_ar(y_train, params$p)
    return(list(yhat = forecast_arima_obj(fit, h), method = method, fit = fit))
  }
  if (method == "sarima") {
    fit <- fit_sarima_auto(y_train)
    return(list(yhat = forecast_arima_obj(fit, h), method = method, fit = fit))
  }
  if (method == "xgb") {
    fit <- fit_xgb(y_train, params)
    return(list(yhat = recursive_tree_forecast(fit, y_train, h),
                method = method, fit = fit))
  }
  if (method == "lgb") {
    fit <- fit_lgb(y_train, params)
    return(list(yhat = recursive_tree_forecast(fit, y_train, h),
                method = method, fit = fit))
  }
  if (method == "catboost") {
    fit <- fit_cat(y_train, params)
    return(list(yhat = recursive_tree_forecast(fit, y_train, h),
                method = method, fit = fit))
  }
  if (method == "wavexgb") {
    wf <- wave_fit_components(y_train, J, fit_xgb, params, filter = filter)
    fc <- wave_forecast_components(wf, y_train, h, "tree")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components))
  }
  if (method == "wavelgb") {
    wf <- wave_fit_components(y_train, J, fit_lgb, params, filter = filter)
    fc <- wave_forecast_components(wf, y_train, h, "tree")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components))
  }
  if (method == "wavecatboost") {
    wf <- wave_fit_components(y_train, J, fit_cat, params, filter = filter)
    fc <- wave_forecast_components(wf, y_train, h, "tree")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components))
  }
  if (method == "wavesarima") {
    wf <- wave_fit_sarima(y_train, J, filter = filter)
    fc <- wave_forecast_components(wf, y_train, h, "sarima")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components))
  }
  stop("Unknown method: ", method)
}
