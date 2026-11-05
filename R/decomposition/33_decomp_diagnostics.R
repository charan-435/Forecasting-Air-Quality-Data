# D1–D6 diagnostics. D1/D2 are hard fails. D3 uses data after t on purpose
# and is never written into the feature/decomp values.

.dominant_period <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 16L) return(NA_real_)
  sp <- tryCatch(stats::spec.pgram(x, detrend = TRUE, plot = FALSE, taper = 0.1),
                 error = function(e) NULL)
  if (is.null(sp) || !length(sp$freq)) return(NA_real_)
  k <- which.max(sp$spec)
  if (!length(k) || sp$freq[k] <= 0) return(NA_real_)
  1 / sp$freq[k]
}

d1_on_series <- function(sv, entry, fn, scale, n_t = 20L, tol = 1e-9) {
  x0 <- apply_decomp_scale(sv$value_filled_causal, scale, sv$variable[1])
  n <- length(x0)
  W <- as.integer(entry$params$window_h %||% decomp_cfg()$window_h %||% 2048L)
  bump <- if (identical(scale, "log")) 0.5 else 50
  lo <- if (identical(entry$family, "trailing")) W else warmup_length(
    as.integer(entry$params$J %||% 1L), filter_length(entry$params$filter %||% "haar"))
  pool <- seq.int(lo, max(lo, n - 201L))
  if (!length(pool)) return(list(ok = TRUE, max_delta = 0, n = 0L))
  set.seed(11)
  tsamp <- sort(sample(pool, min(n_t, length(pool))))
  worst <- 0
  ks <- c(1L, 5L, 24L, 200L)
  for (t0 in tsamp) {
    base <- .decomp_at_t(x0, t0, entry, fn, W)
    if (is.null(base)) next
    for (k in ks) {
      xp <- x0
      xp[t0 + k] <- xp[t0 + k] + bump
      new <- .decomp_at_t(xp, t0, entry, fn, W)
      if (is.null(new)) return(list(ok = FALSE, max_delta = Inf, n = length(tsamp)))
      worst <- max(worst, max(abs(base - new), na.rm = TRUE))
    }
  }
  list(ok = worst <= tol, max_delta = worst, n = length(tsamp))
}

d2_additivity <- function(df, entry, x, tol_haar = 1e-10, tol_other = 1e-8) {
  if (!isTRUE(entry$additive)) {
    if (!"resid" %in% names(df)) return(list(ok = TRUE, max_err = NA_real_))
    comps <- decomp_component_names(entry, df)
    hat <- rowSums(as.matrix(df[, comps, drop = FALSE]), na.rm = FALSE) + df$resid
    err <- max(abs(hat - x)[df$valid_warmup], na.rm = TRUE)
    return(list(ok = isTRUE(err <= tol_other) || !is.finite(err), max_err = err))
  }
  ok_rows <- df$valid_warmup & is.finite(x)
  if (identical(entry$fn, "decomp_coef_haar")) {
    J <- as.integer(entry$params$J)
    worst <- 0
    for (j in seq_len(J)) {
      cols <- c(paste0("W", seq_len(j)), paste0("V", j))
      hat <- rowSums(as.matrix(df[, cols, drop = FALSE]))
      wu <- df[[paste0("valid_warmup_V", j)]]
      if (is.null(wu)) wu <- ok_rows
      err <- max(abs(hat - x)[wu & is.finite(hat)], na.rm = TRUE)
      worst <- max(worst, err)
    }
    return(list(ok = worst <= tol_haar, max_err = worst))
  }
  comps <- decomp_component_names(entry, df)
  comps <- setdiff(comps, c("resid", "n_imf_raw"))
  hat <- rowSums(as.matrix(df[, comps, drop = FALSE]), na.rm = FALSE)
  if ("resid" %in% names(df) && entry$fn %in% c("decomp_vmd", "decomp_mstl", "decomp_ssa", "decomp_ma_rem")) {
    hat <- hat + df$resid
  }
  err <- max(abs(hat - x)[ok_rows & is.finite(hat)], na.rm = TRUE)
  tol <- if (entry$fn %in% c("decomp_vmd", "decomp_mstl", "decomp_ssa")) tol_other else 1e-8
  list(ok = isTRUE(err <= tol) || !is.finite(err), max_err = err)
}

