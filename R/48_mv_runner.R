# Experiment runner helpers (Phase 2). Tuning reads validation labels only;
# test labels are read only by the scoring helpers at the end.

mv_exp_cfg <- function(path = "config/multivariate_experiments.yaml") {
  e <- mv_read_yaml(path)
  base <- mv_cfg(e$base_config)
  stopifnot(all(as.integer(unlist(e$horizons)) %in% as.integer(unlist(base$horizons))))
  list(exp = e, base = base)
}

mv_pkg_versions <- function() {
  pv <- function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "not installed"
  c(R = as.character(getRversion()),
    vapply(c("lightgbm", "xgboost", "catboost", "glmnet", "pls", "arrow", "data.table",
             "yaml", "digest", "jsonlite", "ggplot2"), pv, ""))
}

mv_git_commit <- function() {
  g <- tryCatch(suppressWarnings(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
                error = function(e) NA_character_)
  if (length(g)) g[1] else NA_character_
}

# Candidate parameter lists: base + every grid combination (+ named extras).
mv_candidates <- function(fcfg) {
  base <- fcfg$base %||% list()
  g <- fcfg$grid %||% list()
  out <- list()
  if (length(g)) {
    eg <- expand.grid(g, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
    for (i in seq_len(nrow(eg))) {
      p <- utils::modifyList(base, as.list(eg[i, , drop = FALSE]))
      id <- paste(sprintf("%s=%s", names(eg), unlist(eg[i, ])), collapse = ",")
      out[[id]] <- p
    }
  } else out[["default"]] <- base
  for (nm in names(fcfg$extra_candidates %||% list())) out[[nm]] <- fcfg$extra_candidates[[nm]]
  out
}

mv_family_transform <- function(fcfg) {
  switch(fcfg$transform %||% "identity",
         identity = mv_transform_identity(),
         standardize = mv_transform_standardize(),
         stop("unknown transform ", fcfg$transform))
}

# Validation grid search: selection fit only (train rows, validation for early
# stopping / penalty), scored by validation MAE. Returns table + best params.
mv_tune <- function(family, ds, candidates, seed, transform) {
  fam <- mv_family(family)
  tr <- ds$blocks$train; va <- ds$blocks$validation
  tf <- transform$fit(tr$X, tr$y)
  Xtr <- tf$apply(tr$X); Xva <- tf$apply(va$X)
  rows <- list()
  for (id in names(candidates)) {
    p <- candidates[[id]]
    t0 <- proc.time()[["elapsed"]]
    f <- fam$fit(Xtr, tr$y, Xva, va$y, p, seed, nrounds = p$num_iterations %||% 1L,
                 early_stopping = TRUE)
    pv <- fam$predict(f, Xva); pt <- fam$predict(f, Xtr)
    rows[[id]] <- data.frame(candidate = id, val_MAE = mean(abs(pv - va$y)),
                             val_RMSE = sqrt(mean((pv - va$y)^2)),
                             train_MAE = mean(abs(pt - tr$y)), best_iter = f$best_iter,
                             seconds = proc.time()[["elapsed"]] - t0, stringsAsFactors = FALSE)
  }
  tab <- do.call(rbind, rows); rownames(tab) <- NULL
  best <- tab$candidate[which.min(tab$val_MAE)]
  list(table = tab, best = best, params = candidates[[best]])
}

# Long prediction frame for one run (validation + test; train kept for gap checks).
mv_pred_frame <- function(ds, run, stage, extra = list()) {
  do.call(rbind, lapply(c("train", "validation", "test"), function(b) {
    bk <- ds$blocks[[b]]
    df <- data.frame(stage = stage, family = run$family, design = ds$design,
                     target = bk$target %||% ds$target, horizon_h = ds$h, seed = run$seed,
                     block = b, origin_idx = bk$origin_idx, target_idx = bk$target_idx,
                     y = bk$y_raw %||% bk$y, yhat = run$pred[[b]], stringsAsFactors = FALSE)
    for (k in names(extra)) df[[k]] <- extra[[k]]
    df
  }))
}

# Point metrics for every group (all / fill / non-fill / clean) of a prediction frame
# that holds one (family, design, target, horizon, seed, block) cell or many.
mv_metric_table <- function(pr, panel, fill, lookback, scales,
                            keys = c("stage", "family", "design", "variant", "target",
                                     "horizon_h", "seed", "block")) {
  keys <- intersect(keys, names(pr))
  sp <- split(pr, pr[keys], drop = TRUE)
  out <- lapply(sp, function(s) {
    g <- mv_fill_groups(fill, s$origin_idx, s$target_idx, lookback)
    sc <- scales[[s$target[1]]]
    grp <- c(list(all = rep(TRUE, nrow(s))), g)
    do.call(rbind, lapply(names(grp), function(gn) {
      k <- grp[[gn]]
      if (!any(k)) return(NULL)
      pm <- mv_point_metrics(s$y[k], s$yhat[k], sc)
      cbind(s[1, keys, drop = FALSE],
            data.frame(group = gn, n = sum(k), MAE = pm[["MAE"]], RMSE = pm[["RMSE"]],
                       MASE = pm[["MASE"]], mase_scale = sc, stringsAsFactors = FALSE))
    }))
  })
  out <- do.call(rbind, out); rownames(out) <- NULL
  out
}

# Seed-averaged predictions (the per-cell ensemble used for paired comparisons).
mv_seed_mean <- function(pr) {
  keys <- intersect(c("stage", "family", "design", "variant", "target", "horizon_h", "block",
                      "origin_idx", "target_idx", "y"), names(pr))
  a <- stats::aggregate(pr["yhat"], pr[keys], mean)
  a$seed <- "mean"
  a[order(a$family, a$design, a$target, a$horizon_h, a$block, a$origin_idx), c(keys, "seed", "yhat")]
}

# Final runs: chosen params refitted for each seed; returns predictions + run info.
mv_final_runs <- function(family, ds, params, seeds, transform, stage, extra = list()) {
  preds <- list(); info <- list(); imps <- list()
  for (s in seeds) {
    r <- mv_select_and_refit(family, ds, params, s, transform)
    preds[[as.character(s)]] <- mv_pred_frame(ds, r, stage, extra)
    info[[as.character(s)]] <- data.frame(
      stage = stage, family = family, design = ds$design, target = ds$target %||% NA,
      horizon_h = ds$h, seed = s, best_iter = r$best_iter, iterations_run = r$iterations_run,
      refit_rounds = r$refit_rounds, n_refit = r$n_refit, n_inputs = r$n_inputs,
      refit_params = if (length(r$refit_params)) jsonlite::toJSON(r$refit_params, auto_unbox = TRUE,
                                                                   digits = NA) else "",
      elapsed_s = round(r$elapsed_s, 2), stringsAsFactors = FALSE)
    if (length(r$importance)) imps[[as.character(s)]] <- data.frame(
      stage = stage, family = family, design = ds$design, target = ds$target %||% NA,
      horizon_h = ds$h, seed = s, feature = names(r$importance),
      importance = as.numeric(r$importance), stringsAsFactors = FALSE)
    for (k in names(extra)) {
      info[[as.character(s)]][[k]] <- extra[[k]]
      if (length(imps)) imps[[as.character(s)]][[k]] <- extra[[k]]
    }
  }
  list(pred = do.call(rbind, preds), info = do.call(rbind, info),
       importance = if (length(imps)) do.call(rbind, imps) else NULL,
       last_run = r)
}

mv_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (grepl("\\.gz$", path)) data.table::fwrite(x, path, compress = "gzip") else
    utils::write.csv(x, path, row.names = FALSE)
}
