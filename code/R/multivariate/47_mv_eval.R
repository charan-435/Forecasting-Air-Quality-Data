# Evaluation helpers for the multivariate pipeline (Phase 2).
# Primary metrics stay UNMASKED. Constant-fill groups are diagnostic breakdowns
# of the same predictions; they never filter training or selection rows.

# ---- constant-fill hours (diagnostic grouping only) ----------------------------------
# Phase 0 definition: an hour carrying the single upstream fill vector on all
# six pollutants. The vector is found from the data as the one covering the most
# hours among all-six frozen runs of >= min_run hours. On CPCB this reproduces
# the 2,304 Phase 0 hours. Other all-six frozen runs (107 h on CPCB, at other
# values) are reported by mv_frozen_hours() and are not "constant fill".
mv_frozen_hours <- function(panel, min_run = 24L) {
  X <- panel$X
  same_prev <- c(FALSE, rowSums(abs(X[-1, , drop = FALSE] - X[-nrow(X), , drop = FALSE])) == 0)
  # an hour belongs to a run if it equals its predecessor, or its successor equals it
  in_pair <- same_prev | c(same_prev[-1], FALSE)
  r <- rle(in_pair)
  long <- r$values & r$lengths >= min_run
  rep(long, r$lengths)
}

mv_fill_hours <- function(panel, min_run = 24L) {
  fr <- mv_frozen_hours(panel, min_run)
  if (!any(fr)) return(fr)
  key <- apply(panel$X, 1, function(r) paste(format(r, digits = 15), collapse = "|"))
  tab <- table(key[fr])
  key == names(tab)[which.max(tab)]
}

# Group labels per sample: target fill / not; "clean" = no fill in target or lag window.
mv_fill_groups <- function(fill, origin_idx, target_idx, lookback) {
  tf <- fill[target_idx]
  win <- vapply(origin_idx, function(o) any(fill[(o - lookback + 1L):o]), logical(1))
  list(constant_fill_target = tf, non_fill_target = !tf, clean = !tf & !win)
}

# Seasonal-naive reference: latest observed value at the same hour of day as
# the target, i.e. y(t + h - 24 * ceiling(h / 24)). For h in {24,168,336,744}: y(t).
mv_seasonal_naive <- function(panel, origin_idx, h, target, season = 24L) {
  back <- season * ceiling(h / season)
  as.numeric(panel$X[origin_idx + h - back, target])
}

# ---- dependence-aware block length -----------------------------------------------------
# Politis & White (2004) with the Patton, Politis & White (2009) correction:
# optimal block length for the circular / moving-block bootstrap of the mean.
mv_pw_block_length <- function(x) {
  x <- as.numeric(x); n <- length(x)
  x <- x - mean(x)
  if (stats::var(x) == 0) return(list(b = 1, mhat = 0L, M = 0L, n = n))
  kn <- max(5L, ceiling(sqrt(log10(n))))
  mmax <- ceiling(sqrt(n)) + kn
  thr <- 2 * sqrt(log10(n) / n)
  ac <- stats::acf(x, lag.max = mmax, plot = FALSE, demean = FALSE)$acf[-1]
  # smallest m after which kn consecutive autocorrelations are insignificant
  mhat <- NA_integer_
  for (m in seq_len(mmax - kn + 1L)) {
    if (all(abs(ac[m:(m + kn - 1L)]) < thr)) { mhat <- m - 1L; break }
  }
  if (is.na(mhat)) mhat <- mmax
  M <- min(2L * max(mhat, 1L), mmax)
  gam <- stats::acf(x, lag.max = M, type = "covariance", plot = FALSE, demean = FALSE)$acf[, 1, 1]
  k <- seq.int(-M, M)
  lam <- function(t) ifelse(abs(t) <= 0.5, 1, ifelse(abs(t) <= 1, 2 * (1 - abs(t)), 0))
  R <- gam[abs(k) + 1L]
  G <- sum(lam(k / M) * abs(k) * R)
  g0 <- sum(lam(k / M) * R)
  D <- (4 / 3) * g0^2
  b <- if (D > 0 && G != 0) (2 * G^2 / D)^(1 / 3) * n^(1 / 3) else 1
  list(b = max(1, b), mhat = mhat, M = M, n = n)
}

# Block length used for intervals on a paired loss differential d (time ordered).
# Primary: the PW estimate, floored at the 24-h diurnal cycle and capped so that
# at least `min_blocks` blocks fit in the sample. The h-step overlap length is
# reported alongside as a sensitivity value, not imposed (see REPORT.md).
mv_choose_block <- function(d, h, min_block = 24L, min_blocks = 5L) {
  pw <- mv_pw_block_length(d)
  n <- length(d)
  cap <- max(min_block, floor(n / min_blocks))
  b <- as.integer(min(max(ceiling(pw$b), min_block), cap))
  list(block = b, pw = pw$b, pw_mhat = pw$mhat, cap = cap, capped = ceiling(pw$b) > cap,
       n = n, n_blocks = n / b)
}

