# Cross-frequency EDA for stored Haar MODWT/MRA components (CPCB PM2.5).
# Discovery uses TRAIN only. Validation is confirmation. TEST is never used
# for selection, tuning, or deciding whether intercomponent forecasting is worthwhile.
# No intercomponent forecasting models are trained here.

EDA_COMPONENTS <- c("D1", "D2", "D3", "D4", "D5", "S5")
EDA_METHOD_ID <- "mra_haar_J5"
EDA_SCALE <- "raw"
EDA_DECOMP_ID <- "mra_haar_J5__raw"
EDA_SENSOR <- "CPCB"
EDA_POLLUTANT <- "PM2.5"
EDA_MAX_LAG <- 24L
EDA_OWN_P <- 24L
EDA_ROLL_WINDOW <- 336L
EDA_ROLL_STEP <- 24L
EDA_N_BINS_MI <- 10L
EDA_BLOCK_LEN <- 24L
EDA_N_BOOT <- 200L
EDA_SEED <- 7L
EDA_SPLIT_H <- 24L  # nested last-h test; uses largest train window among paper horizons

eda_out_dir <- function() file.path(RES_DIR, "intercomponent_eda")
eda_plot_dir <- function() file.path(eda_out_dir(), "plots")
eda_data_dir <- function() file.path(eda_out_dir(), "tables")

eda_dir_create <- function() {
  dir.create(eda_out_dir(), recursive = TRUE, showWarnings = FALSE)
  dir.create(eda_plot_dir(), recursive = TRUE, showWarnings = FALSE)
  dir.create(eda_data_dir(), recursive = TRUE, showWarnings = FALSE)
  eda_out_dir()
}

eda_assert <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  allowed <- normalizePath(eda_out_dir(), winslash = "/", mustWork = FALSE)
  if (!startsWith(tolower(path), tolower(allowed))) {
    stop("EDA may only write under results/intercomponent_eda/. Refused: ", path)
  }
  invisible(path)
}

eda_write_csv <- function(df, name) {
  path <- file.path(eda_data_dir(), name)
  eda_assert(path)
  readr::write_csv(df, path)
  path
}

eda_ggsave <- function(filename, plot, width = 9, height = 5) {
  path <- file.path(eda_plot_dir(), filename)
  eda_assert(path)
  ggplot2::ggsave(path, plot, width = width, height = height, dpi = 140)
  path
}

# ---- load / align / split (reuse T1; never recompute MODWT) ----------------

eda_load_aligned <- function(sensor = EDA_SENSOR, pollutant = EDA_POLLUTANT) {
  series_all <- t1_load_prepared_series()
  skey <- paste(sensor, pollutant, sep = "_")
  if (!skey %in% names(series_all)) stop("Missing prepared series: ", skey)
  series_obj <- series_all[[skey]]
  decomp <- t1_load_stored_components(sensor, pollutant, EDA_METHOD_ID, EDA_SCALE)
  aligned <- t1_align_components(series_obj, decomp)
  list(series = series_obj, decomp = decomp, aligned = aligned, skey = skey)
}

eda_split_masks <- function(aligned, h = EDA_SPLIT_H) {
  sp <- chrono_split_tvt(aligned$y, aligned$timestamp, as.integer(h), VAL_HOURS)
  n <- nrow(aligned)
  stage <- rep(NA_character_, n)
  stage[seq_len(sp$n_train)] <- "train"
  stage[(sp$n_train + 1L):(sp$n_train + sp$n_val)] <- "validation"
  stage[(sp$n_train + sp$n_val + 1L):n] <- "test"
  list(sp = sp, stage = stage)
}

eda_complete_rows <- function(aligned, components = EDA_COMPONENTS) {
  stats::complete.cases(aligned[, components, drop = FALSE])
}

# ---- helpers: correlation / MI / bootstrap --------------------------------

eda_pearson <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 30L) return(NA_real_)
  suppressWarnings(stats::cor(x[ok], y[ok], method = "pearson"))
}

eda_spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 30L) return(NA_real_)
  suppressWarnings(stats::cor(x[ok], y[ok], method = "spearman"))
}

eda_discretize <- function(x, n_bins = EDA_N_BINS_MI) {
  x <- as.numeric(x)
  ok <- is.finite(x)
  out <- rep(NA_integer_, length(x))
  if (sum(ok) < n_bins * 3L) return(out)
  br <- unique(stats::quantile(x[ok], probs = seq(0, 1, length.out = n_bins + 1L),
                               na.rm = TRUE, names = FALSE, type = 7))
  if (length(br) < 3L) return(out)
  out[ok] <- as.integer(cut(x[ok], breaks = br, include.lowest = TRUE, labels = FALSE))
  out
}

eda_mi_discrete <- function(a, b) {
  ok <- !is.na(a) & !is.na(b)
  if (sum(ok) < 50L) return(NA_real_)
  a <- a[ok]; b <- b[ok]
  tab <- table(a, b)
  pxy <- tab / sum(tab)
  px <- rowSums(pxy)
  py <- colSums(pxy)
  mi <- 0
  for (i in seq_len(nrow(pxy))) for (j in seq_len(ncol(pxy))) {
    if (pxy[i, j] <= 0) next
    mi <- mi + pxy[i, j] * log(pxy[i, j] / (px[i] * py[j]))
  }
  as.numeric(mi)
}

eda_mi <- function(x, y, n_bins = EDA_N_BINS_MI) {
  eda_mi_discrete(eda_discretize(x, n_bins), eda_discretize(y, n_bins))
}

eda_block_starts <- function(n, block, n_boot, seed) {
  set.seed(seed)
  n_blocks <- ceiling(n / block)
  max_start <- max(1L, n - block + 1L)
  lapply(seq_len(n_boot), function(b) {
    starts <- sample.int(max_start, n_blocks, replace = TRUE)
    idx <- unlist(lapply(starts, function(s) s:(s + block - 1L)))
    idx[idx <= n][seq_len(n)]
  })
}

eda_boot_cor_ci <- function(x, y, method = "pearson", block = EDA_BLOCK_LEN,
                            n_boot = EDA_N_BOOT, seed = EDA_SEED) {
  ok <- which(is.finite(x) & is.finite(y))
  if (length(ok) < 100L) {
    return(list(est = NA_real_, lo = NA_real_, hi = NA_real_, n = length(ok)))
  }
  x <- x[ok]; y <- y[ok]
  n <- length(x)
  est <- if (identical(method, "spearman")) eda_spearman(x, y) else eda_pearson(x, y)
  boots <- eda_block_starts(n, block, n_boot, seed)
  vals <- vapply(boots, function(idx) {
    if (identical(method, "spearman")) eda_spearman(x[idx], y[idx])
    else eda_pearson(x[idx], y[idx])
  }, numeric(1))
  vals <- vals[is.finite(vals)]
  qs <- if (length(vals) >= 20L) stats::quantile(vals, c(0.025, 0.975), names = FALSE)
  else c(NA_real_, NA_real_)
  list(est = est, lo = qs[1], hi = qs[2], n = n)
}

eda_bh <- function(p) {
  p <- as.numeric(p)
  out <- rep(NA_real_, length(p))
  ok <- which(is.finite(p))
  if (!length(ok)) return(out)
  out[ok] <- p.adjust(p[ok], method = "BH")
  out
}

