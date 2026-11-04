# Additional model families for the multivariate pipeline (Phase 2).
# Same interface as R/43_mv_models.R: fit(X_tr, y_tr, X_va, y_va, params, seed,
# nrounds, early_stopping) and predict(fit, X). With early_stopping = TRUE the
# validation rows select the iteration count (trees) or the penalty / number of
# components (linear); the refit receives that choice frozen and never sees
# validation or test labels. Every family runs single-threaded.
# Linear families expect inputs already standardized by a train-fitted transform
# (mv_transform_standardize); they do no scaling of their own.

# ---- XGBoost ----------------------------------------------------------------------

.mv_xgb_params <- function(params, seed) {
  keep <- c("eta", "max_depth", "min_child_weight", "subsample", "colsample_bytree",
            "lambda", "alpha", "gamma", "max_bin", "tree_method")
  p <- params[intersect(names(params), keep)]
  p$objective <- "reg:squarederror"
  p$eval_metric <- "rmse"
  p$nthread <- 1L
  p$seed <- as.integer(seed)
  p$tree_method <- p$tree_method %||% "hist"
  p
}

.mv_xgb_fit <- function(X_tr, y_tr, X_va = NULL, y_va = NULL, params, seed,
                        nrounds, early_stopping = TRUE) {
  p <- .mv_xgb_params(params, seed)
  dtr <- xgboost::xgb.DMatrix(X_tr, label = y_tr, nthread = 1L)
  args <- list(params = p, data = dtr, nrounds = as.integer(nrounds), verbose = 0L)
  if (isTRUE(early_stopping)) {
    if (is.null(X_va)) stop("early stopping needs a validation block")
    args$evals <- list(validation = xgboost::xgb.DMatrix(X_va, label = y_va, nthread = 1L))
    args$early_stopping_rounds <- as.integer(params$early_stopping_rounds)
  }
  model <- do.call(xgboost::xgb.train, args)
  ran <- as.integer(xgboost::xgb.get.num.boosted.rounds(model))
  if (isTRUE(early_stopping)) {
    curve <- attributes(model)$evaluation_log$validation_rmse   # xgboost >= 3 keeps it in attributes
    best <- which.min(curve)                 # 1-based round count with the lowest l2
    score <- curve[best]^2
  } else {
    best <- ran; score <- NA_real_
  }
  list(model = model, best_iter = best, iterations_run = ran, best_score = score,
       early_stopped = isTRUE(early_stopping) && ran < nrounds, family = "xgboost")
}

# iterationrange is 1-based and inclusive in xgboost >= 3 (checked by test P04).
.mv_xgb_predict <- function(fit, X) {
  as.numeric(stats::predict(fit$model, xgboost::xgb.DMatrix(X, nthread = 1L),
                            iterationrange = c(1L, as.integer(fit$best_iter))))
}

.mv_xgb_importance <- function(fit) {
  imp <- xgboost::xgb.importance(model = fit$model)
  stats::setNames(imp$Gain, imp$Feature)
}

mv_register_family("xgboost", "xgboost", .mv_xgb_fit, .mv_xgb_predict, .mv_xgb_importance)

# ---- CatBoost ---------------------------------------------------------------------

.mv_cat_params <- function(params, seed, nrounds) {
  keep <- c("learning_rate", "depth", "l2_leaf_reg", "rsm", "border_count",
            "bootstrap_type", "subsample", "min_data_in_leaf")
  p <- params[intersect(names(params), keep)]
  p$loss_function <- "RMSE"
  p$iterations <- as.integer(nrounds)
  p$random_seed <- as.integer(seed)
  p$thread_count <- 1L
  p$logging_level <- "Silent"
  p$allow_writing_files <- FALSE
  p
}

.mv_cat_fit <- function(X_tr, y_tr, X_va = NULL, y_va = NULL, params, seed,
                        nrounds, early_stopping = TRUE) {
  p <- .mv_cat_params(params, seed, nrounds)
  ptr <- catboost::catboost.load_pool(X_tr, label = y_tr)
  if (isTRUE(early_stopping)) {
    if (is.null(X_va)) stop("early stopping needs a validation block")
    p$od_type <- "Iter"
    p$od_wait <- as.integer(params$early_stopping_rounds)
    p$use_best_model <- TRUE
    model <- catboost::catboost.train(ptr, catboost::catboost.load_pool(X_va, label = y_va),
                                      params = p)
  } else {
    model <- catboost::catboost.train(ptr, NULL, params = p)
  }
  best <- as.integer(model$tree_count)       # use_best_model truncates to the best round
  list(model = model, best_iter = best, iterations_run = NA_integer_,
       best_score = NA_real_, early_stopped = isTRUE(early_stopping) && best < nrounds,
       feature_names = colnames(X_tr), family = "catboost")
}

.mv_cat_predict <- function(fit, X) {
  as.numeric(catboost::catboost.predict(fit$model, catboost::catboost.load_pool(X),
                                        thread_count = 1L))
}

.mv_cat_importance <- function(fit) {
  imp <- catboost::catboost.get_feature_importance(fit$model, thread_count = 1L)
  stats::setNames(as.numeric(imp), fit$feature_names)
}

mv_register_family("catboost", "catboost", .mv_cat_fit, .mv_cat_predict, .mv_cat_importance)

# ---- Penalised linear (glmnet) ------------------------------------------------------
# Selection fit: the full lambda path on the training rows; validation MAE picks
# lambda. Refit: the chosen lambda value (not its index) is frozen.