# Diebold-Mariano with a Newey-West (Bartlett) long-run variance at bandwidth bw
# and the Harvey-Leybourne-Newbold small-sample correction.
mv_dm_test <- function(d, bw) {
  d <- as.numeric(d); n <- length(d); bw <- min(as.integer(bw), n - 1L)
  dc <- d - mean(d)
  g <- stats::acf(dc, lag.max = bw, type = "covariance", plot = FALSE, demean = FALSE)$acf[, 1, 1]
  w <- 1 - seq_len(bw) / (bw + 1)
  lrv <- g[1] + 2 * sum(w * g[-1])
  if (!is.finite(lrv) || lrv <= 0) return(c(dm = NA_real_, p = NA_real_))
  dm <- mean(d) / sqrt(lrv / n)
  hln <- sqrt((n + 1 - 2 * bw + bw * (bw - 1) / n) / n)
  if (!is.finite(hln) || hln <= 0) hln <- 1
  st <- dm * hln
  c(dm = st, p = 2 * stats::pt(-abs(st), df = n - 1))
}

# Paired comparison a vs b on identical samples (time ordered by origin).
# Loss = absolute error. Returns ratio/difference with block-bootstrap CIs at the
# chosen block length, DM test, and the ratio CI at sensitivity block lengths.
mv_paired_compare <- function(y, yhat_a, yhat_b, h, reps = 999L, seed = 7L, level = 0.95,
                              sensitivity = c(24L, 168L, 336L, 744L), min_block = 24L,
                              min_blocks = 5L) {
  d <- abs(yhat_a - y) - abs(yhat_b - y)
  bc <- mv_choose_block(d, h, min_block, min_blocks)
  pc <- mv_bootstrap_paired(y, yhat_a, yhat_b, bc$block, reps, seed, level)
  dm <- mv_dm_test(d, bc$block)
  out <- cbind(pc, data.frame(block_h = bc$block, pw_block_h = round(bc$pw, 1),
                              block_capped = bc$capped, n_blocks = round(bc$n_blocks, 1),
                              dm_stat = dm[["dm"]], dm_p = dm[["p"]]))
  for (s in sensitivity) {
    sb <- min(s, floor(length(y) / 2))
    ps <- mv_bootstrap_paired(y, yhat_a, yhat_b, sb, reps, seed, level)
    out[[paste0("ratio_lo_b", s)]] <- ps$mae_ratio_lo
    out[[paste0("ratio_hi_b", s)]] <- ps$mae_ratio_hi
  }
  out
}

# ---- shared (pooled) multi-target dataset -----------------------------------------------
# One row per (origin, target pollutant). Inputs: the 144 B1 lags standardized
# per pollutant, the target pollutant's own 24 standardized lags in a fixed
# "own" slot, and the target id (categorical). y is standardized per target.
# All scaling statistics come from the training block's hours only.
mv_pooled_stats <- function(cfg, panel) {
  bl <- mv_blocks(cfg, panel$times)
  i <- bl$start_idx[1]:bl$end_idx[1]
  list(mu = colMeans(panel$X[i, , drop = FALSE]),
       sd = apply(panel$X[i, , drop = FALSE], 2, stats::sd))
}

# include_all = FALSE gives the shared univariate analogue (target id + own lags).
mv_pooled_dataset <- function(cfg, panel, h, targets, stats = mv_pooled_stats(cfg, panel),
                              own_slot = TRUE, include_all = TRUE) {
  if (!own_slot && !include_all) stop("pooled dataset needs own lags or all lags")
  L <- as.integer(cfg$lookback_h)
  blocks <- list()
  base <- mv_dataset(cfg, panel, "B1", h)
  pol_of <- sub("__lag[0-9]+$", "", base$feature_names)
  for (b in c("train", "validation", "test")) {
    bk <- base$blocks[[b]]
    Xs <- sweep(sweep(bk$X, 2, stats$mu[pol_of], "-"), 2, stats$sd[pol_of], "/")
    parts <- lapply(seq_along(targets), function(j) {
      tg <- targets[j]
      own <- if (own_slot) {
        o <- Xs[, paste0(tg, "__lag", sprintf("%02d", 0:(L - 1L))), drop = FALSE]
        colnames(o) <- paste0("own__lag", sprintf("%02d", 0:(L - 1L)))
        o
      } else NULL
      X <- cbind(target_id = j - 1L, own, if (include_all) Xs else NULL)
      yraw <- mv_build_y(panel, bk$target_idx, tg)
      list(X = X, y = (yraw - stats$mu[[tg]]) / stats$sd[[tg]], y_raw = yraw,
           target = rep(tg, length(yraw)), origin_idx = bk$origin_idx,
           target_idx = bk$target_idx)
    })
    blocks[[b]] <- list(
      X = do.call(rbind, lapply(parts, `[[`, "X")),
      y = unlist(lapply(parts, `[[`, "y")), y_raw = unlist(lapply(parts, `[[`, "y_raw")),
      target = unlist(lapply(parts, `[[`, "target")),
      origin_idx = unlist(lapply(parts, `[[`, "origin_idx")),
      target_idx = unlist(lapply(parts, `[[`, "target_idx")))
    blocks[[b]]$origin_ts <- panel$times[blocks[[b]]$origin_idx]
    blocks[[b]]$target_ts <- panel$times[blocks[[b]]$target_idx]
  }
  list(design = if (!include_all) "pooled_B0" else if (own_slot) "pooled_B1_own" else "pooled_B1",
       h = as.integer(h), pooled_targets = targets,   # not "targets": ds$target must stay NULL (partial matching)
       feature_names = colnames(blocks$train$X), blocks = blocks, stats = stats,
       quality_mask = cfg$quality_mask)
}

# Back to the original scale for a pooled block.
mv_pooled_unscale <- function(pds, block, yhat_std) {
  tg <- pds$blocks[[block]]$target
  yhat_std * pds$stats$sd[tg] + pds$stats$mu[tg]
}
