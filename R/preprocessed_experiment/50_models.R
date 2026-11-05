# Phase 3-4: LightGBM for every architecture. Validation for early stopping and
# selection; refit on train + validation with frozen parameters and iteration count;
# one test prediction. The test block is never passed to tuning code.

pe_grid <- function(cfg, smoke = FALSE) {
  if (smoke) return(data.frame(num_leaves = 31L, learning_rate = 0.05, min_data_in_leaf = 50L))
  g <- cfg$lightgbm$grid
  expand.grid(num_leaves = unlist(g$num_leaves), learning_rate = unlist(g$learning_rate),
              min_data_in_leaf = unlist(g$min_data_in_leaf), KEEP.OUT.ATTRS = FALSE)
}

pe_lgb_params <- function(cfg, g) {
  b <- cfg$lightgbm
  list(objective = b$objective, metric = "l1", num_leaves = as.integer(g$num_leaves),
       learning_rate = g$learning_rate, min_data_in_leaf = as.integer(g$min_data_in_leaf),
       feature_fraction = b$feature_fraction, feature_fraction_seed = b$seed,
       bagging_fraction = 1, seed = b$seed, deterministic = isTRUE(b$deterministic),
       force_col_wise = TRUE, num_threads = as.integer(b$num_threads), verbose = -1L)
}

pe_lgb_fit <- function(cfg, g, X, y, w = NULL, Xv = NULL, yv = NULL, wv = NULL,
                       nrounds = NULL, smoke = FALSE) {
  cat_f <- if ("component" %in% colnames(X)) "component" else NULL
  dtr <- lightgbm::lgb.Dataset(X, label = y, weight = w, categorical_feature = cat_f,
                               free_raw_data = FALSE)
  max_r <- if (smoke) 200L else as.integer(cfg$lightgbm$max_rounds)
  if (is.null(nrounds)) {
    dva <- lightgbm::lgb.Dataset.create.valid(dtr, Xv, label = yv, weight = wv)
    m <- lightgbm::lgb.train(pe_lgb_params(cfg, g), dtr, nrounds = max_r, valids = list(val = dva),
                             early_stopping_rounds = as.integer(cfg$lightgbm$early_stopping_rounds),
                             verbose = -1L)
    list(model = m, best_iter = as.integer(m$best_iter))
  } else {
    m <- lightgbm::lgb.train(pe_lgb_params(cfg, g), dtr, nrounds = as.integer(nrounds), verbose = -1L)
    list(model = m, best_iter = as.integer(nrounds))
  }
}

pe_mae <- function(e) mean(abs(e))

# ---- one architecture on one dataset ------------------------------------------

