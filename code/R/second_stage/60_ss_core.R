# S bundles one station panel, its time splits, and available inputs.
# smp lists forecast origins and their target rows; ds holds model matrices.
# A unit is one fitted level model, component model, or shared component model.
# st is the rolling history at a virtual origin after k predicted hours.

# Second-stage Shillong experiments: PCA inputs and direct / recursive / hybrid
# strategies. Reuses the Shillong panel, samples, feature sets and model
# interface (R/50-53, R/43-48) unchanged; nothing here writes outside the
# second-stage output directory.
#
# Strategies (target y = PM2.5 at origin o + h, same samples as the direct study):
#   direct    - y(o+h) = f_h(X_o), the original Shillong setup.
#   recursive - one-step models g_v(X_t) -> x_v(t+1) for every series the
#               architecture reads; predictions are written back into the
#               input windows and the loop runs to step h. Decomposed
#               architectures predict components, sum them to the pollutant
#               level, and recompute the components of the extended level
#               series with the same causal Haar filter (R/31), so the inputs
#               stay a valid decomposition.
#   hybrid    - the recursive loop to step s, then a direct model for the
#               remaining h - s hours applied at the virtual origin o + s. The
#               direct stage sees only the architecture's features at o + s
#               (24 recursively predicted hours of every series; covariates at
#               the true origin o; calendar of the target hour). It is trained
#               on the same kind of inputs: recursive predictions for training
#               origins come from one-step models cross-fitted on the other
#               training folds (purged around the fold), never from models that
#               saw those hours.

# Returns the history length needed for lag inputs plus the Haar warmup. Cross-fit purging
# uses this length.
ss_back <- function(panel) SH_LOOKBACK + (2L^panel$J - 1L)
# Returns how many recent pollutant values the rolling forecast state must keep.
ss_win <- function(panel) max(SH_LOOKBACK, 2L^panel$J)   # level window kept in the state

# ---- PCA ---------------------------------------------------------------------------------
# Columns that enter PCA: pollutant or component lags (the own-component slot of
# shared models included). Covariates, calendar fields and comp_id pass through.
# Selects only lag columns for PCA. Calendar fields, weather fields, and component
# identifiers keep their original meaning.
ss_pca_cols <- function(fn) !(fn == "comp_id" | grepl("^cov_", fn) | grepl("^cal_", fn))

# Train-only PCA: standardize with training statistics, keep the fewest
# components whose cumulative training variance reaches `thr`.
# Learns centering, scaling, and PCA directions from training rows. Returns a frozen
# transform that applies those same choices to later rows.
ss_pca_fit <- function(X_train, thr) {
  fn <- colnames(X_train)
  pc_cols <- fn[ss_pca_cols(fn)]
  pass <- fn[!ss_pca_cols(fn)]
  Z <- X_train[, pc_cols, drop = FALSE]
  if (!all(is.finite(Z))) stop("PCA inputs must be finite")
  # Later periods reuse these training statistics instead of learning their own scale.
  mu <- colMeans(Z)
  sdv <- apply(Z, 2, stats::sd)
  sdv[!is.finite(sdv) | sdv == 0] <- 1
  pc <- stats::prcomp(sweep(sweep(Z, 2, mu, "-"), 2, sdv, "/"), center = FALSE, scale. = FALSE)
  ve <- pc$sdev^2 / sum(pc$sdev^2)
  cv <- cumsum(ve)
  k <- which(cv >= thr - 1e-12)[1]
  R <- pc$rotation[, seq_len(k), drop = FALSE]
  name <- sprintf("pca%02d", round(100 * thr))
  list(name = name,
       info = list(thr = thr, k = k, n_in = length(pc_cols), n_pass = length(pass),
                   cum_var = cv, var_explained = ve, n_fit = nrow(Z)),
       mu = mu, sd = sdv, rotation = R, pc_cols = pc_cols, pass = pass,
       apply = function(X) {
         S <- sweep(sweep(X[, pc_cols, drop = FALSE], 2, mu, "-"), 2, sdv, "/") %*% R
         colnames(S) <- sprintf("PC%03d", seq_len(k))
         cbind(S, X[, pass, drop = FALSE])
       })
}

