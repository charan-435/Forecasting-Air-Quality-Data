# B2 experiment pipeline: separate + shared LightGBM, reconstruction, Stage B.

b2_source_all <- function() {
  sys.source("R/b2/b2_config.R", envir = .GlobalEnv)
  sys.source("R/b2/b2_features.R", envir = .GlobalEnv)
  sys.source("R/b2/b2_models.R", envir = .GlobalEnv)
}

b2_write_csv <- function(df, name) {
  b2_dir_create()
  path <- file.path(b2_table_dir(), name)
  b2_assert(path)
  readr::write_csv(df, path)
  path
}

b2_score <- function(y_train_level, y_true, yhat) {
  y_train_mase <- as.numeric(y_train_level)[is.finite(y_train_level)]
  ok <- is.finite(y_true) & is.finite(yhat)
  if (sum(ok) < 1L || length(y_train_mase) < SEASONALITY + 2L) {
    return(tibble::tibble(n_eval = 0L, MAE = NA_real_, RMSE = NA_real_, MASE = NA_real_))
  }
  sc <- score_forecast(y_train_mase, y_true[ok], yhat[ok])
  tibble::tibble(n_eval = sum(ok), MAE = sc$MAE, RMSE = sc$RMSE, MASE = sc$MASE)
}

b2_prepare_xy <- function(sup, scale_x = TRUE) {
  meta <- sup$meta
  X <- sup$X
  tr <- meta$stage == "train"
  va <- meta$stage == "validation"
  te <- meta$stage == "test"
  y_scaler <- b2_target_scaler_fit(meta$y[tr])
  y_tr <- minmax_apply(meta$y[tr], y_scaler)
  y_va <- minmax_apply(meta$y[va], y_scaler)
  y_te <- minmax_apply(meta$y[te], y_scaler)
  x_scaler <- NULL
  X_tr <- X[tr, , drop = FALSE]
  X_va <- X[va, , drop = FALSE]
  X_te <- X[te, , drop = FALSE]
  if (isTRUE(scale_x)) {
    x_scaler <- b2_scale_fit(X_tr)
    X_tr <- b2_scale_apply(X_tr, x_scaler)
    X_va <- b2_scale_apply(X_va, x_scaler)
    X_te <- b2_scale_apply(X_te, x_scaler)
  }
  list(
    X_tr = X_tr, X_va = X_va, X_te = X_te,
    y_tr = y_tr, y_va = y_va, y_te = y_te,
    y_true_tr = meta$y[tr], y_true_va = meta$y[va], y_true_te = meta$y[te],
    meta_tr = meta[tr, ], meta_va = meta[va, ], meta_te = meta[te, ],
    y_scaler = y_scaler, x_scaler = x_scaler,
    feature_names = colnames(X)
  )
}

