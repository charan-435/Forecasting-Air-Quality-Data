# Shillong architecture study: samples and feature sets.
# Direct fixed-horizon: y(t+h) = f_h(X_t). Lag 1 is the value at the origin t,
# lag 24 the value at t-23. Inputs are causal-filled values; every input index
# is <= the origin. Covariates enter at the origin only (never lagged); calendar
# fields describe the target timestamp, which is known in advance.

SH_LOOKBACK <- 24L

# ---- samples --------------------------------------------------------------------
# One sample per origin o with target tau = o + h. A sample is kept when:
#   * every input pollutant is finite on [o - lookback - warmup + 1, o]
#     (warmup = 2^J - 1 so decomposed inputs exist; applied to every
#     architecture so all architectures share target timestamps);
#   * the target hour is scorable (observed and not quality-masked) [primary];
#   * the origin passes the store policy: frac_filled_24h <= 0.25 and not in a
#     long gap, for the target pollutant [primary].
# The block is the block of the target timestamp. Train targets never pass
# the train end, so no label crosses a split boundary.
sh_samples <- function(cfg, panel, splits, target, h, input_pollutants,
                       scorable_only = TRUE, origin_policy = TRUE) {
  n <- length(panel$timestamps)
  h <- as.integer(h)
  back <- SH_LOOKBACK + (2L^panel$J - 1L)
  o <- seq.int(back, n - h)
  ok_in <- rep(TRUE, n)
  for (v in unique(c(target, input_pollutants))) ok_in <- ok_in & is.finite(panel$fill[[v]])
  # all inputs finite over the window ending at o: rolling all() via cumsum
  bad <- cumsum(!ok_in)
  win_ok <- (bad[o] - c(0L, bad)[o - back + 1L]) == 0L
  tau <- o + h
  keep <- win_ok
  if (scorable_only) keep <- keep & (panel$scorable[[target]][tau] %in% TRUE)
  else keep <- keep & is.finite(panel$fill[[target]][tau])
  if (origin_policy) {
    pol <- cfg$origin_policy
    ff <- panel$frac_filled_24h[[target]][o]
    keep <- keep & is.finite(ff) & ff <= as.numeric(pol$max_frac_filled_24h) &
      !(panel$in_long_gap[[target]][o] %in% TRUE)
  }
  o <- o[keep]; tau <- tau[keep]
  ts <- panel$timestamps[tau]
  block <- rep(NA_character_, length(tau))
  for (b in names(splits)) block[ts >= splits[[b]][1] & ts <= splits[[b]][2]] <- b
  k <- !is.na(block)
  data.frame(origin_idx = o[k], target_idx = tau[k], block = block[k],
             origin_ts = panel$timestamps[o[k]], target_ts = ts[k],
             stringsAsFactors = FALSE)
}

# ---- feature blocks ---------------------------------------------------------------

sh_lag_matrix <- function(x, origin_idx, prefix, lookback = SH_LOOKBACK) {
  M <- vapply(seq_len(lookback), function(k) x[origin_idx - k + 1L], numeric(length(origin_idx)))
  if (is.null(dim(M))) M <- matrix(M, nrow = length(origin_idx))
  colnames(M) <- sprintf("%s_l%02d", prefix, seq_len(lookback))
  M
}

sh_raw_lags <- function(panel, origin_idx, pollutants) {
  do.call(cbind, lapply(pollutants, function(v)
    sh_lag_matrix(panel$fill[[v]], origin_idx, v)))
}

sh_comp_lags <- function(panel, origin_idx, pollutants, components = panel$components) {
  do.call(cbind, lapply(pollutants, function(v) do.call(cbind, lapply(components, function(cp)
    sh_lag_matrix(panel$comps[[v]][, cp], origin_idx, paste(v, cp, sep = "_"))))))
}

# Covariates at the origin only (one column each, no lags) + target calendar.
sh_covariates <- function(panel, origin_idx, target_idx, covariates) {
  M <- as.matrix(panel$met[origin_idx, covariates, with = FALSE])
  storage.mode(M) <- "double"
  colnames(M) <- paste0("cov_", covariates)
  tt <- panel$timestamps[target_idx]
  cbind(M, cal_hour = lubridate::hour(tt),
        cal_dow = lubridate::wday(tt, week_start = 1))
}

# ---- architectures -----------------------------------------------------------------
# kind: "level" (undecomposed) or "decomp"; structure: "separate" or "shared".
SH_ARCHS <- list(
  A0 = list(kind = "level", hist = "own", cov = FALSE),
  A1 = list(kind = "level", hist = "own", cov = TRUE),
  A2 = list(kind = "level", hist = "all", cov = FALSE),
  A3 = list(kind = "level", hist = "all", cov = TRUE),
  B0 = list(kind = "decomp", structure = "separate", hist = "own_comp", cov = FALSE),
  B1 = list(kind = "decomp", structure = "shared", hist = "own_comp", cov = FALSE),
  B2 = list(kind = "decomp", structure = "separate", hist = "own_comp", cov = TRUE),
  B3 = list(kind = "decomp", structure = "shared", hist = "own_comp", cov = TRUE),
  C1_sep = list(kind = "decomp", structure = "separate", hist = "all_comp_own_pol", cov = FALSE),
  C1_sh = list(kind = "decomp", structure = "shared", hist = "all_comp_own_pol", cov = FALSE),
  C2_sep = list(kind = "decomp", structure = "separate", hist = "all_comp_all_pol", cov = FALSE),
  C2_sh = list(kind = "decomp", structure = "shared", hist = "all_comp_all_pol", cov = FALSE),
  C3_sep = list(kind = "decomp", structure = "separate", hist = "all_comp_all_pol", cov = TRUE),
  C3_sh = list(kind = "decomp", structure = "shared", hist = "all_comp_all_pol", cov = TRUE)
)