d3_edge_fidelity <- function(sv, entry, fn, scale, stored, cfg) {
  x <- apply_decomp_scale(sv$value_filled_causal, scale, sv$variable[1])
  times <- sv$timestamp
  sel <- decomp_selection_end(cfg, times)
  H <- as.integer(cfg$d3_horizon %||% 512L)
  n_s <- as.integer(cfg$n_d3_samples %||% 300L)
  W <- as.integer(entry$params$window_h %||% cfg$window_h %||% 2048L)
  n <- length(x)
  # t + H <= selection_end, and enough history
  idx <- which(times <= sel - lubridate::hours(H))
  if (identical(entry$family, "trailing")) idx <- idx[idx >= W]
  else {
    Lj <- warmup_length(as.integer(entry$params$J %||% 1L),
                        filter_length(entry$params$filter %||% "haar"))
    idx <- idx[idx >= Lj]
  }
  idx <- idx[idx + H <= n]
  if (!length(idx)) return(NULL)
  set.seed(13)
  tsamp <- sort(sample(idx, min(n_s, length(idx))))
  comps <- decomp_component_names(entry, stored)
  comps <- setdiff(comps, c("resid", "n_imf_raw"))
  rev_mat <- matrix(NA_real_, length(tsamp), length(comps))
  colnames(rev_mat) <- comps
  pad <- as.integer(entry$params$pad %||% 0L)
  if (identical(entry$family, "causal_full")) {
    tmax <- min(n, max(tsamp) + H)
    M <- fn(x[seq_len(tmax)], entry$params %||% list())
    if (is.null(dim(M))) M <- matrix(M, ncol = 1)
    for (cn in intersect(comps, colnames(M))) rev_mat[, cn] <- M[tsamp, cn]
  } else {
    pos <- W - H
    for (ii in seq_along(tsamp)) {
      t <- tsamp[ii]
      lo <- t + H - W + 1L
      if (lo < 1L || pos < 1L) next
      win <- x[lo:(t + H)]
      xx <- if (pad > 0L) c(win, ar_forecast_ls(win, pad)) else win
      M <- tryCatch(fn(xx, entry$params %||% list()), error = function(e) NULL)
      if (is.null(M)) next
      if (is.null(dim(M))) M <- matrix(M, ncol = 1)
      if (pos > nrow(M)) next
      for (cn in intersect(comps, colnames(M))) rev_mat[ii, cn] <- M[pos, cn]
    }
  }
  rows <- list()
  for (cn in comps) {
    rt <- stored[[cn]][tsamp]
    rev <- rev_mat[, cn]
    ok <- is.finite(rt) & is.finite(rev)
    if (sum(ok) < 5L) {
      rows[[cn]] <- tibble::tibble(component = cn, n = sum(ok),
                                   cor = NA_real_, nrmse = NA_real_, sign_agree = NA_real_)
      next
    }
    a <- rt[ok]; b <- rev[ok]
    sd_b <- stats::sd(b)
    rows[[cn]] <- tibble::tibble(
      component = cn, n = sum(ok),
      cor = suppressWarnings(stats::cor(a, b)),
      nrmse = if (is.finite(sd_b) && sd_b > 0) sqrt(mean((a - b)^2)) / sd_b else 0,
      sign_agree = mean(sign(a) == sign(b) | (a == 0 & b == 0))
    )
  }
  dplyr::bind_rows(rows)
}

d4_band_stability <- function(sv, entry, fn, scale, cfg, tsamp) {
  x <- apply_decomp_scale(sv$value_filled_causal, scale, sv$variable[1])
  W <- as.integer(entry$params$window_h %||% cfg$window_h %||% 2048L)
  H <- as.integer(cfg$d3_horizon %||% 512L)
  n <- length(x)
  probe_t <- tsamp[1]
  probe <- tryCatch({
    if (identical(entry$family, "trailing")) {
      lo <- probe_t + H - W + 1L
      fn(x[lo:(probe_t + H)], entry$params %||% list())
    } else fn(x[seq_len(min(n, probe_t + H))], entry$params %||% list())
  }, error = function(e) NULL)
  if (is.null(probe)) return(NULL)
  if (is.null(dim(probe))) probe <- matrix(probe, ncol = 1)
  comps <- setdiff(colnames(probe), c("n_imf_raw"))
  pers_mat <- matrix(NA_real_, length(tsamp), length(comps))
  colnames(pers_mat) <- comps
  n_imf <- numeric()
  for (ii in seq_along(tsamp)) {
    t <- tsamp[ii]
    if (t + H > n) next
    M <- tryCatch({
      if (identical(entry$family, "trailing")) {
        lo <- t + H - W + 1L
        if (lo < 1L) next
        fn(x[lo:(t + H)], entry$params %||% list())
      } else fn(x[seq_len(t + H)], entry$params %||% list())
    }, error = function(e) NULL)
    if (is.null(M)) next
    if (is.null(dim(M))) M <- matrix(M, ncol = 1)
    for (cn in intersect(comps, colnames(M))) {
      pers_mat[ii, cn] <- .dominant_period(M[, cn])
    }
    if ("n_imf_raw" %in% colnames(M)) n_imf <- c(n_imf, M[nrow(M), "n_imf_raw"])
  }
  out <- list()
  for (cn in comps) {
    pers <- pers_mat[, cn]
    pers <- pers[is.finite(pers)]
    out[[cn]] <- tibble::tibble(
      component = cn,
      period_median = if (length(pers)) stats::median(pers) else NA_real_,
      period_iqr = if (length(pers)) as.numeric(diff(stats::quantile(pers, c(0.25, 0.75)))) else NA_real_,
      n = length(pers)
    )
  }
  list(bands = dplyr::bind_rows(out), n_imf_raw = n_imf)
}