b2_run_one_separate <- function(panel, target_comp, h, model_id = "lgb",
                                params = NULL, feature_mode = "full",
                                top_k = 200L, pca_k = 50L,
                                refit_trainval = TRUE) {
  if (is.null(params)) params <- b2_default_lgb_params()
  message("B2 separate ", model_id, " ", target_comp, " h=", h,
          " features=", feature_mode)
  sup <- b2_build_supervised(panel, target_comp, h)
  if (!nrow(sup$meta)) stop("No supervised rows for ", target_comp, " h=", h)
  prep <- b2_prepare_xy(sup, scale_x = TRUE)
  keep <- seq_len(ncol(prep$X_tr))
  transform <- list(mode = feature_mode)
  if (identical(feature_mode, "corr")) {
    keep <- b2_select_correlation(prep$X_tr, prep$y_tr, top_k)
    transform$keep <- keep
  } else if (identical(feature_mode, "mi")) {
    keep <- b2_select_mi(prep$X_tr, prep$y_tr, top_k)
    transform$keep <- keep
  } else if (identical(feature_mode, "pca")) {
    transform$pca <- b2_fit_pca(prep$X_tr, pca_k)
  }

  apply_tr <- function(X) {
    if (identical(feature_mode, "pca")) b2_apply_pca(transform$pca, X)
    else X[, keep, drop = FALSE]
  }
  X_tr <- apply_tr(prep$X_tr)
  X_va <- apply_tr(prep$X_va)
  X_te <- apply_tr(prep$X_te)

  t0 <- proc.time()[["elapsed"]]
  fit <- b2_fit_dispatcher(model_id, X_tr, prep$y_tr, X_va, prep$y_va, params)
  train_sec <- proc.time()[["elapsed"]] - t0

  pred_va_s <- b2_predict_dispatcher(fit, X_va)
  pred_te_s <- b2_predict_dispatcher(fit, X_te)
  pred_va <- minmax_invert(pred_va_s, prep$y_scaler)
  pred_te <- minmax_invert(pred_te_s, prep$y_scaler)

  # Optional refit on train+val after early-stopping selection (use best_iter if lgb).
  if (isTRUE(refit_trainval) && identical(fit$family, "lgb")) {
    best_iter <- tryCatch(fit$model$best_iter, error = function(e) params$nrounds)
    if (!is.finite(best_iter) || best_iter < 1) best_iter <- params$nrounds
    X_tv <- rbind(X_tr, X_va)
    y_tv <- c(prep$y_tr, prep$y_va)
    dtr <- lightgbm::lgb.Dataset(X_tv, label = y_tv)
    fit2 <- lightgbm::lgb.train(
      params = list(
        objective = "regression", metric = "l2",
        learning_rate = params$eta,
        num_leaves = as.integer(params$lgb_leaves %||% 31L),
        max_depth = as.integer(params$max_depth),
        feature_fraction = as.numeric(params$feature_fraction %||% 0.8),
        bagging_fraction = as.numeric(params$bagging_fraction %||% 0.8),
        bagging_freq = 1,
        min_data_in_leaf = as.integer(params$min_data_in_leaf %||% 20L),
        verbosity = -1
      ),
      data = dtr, nrounds = as.integer(best_iter), verbose = -1
    )
    fit$model <- fit2
    pred_te_s <- as.numeric(predict(fit2, X_te))
    pred_te <- minmax_invert(pred_te_s, prep$y_scaler)
  }

  y_train_comp <- panel[[paste0(B2_TARGET_POLLUTANT, "__", target_comp)]]
  y_train_comp <- y_train_comp[sup$stage == "train"]
  sc_va <- b2_score(y_train_comp, prep$y_true_va, pred_va)
  sc_te <- b2_score(y_train_comp, prep$y_true_te, pred_te)
  imp <- b2_importance_lgb(fit, prep$feature_names[keep])

  list(
    model_id = model_id,
    setup = "B2.1_separate",
    target_component = target_comp,
    horizon_hours = as.integer(h),
    feature_mode = feature_mode,
    n_features_used = ncol(X_tr),
    n_train = nrow(X_tr), n_val = nrow(X_va), n_test = nrow(X_te),
    train_sec = train_sec,
    metrics_val = sc_va,
    metrics_test = sc_te,
    pred_val = tibble::tibble(
      target_time = prep$meta_va$target_time,
      origin_time = prep$meta_va$origin_time,
      y_true = prep$y_true_va, yhat = pred_va,
      y_pm25 = prep$meta_va$y_pm25,
      stage = "validation", component = target_comp
    ),
    pred_test = tibble::tibble(
      target_time = prep$meta_te$target_time,
      origin_time = prep$meta_te$origin_time,
      y_true = prep$y_true_te, yhat = pred_te,
      y_pm25 = prep$meta_te$y_pm25,
      stage = "test", component = target_comp
    ),
    importance = imp,
    transform = transform,
    params = params
  )
}

b2_component_onehot <- function(comp, levels = B2_COMPONENTS) {
  m <- matrix(0, nrow = length(comp), ncol = length(levels))
  colnames(m) <- paste0("comp_id__", levels)
  for (i in seq_along(levels)) m[comp == levels[i], i] <- 1
  m
}

