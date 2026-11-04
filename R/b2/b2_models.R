# B2 model fitters — direct fixed-horizon supervised learning.
# No recursive multi-step. No deep learning.

b2_fit_lgb_xy <- function(X_tr, y_tr, X_va, y_va, params) {
  dtr <- lightgbm::lgb.Dataset(X_tr, label = y_tr)
  dva <- lightgbm::lgb.Dataset.create.valid(dtr, X_va, label = y_va)
  model <- lightgbm::lgb.train(
    params = list(
      objective = "regression",
      metric = "l2",
      learning_rate = params$eta,
      num_leaves = as.integer(params$lgb_leaves %||% 31L),
      max_depth = as.integer(params$max_depth),
      feature_fraction = as.numeric(params$feature_fraction %||% 0.8),
      bagging_fraction = as.numeric(params$bagging_fraction %||% 0.8),
      bagging_freq = 1,
      min_data_in_leaf = as.integer(params$min_data_in_leaf %||% 20L),
      verbosity = -1
    ),
    data = dtr,
    nrounds = as.integer(params$nrounds),
    valids = list(eval = dva),
    early_stopping_rounds = as.integer(params$early_stopping %||% 30L),
    verbose = -1
  )
  list(model = model, family = "lgb", params = params)
}

b2_predict_lgb <- function(fit, X) {
  as.numeric(predict(fit$model, X))
}

b2_fit_xgb_xy <- function(X_tr, y_tr, X_va, y_va, params) {
  dtr <- xgboost::xgb.DMatrix(X_tr, label = y_tr)
  dva <- xgboost::xgb.DMatrix(X_va, label = y_va)
  model <- xgboost::xgb.train(
    params = list(
      objective = "reg:squarederror",
      max_depth = as.integer(params$max_depth),
      eta = as.numeric(params$eta),
      subsample = 0.8,
      colsample_bytree = as.numeric(params$feature_fraction %||% 0.8),
      nthread = 1
    ),
    data = dtr,
    nrounds = as.integer(params$nrounds),
    watchlist = list(train = dtr, eval = dva),
    early_stopping_rounds = as.integer(params$early_stopping %||% 30L),
    verbose = 0
  )
  list(model = model, family = "xgb", params = params)
}

b2_predict_xgb <- function(fit, X) {
  as.numeric(predict(fit$model, xgboost::xgb.DMatrix(X)))
}

b2_fit_cat_xy <- function(X_tr, y_tr, X_va, y_va, params,
                          catboost_ok = isTRUE(get0("CATBOOST_AVAILABLE",
                                                    ifnotfound = FALSE))) {
  if (!catboost_ok) stop("CatBoost unavailable for B2.")
  pool_tr <- catboost::catboost.load_pool(X_tr, label = y_tr)
  pool_va <- catboost::catboost.load_pool(X_va, label = y_va)
  model <- catboost::catboost.train(
    pool_tr, pool_va,
    params = list(
      loss_function = "RMSE",
      iterations = as.integer(params$nrounds),
      depth = as.integer(params$max_depth),
      learning_rate = as.numeric(params$eta),
      boosting_type = "Ordered",
      od_type = "Iter",
      od_wait = as.integer(params$early_stopping %||% 30L),
      random_seed = B2_SEED,
      verbose = 0,
      allow_writing_files = FALSE,
      thread_count = 1
    )
  )
  list(model = model, family = "cat", params = params)
}

b2_predict_cat <- function(fit, X) {
  pool <- catboost::catboost.load_pool(X)
  as.numeric(catboost::catboost.predict(fit$model, pool))
}

b2_fit_glmnet_xy <- function(X_tr, y_tr, X_va, y_va, alpha = 1,
                             family_name = "lasso") {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop("Package glmnet required for ridge/lasso/elasticnet.")
  }
  # Choose lambda by validation MAE (no test).
  fit <- glmnet::glmnet(X_tr, y_tr, alpha = alpha, standardize = FALSE)
  preds <- predict(fit, newx = X_va)
  maes <- apply(preds, 2, function(yh) mean(abs(yh - y_va), na.rm = TRUE))
  j <- which.min(maes)
  list(
    model = fit, family = family_name, alpha = alpha,
    lambda = fit$lambda[j], lambda_index = j, params = list(alpha = alpha)
  )
}