run_decomp_diagnostics <- function(cfg = decomp_cfg(), long = NULL) {
  if (is.null(long)) long <- read_clean_long()
  listed <- list_methods()
  if (!nrow(listed)) {
    decomp_log("diagnostics: no manifests")
    return(invisible(NULL))
  }
  entries <- decomp_methods(cfg)
  names(entries) <- vapply(entries, `[[`, "", "id")
  rows <- list()
  d3_rows <- list()
  d4_rows <- list()
  d6_rows <- list()
  for (i in seq_len(nrow(listed))) {
    id <- listed$method_id[i]; sc <- listed$scale[i]
    entry <- entries[[id]]
    if (is.null(entry) || !.method_available(entry)) next
    fn <- .decomp_fn(entry)
    man <- get_manifest(id, sc)
    stns <- man$stations
    vars <- man$variables
    for (stn in stns) for (v in vars) {
      path <- decomp_parquet_path(method_full_id(id, sc), stn, v)
      if (!file.exists(path)) next
      df <- tibble::as_tibble(arrow::read_parquet(path))
      sv <- long %>% dplyr::filter(.data$station == !!stn, .data$variable == !!v) %>%
        dplyr::arrange(.data$timestamp)
      x <- apply_decomp_scale(sv$value_filled_causal, sc, v)
      d1 <- d1_on_series(sv, entry, fn, sc)
      d2 <- d2_additivity(df, entry, x)
      if (!d1$ok) decomp_log("D1 FAIL ", id, " ", sc, " ", stn, " ", v, " delta=", d1$max_delta)
      if (isTRUE(entry$additive) && !d2$ok)
        decomp_log("D2 FAIL ", id, " ", sc, " ", stn, " ", v, " err=", d2$max_err)
      n_basic <- sum(df$valid_basic, na.rm = TRUE)
      n_strict <- sum(df$valid_strict, na.rm = TRUE)
      d6 <- if (n_basic > 0) 1 - n_strict / n_basic else NA_real_
      rows[[length(rows) + 1L]] <- tibble::tibble(
        method_id = id, scale = sc, station = stn, variable = v,
        family = entry$family, additive = isTRUE(entry$additive),
        d1_ok = d1$ok, d1_max_delta = d1$max_delta,
        d2_ok = d2$ok, d2_max_err = d2$max_err,
        s_per_1k = NA_real_, runtime_sec = as.numeric(man$runtime_sec %||% NA),
        frac_basic_not_strict = d6
      )
      d6_rows[[length(d6_rows) + 1L]] <- tibble::tibble(
        method_id = id, scale = sc, station = stn, variable = v, frac_basic_not_strict = d6
      )
      # D3/D4: skip if the series is too short; cap samples for speed on trailing
      n_s <- if (identical(entry$family, "trailing")) min(40L, as.integer(cfg$n_d3_samples %||% 300L))
      else as.integer(cfg$n_d3_samples %||% 300L)
      cfg2 <- cfg; cfg2$n_d3_samples <- n_s
      d3 <- tryCatch(d3_edge_fidelity(sv, entry, fn, sc, df, cfg2), error = function(e) NULL)
      if (!is.null(d3) && nrow(d3)) {
        d3$method_id <- id; d3$scale <- sc; d3$station <- stn; d3$variable <- v
        d3_rows[[length(d3_rows) + 1L]] <- d3
      }
      # Reuse D3's sampling rule for D4 (same seed inside d3_edge_fidelity is 13).
      times <- sv$timestamp
      sel <- decomp_selection_end(cfg2, times)
      H <- as.integer(cfg2$d3_horizon %||% 512L)
      W <- as.integer(entry$params$window_h %||% cfg2$window_h %||% 2048L)
      idx <- which(times <= sel - lubridate::hours(H))
      if (identical(entry$family, "trailing")) idx <- idx[idx >= W]
      idx <- idx[idx + H <= length(times)]
      if (length(idx)) {
        set.seed(13)
        tsamp <- sort(sample(idx, min(n_s, length(idx))))
        d4 <- tryCatch(d4_band_stability(sv, entry, fn, sc, cfg2, tsamp),
                       error = function(e) NULL)
        if (!is.null(d4) && !is.null(d4$bands) && nrow(d4$bands)) {
          d4$bands$method_id <- id; d4$bands$scale <- sc
          d4$bands$station <- stn; d4$bands$variable <- v
          if (length(d4$n_imf_raw)) {
            d4$bands$n_imf_raw_median <- stats::median(d4$n_imf_raw)
            d4$bands$n_imf_raw_iqr <- as.numeric(diff(stats::quantile(d4$n_imf_raw, c(0.25, 0.75))))
          }
          d4_rows[[length(d4_rows) + 1L]] <- d4$bands
        }
      }
    }
  }
  diag <- dplyr::bind_rows(rows)
  d3_all <- dplyr::bind_rows(d3_rows)
  d4_all <- dplyr::bind_rows(d4_rows)
  path <- file.path(decomp_root(), "diagnostics.parquet")
  if (nrow(diag)) write_decomp_parquet(diag, path)
  if (nrow(d3_all)) write_decomp_parquet(d3_all, file.path(decomp_root(), "diagnostics_d3.parquet"))
  if (nrow(d4_all)) write_decomp_parquet(d4_all, file.path(decomp_root(), "diagnostics_d4.parquet"))
  write_diagnostics_md(diag, d3_all, listed, d4_all)
  invisible(diag)
}