b2_run_shared <- function(panel, h, model_id = "lgb", params = NULL,
                          refit_trainval = TRUE) {
  if (is.null(params)) params <- b2_default_lgb_params()
  message("B2 shared ", model_id, " h=", h)
  blocks <- lapply(B2_COMPONENTS, function(comp) {
    sup <- b2_build_supervised(panel, comp, h)
    list(sup = sup, comp = comp)
  })
  # Stack train/val/test with component identity.
  stack_stage <- function(stage_name) {
    Xs <- list(); ys <- list(); metas <- list(); comps <- list()
    for (b in blocks) {
      m <- b$sup$meta
      hit <- m$stage == stage_name
      if (!sum(hit)) next
      Xs[[length(Xs) + 1L]] <- b$sup$X[hit, , drop = FALSE]
      ys[[length(ys) + 1L]] <- m$y[hit]
      metas[[length(metas) + 1L]] <- m[hit, ]
      comps[[length(comps) + 1L]] <- rep(b$comp, sum(hit))
    }
    list(
      X = do.call(rbind, Xs),
      y = unlist(ys, use.names = FALSE),
      meta = dplyr::bind_rows(metas),
      comp = unlist(comps, use.names = FALSE)
    )
  }
  tr <- stack_stage("train")
  va <- stack_stage("validation")
  te <- stack_stage("test")

  y_scaler <- b2_target_scaler_fit(tr$y)  # shared scaler across components (native)
  # Per-component scaling is safer for shared model:
  y_scalers <- lapply(B2_COMPONENTS, function(comp) {
    b2_target_scaler_fit(tr$y[tr$comp == comp])
  })
  names(y_scalers) <- B2_COMPONENTS
  scale_y <- function(y, comp) {
    vapply(seq_along(y), function(i) {
      minmax_apply(y[i], y_scalers[[comp[i]]])
    }, numeric(1))
  }
  invert_y <- function(ys, comp) {
    vapply(seq_along(ys), function(i) {
      minmax_invert(ys[i], y_scalers[[comp[i]]])
    }, numeric(1))
  }

  x_scaler <- b2_scale_fit(tr$X)
  X_tr <- cbind(b2_scale_apply(tr$X, x_scaler), b2_component_onehot(tr$comp))
  X_va <- cbind(b2_scale_apply(va$X, x_scaler), b2_component_onehot(va$comp))
  X_te <- cbind(b2_scale_apply(te$X, x_scaler), b2_component_onehot(te$comp))
  y_tr <- scale_y(tr$y, tr$comp)
  y_va <- scale_y(va$y, va$comp)
  y_te <- scale_y(te$y, te$comp)

  t0 <- proc.time()[["elapsed"]]
  fit <- b2_fit_dispatcher(model_id, X_tr, y_tr, X_va, y_va, params)
  train_sec <- proc.time()[["elapsed"]] - t0
  pred_va <- invert_y(b2_predict_dispatcher(fit, X_va), va$comp)
  pred_te <- invert_y(b2_predict_dispatcher(fit, X_te), te$comp)

  if (isTRUE(refit_trainval) && identical(fit$family, "lgb")) {
    best_iter <- tryCatch(fit$model$best_iter, error = function(e) params$nrounds)
    if (!is.finite(best_iter) || best_iter < 1) best_iter <- params$nrounds
    X_tv <- rbind(X_tr, X_va); y_tv <- c(y_tr, y_va)
    dtr <- lightgbm::lgb.Dataset(X_tv, label = y_tv)
    fit2 <- lightgbm::lgb.train(
      params = list(
        objective = "regression", metric = "l2", learning_rate = params$eta,
        num_leaves = as.integer(params$lgb_leaves %||% 31L),
        max_depth = as.integer(params$max_depth),
        feature_fraction = as.numeric(params$feature_fraction %||% 0.8),
        bagging_fraction = as.numeric(params$bagging_fraction %||% 0.8),
        bagging_freq = 1, min_data_in_leaf = as.integer(params$min_data_in_leaf %||% 20L),
        verbosity = -1
      ),
      data = dtr, nrounds = as.integer(best_iter), verbose = -1
    )
    fit$model <- fit2
    pred_te <- invert_y(as.numeric(predict(fit2, X_te)), te$comp)
  }

  # Metrics per component
  metric_rows <- list()
  pred_store <- list()
  for (comp in B2_COMPONENTS) {
    for (stg in c("validation", "test")) {
      if (identical(stg, "validation")) {
        hit <- va$comp == comp
        yt <- va$y[hit]; yh <- pred_va[hit]; meta <- va$meta[hit, ]
      } else {
        hit <- te$comp == comp
        yt <- te$y[hit]; yh <- pred_te[hit]; meta <- te$meta[hit, ]
      }
      y_train_comp <- panel[[paste0(B2_TARGET_POLLUTANT, "__", comp)]]
      y_train_comp <- y_train_comp[blocks[[1]]$sup$stage == "train"]
      sc <- b2_score(y_train_comp, yt, yh)
      metric_rows[[length(metric_rows) + 1L]] <- tibble::tibble(
        setup = "B2.2_shared", model_id = model_id, component = comp,
        horizon_hours = as.integer(h), stage = stg,
        n_features_used = ncol(X_tr),
        n_train = nrow(X_tr), n_val = nrow(X_va), n_test = nrow(X_te),
        training_time_sec = train_sec,
        n_eval = sc$n_eval, MAE = sc$MAE, RMSE = sc$RMSE, MASE = sc$MASE
      )
      pred_store[[paste(comp, stg, sep = "|")]] <- tibble::tibble(
        target_time = meta$target_time, origin_time = meta$origin_time,
        y_true = yt, yhat = yh, y_pm25 = meta$y_pm25,
        stage = stg, component = comp
      )
    }
  }
  list(
    metrics = dplyr::bind_rows(metric_rows),
    preds = pred_store,
    train_sec = train_sec,
    fit = fit,
    n_features_used = ncol(X_tr)
  )
}

