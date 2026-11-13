# Shillong architecture study: fitting, reconstruction and scoring.
# Fitting reuses the multivariate model interface (R/43, R/45):
# mv_tune() picks a configuration by validation MAE of a train-only fit, and
# mv_select_and_refit() early-stops on validation, then refits on train +
# validation with the iteration count / penalty frozen and predicts test once.

# Linear inputs: train-fitted median imputation (covariates can be NA), one-hot
# component id, then standardization. Trees take the matrix as is.
sh_transform_linear <- function() {
  list(name = "impute_onehot_standardize",
       fit = function(X_fit, y_fit = NULL) {
         onehot <- function(X) {
           if (!"comp_id" %in% colnames(X)) return(X)
           ids <- sort(unique(X_fit[, "comp_id"]))
           D <- vapply(ids[-1], function(i) as.numeric(X[, "comp_id"] == i), numeric(nrow(X)))
           if (is.null(dim(D))) D <- matrix(D, nrow = nrow(X))
           colnames(D) <- paste0("comp_is_", ids[-1])
           cbind(X[, colnames(X) != "comp_id", drop = FALSE], D)
         }
         med <- apply(X_fit, 2, stats::median, na.rm = TRUE)
         med[!is.finite(med)] <- 0
         imp <- function(X) {
           for (j in which(colSums(!is.finite(X)) > 0)) X[!is.finite(X[, j]), j] <- med[j]
           X
         }
         Z <- onehot(imp(X_fit))
         mu <- colMeans(Z); sdv <- apply(Z, 2, stats::sd)
         sdv[!is.finite(sdv) | sdv == 0] <- 1
         list(name = "impute_onehot_standardize",
              apply = function(X) sweep(sweep(onehot(imp(X)), 2, mu, "-"), 2, sdv, "/"))
       })
}

sh_transform_for <- function(family) {
  if (family %in% mv_linear_families()) sh_transform_linear() else mv_transform_identity()
}

sh_candidates <- function(cfg, family, shared) {
  fc <- cfg$families[[family]]
  if (is.null(fc)) stop("no config for family ", family)
  cands <- mv_candidates(fc)
  if (shared && family == "lightgbm")
    cands <- lapply(cands, function(p) { p$categorical_feature <- "comp_id"; p })
  cands
}

# Fit one dataset: tune on validation, then final seeds. Returns predictions in
# original component units for every block.
sh_fit_ds <- function(cfg, ds, family, seeds, tune_seed) {
  shared <- "comp_id" %in% ds$feature_names
  tf <- sh_transform_for(family)
  cands <- sh_candidates(cfg, family, shared)
  tun <- if (length(cands) > 1L || family %in% mv_stochastic_families())
    mv_tune(family, ds, cands, tune_seed, tf) else
    list(table = NULL, best = names(cands)[1], params = cands[[1]])
  seeds_use <- if (family %in% mv_stochastic_families()) seeds else seeds[1]
  preds <- list(); info <- list(); imps <- list()
  for (s in seeds_use) {
    r <- mv_select_and_refit(family, ds, tun$params, s, tf)
    for (b in names(ds$blocks)) {
      bk <- ds$blocks[[b]]
      yh <- sh_unscale(ds, b, r$pred[[b]])
      yt <- sh_unscale(ds, b, bk$y)
      preds[[paste(s, b)]] <- data.table::data.table(
        seed = s, block = b, component = bk$component, origin_idx = bk$origin_idx,
        target_idx = bk$target_idx, y = yt, yhat = yh)
    }
    info[[as.character(s)]] <- data.table::data.table(
      seed = s, candidate = tun$best, best_iter = r$best_iter, refit_rounds = r$refit_rounds,
      n_train = length(ds$blocks$train$y), n_validation = length(ds$blocks$validation$y),
      n_test = length(ds$blocks$test$y), n_inputs = r$n_inputs,
      refit_params = if (length(r$refit_params)) as.character(jsonlite::toJSON(
        r$refit_params, auto_unbox = TRUE, digits = NA)) else "",
      elapsed_s = round(r$elapsed_s, 2))
    if (length(r$importance)) imps[[as.character(s)]] <- data.table::data.table(
      seed = s, feature = names(r$importance), importance = as.numeric(r$importance))
  }
  list(pred = data.table::rbindlist(preds), info = data.table::rbindlist(info),
       tuning = if (!is.null(tun$table)) data.table::as.data.table(tun$table) else NULL,
       importance = data.table::rbindlist(imps))
}