# Approximate AR(1)-aware effective sample size for a pairwise correlation.
eda_neff <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]; y <- y[ok]
  n <- length(x)
  if (n < 40L) return(as.numeric(n))
  rx <- suppressWarnings(stats::acf(x, lag.max = 1, plot = FALSE)$acf[2])
  ry <- suppressWarnings(stats::acf(y, lag.max = 1, plot = FALSE)$acf[2])
  rx <- ifelse(is.finite(rx), rx, 0)
  ry <- ifelse(is.finite(ry), ry, 0)
  fac <- (1 + rx * ry) / (1 - rx * ry)
  as.numeric(max(10, n / max(1, fac)))
}

eda_cor_pvalue <- function(r, n_eff) {
  if (!is.finite(r) || !is.finite(n_eff) || n_eff <= 3) return(NA_real_)
  tstat <- r * sqrt((n_eff - 2) / max(1e-12, 1 - r^2))
  2 * stats::pt(-abs(tstat), df = n_eff - 2)
}

# ---- Analysis A: component characteristics --------------------------------

eda_component_stats <- function(aligned, stage) {
  rows <- list()
  for (st in c("all_complete", "train", "validation", "test")) {
    if (identical(st, "all_complete")) {
      mask <- eda_complete_rows(aligned)
    } else {
      mask <- eda_complete_rows(aligned) & stage == st
    }
    for (nm in EDA_COMPONENTS) {
      x <- as.numeric(aligned[[nm]])
      x_m <- x[mask]
      x_all <- x[if (identical(st, "all_complete")) TRUE else stage == st]
      ac <- tryCatch({
        a <- stats::acf(x_m[is.finite(x_m)], lag.max = EDA_MAX_LAG, plot = FALSE)
        as.numeric(a$acf)[-1]
      }, error = function(e) rep(NA_real_, EDA_MAX_LAG))
      rows[[length(rows) + 1L]] <- tibble::tibble(
        component = nm,
        stage = st,
        n_total = length(x_all),
        n_missing = sum(!is.finite(x_all)),
        n_valid = sum(is.finite(x_m)),
        mean = mean(x_m, na.rm = TRUE),
        sd = stats::sd(x_m, na.rm = TRUE),
        variance = stats::var(x_m, na.rm = TRUE),
        min = min(x_m, na.rm = TRUE),
        max = max(x_m, na.rm = TRUE),
        acf_lag1 = ac[1],
        acf_lag24 = ac[min(24L, length(ac))],
        sum_abs_acf_1_24 = sum(abs(ac[seq_len(min(24L, length(ac)))]), na.rm = TRUE)
      )
    }
  }
  dplyr::bind_rows(rows)
}

eda_acf_table <- function(aligned, stage, use_stage = "train") {
  mask <- eda_complete_rows(aligned) & stage == use_stage
  out <- list()
  for (nm in EDA_COMPONENTS) {
    x <- as.numeric(aligned[[nm]])[mask]
    x <- x[is.finite(x)]
    a <- stats::acf(x, lag.max = EDA_MAX_LAG, plot = FALSE)
    out[[nm]] <- tibble::tibble(
      component = nm, stage = use_stage,
      lag = as.integer(a$lag[-1]),
      acf = as.numeric(a$acf)[-1]
    )
  }
  dplyr::bind_rows(out)
}

# ---- Analysis B: contemporaneous matrices ---------------------------------

eda_pair_matrix <- function(aligned, stage, use_stage = "train", fun) {
  mask <- eda_complete_rows(aligned) & stage == use_stage
  M <- matrix(NA_real_, 6, 6, dimnames = list(EDA_COMPONENTS, EDA_COMPONENTS))
  for (i in seq_along(EDA_COMPONENTS)) {
    for (j in seq_along(EDA_COMPONENTS)) {
      xi <- as.numeric(aligned[[EDA_COMPONENTS[i]]])[mask]
      xj <- as.numeric(aligned[[EDA_COMPONENTS[j]]])[mask]
      M[i, j] <- fun(xi, xj)
    }
  }
  M
}

eda_matrix_to_long <- function(M, metric, stage) {
  tidyr::expand_grid(component_i = rownames(M), component_j = colnames(M)) %>%
    dplyr::mutate(
      value = as.numeric(M[cbind(match(.data$component_i, rownames(M)),
                                 match(.data$component_j, colnames(M)))]),
      metric = metric,
      stage = stage
    )
}

eda_pair_tests <- function(aligned, stage, use_stage = "train") {
  mask <- eda_complete_rows(aligned) & stage == use_stage
  rows <- list()
  pairs <- utils::combn(EDA_COMPONENTS, 2, simplify = FALSE)
  for (pr in pairs) {
    xi <- as.numeric(aligned[[pr[1]]])[mask]
    xj <- as.numeric(aligned[[pr[2]]])[mask]
    pe <- eda_boot_cor_ci(xi, xj, "pearson", seed = EDA_SEED + which(EDA_COMPONENTS == pr[1]))
    sp <- eda_boot_cor_ci(xi, xj, "spearman", seed = EDA_SEED + 100L + which(EDA_COMPONENTS == pr[1]))
    mi <- eda_mi(xi, xj)
    ne <- eda_neff(xi, xj)
    rows[[length(rows) + 1L]] <- tibble::tibble(
      stage = use_stage,
      component_i = pr[1], component_j = pr[2],
      pearson = pe$est, pearson_lo = pe$lo, pearson_hi = pe$hi,
      spearman = sp$est, spearman_lo = sp$lo, spearman_hi = sp$hi,
      mutual_information = mi,
      n = pe$n, n_eff_approx = ne,
      pearson_p = eda_cor_pvalue(pe$est, ne),
      spearman_p = eda_cor_pvalue(sp$est, ne)
    )
  }
  out <- dplyr::bind_rows(rows)
  out$pearson_p_bh <- eda_bh(out$pearson_p)
  out$spearman_p_bh <- eda_bh(out$spearman_p)
  out
}

# ---- Analysis C: lagged cross-correlation ---------------------------------
# Convention: Corr(target(t), predictor(t - k)), k = 0..24.
# Positive k => predictor is in the past of the target (usable as a forecast feature).
# k = 0 => contemporaneous. Negative lags are NOT used as predictors.

eda_ccf_pair <- function(target, predictor, max_lag = EDA_MAX_LAG) {
  ok <- is.finite(target) & is.finite(predictor)
  target <- target[ok]; predictor <- predictor[ok]
  n <- length(target)
  if (n < max_lag + 50L) {
    return(tibble::tibble(lag = 0:max_lag, correlation = NA_real_, n_pairs = 0L))
  }
  rows <- lapply(0:max_lag, function(k) {
    if (k == 0L) {
      r <- eda_pearson(target, predictor)
      np <- sum(is.finite(target) & is.finite(predictor))
    } else {
      yt <- target[(k + 1L):n]
      xp <- predictor[1:(n - k)]
      r <- eda_pearson(yt, xp)
      np <- sum(is.finite(yt) & is.finite(xp))
    }
    tibble::tibble(lag = as.integer(k), correlation = r, n_pairs = as.integer(np))
  })
  dplyr::bind_rows(rows)
}