# Turns the PCA choice into a stable label used in result names.
ss_pca_label <- function(pca) if (identical(pca, "none")) "none" else sprintf("pca%02d", round(100 * as.numeric(pca)))

# Transform for one model: identity or the train-only PCA. The returned object
# ignores the rows it is "fitted" on, so mv_select_and_refit()'s train +
# validation refit applies the training PCA unchanged.
# Wraps the chosen training PCA, or an unchanged-input transform, in the interface used by
# the shared learner code.
ss_transform <- function(X_train, pca) {
  obj <- if (identical(pca, "none"))
    list(name = "none", info = NULL, apply = function(X) X) else ss_pca_fit(X_train, as.numeric(pca))
  list(name = obj$name, obj = obj, fit = function(X_fit, y_fit = NULL) obj)
}

# ---- fitting ------------------------------------------------------------------------------
# sh_fit_ds() with an explicit transform; with pca = "none" it is the original
# Shillong fit (identical candidates, tuning, seeds and refit).
# Tunes one dataset on validation error and fits the requested seeds. Returns predictions,
# iteration choices, tuning records, and optionally the fitted models.
ss_fit_ds <- function(cfg, ds, tf, seeds, tune_seed, keep_models = FALSE) {
  shared <- "comp_id" %in% ds$feature_names
  cands <- sh_candidates(cfg, "lightgbm", shared)
  tun <- mv_tune("lightgbm", ds, cands, tune_seed, tf)
  preds <- list(); info <- list(); models <- list()
  for (s in seeds) {
    r <- mv_select_and_refit("lightgbm", ds, tun$params, s, tf, keep_models = keep_models)
    for (b in names(ds$blocks)) {
      bk <- ds$blocks[[b]]
      preds[[paste(s, b)]] <- data.table::data.table(
        seed = s, block = b, component = bk$component, origin_idx = bk$origin_idx,
        target_idx = bk$target_idx, y = sh_unscale(ds, b, bk$y),
        yhat = sh_unscale(ds, b, r$pred[[b]]))
    }
    info[[as.character(s)]] <- data.table::data.table(
      seed = s, candidate = tun$best, best_iter = r$best_iter, refit_rounds = r$refit_rounds,
      n_train = length(ds$blocks$train$y), n_validation = length(ds$blocks$validation$y),
      n_test = length(ds$blocks$test$y), n_inputs = r$n_inputs, elapsed_s = round(r$elapsed_s, 2))
    if (keep_models) models[[as.character(s)]] <- list(sel = r$models$selection,
                                                       ref = r$models$refit, best_iter = r$best_iter)
  }
  list(pred = data.table::rbindlist(preds), info = data.table::rbindlist(info),
       tuning = data.table::as.data.table(tun$table), params = tun$params, models = models)
}

# Reconstructed level of a decomposed run: sum of component forecasts per
# (seed, block, origin); the level truth is the observed target value.
# Sums every component prediction for the same seed, block, origin, and target. Adds a
# LEVEL row so reconstructed forecasts can be scored against the pollutant.
ss_reconstruct <- function(pred, panel, target) {
  lev <- pred[, .(yhat = sum(yhat), n_comp = .N), by = .(seed, block, origin_idx, target_idx)]
  stopifnot(all(lev$n_comp == length(panel$components)))
  lev[, n_comp := NULL]
  yobs <- panel$observed[[target]][lev$target_idx]
  yobs[is.na(yobs)] <- panel$fill[[target]][lev$target_idx][is.na(yobs)]
  lev[, `:=`(component = "LEVEL", y = yobs)]
  rbind(pred, lev[, names(pred), with = FALSE])
}

