# Build direct-forecast inputs for the five cleaned-CPCB architectures.
# Origin t = latest hour used. lag1 = y_t, lag24 = y_{t-23}.
# Covariates (A1/B2/B3) = other pollutants at t only. Target = y_{t+h}.

PE_COMPS <- c(paste0("D", 1:5), "S5")
PE_ARCHS <- c("B0", "A1", "B1", "B2", "B3")

# dataset = "clean" (this experiment) or "unmasked" (control: original values, same code).
pe_model_data <- function(cfg, dataset = c("clean", "unmasked")) {
  dataset <- match.arg(dataset)
  P <- cfg$pollutants
  h <- as.integer(cfg$forecast$horizon_h)
  cl <- as.data.frame(arrow::read_parquet(file.path(pe_dir(cfg, "store", "clean"), "series.parquet")))
  cl <- cl[order(cl$variable, cl$timestamp), ]
  times <- cl$timestamp[cl$variable == cfg$target]
  n <- length(times)
  # Truth = valid observations of the cleaned target (identical for both datasets).
  truth <- cl$value_masked[cl$variable == cfg$target]
  if (dataset == "clean") {
    input <- sapply(P, function(v) cl$value_filled_causal[cl$variable == v])
  } else {
    src <- as.data.frame(pe_load_source(cfg))
    src <- src[order(src$variable, src$timestamp), ]
    input <- sapply(P, function(v) src$value_hourly_raw[src$variable == v])
  }
  colnames(input) <- P
  comps <- list(); warm <- rep(TRUE, n)
  for (v in P) {
    d <- pe_read_decomp(cfg, dataset, v)
    stopifnot(identical(as.numeric(d$timestamp), as.numeric(times)))
    comps[[v]] <- as.matrix(d[, PE_COMPS])
    warm <- warm & d$valid_warmup
  }
  W <- pe_decomp_entry(cfg)$params$window_h
  el <- pe_eligibility(cfg, cl, W)
  stopifnot(identical(el$origin_idx, seq_len(n - h)))
  pol <- decomp_policy()
  # Clean fits require valid observed targets and acceptable input-fill coverage.
  # The control keeps original training values, but evaluation still uses clean truth.
  if (dataset == "clean") {
    fit_ok <- el$warm & el$target_scorable &
      el$frac_filled_24h <= as.numeric(pol$exclude_training_row_if_frac_filled_24h_gt)
    target_series <- truth
  } else {
    fit_ok <- warm[el$origin_idx]
    target_series <- input[, cfg$target]
  }
  eval_ok <- el$warm & el$target_scorable &
    el$frac_filled_24h <= as.numeric(pol$skip_origin_if_frac_filled_24h_gt) &
    !(isTRUE(pol$skip_origin_if_in_long_gap) & el$in_long_gap)
  fit_ok <- fit_ok & warm[el$origin_idx] & el$origin_idx >= 24L
  sets <- list(
    fit_train = el$origin_idx[fit_ok & el$block == "train"],
    fit_val = el$origin_idx[fit_ok & el$block == "val"],
    eval_val = el$origin_idx[eval_ok & el$block == "val"],
    eval_test = el$origin_idx[eval_ok & el$block == "test"])
  train_hours <- which(times <= pe_time(cfg$split$train_end, cfg))
  trainval_hours <- which(times <= pe_time(cfg$split$val_end, cfg))
  list(dataset = dataset, cfg = cfg, P = P, h = h, times = times, n = n, truth = truth,
       input = input, comps = comps, warm = warm, target_series = target_series,
       sets = sets, train_hours = train_hours, trainval_hours = trainval_hours)
}

# Mean/sd of every input series and every component over warm hours <= last_hour.
pe_scalers <- function(md, last_hour) {
  rows <- which(md$warm & seq_len(md$n) <= last_hour)
  one <- function(x) {
    x <- x[rows]
    s <- stats::sd(x, na.rm = TRUE)
    c(mean = mean(x, na.rm = TRUE), sd = if (is.finite(s) && s > 0) s else 1)
  }
  sc <- list()
  for (v in md$P) {
    sc[[paste0(v, "|input")]] <- one(md$input[, v])
    for (cc in PE_COMPS) sc[[paste0(v, "|", cc)]] <- one(md$comps[[v]][, cc])
  }
  sc
}