eda_lagged_all <- function(aligned, stage, use_stage = "train") {
  mask <- eda_complete_rows(aligned) & stage == use_stage
  out <- list()
  for (ti in EDA_COMPONENTS) {
    for (pj in EDA_COMPONENTS) {
      if (identical(ti, pj)) next
      tab <- eda_ccf_pair(as.numeric(aligned[[ti]])[mask],
                          as.numeric(aligned[[pj]])[mask])
      tab$target <- ti
      tab$predictor <- pj
      tab$stage <- use_stage
      out[[length(out) + 1L]] <- tab
    }
  }
  dplyr::bind_rows(out)
}

eda_lagged_summary <- function(lagged) {
  lagged %>%
    dplyr::filter(.data$lag >= 1L) %>%  # usable past predictors only for "promising"
    dplyr::group_by(.data$stage, .data$target, .data$predictor) %>%
    dplyr::summarise(
      corr_lag0 = {
        # pull lag0 from full table via parent? store separately below
        NA_real_
      },
      max_abs_corr = max(abs(.data$correlation), na.rm = TRUE),
      best_lag = .data$lag[which.max(abs(.data$correlation))],
      best_corr = .data$correlation[which.max(abs(.data$correlation))],
      n_lags_abs_ge_0_10 = sum(abs(.data$correlation) >= 0.10, na.rm = TRUE),
      n_lags_abs_ge_0_20 = sum(abs(.data$correlation) >= 0.20, na.rm = TRUE),
      mean_abs_corr = mean(abs(.data$correlation), na.rm = TRUE),
      .groups = "drop"
    )
}

eda_lagged_summary_full <- function(lagged) {
  lag0 <- lagged %>%
    dplyr::filter(.data$lag == 0L) %>%
    dplyr::select(stage, target, predictor, corr_lag0 = correlation)
  summ <- lagged %>%
    dplyr::filter(.data$lag >= 1L) %>%
    dplyr::group_by(.data$stage, .data$target, .data$predictor) %>%
    dplyr::summarise(
      max_abs_corr = max(abs(.data$correlation), na.rm = TRUE),
      best_lag = .data$lag[which.max(abs(.data$correlation))][1],
      best_corr = .data$correlation[which.max(abs(.data$correlation))][1],
      n_lags_abs_ge_0_10 = sum(abs(.data$correlation) >= 0.10, na.rm = TRUE),
      n_lags_abs_ge_0_20 = sum(abs(.data$correlation) >= 0.20, na.rm = TRUE),
      mean_abs_corr_1_24 = mean(abs(.data$correlation), na.rm = TRUE),
      .groups = "drop"
    )
  dplyr::left_join(summ, lag0, by = c("stage", "target", "predictor"))
}

# ---- Analysis D: incremental / residual dependence ------------------------

eda_fit_ar_residuals <- function(y, p = EDA_OWN_P) {
  y <- as.numeric(y)
  n <- length(y)
  if (n <= p + 10L) return(list(resid = rep(NA_real_, n), r2 = NA_real_, n = 0L))
  X <- make_lags(y, p)
  ok <- stats::complete.cases(X) & is.finite(y)
  if (sum(ok) < p + 20L) return(list(resid = rep(NA_real_, n), r2 = NA_real_, n = 0L))
  fit <- stats::lm(y[ok] ~ X[ok, , drop = FALSE])
  resid <- rep(NA_real_, n)
  resid[ok] <- stats::residuals(fit)
  list(resid = resid, r2 = summary(fit)$r.squared, n = sum(ok), coef = coef(fit))
}

eda_residual_analysis <- function(aligned, stage, use_stage = "train") {
  mask_idx <- which(eda_complete_rows(aligned) & stage == use_stage)
  # Fit AR on contiguous train component series; residuals only defined where lags exist.
  out_rows <- list()
  ar_meta <- list()
  resid_mat <- matrix(NA_real_, nrow(aligned), length(EDA_COMPONENTS),
                      dimnames = list(NULL, EDA_COMPONENTS))
  for (ti in EDA_COMPONENTS) {
    y_full <- as.numeric(aligned[[ti]])
    # Use train-complete subsequence only for fitting AR; keep positions.
    y_fit <- y_full
    y_fit[stage != use_stage | !eda_complete_rows(aligned)] <- NA_real_
    # Fit using finite train points with lag matrix (NAs handled by complete.cases).
    ar <- eda_fit_ar_residuals(y_fit, EDA_OWN_P)
    resid_mat[, ti] <- ar$resid
    ar_meta[[ti]] <- tibble::tibble(
      target = ti, stage = use_stage, ar_p = EDA_OWN_P,
      ar_r2 = ar$r2, ar_n = ar$n
    )
  }
  for (ti in EDA_COMPONENTS) {
    eps <- resid_mat[, ti]
    for (pj in EDA_COMPONENTS) {
      if (identical(ti, pj)) next
      xj <- as.numeric(aligned[[pj]])
      for (k in 1:EDA_MAX_LAG) {
        # Corr(eps(t), C_j(t-k)); both must be in discovery stage and finite.
        n <- length(eps)
        yt <- eps[(k + 1L):n]
        xp <- xj[1:(n - k)]
        st <- stage[(k + 1L):n]
        ok <- is.finite(yt) & is.finite(xp) & st == use_stage
        if (sum(ok) < 50L) {
          r <- NA_real_; ne <- NA_real_; pv <- NA_real_
          n_ok <- sum(ok)
        } else {
          r <- eda_pearson(yt[ok], xp[ok])
          ne <- eda_neff(yt[ok], xp[ok])
          pv <- eda_cor_pvalue(r, ne)
          n_ok <- sum(ok)
        }
        out_rows[[length(out_rows) + 1L]] <- tibble::tibble(
          stage = use_stage,
          target = ti, predictor = pj, lag = as.integer(k),
          residual_corr = r, n = as.integer(n_ok), n_eff_approx = ne,
          p_value = pv
        )
      }
    }
  }
  res <- dplyr::bind_rows(out_rows)
  res$p_bh <- eda_bh(res$p_value)
  list(residuals = res, ar_meta = dplyr::bind_rows(ar_meta), resid_mat = resid_mat)
}

eda_partial_corr_ownlags <- function(aligned, stage, use_stage = "train") {
  # Partial correlation between target(t) and predictor(t-k) controlling for
  # target(t-1..t-p) via residualizing both sides on own lags (same AR design).
  mask_stage <- stage == use_stage & eda_complete_rows(aligned)
  rows <- list()
  for (ti in EDA_COMPONENTS) {
    y <- as.numeric(aligned[[ti]])
    y[!mask_stage] <- NA_real_
    ar_y <- eda_fit_ar_residuals(y, EDA_OWN_P)
    for (pj in EDA_COMPONENTS) {
      if (identical(ti, pj)) next
      x <- as.numeric(aligned[[pj]])
      for (k in c(1L, 2L, 3L, 6L, 12L, 24L)) {
        n <- length(y)
        eps <- ar_y$resid[(k + 1L):n]
        # Residualize predictor lag against target's own lags at time t.
        Xown <- make_lags(y, EDA_OWN_P)
        xlag <- c(rep(NA_real_, k), x[1:(n - k)])
        ok <- is.finite(eps) & is.finite(xlag[(k + 1L):n]) &
          rowSums(!is.finite(Xown[(k + 1L):n, , drop = FALSE])) == 0 &
          stage[(k + 1L):n] == use_stage
        if (sum(ok) < 80L) {
          rows[[length(rows) + 1L]] <- tibble::tibble(
            stage = use_stage, target = ti, predictor = pj, lag = k,
            partial_corr = NA_real_, n = sum(ok)
          )
          next
        }
        idx <- which(ok)
        t_idx <- (k + 1L):n
        t_idx <- t_idx[idx]
        xp <- xlag[t_idx]
        Xc <- Xown[t_idx, , drop = FALSE]
        fitx <- stats::lm(xp ~ Xc)
        rx <- stats::residuals(fitx)
        ry <- eps[idx]
        r <- eda_pearson(ry, rx)
        rows[[length(rows) + 1L]] <- tibble::tibble(
          stage = use_stage, target = ti, predictor = pj, lag = as.integer(k),
          partial_corr = r, n = length(idx)
        )
      }
    }
  }
  dplyr::bind_rows(rows)
}