# One architecture for one (station, target, horizon, family). Returns
# component-level predictions and the reconstructed level (sum of components).
sh_run_arch <- function(cfg, panel, avail, splits, smp, target, h, arch_id, family,
                        seeds, tune_seed) {
  arch <- sh_arch(arch_id)
  t0 <- proc.time()[["elapsed"]]
  units <- if (arch$kind == "decomp" && arch$structure == "separate")
    as.list(panel$components) else list(NULL)
  res <- lapply(units, function(cp) {
    ds <- sh_dataset(panel, arch, smp, target, h, avail, splits, component = cp)
    f <- sh_fit_ds(cfg, ds, family, seeds, tune_seed)
    tag <- ds$component
    if (!is.null(f$tuning)) f$tuning[, component := tag]
    f$info[, component := tag]
    if (nrow(f$importance)) f$importance[, component := tag]
    f$schema <- sh_feature_schema(ds)
    f
  })
  pred <- data.table::rbindlist(lapply(res, `[[`, "pred"))
  if (arch$kind == "decomp") {
    # reconstruct: sum of component forecasts per (seed, block, origin); the
    # level truth is the observed target value at the target hour
    lev <- pred[, .(yhat = sum(yhat), n_comp = .N), by = .(seed, block, origin_idx, target_idx)]
    stopifnot(all(lev$n_comp == length(panel$components)))
    lev[, n_comp := NULL]
    yobs <- panel$observed[[target]][lev$target_idx]
    yobs[is.na(yobs)] <- panel$fill[[target]][lev$target_idx][is.na(yobs)]
    lev[, `:=`(component = "LEVEL", y = yobs)]
    pred <- rbind(pred, lev[, names(pred), with = FALSE])
  }
  meta <- list(station = panel$station, target = target, horizon_h = as.integer(h),
               arch = arch_id, family = family, kind = arch$kind,
               structure = arch$structure %||% "separate")
  add <- function(d) { if (is.null(d) || !nrow(d)) return(d)
    for (k in names(meta)) d[[k]] <- meta[[k]]; d }
  list(pred = add(pred),
       tuning = add(data.table::rbindlist(lapply(res, `[[`, "tuning"))),
       info = add(data.table::rbindlist(lapply(res, `[[`, "info"))),
       importance = add(data.table::rbindlist(lapply(res, `[[`, "importance"))),
       schema = add(data.table::as.data.table(do.call(rbind, lapply(res, `[[`, "schema")))),
       elapsed_s = proc.time()[["elapsed"]] - t0)
}

# ---- references and scoring -------------------------------------------------------------

# Persistence = seasonal naive (24 h) for these horizons: every h is a multiple
# of 24, so the latest same-hour value at the origin is y(t) itself.
sh_reference_preds <- function(panel, smp, target, splits) {
  ts <- panel$timestamps
  y <- panel$observed[[target]]
  yf <- panel$fill[[target]]
  in_b <- function(b) ts >= splits[[b]][1] & ts <= splits[[b]][2] & is.finite(y)
  tr <- in_b("train"); trva <- tr | in_b("validation")
  hod <- lubridate::hour(ts)
  clim <- function(w) mean(y[w])
  hclim <- function(w) tapply(y[w], hod[w], mean)
  out <- list()
  for (b in c("train", "validation", "test")) {
    s <- smp[smp$block == b, ]
    if (!nrow(s)) next
    w <- if (b == "test") trva else tr          # test references refit on train + validation
    hc <- hclim(w)
    yt <- y[s$target_idx]; yt[is.na(yt)] <- yf[s$target_idx][is.na(yt)]
    base <- data.table::data.table(block = b, origin_idx = s$origin_idx,
                                   target_idx = s$target_idx, y = yt)
    out[[b]] <- rbind(
      data.table::copy(base)[, `:=`(arch = "persistence", yhat = yf[s$origin_idx])],
      data.table::copy(base)[, `:=`(arch = "seasonal_naive", yhat = yf[s$target_idx -
        24L * ceiling((s$target_idx - s$origin_idx) / 24)])],
      data.table::copy(base)[, `:=`(arch = "climatology", yhat = clim(w))],
      data.table::copy(base)[, `:=`(arch = "hour_climatology",
                                    yhat = as.numeric(hc[as.character(hod[s$target_idx])]))])
  }
  r <- data.table::rbindlist(out)
  r[, `:=`(seed = "ref", component = "LEVEL", family = "reference", kind = "reference",
           structure = "none")]
  r
}

# MASE denominators: seasonal-naive (24 h) MAE over the training block, using
# observed target pairs for the level and the component series for components.
sh_mase_scales <- function(panel, target, splits) {
  ts <- panel$timestamps
  w <- which(ts >= splits$train[1] & ts <= splits$train[2])
  sc <- function(x) { x <- x[w]; d <- abs(x[-(1:24)] - x[seq_len(length(x) - 24L)])
    mean(d[is.finite(d)]) }
  out <- c(LEVEL = sc(panel$observed[[target]]))
  for (cp in panel$components) out[cp] <- sc(panel$comps[[target]][, cp])
  out
}

sh_seed_mean <- function(pred) {
  keys <- intersect(c("station", "target", "horizon_h", "arch", "family", "kind", "structure",
                      "variant", "component", "block", "origin_idx", "target_idx"), names(pred))
  pred[, .(y = y[1], yhat = mean(yhat), n_seeds = .N), by = keys]
}

sh_metrics <- function(pred, scales) {
  keys <- intersect(c("station", "target", "horizon_h", "arch", "family", "kind", "structure",
                      "component", "seed", "block"), names(pred))
  m <- pred[, .(n = .N, MAE = mean(abs(yhat - y)), RMSE = sqrt(mean((yhat - y)^2))), by = keys]
  m[, MASE := MAE / scales[component]]
  m[]
}