# Returns validation and test predictions (component and target level), the tuning
# table and the selected configuration.
pe_run_arch <- function(md, arch, smoke = FALSE) {
  cfg <- md$cfg
  tgt <- cfg$target
  h <- md$h
  grid <- pe_grid(cfg, smoke)
  cov_sets <- if (arch %in% c("B2", "B3")) unlist(cfg$architectures$covariate_sets) else NA_character_
  sc_tr <- pe_scalers(md, max(md$train_hours))
  sc_tv <- pe_scalers(md, max(md$trainval_hours))
  S <- md$sets
  if (smoke) {
    S$fit_train <- utils::tail(S$fit_train, 600L)
    S$eval_val <- utils::head(S$eval_val, 200L)
    S$fit_val <- S$fit_val[S$fit_val %in% S$eval_val | S$fit_val <= max(S$eval_val)]
    S$eval_test <- utils::head(S$eval_test, 200L)
  }
  tuning <- list()
  pred <- list()

  if (arch %in% c("A1", "B0", "B2")) {
    units <- if (arch == "A1") NA_character_ else PE_COMPS
    sel <- list()
    for (u in units) {
      best <- NULL
      for (cs in cov_sets) {
        tr <- pe_xy_single(md, arch, S$fit_train, sc_tr, comp = u, cov_set = cs)
        va <- pe_xy_single(md, arch, S$eval_val, sc_tr, comp = u, cov_set = cs)
        for (k in seq_len(nrow(grid))) {
          f <- pe_lgb_fit(cfg, grid[k, ], tr$X, tr$y, Xv = va$X, yv = va$y, smoke = smoke)
          p <- pe_unz(stats::predict(f$model, va$X), va$scaler)
          mae <- pe_mae(p - va$y_orig)
          tuning[[length(tuning) + 1L]] <- data.frame(unit = u, cov_set = cs, grid[k, ],
                                                     best_iter = f$best_iter, val_mae_unit = mae)
          if (is.null(best) || mae < best$mae)
            best <- list(mae = mae, g = grid[k, ], cov_set = cs, iter = f$best_iter, pred = p)
        }
      }
      # Refit on train + validation with frozen parameters and iterations; test once.
      tv <- pe_xy_single(md, arch, c(S$fit_train, S$fit_val), sc_tv, comp = u, cov_set = best$cov_set)
      te <- pe_xy_single(md, arch, S$eval_test, sc_tv, comp = u, cov_set = best$cov_set)
      f <- pe_lgb_fit(cfg, best$g, tv$X, tv$y, nrounds = best$iter, smoke = smoke)
      pred[[if (is.na(u)) "target" else u]] <- list(
        val = best$pred, test = pe_unz(stats::predict(f$model, te$X), te$scaler))
      sel[[if (is.na(u)) "target" else u]] <- c(as.list(best$g), cov_set = best$cov_set,
                                                best_iter = best$iter, val_mae_unit = best$mae,
                                                n_features = ncol(tv$X), n_train = nrow(tr$X),
                                                n_refit = nrow(tv$X))
    }
  } else {
    best <- NULL
    for (cs in cov_sets) {
      tr <- pe_xy_shared(md, arch, S$fit_train, sc_tr, cov_set = cs)
      va <- pe_xy_shared(md, arch, S$eval_val, sc_tr, cov_set = cs)
      for (k in seq_len(nrow(grid))) {
        f <- pe_lgb_fit(cfg, grid[k, ], tr$X, tr$y, w = tr$w, Xv = va$X, yv = va$y, wv = va$w,
                        smoke = smoke)
        z <- stats::predict(f$model, va$X)
        p <- numeric(length(z))
        for (cc in PE_COMPS) {
          ii <- va$comp == cc
          p[ii] <- pe_unz(z[ii], sc_tr[[paste0(tgt, "|", cc)]])
        }
        recon <- rowSums(sapply(PE_COMPS, function(cc) p[va$comp == cc]))
        mae <- pe_mae(recon - md$truth[S$eval_val + h])
        tuning[[length(tuning) + 1L]] <- data.frame(unit = "shared", cov_set = cs, grid[k, ],
                                                   best_iter = f$best_iter, val_mae_unit = mae)
        if (is.null(best) || mae < best$mae)
          best <- list(mae = mae, g = grid[k, ], cov_set = cs, iter = f$best_iter, p = p, comp = va$comp)
      }
    }
    tv <- pe_xy_shared(md, arch, c(S$fit_train, S$fit_val), sc_tv, cov_set = best$cov_set)
    te <- pe_xy_shared(md, arch, S$eval_test, sc_tv, cov_set = best$cov_set)
    f <- pe_lgb_fit(cfg, best$g, tv$X, tv$y, w = tv$w, nrounds = best$iter, smoke = smoke)
    z <- stats::predict(f$model, te$X)
    for (cc in PE_COMPS) {
      pred[[cc]] <- list(val = best$p[best$comp == cc],
                         test = pe_unz(z[te$comp == cc], sc_tv[[paste0(tgt, "|", cc)]]))
    }
    sel <- list(shared = c(as.list(best$g), cov_set = best$cov_set, best_iter = best$iter,
                           val_mae_unit = best$mae, n_features = ncol(tv$X),
                           n_train = nrow(tr$X), n_refit = nrow(tv$X)))
  }

  out <- list(arch = arch, dataset = md$dataset, selected = sel,
              tuning = dplyr::bind_rows(tuning), sets = S)
  for (blk in c("val", "test")) {
    idx <- if (blk == "val") S$eval_val else S$eval_test
    df <- data.frame(origin = md$times[idx], target_time = md$times[idx + h],
                     actual = md$truth[idx + h])
    if (arch == "A1") {
      df$predicted <- pred$target[[blk]]
    } else {
      for (cc in PE_COMPS) {
        df[[paste0("pred_", cc)]] <- pred[[cc]][[blk]]
        df[[paste0("actual_", cc)]] <- md$comps[[tgt]][idx + h, cc]
      }
      df$predicted <- rowSums(df[, paste0("pred_", PE_COMPS)])
    }
    out[[blk]] <- df
  }
  out
}