# ---- Analysis E: temporal stability ---------------------------------------

eda_rolling_corr <- function(aligned, stage, pairs, window = EDA_ROLL_WINDOW,
                             step = EDA_ROLL_STEP, lag = 1L,
                             resid_mat = NULL) {
  # pairs: list of c(target, predictor)
  # If resid_mat is supplied, roll Corr(ε_target(t), predictor(t-lag)) so
  # stability matches the incremental-dependence diagnostic.
  train_idx <- which(stage == "train" & eda_complete_rows(aligned))
  if (length(train_idx) < window + 10L) return(tibble::tibble())
  starts <- seq(min(train_idx), max(train_idx) - window + 1L, by = step)
  out <- list()
  for (pr in pairs) {
    ti <- pr[1]; pj <- pr[2]
    y <- if (!is.null(resid_mat)) as.numeric(resid_mat[, ti]) else as.numeric(aligned[[ti]])
    x <- as.numeric(aligned[[pj]])
    for (s in starts) {
      idx <- s:(s + window - 1L)
      yt <- y[idx]
      if (lag == 0L) {
        xp <- x[idx]
      } else {
        xp <- x[idx - lag]
      }
      ok <- is.finite(yt) & is.finite(xp) & stage[idx] == "train"
      r <- if (sum(ok) >= 80L) eda_pearson(yt[ok], xp[ok]) else NA_real_
      out[[length(out) + 1L]] <- tibble::tibble(
        target = ti, predictor = pj, lag = as.integer(lag),
        window_start = aligned$timestamp[s],
        window_end = aligned$timestamp[s + window - 1L],
        n = sum(ok), correlation = r,
        series = if (!is.null(resid_mat)) "residual" else "raw"
      )
    }
  }
  dplyr::bind_rows(out)
}

eda_stage_confirm <- function(aligned, stage, top_pairs) {
  # Recompute best-lag residual corr on validation for shortlisted pairs.
  rows <- list()
  for (i in seq_len(nrow(top_pairs))) {
    ti <- top_pairs$target[i]
    pj <- top_pairs$predictor[i]
    k <- as.integer(top_pairs$best_lag[i])
    for (st in c("train", "validation")) {
      y <- as.numeric(aligned[[ti]])
      y[stage != st | !eda_complete_rows(aligned)] <- NA_real_
      ar <- eda_fit_ar_residuals(y, EDA_OWN_P)
      x <- as.numeric(aligned[[pj]])
      n <- length(y)
      yt <- ar$resid[(k + 1L):n]
      xp <- x[1:(n - k)]
      ok <- is.finite(yt) & is.finite(xp) & stage[(k + 1L):n] == st
      r <- if (sum(ok) >= 40L) eda_pearson(yt[ok], xp[ok]) else NA_real_
      rows[[length(rows) + 1L]] <- tibble::tibble(
        target = ti, predictor = pj, lag = k, stage = st,
        residual_corr = r, n = sum(ok),
        train_residual_corr = top_pairs$best_resid_corr[i]
      )
    }
  }
  dplyr::bind_rows(rows)
}

# ---- plots ----------------------------------------------------------------

eda_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      legend.position = "right"
    )
}

eda_plot_components_ts <- function(aligned, stage) {
  # Last 14 days of train for readability
  train_idx <- which(stage == "train" & eda_complete_rows(aligned))
  take <- tail(train_idx, 336L)
  df <- aligned[take, c("timestamp", EDA_COMPONENTS)]
  long <- tidyr::pivot_longer(df, -timestamp, names_to = "component", values_to = "value")
  long$component <- factor(long$component, levels = EDA_COMPONENTS)
  ggplot2::ggplot(long, ggplot2::aes(timestamp, value, colour = component)) +
    ggplot2::geom_line(linewidth = 0.35) +
    ggplot2::facet_wrap(~component, scales = "free_y", ncol = 1) +
    ggplot2::guides(colour = "none") +
    ggplot2::labs(
      title = "Stored Haar MRA components (last 14 train days)",
      subtitle = paste(EDA_SENSOR, EDA_POLLUTANT, EDA_DECOMP_ID),
      x = NULL, y = "Component value (native scale)"
    ) + eda_theme()
}

eda_plot_distributions <- function(aligned, stage) {
  mask <- stage == "train" & eda_complete_rows(aligned)
  df <- aligned[mask, EDA_COMPONENTS]
  long <- tidyr::pivot_longer(df, everything(), names_to = "component", values_to = "value")
  long$component <- factor(long$component, levels = EDA_COMPONENTS)
  ggplot2::ggplot(long, ggplot2::aes(value, fill = component)) +
    ggplot2::geom_histogram(bins = 40, colour = NA) +
    ggplot2::facet_wrap(~component, scales = "free", ncol = 3) +
    ggplot2::guides(fill = "none") +
    ggplot2::labs(title = "Component distributions (train, complete rows)",
                  x = "Value", y = "Count") + eda_theme()
}

eda_plot_acf <- function(acf_tbl) {
  acf_tbl$component <- factor(acf_tbl$component, levels = EDA_COMPONENTS)
  ggplot2::ggplot(acf_tbl, ggplot2::aes(lag, acf)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) +
    ggplot2::geom_col(width = 0.7, fill = "#2C7FB8") +
    ggplot2::facet_wrap(~component, ncol = 3) +
    ggplot2::labs(title = "ACF of each component (train)", x = "Lag (hours)", y = "ACF") +
    eda_theme()
}

eda_plot_heatmap <- function(M, title, mid = 0, lim = NULL) {
  df <- eda_matrix_to_long(M, "v", "train")
  df$component_i <- factor(df$component_i, levels = rev(EDA_COMPONENTS))
  df$component_j <- factor(df$component_j, levels = EDA_COMPONENTS)
  if (is.null(lim)) lim <- max(abs(df$value), na.rm = TRUE)
  ggplot2::ggplot(df, ggplot2::aes(component_j, component_i, fill = value)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", value)), size = 2.8) +
    ggplot2::scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC",
                                  midpoint = mid, limits = c(-lim, lim)) +
    ggplot2::labs(title = title, x = NULL, y = NULL, fill = NULL) +
    eda_theme() + ggplot2::coord_fixed()
}