b2_metric_row_from_separate <- function(res, stage = "test") {
  sc <- if (identical(stage, "validation")) res$metrics_val else res$metrics_test
  tibble::tibble(
    setup = res$setup, model_id = res$model_id,
    component = res$target_component,
    horizon_hours = res$horizon_hours,
    feature_mode = res$feature_mode,
    stage = stage,
    n_features_used = res$n_features_used,
    n_train = res$n_train, n_val = res$n_val, n_test = res$n_test,
    training_time_sec = res$train_sec,
    n_eval = sc$n_eval, MAE = sc$MAE, RMSE = sc$RMSE, MASE = sc$MASE,
    sensor = B2_SENSOR, pollutant = B2_TARGET_POLLUTANT,
    label = B2_LABEL, decomp_id = B2_DECOMP_ID,
    split_id = B2_SPLIT_ID, forecast_strategy = B2_FORECAST_STRATEGY,
    random_seed = B2_SEED
  )
}

b2_reconstruct <- function(pred_by_comp, panel, h, setup, model_id) {
  # pred_by_comp: named list of test tibbles with target_time, yhat, component
  # Align on target_time intersection.
  times <- Reduce(intersect, lapply(pred_by_comp, function(z) as.character(z$target_time)))
  if (!length(times)) {
    return(list(metrics = tibble::tibble(), preds = tibble::tibble()))
  }
  mats <- lapply(B2_COMPONENTS, function(comp) {
    df <- pred_by_comp[[comp]]
    df <- df[as.character(df$target_time) %in% times, ]
    df[order(df$target_time), ]
  })
  names(mats) <- B2_COMPONENTS
  yhat <- Reduce(`+`, lapply(mats, function(z) z$yhat))
  y_true_level <- mats[[1]]$y_pm25
  # Prefer panel y at those times
  idx <- match(mats[[1]]$target_time, panel$timestamp)
  y_true_level <- panel$y_pm25[idx]
  yhat_clip <- clip_impossible(yhat, B2_TARGET_POLLUTANT)
  sp <- chrono_split_tvt(panel$y_pm25, panel$timestamp, as.integer(h), VAL_HOURS)
  sc <- b2_score(sp$y_fit, y_true_level, yhat_clip)
  preds <- tibble::tibble(
    target_time = mats[[1]]$target_time,
    y_true = y_true_level, yhat = yhat, yhat_clip = yhat_clip,
    setup = setup, model_id = model_id, horizon_hours = as.integer(h)
  )
  for (comp in B2_COMPONENTS) preds[[paste0(comp, "_hat")]] <- mats[[comp]]$yhat
  list(
    metrics = tibble::tibble(
      setup = setup, model_id = model_id, horizon_hours = as.integer(h),
      stage = "test", level = "PM2.5_reconstructed",
      n_eval = sc$n_eval, MAE = sc$MAE, RMSE = sc$RMSE, MASE = sc$MASE,
      n_components = 6L, sensor = B2_SENSOR, label = B2_LABEL
    ),
    preds = preds
  )
}