.mv_glmnet_maker <- function(family_name, default_alpha) {
  fit <- function(X_tr, y_tr, X_va = NULL, y_va = NULL, params, seed,
                  nrounds, early_stopping = TRUE) {
    alpha <- as.numeric(params$alpha %||% default_alpha)
    if (isTRUE(early_stopping)) {
      if (is.null(X_va)) stop("lambda selection needs a validation block")
      m <- glmnet::glmnet(X_tr, y_tr, alpha = alpha, standardize = FALSE,
                          nlambda = as.integer(params$nlambda %||% 100L),
                          lambda.min.ratio = as.numeric(params$lambda_min_ratio %||% 1e-4),
                          control = list(maxit = 1e6))
      pv <- stats::predict(m, X_va)
      mae <- colMeans(abs(pv - y_va))
      best <- which.min(mae)
      lam <- m$lambda[best]
      list(model = m, lambda = lam, best_iter = best, iterations_run = length(m$lambda),
           best_score = mean((pv[, best] - y_va)^2), early_stopped = FALSE,
           refit_params = list(lambda = lam), alpha = alpha,
           nonzero = sum(as.numeric(stats::coef(m, s = lam))[-1] != 0), family = family_name)
    } else {
      lam <- params$lambda
      if (is.null(lam)) stop(family_name, " refit needs a frozen lambda")
      m <- glmnet::glmnet(X_tr, y_tr, alpha = alpha, standardize = FALSE,
                          lambda = lam, control = list(maxit = 1e6))
      list(model = m, lambda = lam, best_iter = 1L, iterations_run = 1L,
           best_score = NA_real_, early_stopped = FALSE, alpha = alpha,
           nonzero = sum(as.numeric(stats::coef(m, s = lam))[-1] != 0), family = family_name)
    }
  }
  predict <- function(fit, X) as.numeric(stats::predict(fit$model, X, s = fit$lambda))
  importance <- function(fit) {
    b <- as.numeric(stats::coef(fit$model, s = fit$lambda))[-1]
    stats::setNames(abs(b), rownames(stats::coef(fit$model, s = fit$lambda))[-1])
  }
  mv_register_family(family_name, "glmnet", fit, predict, importance)
}
.mv_glmnet_maker("ridge", 0)
.mv_glmnet_maker("lasso", 1)
.mv_glmnet_maker("elasticnet", 0.5)

# ---- OLS (used after PCA = principal-component regression) -------------------------

.mv_ols_fit <- function(X_tr, y_tr, X_va = NULL, y_va = NULL, params, seed,
                        nrounds, early_stopping = TRUE) {
  m <- stats::lm.fit(cbind(1, X_tr), y_tr)
  b <- m$coefficients; b[is.na(b)] <- 0
  list(coef = b, best_iter = 1L, iterations_run = 1L, best_score = NA_real_,
       early_stopped = FALSE, feature_names = colnames(X_tr), family = "ols")
}
.mv_ols_predict <- function(fit, X) as.numeric(cbind(1, X) %*% fit$coef)
.mv_ols_importance <- function(fit) stats::setNames(abs(fit$coef[-1]), fit$feature_names)
mv_register_family("ols", character(0), .mv_ols_fit, .mv_ols_predict, .mv_ols_importance)

# ---- PLS regression ------------------------------------------------------------------
# Validation MAE picks the number of components (1..max_ncomp); refit freezes it.

.mv_pls_fit <- function(X_tr, y_tr, X_va = NULL, y_va = NULL, params, seed,
                        nrounds, early_stopping = TRUE) {
  kmax <- min(as.integer(params$max_ncomp %||% 30L), ncol(X_tr), nrow(X_tr) - 1L)
  if (isTRUE(early_stopping)) {
    m <- pls::plsr(y ~ X, ncomp = kmax, data = list(y = y_tr, X = X_tr),
                   method = "simpls", scale = FALSE, validation = "none")
    pv <- stats::predict(m, newdata = list(X = X_va), ncomp = seq_len(kmax))[, 1, ]
    mae <- colMeans(abs(pv - y_va))
    k <- which.min(mae)
    list(model = m, ncomp = k, best_iter = k, iterations_run = kmax,
         best_score = mean((pv[, k] - y_va)^2), early_stopped = FALSE,
         refit_params = list(ncomp = k), family = "pls")
  } else {
    k <- as.integer(params$ncomp)
    if (!length(k)) stop("pls refit needs a frozen ncomp")
    m <- pls::plsr(y ~ X, ncomp = k, data = list(y = y_tr, X = X_tr),
                   method = "simpls", scale = FALSE, validation = "none")
    list(model = m, ncomp = k, best_iter = k, iterations_run = k, best_score = NA_real_,
         early_stopped = FALSE, family = "pls")
  }
}
.mv_pls_predict <- function(fit, X) {
  as.numeric(stats::predict(fit$model, newdata = list(X = X), ncomp = fit$ncomp)[, 1, 1])
}
.mv_pls_importance <- function(fit) {
  b <- stats::coef(fit$model, ncomp = fit$ncomp)[, 1, 1]
  abs(b)
}
mv_register_family("pls", "pls", .mv_pls_fit, .mv_pls_predict, .mv_pls_importance)

# Families whose inputs must be standardized by a train-fitted transform.
mv_linear_families <- function() c("ridge", "lasso", "elasticnet", "ols", "pls")
mv_stochastic_families <- function() c("lightgbm", "xgboost", "catboost")