# Fit a list of datasets (one per unit: the level, a component, or the stacked
# shared set) with one PCA setting; reconstruct the level for decomposed archs.
# Fits the required level or component datasets for one architecture and PCA choice.
# Combines their records and reconstructs the pollutant when needed.
ss_run_units <- function(cfg, panel, arch, target, ds_list, pca, seeds, tune_seed) {
  t0 <- proc.time()[["elapsed"]]
  res <- lapply(ds_list, function(ds) {
    tf <- ss_transform(ds$blocks$train$X, pca)
    f <- ss_fit_ds(cfg, ds, tf, seeds, tune_seed)
    f$info[, component := ds$component]
    f$tuning[, component := ds$component]
    pi <- tf$obj$info
    f$pca <- data.table::data.table(component = ds$component, n_in = length(ds$feature_names),
      n_pca_in = pi$n_in %||% NA_integer_, k = pi$k %||% NA_integer_,
      cum_var_k = if (is.null(pi)) NA_real_ else pi$cum_var[pi$k],
      cum_var = if (is.null(pi)) "" else paste(round(pi$cum_var, 5), collapse = ";"))
    f
  })
  pred <- data.table::rbindlist(lapply(res, `[[`, "pred"))
  if (arch$kind == "decomp") pred <- ss_reconstruct(pred, panel, target)
  list(pred = pred, info = data.table::rbindlist(lapply(res, `[[`, "info")),
       tuning = data.table::rbindlist(lapply(res, `[[`, "tuning")),
       pca = data.table::rbindlist(lapply(res, `[[`, "pca")),
       elapsed_s = proc.time()[["elapsed"]] - t0)
}

# Separate component architectures need one dataset per component. Raw-level and shared
# architectures need one dataset.
ss_units <- function(panel, arch) {
  if (arch$kind == "decomp" && arch$structure == "separate") as.list(panel$components) else list(NULL)
}

# Builds the horizon-specific datasets and fits a direct forecast of the later target.
ss_run_direct <- function(cfg, S, smp, target, h, arch, pca, seeds, tune_seed) {
  ds_list <- lapply(ss_units(S$panel, arch), function(cp)
    sh_dataset(S$panel, arch, smp, target, h, S$avail, S$splits, component = cp))
  ss_run_units(cfg, S$panel, arch, target, ds_list, pca, seeds, tune_seed)
}

# ---- recursion state ---------------------------------------------------------------------
# For a set of origins, the last ss_win() level values of every state series
# and the last SH_LOOKBACK values of each of its components, ending at the
# virtual origin origin + k. Only values at or before the true origin come from
# the panel; everything after it is a model prediction.

# Series the architecture reads (and the recursion must therefore forecast).
# Lists every pollutant that must be predicted to keep this architecture supplied with
# recursive inputs.
ss_state_pols <- function(arch, target, avail) {
  if (arch$hist %in% c("all", "all_comp_all_pol")) avail$pollutants else target
}

# Causal Haar filter: the components at t are a fixed linear map of x[t-2^J+1 .. t].
# Builds a fixed matrix that maps the recent pollutant window to its current Haar
# components.
ss_haar_filter <- function(J) {
  L <- 2L^J
  Fm <- t(vapply(seq_len(L), function(i) {
    e <- numeric(L); e[i] <- 1
    sh_decompose(e, J)[L, ]
  }, numeric(J + 1L)))
  colnames(Fm) <- sh_components(J)
  Fm
}

# Copies the measured history ending at each forecast origin into a rolling state. Later
# state updates append model predictions, not later observations.
ss_state_init <- function(S, arch, target, origins) {
  panel <- S$panel
  n <- length(origins)
  W <- ss_win(panel)
  pols <- ss_state_pols(arch, target, S$avail)
  # Each row is one origin. Columns run from the oldest value to the newest.
  idx <- outer(origins, seq_len(W) - W, "+")          # times o-W+1 .. o
  idl <- outer(origins, seq_len(SH_LOOKBACK) - SH_LOOKBACK, "+")
  lev <- list(); comps <- list()
  for (v in pols) {
    lev[[v]] <- matrix(panel$fill[[v]][idx], nrow = n)
    if (arch$kind == "decomp") comps[[v]] <- lapply(stats::setNames(panel$components, panel$components),
      function(cp) matrix(panel$comps[[v]][, cp][idl], nrow = n))
  }
  covs <- if (isTRUE(arch$cov)) S$avail$covariates else character(0)
  met <- if (length(covs)) {
    M <- as.matrix(panel$met[origins, covs, with = FALSE]); storage.mode(M) <- "double"
    colnames(M) <- paste0("cov_", covs); M
  } else NULL
  list(origins = origins, k = 0L, lev = lev, comps = comps, met = met, pols = pols,
       decomp = arch$kind == "decomp")
}