# Univariate direct-horizon LightGBM baseline on same supervised timestamps.
b2_run_univariate_direct <- function(panel, target_comp, h, params = NULL) {
  if (is.null(params)) params <- b2_default_lgb_params()
  message("B2 univariate-direct lgb ", target_comp, " h=", h)
  # Features: only PM2.5 target_comp lags 1..24 (24 features)
  sup <- b2_build_supervised(panel, target_comp, h)
  own <- paste0(B2_TARGET_POLLUTANT, "__", target_comp, "__lag", seq_len(B2_P))
  sup$X <- sup$X[, own, drop = FALSE]
  prep <- b2_prepare_xy(sup, scale_x = TRUE)
  fit <- b2_fit_dispatcher("lgb", prep$X_tr, prep$y_tr, prep$X_va, prep$y_va, params)
  pred_va <- minmax_invert(b2_predict_dispatcher(fit, prep$X_va), prep$y_scaler)
  pred_te <- minmax_invert(b2_predict_dispatcher(fit, prep$X_te), prep$y_scaler)
  # refit
  best_iter <- tryCatch(fit$model$best_iter, error = function(e) params$nrounds)
  if (!is.finite(best_iter) || best_iter < 1) best_iter <- params$nrounds
  X_tv <- rbind(prep$X_tr, prep$X_va); y_tv <- c(prep$y_tr, prep$y_va)
  dtr <- lightgbm::lgb.Dataset(X_tv, label = y_tv)
  fit2 <- lightgbm::lgb.train(
    params = list(
      objective = "regression", metric = "l2", learning_rate = params$eta,
      num_leaves = as.integer(params$lgb_leaves %||% 31L),
      max_depth = as.integer(params$max_depth),
      feature_fraction = as.numeric(params$feature_fraction %||% 0.8),
      bagging_fraction = 0.8, bagging_freq = 1,
      min_data_in_leaf = as.integer(params$min_data_in_leaf %||% 20L),
      verbosity = -1
    ),
    data = dtr, nrounds = as.integer(best_iter), verbose = -1
  )
  pred_te <- minmax_invert(as.numeric(predict(fit2, prep$X_te)), prep$y_scaler)
  y_train_comp <- panel[[paste0(B2_TARGET_POLLUTANT, "__", target_comp)]]
  y_train_comp <- y_train_comp[sup$stage == "train"]
  sc_va <- b2_score(y_train_comp, prep$y_true_va, pred_va)
  sc_te <- b2_score(y_train_comp, prep$y_true_te, pred_te)
  list(
    model_id = "lgb", setup = "B2.0_univariate_direct",
    target_component = target_comp, horizon_hours = as.integer(h),
    feature_mode = "own_lags_24", n_features_used = 24L,
    n_train = nrow(prep$X_tr), n_val = nrow(prep$X_va), n_test = nrow(prep$X_te),
    train_sec = NA_real_,
    metrics_val = sc_va, metrics_test = sc_te,
    pred_val = tibble::tibble(
      target_time = prep$meta_va$target_time, origin_time = prep$meta_va$origin_time,
      y_true = prep$y_true_va, yhat = pred_va, y_pm25 = prep$meta_va$y_pm25,
      stage = "validation", component = target_comp
    ),
    pred_test = tibble::tibble(
      target_time = prep$meta_te$target_time, origin_time = prep$meta_te$origin_time,
      y_true = prep$y_true_te, yhat = pred_te, y_pm25 = prep$meta_te$y_pm25,
      stage = "test", component = target_comp
    ),
    importance = tibble::tibble(), transform = list(mode = "own"), params = params
  )
}