b2_predict_glmnet <- function(fit, X) {
  as.numeric(predict(fit$model, newx = X, s = fit$lambda))
}

b2_fit_dispatcher <- function(model_id, X_tr, y_tr, X_va, y_va, params) {
  set.seed(B2_SEED)
  if (identical(model_id, "lgb")) {
    b2_fit_lgb_xy(X_tr, y_tr, X_va, y_va, params)
  } else if (identical(model_id, "xgb")) {
    b2_fit_xgb_xy(X_tr, y_tr, X_va, y_va, params)
  } else if (identical(model_id, "catboost")) {
    b2_fit_cat_xy(X_tr, y_tr, X_va, y_va, params)
  } else if (identical(model_id, "ridge")) {
    b2_fit_glmnet_xy(X_tr, y_tr, X_va, y_va, alpha = 0, "ridge")
  } else if (identical(model_id, "lasso")) {
    b2_fit_glmnet_xy(X_tr, y_tr, X_va, y_va, alpha = 1, "lasso")
  } else if (identical(model_id, "elasticnet")) {
    b2_fit_glmnet_xy(X_tr, y_tr, X_va, y_va, alpha = 0.5, "elasticnet")
  } else {
    stop("Unknown B2 model_id: ", model_id)
  }
}

b2_predict_dispatcher <- function(fit, X) {
  switch(fit$family,
    lgb = b2_predict_lgb(fit, X),
    xgb = b2_predict_xgb(fit, X),
    cat = b2_predict_cat(fit, X),
    ridge = b2_predict_glmnet(fit, X),
    lasso = b2_predict_glmnet(fit, X),
    elasticnet = b2_predict_glmnet(fit, X),
    stop("Unknown family: ", fit$family)
  )
}

# Feature selection / DR fit on train only ---------------------------------

b2_select_variance <- function(X_tr, thresh = 1e-10) {
  v <- apply(X_tr, 2, stats::var, na.rm = TRUE)
  which(is.finite(v) & v > thresh)
}

b2_select_correlation <- function(X_tr, y_tr, top_k = 200L) {
  cors <- apply(X_tr, 2, function(z) {
    suppressWarnings(stats::cor(z, y_tr, use = "complete.obs"))
  })
  cors[!is.finite(cors)] <- 0
  ord <- order(abs(cors), decreasing = TRUE)
  ord[seq_len(min(top_k, length(ord)))]
}

b2_select_mi <- function(X_tr, y_tr, top_k = 200L, n_bins = 10L) {
  # Reuse EDA discretize/MI if available; else simple correlation proxy.
  if (exists("eda_mi")) {
    mi <- apply(X_tr, 2, function(z) eda_mi(z, y_tr, n_bins))
  } else {
    mi <- abs(apply(X_tr, 2, function(z) {
      suppressWarnings(stats::cor(z, y_tr, use = "complete.obs"))
    }))
  }
  mi[!is.finite(mi)] <- 0
  ord <- order(mi, decreasing = TRUE)
  ord[seq_len(min(top_k, length(ord)))]
}

b2_fit_pca <- function(X_tr, ncomp = 50L) {
  pr <- stats::prcomp(X_tr, center = TRUE, scale. = FALSE)
  ncomp <- min(as.integer(ncomp), ncol(X_tr), nrow(X_tr) - 1L)
  list(pr = pr, ncomp = ncomp)
}

b2_apply_pca <- function(pca_fit, X) {
  as.matrix(predict(pca_fit$pr, X)[, seq_len(pca_fit$ncomp), drop = FALSE])
}

b2_importance_lgb <- function(fit, feature_names, top_n = 40L) {
  if (!identical(fit$family, "lgb")) return(tibble::tibble())
  imp <- lightgbm::lgb.importance(fit$model)
  if (is.null(imp) || !nrow(imp)) return(tibble::tibble())
  tibble::as_tibble(imp) %>%
    dplyr::mutate(rank = dplyr::row_number()) %>%
    dplyr::slice(1:min(top_n, dplyr::n()))
}