# Keeps selected forecast origins and the matching rows of every state matrix.
ss_state_subset <- function(st, rows) {
  st$origins <- st$origins[rows]
  st$lev <- lapply(st$lev, function(M) M[rows, , drop = FALSE])
  st$comps <- lapply(st$comps, function(L) lapply(L, function(M) M[rows, , drop = FALSE]))
  if (!is.null(st$met)) st$met <- st$met[rows, , drop = FALSE]
  st
}

# Combines two batches of forecast origins while preserving their pollutant, component,
# and weather rows.
ss_state_rbind <- function(a, b) {
  a$origins <- c(a$origins, b$origins)
  for (v in names(a$lev)) a$lev[[v]] <- rbind(a$lev[[v]], b$lev[[v]])
  for (v in names(a$comps)) for (cp in names(a$comps[[v]]))
    a$comps[[v]][[cp]] <- rbind(a$comps[[v]][[cp]], b$comps[[v]][[cp]])
  if (!is.null(a$met)) a$met <- rbind(a$met, b$met)
  a
}

# Append one predicted hour. `lev_new` is a named list of level predictions;
# components of the extended level series are recomputed with the Haar filter.
# Drops the oldest value and appends one predicted hour. Recomputes Haar components from
# the extended pollutant history to keep them consistent.
ss_state_push <- function(st, lev_new, Fm) {
  for (v in names(lev_new)) {
    M <- cbind(st$lev[[v]][, -1L, drop = FALSE], lev_new[[v]])
    st$lev[[v]] <- M
    if (st$decomp) {
      L <- nrow(Fm)
      cnew <- M[, (ncol(M) - L + 1L):ncol(M), drop = FALSE] %*% Fm
      for (cp in colnames(Fm))
        st$comps[[v]][[cp]] <- cbind(st$comps[[v]][[cp]][, -1L, drop = FALSE], cnew[, cp])
    }
  }
  st$k <- st$k + 1L
  st
}

# Lag block of a window matrix: lag 1 = last column (the virtual origin).
# Reads each rolling window from newest to oldest and names the lag columns expected by
# the models.
ss_lags <- function(M, prefix) {
  X <- M[, ncol(M) - seq_len(SH_LOOKBACK) + 1L, drop = FALSE]
  colnames(X) <- sprintf("%s_l%02d", prefix, seq_len(SH_LOOKBACK))
  X
}

# Combines the requested pollutant and component lag windows into one input matrix.
ss_comp_block <- function(st, pols, comps) do.call(cbind, lapply(pols, function(v)
  do.call(cbind, lapply(comps, function(cp) ss_lags(st$comps[[v]][[cp]], paste(v, cp, sep = "_"))))))

# Covariates at the true origin + calendar of the target hour origin + k + hh.
# Uses weather measured at the true forecast origin and the calendar of the future target.
# Future observed weather is not read here.
ss_state_cov <- function(st, panel, hh) {
  tt <- panel$timestamps[1] + 3600 * (st$origins + st$k + hh - 1L)
  cbind(st$met, cal_hour = lubridate::hour(tt), cal_dow = lubridate::wday(tt, week_start = 1))
}