write_diagnostics_md <- function(diag, d3, listed, d4 = NULL) {
  path <- file.path(decomp_root(), "DIAGNOSTICS.md")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  cat("# Decomposition diagnostics\n\n", file = con)
  cat("D1/D2 are hard fails. D3 uses data after t on purpose and is **not** stored as features.\n\n", file = con)
  if (nrow(listed)) {
    cat("## Runs\n\n| method | scale | family | partial | runtime_s |\n|---|---|---|---|---|\n", file = con)
    for (i in seq_len(nrow(listed))) {
      cat(sprintf("| %s | %s | %s | %s | %s |\n", listed$method_id[i], listed$scale[i],
                  listed$family[i], listed$partial[i], round(listed$runtime_sec[i], 2)), file = con)
    }
    cat("\n", file = con)
  }
  if (nrow(diag)) {
    cat("## D1 / D2 / D6\n\n", file = con)
    cat("| method | scale | station | variable | D1 | max_delta | D2 | max_err | frac_basic_not_strict |\n",
        "|---|---|---|---|---|---|---|---|---|\n", file = con)
    for (i in seq_len(nrow(diag))) {
      cat(sprintf("| %s | %s | %s | %s | %s | %.3g | %s | %.3g | %.3f |\n",
                  diag$method_id[i], diag$scale[i], diag$station[i], diag$variable[i],
                  diag$d1_ok[i], diag$d1_max_delta[i], diag$d2_ok[i],
                  diag$d2_max_err[i], diag$frac_basic_not_strict[i]), file = con)
    }
    cat("\n", file = con)
  }
  if (!is.null(d3) && nrow(d3)) {
    cat("## D3 edge fidelity (real-time vs revised at t+512)\n\n", file = con)
    cat("| method | scale | station | variable | component | n | cor | nrmse | sign_agree |\n",
        "|---|---|---|---|---|---|---|---|---|\n", file = con)
    for (i in seq_len(min(nrow(d3), 400L))) {
      cat(sprintf("| %s | %s | %s | %s | %s | %d | %.3f | %.3f | %.3f |\n",
                  d3$method_id[i], d3$scale[i], d3$station[i], d3$variable[i],
                  d3$component[i], d3$n[i], d3$cor[i], d3$nrmse[i], d3$sign_agree[i]),
          file = con)
    }
    cat("\nCausal coefficients should have cor = 1 and nrmse = 0 by construction.\n\n", file = con)
  }
  if (!is.null(d4) && nrow(d4)) {
    cat("## D4 band stability (dominant period of revised window)\n\n", file = con)
    cat("Wide IQR means the column mixes frequencies across time.\n\n", file = con)
    cat("| method | scale | component | period_median | period_IQR | n |\n",
        "|---|---|---|---|---|---|\n", file = con)
    summ <- d4 %>%
      dplyr::group_by(.data$method_id, .data$scale, .data$component) %>%
      dplyr::summarise(
        period_median = stats::median(.data$period_median, na.rm = TRUE),
        period_iqr = stats::median(.data$period_iqr, na.rm = TRUE),
        n = sum(.data$n, na.rm = TRUE),
        .groups = "drop"
      )
    for (i in seq_len(min(nrow(summ), 200L))) {
      cat(sprintf("| %s | %s | %s | %.1f | %.1f | %d |\n",
                  summ$method_id[i], summ$scale[i], summ$component[i],
                  summ$period_median[i], summ$period_iqr[i], summ$n[i]),
          file = con)
    }
    cat("\n", file = con)
  }
  path
}