b2_run <- function(mode = "smoke") {
  b2_dir_create()
  params <- b2_default_lgb_params()
  panel <- b2_load_panel()
  b2_write_csv(b2_audit_panel_table(panel), "decomp_audit.csv")

  if (identical(mode, "smoke")) {
    horizons <- 24L
    comps <- "D1"
    do_separate <- TRUE
    do_shared <- TRUE
    do_univ <- TRUE
    do_stage_b <- FALSE
    do_fs <- FALSE
  } else if (identical(mode, "stageA")) {
    horizons <- unlist(HORIZONS)
    comps <- B2_COMPONENTS
    do_separate <- TRUE
    do_shared <- TRUE
    do_univ <- TRUE
    do_stage_b <- FALSE
    do_fs <- FALSE
  } else if (identical(mode, "full")) {
    horizons <- unlist(HORIZONS)
    comps <- B2_COMPONENTS
    do_separate <- TRUE
    do_shared <- TRUE
    do_univ <- TRUE
    do_stage_b <- TRUE
    do_fs <- TRUE
  } else if (identical(mode, "stageB")) {
    # 1d classical models + FS/DR only; append to existing Stage A metrics.
    horizons <- 24L
    comps <- B2_COMPONENTS
    do_separate <- FALSE
    do_shared <- FALSE
    do_univ <- FALSE
    do_stage_b <- TRUE
    do_fs <- TRUE
  } else {
    stop("mode must be smoke|stageA|stageB|full")
  }

  metric_rows <- list()
  recon_rows <- list()
  imp_rows <- list()
  pred_cache <- list()

  for (h in horizons) {
    # Univariate direct baseline
    univ_preds <- list()
    if (do_univ) {
      for (comp in comps) {
        u <- b2_run_univariate_direct(panel, comp, h, params)
        metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(u, "validation")
        metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(u, "test")
        univ_preds[[comp]] <- u$pred_test
        pred_cache[[paste("univ", comp, h, sep = "|")]] <- u
      }
      if (length(comps) == 6L) {
        rr <- b2_reconstruct(univ_preds, panel, h, "B2.0_univariate_direct", "lgb")
        recon_rows[[length(recon_rows) + 1L]] <- rr$metrics
        saveRDS(rr$preds, file.path(b2_cache_dir(), sprintf("recon_univ_h%s.rds", h)))
      }
    }

    # Separate multivariate LightGBM
    sep_preds <- list()
    if (isTRUE(do_separate)) {
      for (comp in comps) {
        r <- b2_run_one_separate(panel, comp, h, "lgb", params, "full")
        metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(r, "validation")
        metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(r, "test")
        sep_preds[[comp]] <- r$pred_test
        pred_cache[[paste("sep", comp, h, sep = "|")]] <- r
        if (nrow(r$importance)) {
          imp_rows[[length(imp_rows) + 1L]] <- r$importance %>%
            dplyr::mutate(component = comp, horizon_hours = h, setup = "B2.1_separate")
        }
      }
      if (length(comps) == 6L) {
        rr <- b2_reconstruct(sep_preds, panel, h, "B2.1_separate", "lgb")
        recon_rows[[length(recon_rows) + 1L]] <- rr$metrics
        saveRDS(rr$preds, file.path(b2_cache_dir(), sprintf("recon_sep_h%s.rds", h)))
      }
    }

    # Shared
    if (do_shared && length(comps) == 6L) {
      sh <- b2_run_shared(panel, h, "lgb", params)
      metric_rows[[length(metric_rows) + 1L]] <- sh$metrics %>%
        dplyr::mutate(
          feature_mode = "full+comp_id", sensor = B2_SENSOR,
          pollutant = B2_TARGET_POLLUTANT, label = B2_LABEL,
          decomp_id = B2_DECOMP_ID, split_id = B2_SPLIT_ID,
          forecast_strategy = B2_FORECAST_STRATEGY, random_seed = B2_SEED
        )
      sh_preds <- lapply(B2_COMPONENTS, function(comp) sh$preds[[paste(comp, "test", sep = "|")]])
      names(sh_preds) <- B2_COMPONENTS
      rr <- b2_reconstruct(sh_preds, panel, h, "B2.2_shared", "lgb")
      recon_rows[[length(recon_rows) + 1L]] <- rr$metrics
      saveRDS(rr$preds, file.path(b2_cache_dir(), sprintf("recon_shared_h%s.rds", h)))
    } else if (do_shared && length(comps) == 1L) {
      # smoke: still run shared but only one component in stack is odd; skip shared smoke
      message("Smoke mode: skipping shared model (needs all 6 components).")
    }

    # Stage B: other models on 1d only for speed when full
    if (do_stage_b && identical(as.integer(h), 24L)) {
      for (mid in c("xgb", "catboost", "ridge", "lasso", "elasticnet")) {
        ok <- TRUE
        if (mid %in% c("ridge", "lasso", "elasticnet") &&
            !requireNamespace("glmnet", quietly = TRUE)) {
          warning("glmnet missing; skip ", mid); ok <- FALSE
        }
        if (identical(mid, "catboost") &&
            !isTRUE(get0("CATBOOST_AVAILABLE", ifnotfound = FALSE))) {
          warning("CatBoost missing; skip"); ok <- FALSE
        }
        if (!ok) next
        for (comp in B2_COMPONENTS) {
          r <- tryCatch(
            b2_run_one_separate(panel, comp, h, mid, params, "full",
                                refit_trainval = identical(mid, "lgb")),
            error = function(e) { warning(mid, " ", comp, ": ", e$message); NULL }
          )
          if (is.null(r)) next
          metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(r, "validation")
          metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(r, "test")
        }
      }
    }

    # Feature selection / PCA on 1d separate LGB
    if (do_fs && identical(as.integer(h), 24L)) {
      for (fm in c("corr", "mi", "pca")) {
        for (comp in B2_COMPONENTS) {
          r <- b2_run_one_separate(panel, comp, h, "lgb", params, fm,
                                   top_k = 200L, pca_k = 50L)
          metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(r, "validation")
          metric_rows[[length(metric_rows) + 1L]] <- b2_metric_row_from_separate(r, "test")
        }
      }
    }
  }

  metrics <- dplyr::bind_rows(metric_rows)
  recon <- dplyr::bind_rows(recon_rows)
  # stageB appends to Stage A tables instead of wiping them.
  if (identical(mode, "stageB") &&
      file.exists(file.path(b2_table_dir(), "component_metrics.csv"))) {
    prev <- readr::read_csv(file.path(b2_table_dir(), "component_metrics.csv"),
                            show_col_types = FALSE)
    metrics <- dplyr::bind_rows(prev, metrics)
  }
  b2_write_csv(metrics, "component_metrics.csv")
  if (nrow(recon)) {
    if (identical(mode, "stageB") &&
        file.exists(file.path(b2_table_dir(), "reconstructed_metrics.csv"))) {
      # keep previous recon; stageB does not rebuild all six for every family here
    } else {
      b2_write_csv(recon, "reconstructed_metrics.csv")
    }
  }
  if (length(imp_rows)) {
    imp_path <- file.path(b2_table_dir(), "feature_importance_top.csv")
    imp_new <- dplyr::bind_rows(imp_rows)
    if (identical(mode, "stageB") && file.exists(imp_path)) {
      imp_new <- dplyr::bind_rows(readr::read_csv(imp_path, show_col_types = FALSE), imp_new)
    }
    b2_write_csv(imp_new, "feature_importance_top.csv")
  }
  saveRDS(pred_cache, file.path(b2_cache_dir(), "pred_cache.rds"))
  saveRDS(list(mode = mode, params = params, sensor = B2_SENSOR,
               label = B2_LABEL, decomp = B2_DECOMP_ID),
          file.path(b2_out_dir(), "_run_config.rds"))

  b2_write_plots(metrics, recon)
  b2_write_report(metrics, recon, mode, panel)
  invisible(list(metrics = metrics, recon = recon, panel = panel, mode = mode))
}