# Features of the architecture at the state's virtual origin for a model of
# pollutant v (component cp) with horizon hh; same columns as sh_features().
# Builds the architecture-specific input columns from the rolling state for a level or
# separate component model.
ss_state_X <- function(st, panel, arch, v, cp, hh, avail) {
  X <- switch(arch$hist,
    own = ss_lags(st$lev[[v]], v),
    all = do.call(cbind, lapply(avail$pollutants, function(p) ss_lags(st$lev[[p]], p))),
    own_comp = ss_lags(st$comps[[v]][[cp]], paste(v, cp, sep = "_")),
    all_comp_own_pol = ss_comp_block(st, v, panel$components),
    all_comp_all_pol = ss_comp_block(st, avail$pollutants, panel$components),
    stop("unknown history set ", arch$hist))
  if (isTRUE(arch$cov)) X <- cbind(X, ss_state_cov(st, panel, hh))
  X
}

# Shared-model rows for component j (as in sh_dataset): comp_id, the
# standardized own-component slot, then the architecture's other inputs.
# Builds a row for the shared component model. Applies the stored component scaling and
# includes the component identifier.
ss_state_X_shared <- function(st, panel, arch, v, j, hh, avail, stats) {
  cp <- panel$components[j]
  own <- (ss_lags(st$comps[[v]][[cp]], "own") - stats$mean[j]) / stats$sd[j]
  extra <- if (arch$hist == "own_comp") {
    if (isTRUE(arch$cov)) ss_state_cov(st, panel, hh) else NULL
  } else ss_state_X(st, panel, arch, v, NULL, hh, avail)
  cbind(comp_id = j - 1L, own, extra)
}

# ---- one-step models ---------------------------------------------------------------------

# Gets the LightGBM interface used by the second-stage experiments.
ss_fam <- function() mv_family("lightgbm")

# One unit per forecast series: (pollutant, level) for undecomposed archs,
# (pollutant, component) for separate decomposed archs, (pollutant, all
# components stacked) for shared ones. Each is fitted like a direct model at
# h = 1 on that pollutant's own sample rule; models are kept for the recursion.
# Fits the one-hour-ahead models needed to predict every input series during recursion.
# Keeps the fitted models for repeated state updates.
ss_fit_onestep <- function(cfg, S, arch, target, pca, seeds, tune_seed, say = function(...) NULL) {
  panel <- S$panel
  units <- list()
  for (v in ss_state_pols(arch, target, S$avail)) {
    smp1 <- sh_samples(cfg, panel, S$splits, v, 1L, S$avail$pollutants)
    for (cp in ss_units(panel, arch)) {
      ds <- sh_dataset(panel, arch, smp1, v, 1L, S$avail, S$splits, component = cp)
      t0 <- proc.time()[["elapsed"]]
      tf <- ss_transform(ds$blocks$train$X, pca)
      f <- ss_fit_ds(cfg, ds, tf, seeds, tune_seed, keep_models = TRUE)
      u <- list(v = v, component = ds$component, shared = !is.null(ds$comp_stats),
                stats = ds$comp_stats, feature_names = ds$feature_names, tf = tf$obj,
                params = f$params, models = f$models, ds_train = ds$blocks$train,
                elapsed_s = proc.time()[["elapsed"]] - t0)
      pi <- tf$obj$info
      u$summary <- cbind(f$info[, .(seed, candidate, best_iter, n_train, n_validation, n_test,
                                    n_inputs, elapsed_s)],
                         data.table::data.table(pollutant = v, component = ds$component,
                                                pca_k = pi$k %||% NA_integer_,
                                                pca_n_in = pi$n_in %||% NA_integer_))
      # one-step validation / test accuracy (seed mean), a diagnostic only
      sm <- f$pred[, .(y = y[1], yhat = mean(yhat)), by = .(block, component, origin_idx)]
      u$onestep_mae <- sm[, .(MAE = mean(abs(yhat - y)), n = .N), by = .(block, component)][
        , pollutant := v]
      units[[paste(v, ds$component)]] <- u
      say(sprintf("  one-step %s %s: k=%s, %.0f s", v, ds$component, pi$k %||% "-", u$elapsed_s))
    }
  }
  units
}

