# Multivariate feature layer (Phase 1). Builds fixed-horizon (direct) datasets
# from the verified panel. Column order: pollutant order from the config, then
# lag 00..23. lagKK = value at origin t minus KK hours. Nothing after t is read.

mv_design_pollutants <- function(cfg, design) {
  d <- cfg$designs[[design]]
  if (is.null(d)) stop("Unknown design: ", design)
  p <- unlist(d$pollutants)
  bad <- setdiff(p, unlist(cfg$data$pollutants))
  if (length(bad)) stop("Design ", design, " uses unknown pollutants: ", paste(bad, collapse = ", "))
  # keep the global pollutant order
  unlist(cfg$data$pollutants)[unlist(cfg$data$pollutants) %in% p]
}

mv_feature_names <- function(pollutants, lookback) {
  as.vector(unlist(lapply(pollutants, function(p)
    paste0(p, "__lag", sprintf("%02d", seq.int(0L, lookback - 1L))))))
}

mv_feature_manifest <- function(cfg, design) {
  p <- mv_design_pollutants(cfg, design)
  L <- as.integer(cfg$lookback_h)
  nm <- mv_feature_names(p, L)
  data.frame(position = seq_along(nm), feature = nm,
             pollutant = rep(p, each = L), lag_h = rep(seq.int(0L, L - 1L), times = length(p)),
             source_hour = paste0("t-", rep(seq.int(0L, L - 1L), times = length(p))),
             unit = unlist(cfg$data$units[rep(p, each = L)]),
             source_column = cfg$data$value_column, design = design,
             stringsAsFactors = FALSE)
}

# X for a set of origins: X[i, p__lagKK] = panel$X[origin_idx[i] - KK, p].
mv_build_X <- function(panel, origin_idx, pollutants, lookback) {
  origin_idx <- as.integer(origin_idx)
  L <- as.integer(lookback)
  if (length(origin_idx) && min(origin_idx) - (L - 1L) < 1L)
    stop("origin without full lookback history")
  if (length(origin_idx) && max(origin_idx) > nrow(panel$X))
    stop("origin beyond the panel")
  nm <- mv_feature_names(pollutants, L)
  X <- matrix(NA_real_, length(origin_idx), length(nm), dimnames = list(NULL, nm))
  j <- 0L
  for (p in pollutants) {
    col <- panel$X[, p]
    for (k in seq.int(0L, L - 1L)) {
      j <- j + 1L
      X[, j] <- col[origin_idx - k]
    }
  }
  X
}

mv_build_y <- function(panel, target_idx, target) as.numeric(panel$X[as.integer(target_idx), target])

# One design x one horizon, split into blocks. Test labels are carried for
# scoring only; model code receives them only through mv_score().
# `target` defaults to the configured target (PM2.5); designs list input pollutants only.
mv_dataset <- function(cfg, panel, design, h, target = cfg$target) {
  pols <- mv_design_pollutants(cfg, design)
  if (!target %in% panel$pollutants) stop("Unknown target: ", target)
  L <- as.integer(cfg$lookback_h)
  s <- mv_samples(cfg, panel$times, h)
  blocks <- list()
  for (b in c("train", "validation", "test")) {
    sb <- s[s$block == b, ]
    blocks[[b]] <- list(
      X = mv_build_X(panel, sb$origin_idx, pols, L),
      y = mv_build_y(panel, sb$target_idx, target),
      origin_idx = sb$origin_idx, target_idx = sb$target_idx,
      origin_ts = panel$times[sb$origin_idx], target_ts = panel$times[sb$target_idx])
  }
  list(design = design, h = as.integer(h), target = target, pollutants = pols,
       lookback = L, feature_names = mv_feature_names(pols, L), blocks = blocks,
       quality_mask = cfg$quality_mask)
}

mv_dataset_hashes <- function(ds) {
  do.call(rbind, lapply(names(ds$blocks), function(b) {
    bk <- ds$blocks[[b]]
    data.frame(design = ds$design, horizon_h = ds$h, block = b, n = length(bk$y),
               n_features = ncol(bk$X),
               X_sha256 = digest::digest(unname(bk$X), algo = "sha256"),
               y_sha256 = digest::digest(bk$y, algo = "sha256"),
               origins_sha256 = digest::digest(as.numeric(bk$origin_ts), algo = "sha256"),
               stringsAsFactors = FALSE)
  }))
}

# ---- train-fitted transforms ---------------------------------------------------
# Contract for later linear / PCA / PLS work: fit() sees the fitting rows only
# (and their labels, for supervised transforms such as PLS) and returns an
# apply() closure used unchanged on validation and test rows.
# Phase 1 trees use mv_transform_identity().

mv_transform_identity <- function() {
  list(name = "identity",
       fit = function(X_fit, y_fit = NULL) list(name = "identity", apply = function(X) X))
}

mv_transform_standardize <- function() {
  list(name = "standardize",
       fit = function(X_fit, y_fit = NULL) {
         mu <- colMeans(X_fit)
         sdv <- apply(X_fit, 2, stats::sd)
         sdv[!is.finite(sdv) | sdv == 0] <- 1
         list(name = "standardize", center = mu, scale = sdv,
              apply = function(X) sweep(sweep(X, 2, mu, "-"), 2, sdv, "/"))
       })
}