sh_arch <- function(id) {
  a <- SH_ARCHS[[id]]
  if (is.null(a)) stop("unknown architecture ", id)
  a$id <- id
  a
}

# Feature matrix of one architecture for one target component (decomposed) or
# the level (undecomposed), excluding the shared-model own slot / id.
sh_features <- function(panel, arch, smp, target, component = NULL, avail) {
  o <- smp$origin_idx
  X <- switch(arch$hist,
    own = sh_raw_lags(panel, o, target),
    all = sh_raw_lags(panel, o, avail$pollutants),
    own_comp = sh_comp_lags(panel, o, target, component),
    all_comp_own_pol = sh_comp_lags(panel, o, target),
    all_comp_all_pol = sh_comp_lags(panel, o, avail$pollutants),
    stop("unknown history set ", arch$hist))
  if (isTRUE(arch$cov)) X <- cbind(X, sh_covariates(panel, o, smp$target_idx, avail$covariates))
  X
}

# Train-block statistics of each target component (for shared-model scaling).
sh_comp_stats <- function(panel, target, splits) {
  ts <- panel$timestamps
  w <- ts >= splits$train[1] & ts <= splits$train[2] & seq_along(ts) >= 2^panel$J
  M <- panel$comps[[target]]
  data.frame(component = panel$components,
             mean = vapply(panel$components, function(cp) mean(M[w, cp], na.rm = TRUE), 0),
             sd = vapply(panel$components, function(cp) stats::sd(M[w, cp], na.rm = TRUE), 0))
}

# Dataset in the shape mv_select_and_refit() expects:
#   ds$blocks$<block>$X / $y / origin_idx / target_idx (+ component for shared).
# Separate: one dataset per component (or the level). Shared: rows stacked over
# components with comp_id (categorical), the target component's own 24 lags in a
# fixed standardized slot, and a per-component standardized target; scaling uses
# training-block statistics only (sh_comp_stats).
sh_dataset <- function(panel, arch, smp, target, h, avail, splits, component = NULL) {
  blocks <- c("train", "validation", "test")
  comps_all <- panel$components
  if (arch$kind == "level") {
    X <- sh_features(panel, arch, smp, target, NULL, avail)
    y <- panel$observed[[target]][smp$target_idx]
    y[is.na(y)] <- panel$fill[[target]][smp$target_idx][is.na(y)]   # unmasked runs only
    rows <- list(X = X, y = y, comp = rep("LEVEL", nrow(X)), smp = smp)
  } else if (arch$structure == "separate") {
    X <- sh_features(panel, arch, smp, target, component, avail)
    y <- panel$comps[[target]][smp$target_idx, component]
    rows <- list(X = X, y = y, comp = rep(component, nrow(X)), smp = smp)
  } else {
    st <- sh_comp_stats(panel, target, splits)
    parts <- lapply(seq_along(comps_all), function(j) {
      cp <- comps_all[j]
      mu <- st$mean[j]; s <- st$sd[j]
      own <- (sh_comp_lags(panel, smp$origin_idx, target, cp) - mu) / s
      colnames(own) <- sprintf("own_l%02d", seq_len(SH_LOOKBACK))
      extra <- if (arch$hist == "own_comp") {
        if (isTRUE(arch$cov)) sh_covariates(panel, smp$origin_idx, smp$target_idx, avail$covariates)
        else NULL
      } else sh_features(panel, arch, smp, target, NULL, avail)
      X <- cbind(comp_id = j - 1L, own, extra)
      list(X = X, y = (panel$comps[[target]][smp$target_idx, cp] - mu) / s,
           comp = rep(cp, nrow(X)), smp = smp)
    })
    rows <- list(X = do.call(rbind, lapply(parts, `[[`, "X")),
                 y = unlist(lapply(parts, `[[`, "y")),
                 comp = unlist(lapply(parts, `[[`, "comp")),
                 smp = do.call(rbind, lapply(parts, `[[`, "smp")),
                 stats = st)
  }
  out <- list(design = arch$id, h = as.integer(h), target = target, arch = arch,
              component = component %||% if (arch$kind == "level") "LEVEL" else "ALL",
              feature_names = colnames(rows$X), comp_stats = rows$stats, blocks = list())
  for (b in blocks) {
    k <- which(rows$smp$block == b)
    # order by origin then component so time-ordered bootstrap blocks stay intact
    k <- k[order(rows$smp$origin_idx[k], match(rows$comp[k], comps_all))]
    out$blocks[[b]] <- list(X = rows$X[k, , drop = FALSE], y = rows$y[k],
                            origin_idx = rows$smp$origin_idx[k],
                            target_idx = rows$smp$target_idx[k],
                            component = rows$comp[k], target = target)
  }
  out
}

# Undo the shared-model per-component scaling.
sh_unscale <- function(ds, block, yhat) {
  if (is.null(ds$comp_stats)) return(yhat)
  st <- ds$comp_stats
  j <- match(ds$blocks[[block]]$component, st$component)
  yhat * st$sd[j] + st$mean[j]
}

sh_feature_schema <- function(ds) {
  fn <- ds$feature_names
  grp <- ifelse(fn == "comp_id", "component_id",
         ifelse(grepl("^own_l", fn), "own_component_slot",
         ifelse(grepl("^cov_", fn), "covariate_at_origin",
         ifelse(grepl("^cal_", fn), "target_calendar",
         ifelse(grepl("_D[0-9]+_l|_S[0-9]+_l", fn), "component_lag", "pollutant_lag")))))
  data.frame(design = ds$design, h = ds$h, target = ds$target, component = ds$component,
             feature = fn, group = grp, stringsAsFactors = FALSE)
}