# Predict one unit on a state (mean over seeds of `version` models). Returns a
# vector (level / one component) or an n x components matrix (shared).
# Predicts one unit by averaging seeds from the requested fitted-model version.
ss_unit_predict <- function(u, st, panel, arch, hh, avail, version) {
  fam <- ss_fam()
  fits <- lapply(u$models, function(m) m[[version]])
  pred_X <- function(X) {
    Z <- u$tf$apply(X[, u$feature_names, drop = FALSE])
    Reduce(`+`, lapply(fits, function(f) fam$predict(f, Z))) / length(fits)
  }
  if (!u$shared) return(pred_X(ss_state_X(st, panel, arch, u$v, if (u$component == "LEVEL") NULL else u$component,
                                          hh, avail)))
  vapply(seq_along(panel$components), function(j)
    pred_X(ss_state_X_shared(st, panel, arch, u$v, j, hh, avail, u$stats)) * u$stats$sd[j] + u$stats$mean[j],
    numeric(length(st$origins)))
}

# Run the recursion for `origins` to step need[i]. Records the target's level
# and (decomposed) component forecasts at the steps in `record`, and snapshots
# of the state at the steps in `snap`.
# Advances the forecast state one predicted hour at a time. Records requested horizon
# forecasts and optional state snapshots for the hybrid stage.
ss_recurse <- function(S, arch, target, units, origins, need, version, record, snap = integer(0)) {
  panel <- S$panel
  Fm <- ss_haar_filter(panel$J)
  st <- ss_state_init(S, arch, target, origins)
  out <- list(); snaps <- list()
  for (k in seq_len(max(need))) {
    # Stop carrying an origin once its requested forecast horizon is complete.
    keep <- need >= k
    if (!all(keep)) { st <- ss_state_subset(st, which(keep)); need <- need[keep] }
    lev_new <- list(); comp_tgt <- NULL
    for (v in st$pols) {
      us <- Filter(function(u) u$v == v, units)
      if (arch$kind == "level") {
        lev_new[[v]] <- ss_unit_predict(us[[1]], st, panel, arch, 1L, S$avail, version)
      } else {
        P <- if (us[[1]]$shared) ss_unit_predict(us[[1]], st, panel, arch, 1L, S$avail, version) else
          vapply(us, function(u) ss_unit_predict(u, st, panel, arch, 1L, S$avail, version),
                 numeric(length(st$origins)))
        P <- matrix(P, nrow = length(st$origins), dimnames = list(NULL, panel$components))
        lev_new[[v]] <- rowSums(P)
        if (v == target) comp_tgt <- P
      }
    }
    if (k %in% record) {
      d <- data.table::data.table(origin_idx = st$origins, step = k, component = "LEVEL",
                                  yhat = lev_new[[target]])
      if (!is.null(comp_tgt)) d <- rbind(d, data.table::rbindlist(lapply(colnames(comp_tgt), function(cp)
        data.table::data.table(origin_idx = st$origins, step = k, component = cp, yhat = comp_tgt[, cp]))))
      out[[as.character(k)]] <- d
    }
    # Feed this hour's predictions back into the next input window.
    st <- ss_state_push(st, lev_new, Fm)
    if (k %in% snap) snaps[[as.character(k)]] <- st
  }
  list(pred = data.table::rbindlist(out), snaps = snaps)
}

# ---- cross-fitted one-step models for the hybrid's training inputs ------------------------
# Training origins are split into K contiguous folds. For fold f, every unit is
# refitted on the training rows whose input-to-target span [o - back, o + 1]
# does not touch [lo_f - back, hi_f + s_max]; same tuned parameters and the
# selection fit's iteration count for each seed (no early stopping, no
# validation rows).
# Divides training origins into contiguous folds for the hybrid training inputs.
ss_folds <- function(origins, K) {
  o <- sort(unique(origins))
  f <- cut(seq_along(o), K, labels = FALSE)
  lapply(seq_len(K), function(i) o[f == i])
}

