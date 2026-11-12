# Point forecasts. Recursive 1-step out to horizon h.
# Trees share lag-p features; AR/SARIMA stay on original scale.

# %||% without pulling in magrittr.
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

# Darts CatBoostModel defaults used in the letter notebook:
# lags=24, 1000 trees, auto learning rate, no early-stopping val split.
paper_tree_params <- function() {
  list(
    p = 24L,
    nrounds = 1000L,
    max_depth = 6L,
    eta = NA_real_,
    early_stopping = NA_integer_,
    val_hours = 0L,
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

forecast_snaive <- function(y_train, h, season = SEASONALITY) {
  as.numeric(forecast::snaive(stats::ts(y_train, frequency = season), h = h)$mean)
}

fit_ar <- function(y_train, p) {
  stats::arima(y_train, order = c(p, 0, 0), method = "CSS")
}

forecast_arima_obj <- function(fit, h) {
  as.numeric(forecast::forecast(fit, h = h)$mean)
}

# Rolled 1-step: each origin uses observed history (teacher forcing), no retrain
# of the coefficient structure beyond applying the frozen model to the prefix.
walkforward_arima <- function(fit, y_hist, y_future, season = SEASONALITY) {
  y <- as.numeric(y_hist)
  y_future <- as.numeric(y_future)
  h <- length(y_future)
  fc <- numeric(h)
  for (i in seq_len(h)) {
    fit_i <- tryCatch(
      forecast::Arima(stats::ts(y, frequency = season), model = fit),
      error = function(e) {
        forecast::auto.arima(
          stats::ts(y, frequency = season),
          stepwise = TRUE, approximation = TRUE, seasonal = TRUE,
          max.p = 2, max.q = 2, max.P = 1, max.Q = 1, max.d = 1, max.D = 1,
          trace = FALSE
        )
      }
    )
    fc[i] <- as.numeric(forecast::forecast(fit_i, h = 1L)$mean)[1L]
    y <- c(y, y_future[i])
  }
  fc
}

fit_sarima_auto <- function(y_train, season = SEASONALITY) {
  forecast::auto.arima(
    stats::ts(y_train, frequency = season),
    stepwise = TRUE, approximation = TRUE, seasonal = TRUE,
    max.p = 3, max.q = 3, max.P = 1, max.Q = 1, max.d = 1, max.D = 1,
    trace = FALSE
  )
}

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

# Letter notebook: fit on the full training slice, 1000 iterations, auto η.
fit_cat_paper <- function(y_train, params = paper_tree_params(),
                          catboost_ok = isTRUE(get0("CATBOOST_AVAILABLE",
                                                    ifnotfound = FALSE))) {
  if (!catboost_ok) {
    sup <- supervised_from_series(y_train, params$p)
    dtr <- xgboost::xgb.DMatrix(sup$X, label = sup$y)
    model <- xgboost::xgb.train(
      params = list(
        objective = "reg:squarederror",
        max_depth = params$max_depth %||% 6L,
        eta = 0.057612,
        subsample = 0.8,
        colsample_bytree = 0.8,
        nthread = 1
      ),
      data = dtr,
      nrounds = params$nrounds %||% 1000L,
      verbose = 0
    )
    return(list(model = model, p = params$p, family = "cat_fallback_xgb",
                fallback = TRUE))
  }
  sup <- supervised_from_series(y_train, params$p)
  pool_tr <- catboost::catboost.load_pool(sup$X, label = sup$y)
  cb <- list(
    loss_function       = "RMSE",
    iterations          = as.integer(params$nrounds %||% 1000L),
    depth               = as.integer(params$max_depth %||% 6L),
    boosting_type       = "Ordered",
    random_seed         = 7,
    verbose             = 0,
    allow_writing_files = FALSE,
    thread_count        = 1
  )
  model <- catboost::catboost.train(pool_tr, NULL, params = cb)
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
  # No actuals arrive during this forecast path: each prediction becomes history
  # for the next step. Keep this separate from the rolling one-step evaluator.
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

# Darts historical_forecasts analogue: 1-step, observed lags, no retrain.
# y_future is the actual continuation (teacher forcing), not previous predictions.
walkforward_tree_forecast <- function(fit, y_hist, y_future) {
  y  <- as.numeric(y_hist)
  p  <- fit$p
  h  <- length(y_future)
  fc <- numeric(h)
  y_future <- as.numeric(y_future)
  for (i in seq_len(h)) {
    row   <- last_lag_row(y, p)
    fc[i] <- predict_tree_row(fit, row)
    y     <- c(y, y_future[i])
  }
  fc
}

walkforward_snaive <- function(y_hist, y_future, season = SEASONALITY) {
  y <- c(as.numeric(y_hist), as.numeric(y_future))
  ntr <- length(y_hist)
  h <- length(y_future)
  y[(ntr + seq_len(h)) - season]
}

# Original notebook protocol (jborah2/WaveCatBoost-Time-Series-Model):
#   Haar MODWT on the full series (K = ln N), CatBoost(lags=24) per coefficient,
#   walk-forward 1-step on each W_j / V_K using observed coefficient lags,
#   then IMODWT of the predicted coefficients.
# This is what makes Fig. 2 track the actuals. Recursive 168-step does not.
paper_wave_walkforward <- function(y, h, J, fitter, params) {
  y <- as.numeric(y)
  n <- length(y)
  if (h >= n) stop("Horizon longer than the series.")
  J <- as.integer(J)
  wt <- haar_modwt(y, J)
  comps <- c(wt$W, list(V = wt$V))
  What <- vector("list", J)
  names(What) <- names(wt$W)
  Vhat <- NULL
  models <- list()
  for (nm in names(comps)) {
    comp <- comps[[nm]]
    y_tr <- comp[seq_len(n - h)]
    y_te <- comp[(n - h + 1):n]
    message("  component ", nm)
    fit <- fitter(y_tr, params)
    models[[nm]] <- fit
    fc <- walkforward_tree_forecast(fit, y_tr, y_te)
    if (nm == "V") Vhat <- fc else What[[nm]] <- fc
  }
  # Inverse on the full timeline (train actual coeffs + test forecasts).
  # IMODWT of the 168-point window alone is ill-posed at K = ln N.
  Wfull <- lapply(names(wt$W), function(nm) {
    c(wt$W[[nm]][seq_len(n - h)], What[[nm]])
  })
  names(Wfull) <- names(wt$W)
  Vfull <- c(wt$V[seq_len(n - h)], Vhat)
  yhat <- tail(as.numeric(haar_imodwt(Wfull, Vfull)), h)
  list(yhat = yhat, models = models, J = J, What = What, Vhat = Vhat)
}

paper_wave_insample <- function(models, y_train, J, max_n = 400L) {
  y_train <- as.numeric(y_train)
  if (length(y_train) > max_n) y_train <- tail(y_train, max_n)
  wt <- haar_modwt(y_train, J)
  comps <- c(wt$W, list(V = wt$V))
  parts <- lapply(names(comps), function(nm) tree_insample(models[[nm]], comps[[nm]]))
  L <- min(vapply(parts, function(z) length(z$yhat), integer(1)))
  What <- lapply(seq_len(J), function(j) tail(parts[[j]]$yhat, L))
  names(What) <- names(wt$W)
  Vhat <- tail(parts[[J + 1L]]$yhat, L)
  list(y = tail(y_train, L), yhat = as.numeric(haar_imodwt(What, Vhat)))
}

# filter: "haar" (paper default), "d4", "la8"  — passed to generic_mra().

wave_fit_components <- function(y_train, J, fitter, params, filter = "haar") {
  # This is the original periodic MRA path, retained for the recorded benchmark.
  # Train-only decomposition still has boundary effects; causal stores use a
  # separate implementation under R/decomposition/.
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

# Honest rolled 1-step: at origin t the model sees y[1:t] only.
# MRA is recomputed on that prefix (test hour t+1 is not in the filter).
# Frozen component models (trained on the pre-test window).
wave_walkforward_1step <- function(wave_fit, y, n_train, h, fitter_kind = "tree") {
  y <- as.numeric(y)
  n <- length(y)
  n_train <- as.integer(n_train)
  h <- as.integer(h)
  if (n_train + h > n) stop("walk-forward window exceeds series length.")
  filt <- wave_fit$filter %||% "haar"
  J <- as.integer(wave_fit$J)
  fitter_kind <- tolower(fitter_kind)
  yhat <- numeric(h)
  for (i in seq_len(h)) {
    origin <- n_train + i - 1L
    mra <- generic_mra(y[seq_len(origin)], J, filter = filt)
    comps <- c(mra$D, list(S = mra$S))
    acc <- 0
    for (nm in names(wave_fit$models)) {
      fit <- wave_fit$models[[nm]]
      if (fitter_kind == "tree") {
        acc <- acc + predict_tree_row(fit, last_lag_row(comps[[nm]], fit$p))
      } else {
        fit_i <- tryCatch(
          forecast::Arima(stats::ts(comps[[nm]], frequency = SEASONALITY), model = fit),
          error = function(e) fit
        )
        acc <- acc + as.numeric(forecast::forecast(fit_i, h = 1L)$mean)[1L]
      }
    }
    yhat[i] <- acc
  }
  yhat
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

# y_future: if provided, use rolled (walk-forward 1-step) with observed lags;
#           if NULL, use recursive multi-step from one origin (legacy).

fit_and_forecast <- function(method, y_train, h,
                              params = default_tree_params(),
                              J = 5L,
                              filter = "haar",
                              y_future = NULL) {
  method <- tolower(method)
  y_train <- as.numeric(y_train)
  rolled <- !is.null(y_future)
  if (rolled) {
    y_future <- as.numeric(y_future)
    h <- length(y_future)
  }

  if (method == "snaive") {
    yhat <- if (rolled) {
      walkforward_snaive(y_train, y_future)
    } else {
      forecast_snaive(y_train, h)
    }
    return(list(yhat = yhat, method = method, protocol = if (rolled) "rolled" else "recursive"))
  }
  if (method == "ar") {
    fit <- fit_ar(y_train, params$p)
    yhat <- if (rolled) walkforward_arima(fit, y_train, y_future) else forecast_arima_obj(fit, h)
    return(list(yhat = yhat, method = method, fit = fit,
                protocol = if (rolled) "rolled" else "recursive"))
  }
  if (method == "sarima") {
    fit <- fit_sarima_auto(y_train)
    yhat <- if (rolled) walkforward_arima(fit, y_train, y_future) else forecast_arima_obj(fit, h)
    return(list(yhat = yhat, method = method, fit = fit,
                protocol = if (rolled) "rolled" else "recursive"))
  }
  if (method == "xgb") {
    fit <- fit_xgb(y_train, params)
    yhat <- if (rolled) {
      walkforward_tree_forecast(fit, y_train, y_future)
    } else {
      recursive_tree_forecast(fit, y_train, h)
    }
    return(list(yhat = yhat, method = method, fit = fit,
                protocol = if (rolled) "rolled" else "recursive"))
  }
  if (method == "lgb") {
    fit <- fit_lgb(y_train, params)
    yhat <- if (rolled) {
      walkforward_tree_forecast(fit, y_train, y_future)
    } else {
      recursive_tree_forecast(fit, y_train, h)
    }
    return(list(yhat = yhat, method = method, fit = fit,
                protocol = if (rolled) "rolled" else "recursive"))
  }
  if (method == "catboost") {
    fit <- fit_cat(y_train, params)
    yhat <- if (rolled) {
      walkforward_tree_forecast(fit, y_train, y_future)
    } else {
      recursive_tree_forecast(fit, y_train, h)
    }
    return(list(yhat = yhat, method = method, fit = fit,
                protocol = if (rolled) "rolled" else "recursive"))
  }
  if (method == "wavexgb") {
    wf <- wave_fit_components(y_train, J, fit_xgb, params, filter = filter)
    if (rolled) {
      yhat <- wave_walkforward_1step(wf, c(y_train, y_future), length(y_train), h, "tree")
      return(list(yhat = yhat, method = method, fit = wf, protocol = "rolled"))
    }
    fc <- wave_forecast_components(wf, y_train, h, "tree")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components, protocol = "recursive"))
  }
  if (method == "wavelgb") {
    wf <- wave_fit_components(y_train, J, fit_lgb, params, filter = filter)
    if (rolled) {
      yhat <- wave_walkforward_1step(wf, c(y_train, y_future), length(y_train), h, "tree")
      return(list(yhat = yhat, method = method, fit = wf, protocol = "rolled"))
    }
    fc <- wave_forecast_components(wf, y_train, h, "tree")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components, protocol = "recursive"))
  }
  if (method == "wavecatboost") {
    wf <- wave_fit_components(y_train, J, fit_cat, params, filter = filter)
    if (rolled) {
      yhat <- wave_walkforward_1step(wf, c(y_train, y_future), length(y_train), h, "tree")
      return(list(yhat = yhat, method = method, fit = wf, protocol = "rolled"))
    }
    fc <- wave_forecast_components(wf, y_train, h, "tree")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components, protocol = "recursive"))
  }
  if (method == "wavesarima") {
    wf <- wave_fit_sarima(y_train, J, filter = filter)
    if (rolled) {
      yhat <- wave_walkforward_1step(wf, c(y_train, y_future), length(y_train), h, "sarima")
      return(list(yhat = yhat, method = method, fit = wf, protocol = "rolled"))
    }
    fc <- wave_forecast_components(wf, y_train, h, "sarima")
    return(list(yhat = fc$yhat, method = method, fit = wf,
                components = fc$components, protocol = "recursive"))
  }
  stop("Unknown method: ", method)
}