eda_plot_heatmap_mi <- function(M, title) {
  df <- eda_matrix_to_long(M, "v", "train")
  df$component_i <- factor(df$component_i, levels = rev(EDA_COMPONENTS))
  df$component_j <- factor(df$component_j, levels = EDA_COMPONENTS)
  ggplot2::ggplot(df, ggplot2::aes(component_j, component_i, fill = value)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", value)), size = 2.8) +
    ggplot2::scale_fill_viridis_c(option = "C") +
    ggplot2::labs(title = title, x = NULL, y = NULL, fill = "MI") +
    eda_theme() + ggplot2::coord_fixed()
}

eda_plot_ccf_facets <- function(lagged) {
  lagged$pair <- paste(lagged$predictor, "→", lagged$target)
  ggplot2::ggplot(lagged, ggplot2::aes(lag, correlation)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) +
    ggplot2::geom_line(colour = "#1B4F72", linewidth = 0.4) +
    ggplot2::facet_grid(target ~ predictor) +
    ggplot2::labs(
      title = "Lagged cross-correlation: Corr(target(t), predictor(t−k))",
      subtitle = "k>0 = predictor in the past (forecast-usable). Diagonal omitted.",
      x = "Lag k (hours)", y = "Pearson correlation"
    ) + eda_theme()
}

eda_plot_maxabs_heatmap <- function(summ) {
  df <- summ
  df$target <- factor(df$target, levels = rev(EDA_COMPONENTS))
  df$predictor <- factor(df$predictor, levels = EDA_COMPONENTS)
  ggplot2::ggplot(df, ggplot2::aes(predictor, target, fill = max_abs_corr)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f@%d", best_corr, best_lag)),
                       size = 2.4) +
    ggplot2::scale_fill_viridis_c(option = "C", limits = c(0, NA)) +
    ggplot2::labs(
      title = "Max |lagged correlation| for k=1..24 (train)",
      subtitle = "Cell text: best correlation @ lag",
      x = "Predictor (past)", y = "Target", fill = "max|r|"
    ) + eda_theme() + ggplot2::coord_fixed()
}

eda_plot_resid_heatmap <- function(resid_summ) {
  df <- resid_summ
  df$target <- factor(df$target, levels = rev(EDA_COMPONENTS))
  df$predictor <- factor(df$predictor, levels = EDA_COMPONENTS)
  ggplot2::ggplot(df, ggplot2::aes(predictor, target, fill = max_abs_resid_corr)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f@%d", best_resid_corr, best_lag)),
                       size = 2.4) +
    ggplot2::scale_fill_viridis_c(option = "C", limits = c(0, NA)) +
    ggplot2::labs(
      title = "Max |residual correlation| after AR(24) own history (train)",
      subtitle = "Corr(ε_target(t), predictor(t−k)), k=1..24",
      x = "Predictor (past)", y = "Target", fill = "max|r|"
    ) + eda_theme() + ggplot2::coord_fixed()
}

eda_plot_rolling <- function(roll) {
  if (!nrow(roll)) return(NULL)
  roll$pair <- paste(roll$predictor, "→", roll$target, "(k=", roll$lag, ")", sep = "")
  ggplot2::ggplot(roll, ggplot2::aes(window_start, correlation, colour = pair)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.45, alpha = 0.9) +
    ggplot2::labs(
      title = "Rolling residual cross-correlation stability (train)",
      subtitle = paste0("Corr(ε_target(t), predictor(t−k)); window=",
                       EDA_ROLL_WINDOW, "h, step=", EDA_ROLL_STEP, "h"),
      x = "Window start", y = "Residual correlation", colour = NULL
    ) + eda_theme() +
    ggplot2::theme(legend.position = "bottom")
}

# ---- reconstruction check -------------------------------------------------

eda_recon_check <- function(aligned, stage) {
  mask <- eda_complete_rows(aligned) & stage == "train"
  recon <- rowSums(as.matrix(aligned[mask, EDA_COMPONENTS]))
  y <- as.numeric(aligned$y[mask])
  tibble::tibble(
    n = sum(mask),
    mae_recon = mean(abs(recon - y), na.rm = TRUE),
    max_abs_recon = max(abs(recon - y), na.rm = TRUE),
    cor_recon = eda_pearson(recon, y)
  )
}

# ---- main runner ----------------------------------------------------------

eda_run <- function(sensor = EDA_SENSOR, pollutant = EDA_POLLUTANT) {
  eda_dir_create()
  message("EDA: loading stored ", EDA_DECOMP_ID, " for ", sensor, " ", pollutant)
  loaded <- eda_load_aligned(sensor, pollutant)
  aligned <- loaded$aligned
  masks <- eda_split_masks(aligned, EDA_SPLIT_H)
  stage <- masks$stage
  sp <- masks$sp

  # Verify parquet fingerprint unchanged
  path <- t1_decomp_parquet_path(sensor, pollutant, EDA_METHOD_ID, EDA_SCALE)
  fp <- t1_file_fingerprint(path)

  recon <- eda_recon_check(aligned, stage)
  message("Recon train MAE=", signif(recon$mae_recon, 4),
          " max|err|=", signif(recon$max_abs_recon, 4))

  # A
  message("Analysis A: component stats")
  stats_tbl <- eda_component_stats(aligned, stage)
  acf_tbl <- eda_acf_table(aligned, stage, "train")
  eda_write_csv(stats_tbl, "component_stats.csv")
  eda_write_csv(acf_tbl, "component_acf.csv")
  eda_ggsave("components_timeseries.png", eda_plot_components_ts(aligned, stage), 10, 12)
  eda_ggsave("component_distributions.png", eda_plot_distributions(aligned, stage), 10, 6)
  eda_ggsave("component_acf.png", eda_plot_acf(acf_tbl), 10, 6)

  # B
  message("Analysis B: contemporaneous dependence")
  M_p <- eda_pair_matrix(aligned, stage, "train", eda_pearson)
  M_s <- eda_pair_matrix(aligned, stage, "train", eda_spearman)
  M_m <- eda_pair_matrix(aligned, stage, "train", eda_mi)
  pearson_long <- eda_matrix_to_long(M_p, "pearson", "train")
  spearman_long <- eda_matrix_to_long(M_s, "spearman", "train")
  mi_long <- eda_matrix_to_long(M_m, "mutual_information", "train")
  pair_tests <- eda_pair_tests(aligned, stage, "train")
  eda_write_csv(pearson_long, "pearson_matrix_long.csv")
  eda_write_csv(spearman_long, "spearman_matrix_long.csv")
  eda_write_csv(mi_long, "mutual_information_matrix_long.csv")
  eda_write_csv(pair_tests, "contemporaneous_pair_tests.csv")
  write.csv(M_p, file.path(eda_data_dir(), "pearson_matrix.csv"))
  write.csv(M_s, file.path(eda_data_dir(), "spearman_matrix.csv"))
  write.csv(M_m, file.path(eda_data_dir(), "mutual_information_matrix.csv"))
  eda_ggsave("heatmap_pearson.png", eda_plot_heatmap(M_p, "Pearson correlation (train)"), 7, 6)
  eda_ggsave("heatmap_spearman.png", eda_plot_heatmap(M_s, "Spearman correlation (train)"), 7, 6)
  eda_ggsave("heatmap_mutual_information.png",
             eda_plot_heatmap_mi(M_m, "Mutual information, 10-quantile bins (train)"), 7, 6)

  # C
  message("Analysis C: lagged cross-correlation")
  lagged <- eda_lagged_all(aligned, stage, "train")
  lagged_summ <- eda_lagged_summary_full(lagged)
  eda_write_csv(lagged, "lagged_cross_correlation.csv")
  eda_write_csv(lagged_summ, "lagged_cross_correlation_summary.csv")
  eda_ggsave("lagged_ccf_grid.png", eda_plot_ccf_facets(lagged), 12, 10)
  eda_ggsave("lagged_maxabs_heatmap.png", eda_plot_maxabs_heatmap(lagged_summ), 8, 7)

  # D
  message("Analysis D: residual / incremental dependence")
  resid <- eda_residual_analysis(aligned, stage, "train")
  resid_tbl <- resid$residuals
  ar_meta <- resid$ar_meta
  resid_summ <- resid_tbl %>%
    dplyr::group_by(.data$target, .data$predictor) %>%
    dplyr::summarise(
      max_abs_resid_corr = max(abs(.data$residual_corr), na.rm = TRUE),
      best_lag = .data$lag[which.max(abs(.data$residual_corr))][1],
      best_resid_corr = .data$residual_corr[which.max(abs(.data$residual_corr))][1],
      n_lags_abs_ge_0_05 = sum(abs(.data$residual_corr) >= 0.05, na.rm = TRUE),
      n_lags_abs_ge_0_10 = sum(abs(.data$residual_corr) >= 0.10, na.rm = TRUE),
      n_sig_bh_0_05 = sum(is.finite(.data$p_bh) & .data$p_bh < 0.05, na.rm = TRUE),
      .groups = "drop"
    )
  partial_tbl <- eda_partial_corr_ownlags(aligned, stage, "train")
  eda_write_csv(resid_tbl, "residual_correlations.csv")
  eda_write_csv(resid_summ, "residual_correlation_summary.csv")
  eda_write_csv(ar_meta, "ar24_baseline_fit.csv")
  eda_write_csv(partial_tbl, "partial_correlations.csv")
  eda_ggsave("residual_maxabs_heatmap.png", eda_plot_resid_heatmap(resid_summ), 8, 7)

  # Shortlist from residual analysis (train only)
  shortlist <- resid_summ %>%
    dplyr::filter(.data$max_abs_resid_corr >= 0.05) %>%
    dplyr::arrange(dplyr::desc(.data$max_abs_resid_corr))
  eda_write_csv(shortlist, "promising_pairs_shortlist_train.csv")

  # E
  message("Analysis E: temporal stability")
  top_n <- head(shortlist, 8L)
  if (!nrow(top_n)) {
    # fallback: strongest raw lagged pairs
    top_n <- lagged_summ %>%
      dplyr::arrange(dplyr::desc(.data$max_abs_corr)) %>%
      dplyr::slice(1:6) %>%
      dplyr::transmute(target, predictor, best_lag, best_resid_corr = best_corr,
                       max_abs_resid_corr = max_abs_corr)
  } else {
    top_n <- top_n %>%
      dplyr::transmute(target, predictor, best_lag, best_resid_corr, max_abs_resid_corr)
  }
  pairs <- lapply(seq_len(nrow(top_n)), function(i) c(top_n$target[i], top_n$predictor[i]))
  roll <- dplyr::bind_rows(lapply(seq_len(nrow(top_n)), function(i) {
    eda_rolling_corr(aligned, stage, list(c(top_n$target[i], top_n$predictor[i])),
                     lag = as.integer(top_n$best_lag[i]),
                     resid_mat = resid$resid_mat)
  }))
  roll_summ <- roll %>%
    dplyr::group_by(.data$target, .data$predictor, .data$lag) %>%
    dplyr::summarise(
      mean_corr = mean(.data$correlation, na.rm = TRUE),
      sd_corr = stats::sd(.data$correlation, na.rm = TRUE),
      min_corr = min(.data$correlation, na.rm = TRUE),
      max_corr = max(.data$correlation, na.rm = TRUE),
      frac_abs_ge_0_05 = mean(abs(.data$correlation) >= 0.05, na.rm = TRUE),
      frac_same_sign_as_mean = mean(sign(.data$correlation) == sign(mean(.data$correlation, na.rm = TRUE)),
                                    na.rm = TRUE),
      .groups = "drop"
    )
  confirm <- eda_stage_confirm(aligned, stage, top_n)
  # Validation contemporaneous confirmation for same pairs at lag0/best lag raw
  eda_write_csv(roll, "rolling_correlations.csv")
  eda_write_csv(roll_summ, "rolling_correlation_summary.csv")
  eda_write_csv(confirm, "validation_confirmation.csv")
  p_roll <- eda_plot_rolling(roll)
  if (!is.null(p_roll)) eda_ggsave("rolling_stability.png", p_roll, 11, 6)

  # Meta
  meta <- list(
    sensor = sensor, pollutant = pollutant,
    decomp_id = EDA_DECOMP_ID, method_id = EDA_METHOD_ID, scale = EDA_SCALE,
    parquet = fp, split_h = EDA_SPLIT_H,
    n_train = sp$n_train, n_val = sp$n_val, n_test = sp$n_test,
    n_complete = sum(eda_complete_rows(aligned)),
    n_complete_train = sum(eda_complete_rows(aligned) & stage == "train"),
    recon = recon,
    max_lag = EDA_MAX_LAG, own_p = EDA_OWN_P,
    roll_window = EDA_ROLL_WINDOW, roll_step = EDA_ROLL_STEP,
    mi_bins = EDA_N_BINS_MI, block_len = EDA_BLOCK_LEN, n_boot = EDA_N_BOOT,
    seed = EDA_SEED
  )
  saveRDS(meta, file.path(eda_out_dir(), "_meta.rds"))

  # Build recommendation object for report writer
  rec <- eda_build_recommendation(stats_tbl, pair_tests, lagged_summ, resid_summ,
                                  shortlist, roll_summ, confirm, ar_meta, meta)
  saveRDS(rec, file.path(eda_out_dir(), "_recommendation.rds"))
  eda_write_report(stats_tbl, pair_tests, M_p, M_s, M_m, lagged_summ, resid_summ,
                   shortlist, roll_summ, confirm, ar_meta, meta, rec)
  message("EDA finished. Outputs under ", eda_out_dir())
  invisible(list(meta = meta, recommendation = rec, shortlist = shortlist))
}

eda_build_recommendation <- function(stats_tbl, pair_tests, lagged_summ, resid_summ,
                                     shortlist, roll_summ, confirm, ar_meta, meta) {
  # Classification rules (documented in report):
  # Promising: several targets have residual |r|>=0.10 at some lag, BH-significant,
  #            and validation confirmation keeps the same sign with |r|>=0.05.
  # Partially: residual |r|>=0.05 for some pairs, or strong raw lag but weak residual.
  # Not: residual structure mostly <0.05 and/or unstable.
  strong_resid <- resid_summ %>% dplyr::filter(.data$max_abs_resid_corr >= 0.10)
  weak_resid <- resid_summ %>% dplyr::filter(.data$max_abs_resid_corr >= 0.05,
                                             .data$max_abs_resid_corr < 0.10)
  conf_ok <- confirm %>%
    dplyr::filter(.data$stage == "validation") %>%
    dplyr::mutate(ok = is.finite(.data$residual_corr) &
                    abs(.data$residual_corr) >= 0.05 &
                    sign(.data$residual_corr) == sign(.data$train_residual_corr))
  n_conf_ok <- sum(conf_ok$ok, na.rm = TRUE)
  n_strong <- nrow(strong_resid)
  n_weak <- nrow(weak_resid)

  verdict <- if (n_strong >= 3L && n_conf_ok >= 2L) {
    "Promising"
  } else if (n_strong >= 1L || n_weak >= 3L) {
    "Partially promising"
  } else {
    "Not promising"
  }

  by_target <- lapply(EDA_COMPONENTS, function(ti) {
    hit <- shortlist %>% dplyr::filter(.data$target == ti) %>%
      dplyr::arrange(dplyr::desc(.data$max_abs_resid_corr)) %>%
      dplyr::slice(1:3)
    list(target = ti, candidates = hit)
  })
  list(
    verdict = verdict,
    n_strong_resid_pairs = n_strong,
    n_weak_resid_pairs = n_weak,
    n_validation_confirmed = n_conf_ok,
    by_target = by_target,
    strong_resid = strong_resid,
    shortlist = shortlist
  )
}

eda_fmt <- function(x, d = 3) {
  ifelse(is.finite(x), format(round(x, d), nsmall = d), "NA")
}

eda_write_report <- function(stats_tbl, pair_tests, M_p, M_s, M_m, lagged_summ,
                             resid_summ, shortlist, roll_summ, confirm, ar_meta,
                             meta, rec) {
  path <- file.path(eda_out_dir(), "REPORT.md")
  eda_assert(path)
  train_stats <- stats_tbl %>% dplyr::filter(.data$stage == "train")
  top_raw <- lagged_summ %>% dplyr::arrange(dplyr::desc(.data$max_abs_corr)) %>% dplyr::slice(1:8)
  top_resid <- resid_summ %>% dplyr::arrange(dplyr::desc(.data$max_abs_resid_corr)) %>% dplyr::slice(1:10)

  lines_stats <- apply(train_stats, 1, function(r) {
    sprintf("- **%s**: n_valid=%s, mean=%s, sd=%s, var=%s, range=[%s,%s], ACF(1)=%s, ACF(24)=%s, Σ|ACF1–24|=%s",
            r[["component"]], r[["n_valid"]],
            eda_fmt(as.numeric(r[["mean"]])), eda_fmt(as.numeric(r[["sd"]])),
            eda_fmt(as.numeric(r[["variance"]])),
            eda_fmt(as.numeric(r[["min"]])), eda_fmt(as.numeric(r[["max"]])),
            eda_fmt(as.numeric(r[["acf_lag1"]])), eda_fmt(as.numeric(r[["acf_lag24"]])),
            eda_fmt(as.numeric(r[["sum_abs_acf_1_24"]])))
  })

  lines_pairs <- apply(pair_tests %>% dplyr::arrange(dplyr::desc(abs(.data$pearson))) %>% dplyr::slice(1:8),
                       1, function(r) {
                         sprintf("- %s–%s: Pearson=%s [%s,%s], Spearman=%s, MI=%s, n_eff≈%s, BH p(Pearson)=%s",
                                 r[["component_i"]], r[["component_j"]],
                                 eda_fmt(as.numeric(r[["pearson"]])),
                                 eda_fmt(as.numeric(r[["pearson_lo"]])),
                                 eda_fmt(as.numeric(r[["pearson_hi"]])),
                                 eda_fmt(as.numeric(r[["spearman"]])),
                                 eda_fmt(as.numeric(r[["mutual_information"]]), 4),
                                 eda_fmt(as.numeric(r[["n_eff_approx"]]), 1),
                                 eda_fmt(as.numeric(r[["pearson_p_bh"]]), 4))
                       })

  lines_lag <- apply(top_raw, 1, function(r) {
    sprintf("- %s ← %s: max|r|=%s at lag %s (r=%s); lag0=%s; #lags |r|≥0.10: %s",
            r[["target"]], r[["predictor"]],
            eda_fmt(as.numeric(r[["max_abs_corr"]])), r[["best_lag"]],
            eda_fmt(as.numeric(r[["best_corr"]])),
            eda_fmt(as.numeric(r[["corr_lag0"]])),
            r[["n_lags_abs_ge_0_10"]])
  })

  lines_resid <- apply(top_resid, 1, function(r) {
    sprintf("- %s ← %s: max|resid r|=%s at lag %s (r=%s); #lags |r|≥0.05: %s; BH-sig lags: %s",
            r[["target"]], r[["predictor"]],
            eda_fmt(as.numeric(r[["max_abs_resid_corr"]])), r[["best_lag"]],
            eda_fmt(as.numeric(r[["best_resid_corr"]])),
            r[["n_lags_abs_ge_0_05"]], r[["n_sig_bh_0_05"]])
  })

  lines_ar <- apply(ar_meta, 1, function(r) {
    sprintf("- %s AR(24) train R²=%s (n=%s)", r[["target"]],
            eda_fmt(as.numeric(r[["ar_r2"]])), r[["ar_n"]])
  })

  lines_conf <- if (nrow(confirm)) {
    apply(confirm %>% dplyr::filter(.data$stage == "validation"), 1, function(r) {
      sprintf("- %s ← %s (k=%s): train resid r=%s → validation resid r=%s (n=%s)",
              r[["target"]], r[["predictor"]], r[["lag"]],
              eda_fmt(as.numeric(r[["train_residual_corr"]])),
              eda_fmt(as.numeric(r[["residual_corr"]])), r[["n"]])
    })
  } else character()

  lines_roll <- if (nrow(roll_summ)) {
    apply(roll_summ, 1, function(r) {
      sprintf("- %s ← %s (k=%s): mean r=%s, sd=%s, frac(|r|≥0.05)=%s, same-sign frac=%s",
              r[["target"]], r[["predictor"]], r[["lag"]],
              eda_fmt(as.numeric(r[["mean_corr"]])),
              eda_fmt(as.numeric(r[["sd_corr"]])),
              eda_fmt(as.numeric(r[["frac_abs_ge_0_05"]])),
              eda_fmt(as.numeric(r[["frac_same_sign_as_mean"]])))
    })
  } else character()

  by_target_lines <- unlist(lapply(rec$by_target, function(item) {
    if (!nrow(item$candidates)) {
      return(sprintf("- **%s**: no residual |r|≥0.05 shortlist candidates on train.", item$target))
    }
    cands <- apply(item$candidates, 1, function(r) {
      sprintf("%s (lag %s, resid r=%s)", r[["predictor"]], r[["best_lag"]],
              eda_fmt(as.numeric(r[["best_resid_corr"]])))
    })
    sprintf("- **%s**: %s", item$target, paste(cands, collapse = "; "))
  }))

  md <- c(
    "# Cross-frequency EDA: Haar MODWT/MRA components (CPCB PM2.5)",
    "",
    "## 1. Objective and context",
    "",
    "Univariate component-wise forecasting (T1 / A1) already assigns each of D1–D5 and S5 its own model using only that component's history.",
    "This EDA asks whether **other frequency bands contain incremental information** about a target band beyond that target's own lags.",
    "",
    "**Scope:** exploratory and statistical only. No intercomponent forecasting models were trained.",
    "",
    "## 2. Dataset and decomposition verification",
    "",
    sprintf("- Sensor / variable: `%s` / `%s`", meta$sensor, meta$pollutant),
    sprintf("- Stored decomposition: `%s` (Haar MODWT/MRA, J=5, raw scale)", meta$decomp_id),
    sprintf("- Parquet: `%s`", meta$parquet$path),
    sprintf("- Parquet md5: `%s`", meta$parquet$md5),
    sprintf("- Components: %s (additive reconstruction)", paste(EDA_COMPONENTS, collapse = ", ")),
    sprintf("- Split helper: `chrono_split_tvt` with nested test horizon h=%s hours, val_hours=%s",
            meta$split_h, VAL_HOURS),
    sprintf("- Train / validation / test lengths: %s / %s / %s", meta$n_train, meta$n_val, meta$n_test),
    sprintf("- Complete six-component rows: %s (train complete: %s)", meta$n_complete, meta$n_complete_train),
    sprintf("- Train reconstruction check vs PM2.5: MAE=%s, max|err|=%s, cor=%s",
            eda_fmt(meta$recon$mae_recon, 6), eda_fmt(meta$recon$max_abs_recon, 6),
            eda_fmt(meta$recon$cor_recon, 6)),
    "",
    "Loading used `t1_load_stored_components()` / `get_decomp()` and `t1_align_components()`.",
    "Warm-up / invalid MRA rows remain NA; they were **not** imputed for this analysis.",
    "Discovery statistics use **train only**. Validation is confirmation. **Test was not used** to select relationships.",
    "",
    "### Packages and parameters",
    "",
    "- R packages: base/stats, readr, dplyr, tidyr, ggplot2, tibble, plus project `R/load_all.R` stack.",
    sprintf("- Max lag k: %s h; own-history AR order p: %s; MI bins: %s", meta$max_lag, meta$own_p, meta$mi_bins),
    sprintf("- Block bootstrap: block=%s h, replicates=%s, seed=%s", meta$block_len, meta$n_boot, meta$seed),
    sprintf("- Rolling window: %s h, step %s h", meta$roll_window, meta$roll_step),
    "",
    "Lag convention: **Corr(target(t), predictor(t−k))** with k≥1 = predictor in the past (forecast-usable).",
    "",
    "## 3. Component-wise characteristics (Analysis A)",
    "",
    lines_stats,
    "",
    "Interpretation (descriptive, not predictive):",
    "- **D1–D2** are high-frequency detail bands: lower persistence (smaller long-lag ACF mass).",
    "- **D3–D4** are mid-frequency.",
    "- **D5 / S5** are lower-frequency / smooth: stronger persistence.",
    "- Visual similarity of low-frequency bands does **not** by itself imply cross-frequency forecast value.",
    "",
    "Figures: `plots/components_timeseries.png`, `component_distributions.png`, `component_acf.png`.",
    "",
    "## 4. Contemporaneous relationships (Analysis B)",
    "",
    "Top absolute Pearson pairs (train), with block-bootstrap 95% CIs and BH-adjusted p-values:",
    "",
    lines_pairs,
    "",
    "Full matrices: `tables/pearson_matrix.csv`, `spearman_matrix.csv`, `mutual_information_matrix.csv`.",
    "Heatmaps: `plots/heatmap_*.png`.",
    "",
    "Notes:",
    "- Adjacent scales can show moderate association; distant scales are often weaker.",
    "- MI captures possibly nonlinear dependence; compare MI vs Pearson to spot nonlinear candidates.",
    "- Contemporaneous dependence is **not** permission to use another component's future value in forecasting.",
    "",
    "## 5. Lagged cross-correlation (Analysis C)",
    "",
    "Strongest usable lagged relationships (k=1..24, train):",
    "",
    lines_lag,
    "",
    "Figures: `plots/lagged_ccf_grid.png`, `plots/lagged_maxabs_heatmap.png`.",
    "",
    "## 6. Incremental dependence after own history (Analysis D)",
    "",
    "AR(24) OLS baseline fit on each target (train):",
    "",
    lines_ar,
    "",
    "Residual correlations Corr(ε_i(t), C_j(t−k)) — top pairs:",
    "",
    lines_resid,
    "",
    "Also computed: partial correlations controlling for own lags (`tables/partial_correlations.csv`).",
    "Figure: `plots/residual_maxabs_heatmap.png`.",
    "",
    "**Key question:** after AR(24) own history, do other bands still correlate with the residual?",
    "",
    "## 7. Temporal stability (Analysis E)",
    "",
    "Rolling-window summary for shortlisted pairs (residual correlations at the train-selected lag):",
    "",
    if (length(lines_roll)) lines_roll else "- (no rolling pairs)",
    "",
    "Validation confirmation of train residual relationships:",
    "",
    if (length(lines_conf)) lines_conf else "- (no confirmation rows)",
    "",
    "Figure: `plots/rolling_stability.png`.",
    "",
    "## 8. Limitations",
    "",
    "- Haar MRA components are linearly related to Y; some cross-band structure can reflect filter leakage / shared driving shocks rather than transferable forecast features.",
    "- Thousands of hourly points are highly autocorrelated; n_eff and block bootstrap CIs are approximate.",
    "- MI uses quantile binning (10 bins); absolute MI scale depends on discretization.",
    "- AR(24) residual diagnostic is linear/OLS; nonlinear incremental dependence could be missed.",
    "- Smooth bands (especially S5) have near-perfect AR(24) R²; residual correlations are then correlations with a tiny leftover signal and may overstate practical forecast gains.",
    "- Nested split uses h=24 for discovery train size; longer paper horizons shrink train further.",
    "- Warm-up NAs reduce usable sample at the start of the series.",
    "- Adjacent-band contemporaneous correlations are partly expected from wavelet filter leakage; lagged residual evidence is the more relevant gate for forecasting.",
    "",
    "## 9. Final recommendation",
    "",
    sprintf("### Verdict: **%s**", rec$verdict),
    "",
    sprintf("- Residual pairs with max|r|≥0.10 (train): **%s**", rec$n_strong_resid_pairs),
    sprintf("- Residual pairs with 0.05≤max|r|<0.10 (train): **%s**", rec$n_weak_resid_pairs),
    sprintf("- Shortlisted pairs with validation residual confirmation (|r|≥0.05, same sign): **%s**",
            rec$n_validation_confirmed),
    "",
    "### Per-target shortlist (train residual evidence)",
    "",
    by_target_lines,
    "",
    "### Decision rule applied",
    "",
    "- **Promising:** ≥3 pairs with residual |r|≥0.10 and ≥2 validation-confirmed.",
    "- **Partially promising:** ≥1 strong residual pair or ≥3 weak residual pairs.",
    "- **Not promising:** otherwise.",
    "",
    "This recommendation uses train discovery + validation confirmation only. Test metrics were not consulted.",
    "",
    "### Next step (gated)",
    "",
    "Do **not** train intercomponent LightGBM/XGBoost/CatBoost models until this recommendation is reviewed.",
    "If the verdict is Partially promising, prefer a **selective** experiment using only the shortlisted predictors/lags above.",
    ""
  )
  writeLines(md, path)
  path
}