b2_write_plots <- function(metrics, recon) {
  b2_dir_create()
  te <- dplyr::filter(metrics, .data$stage == "test")
  if (nrow(te)) {
    p1 <- ggplot2::ggplot(te, ggplot2::aes(.data$component, .data$MASE,
                                           fill = .data$setup)) +
      ggplot2::geom_col(position = "dodge") +
      ggplot2::facet_wrap(~horizon_hours, scales = "free_y") +
      ggplot2::labs(title = "B2 component test MASE", x = NULL, y = "MASE") +
      ggplot2::theme_minimal(base_size = 11)
    ggplot2::ggsave(file.path(b2_plot_dir(), "component_test_mase.png"),
                    p1, width = 11, height = 6, dpi = 130)
  }
  if (nrow(recon)) {
    p2 <- ggplot2::ggplot(recon, ggplot2::aes(.data$setup, .data$MASE,
                                              fill = .data$setup)) +
      ggplot2::geom_col() +
      ggplot2::facet_wrap(~horizon_hours) +
      ggplot2::coord_flip() +
      ggplot2::labs(title = "Reconstructed PM2.5 test MASE", x = NULL, y = "MASE") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(legend.position = "none")
    ggplot2::ggsave(file.path(b2_plot_dir(), "reconstructed_mase.png"),
                    p2, width = 9, height = 5, dpi = 130)
  }
}

b2_fmt <- function(x, d = 3) ifelse(is.finite(x), format(round(x, d), nsmall = d), "NA")