pe_z <- function(x, s) (x - s[["mean"]]) / s[["sd"]]
pe_unz <- function(z, s) z * s[["sd"]] + s[["mean"]]

pe_lags <- function(s, idx, L) {
  m <- vapply(seq_len(L) - 1L, function(k) s[idx - k], numeric(length(idx)))
  m <- matrix(m, nrow = length(idx))
  colnames(m) <- paste0("lag", seq_len(L))
  m
}

pe_others <- function(md) setdiff(md$P, md$cfg$target)

# Covariates at the origin only. same_level: the other pollutants' component of the
# same level as the target component; all_levels: all six components of each.
pe_comp_covariates <- function(md, idx, comp, cov_set, sc) {
  if (identical(cov_set, "same_level")) {
    m <- sapply(pe_others(md), function(v) pe_z(md$comps[[v]][idx, comp], sc[[paste0(v, "|", comp)]]))
    m <- matrix(m, nrow = length(idx))
    colnames(m) <- paste0("cov_", pe_others(md))
  } else {
    m <- do.call(cbind, lapply(pe_others(md), function(v) {
      mm <- sapply(PE_COMPS, function(cc) pe_z(md$comps[[v]][idx, cc], sc[[paste0(v, "|", cc)]]))
      mm <- matrix(mm, nrow = length(idx))
      colnames(mm) <- paste0("cov_", v, "_", PE_COMPS)
      mm
    }))
  }
  m
}

# One target component (B0, B2) or the raw target (A1). Returns X, y (scaled),
# the scaler of the target, and the original-unit target.
pe_xy_single <- function(md, arch, idx, sc, comp = NULL, cov_set = NULL) {
  L <- as.integer(md$cfg$forecast$n_lags)
  h <- md$h
  tgt <- md$cfg$target
  if (identical(arch, "A1")) {
    s_t <- sc[[paste0(tgt, "|input")]]
    X <- pe_lags(pe_z(md$input[, tgt], s_t), idx, L)
    cov <- sapply(pe_others(md), function(v) pe_z(md$input[idx, v], sc[[paste0(v, "|input")]]))
    cov <- matrix(cov, nrow = length(idx)); colnames(cov) <- paste0("cov_", pe_others(md))
    X <- cbind(X, cov)
    y_orig <- md$target_series[idx + h]
  } else {
    s_t <- sc[[paste0(tgt, "|", comp)]]
    X <- pe_lags(pe_z(md$comps[[tgt]][, comp], s_t), idx, L)
    if (identical(arch, "B2")) X <- cbind(X, pe_comp_covariates(md, idx, comp, cov_set, sc))
    y_orig <- md$comps[[tgt]][idx + h, comp]
  }
  list(X = X, y = pe_z(y_orig, s_t), y_orig = y_orig, scaler = s_t, idx = idx)
}

# Shared model rows (B1, B3): the six target components stacked; component identity
# is a categorical feature (0..5) and each row weighs its component's training sd.
pe_xy_shared <- function(md, arch, idx, sc, cov_set = NULL) {
  tgt <- md$cfg$target
  parts <- lapply(seq_along(PE_COMPS), function(k) {
    cc <- PE_COMPS[k]
    a <- pe_xy_single(md, "B0", idx, sc, comp = cc)
    X <- cbind(a$X, component = k - 1L)
    if (identical(arch, "B3")) X <- cbind(X, pe_comp_covariates(md, idx, cc, cov_set, sc))
    list(X = X, y = a$y, y_orig = a$y_orig, comp = rep(cc, length(idx)), idx = idx,
         w = rep(sc[[paste0(tgt, "|", cc)]][["sd"]], length(idx)))
  })
  list(X = do.call(rbind, lapply(parts, `[[`, "X")), y = unlist(lapply(parts, `[[`, "y")),
       y_orig = unlist(lapply(parts, `[[`, "y_orig")), comp = unlist(lapply(parts, `[[`, "comp")),
       idx = unlist(lapply(parts, `[[`, "idx")), w = unlist(lapply(parts, `[[`, "w")))
}