# Fits one-step models while excluding a fold and nearby overlapping windows. These models
# create hybrid training inputs for origins they did not fit.
ss_crossfit_units <- function(units, folds, back, s_max) {
  fam <- ss_fam()
  for (nm in names(units)) {
    u <- units[[nm]]
    tr <- u$ds_train
    for (f in seq_along(folds)) {
      lo <- min(folds[[f]]); hi <- max(folds[[f]])
      ok <- !(tr$origin_idx + 1L >= lo - back & tr$origin_idx - back <= hi + s_max)
      Z <- u$tf$apply(tr$X[ok, , drop = FALSE])
      for (sd in names(u$models)) {
        m <- u$models[[sd]]
        m[[paste0("cf", f)]] <- fam$fit(Z, tr$y[ok], NULL, NULL, u$params, as.integer(sd),
                                        nrounds = m$best_iter, early_stopping = FALSE)
        m[[paste0("cf", f, "_n")]] <- sum(ok)
        u$models[[sd]] <- m
      }
    }
    units[[nm]] <- u
  }
  units
}

# ---- hybrid direct stage --------------------------------------------------------------------
# Dataset in sh_dataset()'s shape whose features are built from recursion
# snapshots at step s (state per block: train = cross-fitted, validation =
# selection models, test = refit models), for horizon h - s.
# Builds direct-model training rows from recursive state snapshots. The target stays at
# the original horizon while the remaining direct lead is shorter.
ss_hybrid_ds <- function(S, arch, target, h, s, smp, snaps, component = NULL) {
  panel <- S$panel
  comps_all <- panel$components
  stats <- if (arch$kind == "decomp" && arch$structure == "shared")
    sh_comp_stats(panel, target, S$splits) else NULL
  out <- list(design = arch$id, h = as.integer(h), target = target, arch = arch,
              component = component %||% if (arch$kind == "level") "LEVEL" else "ALL",
              comp_stats = stats, blocks = list())
  for (b in c("train", "validation", "test")) {
    sb <- smp[smp$block == b, ]
    sb <- sb[order(sb$origin_idx), ]
    st <- snaps[[b]]
    r <- match(sb$origin_idx, st$origins)
    if (anyNA(r)) stop("hybrid: missing recursive state for ", sum(is.na(r)), " ", b, " origins")
    st <- ss_state_subset(st, r)
    hh <- as.integer(h - s)
    if (arch$kind == "level") {
      X <- ss_state_X(st, panel, arch, target, NULL, hh, S$avail)
      y <- panel$observed[[target]][sb$target_idx]
      comp <- rep("LEVEL", nrow(X)); oi <- sb$origin_idx; ti <- sb$target_idx
    } else if (arch$structure == "separate") {
      X <- ss_state_X(st, panel, arch, target, component, hh, S$avail)
      y <- panel$comps[[target]][sb$target_idx, component]
      comp <- rep(component, nrow(X)); oi <- sb$origin_idx; ti <- sb$target_idx
    } else {
      parts <- lapply(seq_along(comps_all), function(j) list(
        X = ss_state_X_shared(st, panel, arch, target, j, hh, S$avail, stats),
        y = (panel$comps[[target]][sb$target_idx, comps_all[j]] - stats$mean[j]) / stats$sd[j]))
      X <- do.call(rbind, lapply(parts, `[[`, "X"))
      y <- unlist(lapply(parts, `[[`, "y"))
      comp <- rep(comps_all, each = nrow(sb))
      oi <- rep(sb$origin_idx, length(comps_all)); ti <- rep(sb$target_idx, length(comps_all))
      o <- order(oi, match(comp, comps_all))
      X <- X[o, , drop = FALSE]; y <- y[o]; comp <- comp[o]; oi <- oi[o]; ti <- ti[o]
    }
    out$blocks[[b]] <- list(X = X, y = y, origin_idx = oi, target_idx = ti, component = comp,
                            target = target)
  }
  out$feature_names <- colnames(out$blocks$train$X)
  out
}