b2_write_report <- function(metrics, recon, mode, panel) {
  path <- file.path(b2_out_dir(), "REPORT.md")
  b2_assert(path)
  audit <- b2_audit_panel_table(panel)
  te <- dplyr::filter(metrics, .data$stage == "test")
  lines_comp <- if (nrow(te)) {
    te2 <- te %>%
      dplyr::group_by(.data$setup, .data$component, .data$horizon_hours) %>%
      dplyr::summarise(MASE = mean(.data$MASE, na.rm = TRUE),
                       MAE = mean(.data$MAE, na.rm = TRUE), .groups = "drop")
    apply(te2, 1, function(r) {
      sprintf("- %s | %s | h=%s: MASE=%s MAE=%s",
              r[["setup"]], r[["component"]], r[["horizon_hours"]],
              b2_fmt(as.numeric(r[["MASE"]])), b2_fmt(as.numeric(r[["MAE"]])))
    })
  } else character()
  lines_recon <- if (nrow(recon)) {
    apply(recon, 1, function(r) {
      sprintf("- %s h=%s: MASE=%s MAE=%s RMSE=%s n=%s",
              r[["setup"]], r[["horizon_hours"]],
              b2_fmt(as.numeric(r[["MASE"]])), b2_fmt(as.numeric(r[["MAE"]])),
              b2_fmt(as.numeric(r[["RMSE"]])), r[["n_eval"]])
    })
  } else character()

  # Answer research questions from available numbers
  ans <- b2_answer_questions(te, recon)

  md <- c(
    "# B2 — Decomposed Multivariate Forecasting (CPCB UNMASKED)",
    "",
    "## Objective",
    "",
    "Does forecasting each PM2.5 Haar MRA component with 864 multivariate lags",
    "(6 pollutants × 6 components × 24 hours) beat univariate own-history component forecasting?",
    "",
    sprintf("- Mode: `%s`", mode),
    sprintf("- Sensor: `%s`  Label: `%s`  Decomp: `%s`", B2_SENSOR, B2_LABEL, B2_DECOMP_ID),
    sprintf("- Strategy: `%s` (no recursive / hybrid in this track)", B2_FORECAST_STRATEGY),
    sprintf("- Feature count (full): **%s**", B2_N_FEATURES),
    "",
    "## Decomposition audit",
    "",
    apply(audit, 1, function(r) {
      sprintf("- %s: complete6=%s aligned=%s md5=`%s`",
              r[["pollutant"]], r[["n_complete6"]], r[["n_aligned_finite"]], r[["md5"]])
    }),
    "",
    "Warmup / invalid basic rows stay NA; no future-looking imputation.",
    "",
    "## Component test metrics",
    "",
    lines_comp,
    "",
    "## Reconstructed PM2.5",
    "",
    if (length(lines_recon)) lines_recon else "- (reconstruction requires all six components; smoke may omit)",
    "",
    "## Research answers",
    "",
    ans,
    "",
    "## Reproduction",
    "",
    "```bash",
    "Rscript run_b2.R smoke    # D1 @ 24h + univ vs separate",
    "Rscript run_b2.R stageA   # all components, 4 horizons, separate+shared+univ",
    "Rscript run_b2.R full     # + Stage B models + feature selection on 1d",
    "Rscript tests/b2/run_all.R",
    "```",
    "",
    "Outputs only under `results/b2/`. T1 / stored decomps / B1 untouched.",
    ""
  )
  writeLines(md, path)
  path
}

b2_answer_questions <- function(te, recon) {
  if (!nrow(te)) return("- Insufficient rows to answer yet (smoke may be partial).")
  lines <- character()
  # Compare separate vs univ at each component for h=24 if present
  sub <- te %>% dplyr::filter(.data$horizon_hours == 24L,
                              .data$model_id == "lgb" | .data$setup == "B2.0_univariate_direct")
  if (nrow(sub)) {
    wide <- sub %>%
      dplyr::select(setup, component, MASE) %>%
      tidyr::pivot_wider(names_from = setup, values_from = MASE)
    if (all(c("B2.0_univariate_direct", "B2.1_separate") %in% names(wide))) {
      wide$delta <- wide[["B2.1_separate"]] - wide[["B2.0_univariate_direct"]]
      better <- wide$component[is.finite(wide$delta) & wide$delta < -1e-12]
      worse <- wide$component[is.finite(wide$delta) & wide$delta > 1e-12]
      lines <- c(lines,
        sprintf("1. Multivariate vs univariate (1d, LightGBM): separate wins on {%s}; univ wins on {%s}.",
                paste(better, collapse = ","),
                paste(worse, collapse = ",")))
      lines <- c(lines, sprintf("   Per-component ΔMASE (sep−univ): %s",
        paste(sprintf("%s=%s", wide$component, b2_fmt(wide$delta)), collapse = "; ")))
    }
  }
  if ("B2.2_shared" %in% te$setup && "B2.1_separate" %in% te$setup) {
    a <- te %>% dplyr::filter(.data$horizon_hours == 24L, .data$setup == "B2.1_separate") %>%
      dplyr::summarise(m = mean(.data$MASE, na.rm = TRUE))
    b <- te %>% dplyr::filter(.data$horizon_hours == 24L, .data$setup == "B2.2_shared") %>%
      dplyr::summarise(m = mean(.data$MASE, na.rm = TRUE))
    lines <- c(lines, sprintf("4. Shared vs separate mean test MASE @1d: separate=%s shared=%s",
                              b2_fmt(a$m), b2_fmt(b$m)))
  }
  if (nrow(recon)) {
    lines <- c(lines, "7. Reconstructed PM2.5 (see reconstructed_metrics.csv).")
  }
  lines <- c(lines,
    "2–3. See feature_importance_top.csv for predictive (not causal) pollutant-component contributors.",
    "5–6. Horizon persistence and FS/DR answered after stageA/full runs.",
    "Note: B2 uses direct fixed-horizon supervision; original T1 used recursive h-step. Fair protocol comparison is B2.0 univariate-direct vs B2.1/B2.2 on identical timestamps.")
  lines
}
