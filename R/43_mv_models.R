# External-feature-matrix model interface (Phase 1).
# A family is fit(X_tr, y_tr, X_va, y_va, params, seed, nrounds, early_stopping)
# plus predict(fit, X). Feature construction does not depend on the family.
# Only LightGBM is registered in Phase 1. A family whose package is missing
# raises an error; there is no fallback to another family.

.mv_families <- new.env(parent = emptyenv())

# importance(fit) -> named numeric over the model's input columns (optional).
mv_register_family <- function(name, packages, fit, predict, importance = NULL) {
  assign(name, list(name = name, packages = packages, fit = fit, predict = predict,
                    importance = importance),
         envir = .mv_families)
  invisible(name)
}

mv_family <- function(name) {
  if (!exists(name, envir = .mv_families, inherits = FALSE))
    stop("Model family '", name, "' is not implemented in Phase 1. Register it with ",
         "mv_register_family(); families are never substituted.", call. = FALSE)
  fam <- get(name, envir = .mv_families)
  miss <- fam$packages[!vapply(fam$packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(miss))
    stop("Model family '", name, "' needs package(s) not installed: ",
         paste(miss, collapse = ", "), ". No fallback is used.", call. = FALSE)
  fam
}

mv_families <- function() sort(ls(.mv_families))

# ---- LightGBM -------------------------------------------------------------------

.mv_lgb_params <- function(params, seed) {
  p <- params
  p$num_iterations <- NULL
  p$early_stopping_rounds <- NULL
  p$categorical_feature <- NULL          # passed to the Dataset instead
  p$metric <- p$metric %||% "l2"
  p$seed <- as.integer(seed)
  p$deterministic <- TRUE
  p$force_col_wise <- TRUE
  p$verbosity <- -1L
  p$num_threads <- as.integer(p$num_threads %||% 1L)
  p
}

.mv_lgb_fit <- function(X_tr, y_tr, X_va = NULL, y_va = NULL, params, seed,
                        nrounds, early_stopping = TRUE) {
  lp <- .mv_lgb_params(params, seed)
  dtr <- if (length(params$categorical_feature))
    lightgbm::lgb.Dataset(X_tr, label = y_tr, free_raw_data = FALSE,
                          params = list(verbosity = -1L),
                          categorical_feature = unlist(params$categorical_feature)) else
    lightgbm::lgb.Dataset(X_tr, label = y_tr, free_raw_data = FALSE,
                          params = list(verbosity = -1L))
  args <- list(params = lp, data = dtr, nrounds = as.integer(nrounds), verbose = -1L)
  if (isTRUE(early_stopping)) {
    if (is.null(X_va)) stop("early stopping needs a validation block")
    dva <- lightgbm::lgb.Dataset.create.valid(dtr, X_va, label = y_va)
    args$valids <- list(validation = dva)
    args$early_stopping_rounds <- as.integer(params$early_stopping_rounds)
  }
  model <- do.call(lightgbm::lgb.train, args)
  # lightgbm's current_iter() fills an integer in place, so the returned object
  # can be overwritten by later calls on any booster. "+ 0L" forces a fresh copy.
  ran <- as.integer(model$current_iter()) + 0L
  best <- if (isTRUE(early_stopping)) as.integer(model$best_iter) + 0L else as.integer(nrounds) + 0L
  if (length(best) != 1L || is.na(best) || best < 1L) best <- ran
  list(model = model, best_iter = best, iterations_run = ran,
       best_score = if (isTRUE(early_stopping)) as.numeric(model$best_score) else NA_real_,
       early_stopped = isTRUE(early_stopping) && ran < nrounds,
       family = "lightgbm")
}

.mv_lgb_predict <- function(fit, X) {
  as.numeric(stats::predict(fit$model, X, num_iteration = fit$best_iter))
}

.mv_lgb_importance <- function(fit) {
  imp <- lightgbm::lgb.importance(fit$model, percentage = FALSE)
  stats::setNames(imp$Gain, imp$Feature)
}

mv_register_family("lightgbm", "lightgbm", .mv_lgb_fit, .mv_lgb_predict, .mv_lgb_importance)

# ---- selection and refit ---------------------------------------------------------
# 1. Fit on train, early stopping on validation -> best iteration.
# 2. Refit on train + validation samples with that iteration count frozen.
#    A family may freeze further validation-selected values (e.g. a penalty)
#    by returning them as `refit_params`.
# 3. Predict test. Test labels are never passed to any fit or selection step.

mv_select_and_refit <- function(family, ds, params, seed,
                                transform = mv_transform_identity(),
                                keep_models = FALSE) {
  fam <- mv_family(family)
  tr <- ds$blocks$train; va <- ds$blocks$validation
  X_test <- ds$blocks$test$X
  t0 <- proc.time()[["elapsed"]]

  tf_sel <- transform$fit(tr$X, tr$y)
  sel <- fam$fit(tf_sel$apply(tr$X), tr$y, tf_sel$apply(va$X), va$y, params, seed,
                 nrounds = params$num_iterations, early_stopping = TRUE)
  pred_train <- fam$predict(sel, tf_sel$apply(tr$X))
  pred_val <- fam$predict(sel, tf_sel$apply(va$X))

  X_fit <- rbind(tr$X, va$X)
  y_fit <- c(tr$y, va$y)
  params_ref <- if (length(sel$refit_params)) utils::modifyList(params, sel$refit_params) else params
  tf_ref <- transform$fit(X_fit, y_fit)
  ref <- fam$fit(tf_ref$apply(X_fit), y_fit, NULL, NULL, params_ref, seed,
                 nrounds = sel$best_iter, early_stopping = FALSE)
  pred_test <- fam$predict(ref, tf_ref$apply(X_test))

  imp <- if (is.function(fam$importance)) fam$importance(ref) else NULL
  list(family = family, design = ds$design, h = ds$h, seed = seed,
       best_iter = sel$best_iter, iterations_run = sel$iterations_run,
       early_stopped = sel$early_stopped, best_val_l2 = sel$best_score,
       refit_rounds = ref$best_iter, n_refit = length(y_fit),
       refit_params = sel$refit_params,
       pred = list(train = pred_train, validation = pred_val, test = pred_test),
       transform = transform$name,
       transform_info = list(selection = tf_sel$info, refit = tf_ref$info),
       n_inputs = ncol(tf_sel$apply(tr$X[1:2, , drop = FALSE])),
       importance = imp,
       models = if (keep_models) list(selection = sel, refit = ref) else NULL,
       elapsed_s = proc.time()[["elapsed"]] - t0)
}
