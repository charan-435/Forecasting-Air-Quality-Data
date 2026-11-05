# Cheap ranking of decomposition methods. Train only on t+h < screen_start.
# Score only targets ≤ selection_end. Not a final model result.

.f0_lag_idx <- c(1:24, 48, 72, 168)

.screen_calendar <- function(times, sel, lookback_days) {
  sel <- lubridate::with_tz(sel, "Asia/Kolkata")
  screen_start <- sel - lubridate::days(as.integer(lookback_days))
  list(sel = sel, screen_start = screen_start)
}

.f0_matrix <- function(sv) {
  y <- as.numeric(sv$value_filled_causal)
  n <- length(y)
  hod <- lubridate::hour(sv$timestamp)
  dow <- as.integer(lubridate::wday(sv$timestamp, week_start = 1))
  hso <- as.numeric(sv$hours_since_observed)
  hso[!is.finite(hso)] <- n
  lags <- .f0_lag_idx
  X <- matrix(NA_real_, n, length(lags) + 5L)
  cn <- c(paste0("lag_", lags), "hours_since_observed", "hod_sin", "hod_cos",
          "dow_sin", "dow_cos")
  colnames(X) <- cn
  for (j in seq_along(lags)) {
    k <- lags[j]
    if (k < n) X[(k + 1L):n, j] <- y[seq_len(n - k)]
  }
  X[, "hours_since_observed"] <- hso
  X[, "hod_sin"] <- sin(2 * pi * hod / 24)
  X[, "hod_cos"] <- cos(2 * pi * hod / 24)
  X[, "dow_sin"] <- sin(2 * pi * (dow - 1) / 7)
  X[, "dow_cos"] <- cos(2 * pi * (dow - 1) / 7)
  X
}

.comp_lags <- function(df, comps, lags = c(0L, 1L, 24L)) {
  n <- nrow(df)
  cols <- list()
  for (cn in comps) {
    z <- as.numeric(df[[cn]])
    for (k in lags) {
      nm <- if (k == 0L) cn else paste0(cn, "_l", k)
      v <- rep(NA_real_, n)
      if (k == 0L) v <- z
      else if (k < n) v[(k + 1L):n] <- z[seq_len(n - k)]
      cols[[nm]] <- v
    }
  }
  do.call(cbind, cols)
}

.fit_lgb_l1 <- function(X, y, params) {
  ok <- stats::complete.cases(X) & is.finite(y)
  if (sum(ok) < as.integer(params$min_data_in_leaf %||% 50) + 10L) return(NULL)
  dtr <- lightgbm::lgb.Dataset(X[ok, , drop = FALSE], label = y[ok])
  lightgbm::lgb.train(
    params = list(
      objective = params$objective %||% "regression_l1",
      num_leaves = as.integer(params$num_leaves %||% 31),
      learning_rate = as.numeric(params$learning_rate %||% 0.05),
      min_data_in_leaf = as.integer(params$min_data_in_leaf %||% 50),
      feature_fraction = as.numeric(params$feature_fraction %||% 0.8),
      verbosity = -1L, seed = as.integer(params$seed %||% 7),
      num_threads = 1L
    ),
    data = dtr,
    nrounds = as.integer(params$nrounds %||% 500),
    verbose = -1L
  )
}

.block_boot_ci <- function(err_a, err_b, origins, block = 7L, reps = 199L, seed = 7L) {
  # relative MAE = mean(|ea|) / mean(|eb|) on resampled origin blocks
  set.seed(seed)
  u <- unique(origins)
  n <- length(u)
  if (n < block + 2L) {
    r <- mean(abs(err_a), na.rm = TRUE) / mean(abs(err_b), na.rm = TRUE)
    return(c(r, r, r))
  }
  n_blocks <- ceiling(n / block)
  draws <- numeric(reps)
  for (r in seq_len(reps)) {
    starts <- sample.int(max(1L, n - block + 1L), n_blocks, replace = TRUE)
    take <- unique(unlist(lapply(starts, function(s) u[s:min(n, s + block - 1L)])))
    ii <- origins %in% take
    ma <- mean(abs(err_a[ii]), na.rm = TRUE)
    mb <- mean(abs(err_b[ii]), na.rm = TRUE)
    draws[r] <- if (is.finite(mb) && mb > 0) ma / mb else NA_real_
  }
  qs <- stats::quantile(draws, c(0.05, 0.5, 0.95), na.rm = TRUE, names = FALSE)
  qs
}

.screen_origins <- function(times, screen_start, sel, h) {
  keep <- times >= screen_start & times <= sel - lubridate::hours(h) &
    lubridate::hour(times) == 23L
  which(keep)
}

run_decomp_screen <- function(cfg = decomp_cfg(), long = NULL) {
  if (is.null(long)) long <- read_clean_long()
  listed <- list_methods()
  if (!nrow(listed)) {
    decomp_log("screen: no methods in store")
    return(invisible(NULL))
  }
  scfg <- cfg$screen
  horizons <- as.integer(unlist(scfg$horizons %||% c(1, 6, 24, 72, 168)))
  lgb_p <- scfg$lgb %||% list()
  lookback <- as.integer(scfg$lookback_days %||% 60)
  entries <- decomp_methods(cfg)
  names(entries) <- vapply(entries, `[[`, "", "id")
  pairs <- unique(long[, c("station", "variable")])
  pairs <- pairs[pairs$variable %in% DECOMP_POLLUTANTS, ]

  screen_one_pair <- function(pi) {
    stn <- pairs$station[pi]; v <- pairs$variable[pi]
    results <- list()
    embargo_ok <- TRUE
    sv <- long %>% dplyr::filter(.data$station == !!stn, .data$variable == !!v) %>%
      dplyr::arrange(.data$timestamp)
    times <- sv$timestamp
    cal <- .screen_calendar(times, decomp_selection_end(cfg, times), lookback)
    y <- as.numeric(sv$value_filled_causal)
    y_log <- log1p(pmax(y, 0))
    scor <- as.logical(sv$is_scorable)
    f0 <- .f0_matrix(sv)
    n <- nrow(sv)

    for (h in horizons) {
      tgt <- c(y_log[(h + 1L):n], rep(NA_real_, h))
      tgt_raw <- c(y[(h + 1L):n], rep(NA_real_, h))
      tgt_scor <- c(scor[(h + 1L):n], rep(FALSE, h))
      train <- which(times + lubridate::hours(h) < cal$screen_start)
      train <- train[tgt_scor[train] & stats::complete.cases(f0[train, , drop = FALSE])]
      orig <- .screen_origins(times, cal$screen_start, cal$sel, h)
      orig <- orig[tgt_scor[orig]]
      if (!length(train) || !length(orig)) next
      if (any(times[train] + lubridate::hours(h) >= cal$screen_start)) embargo_ok <- FALSE
      if (any(times[orig] + lubridate::hours(h) > cal$sel)) embargo_ok <- FALSE

      m0 <- .fit_lgb_l1(f0[train, , drop = FALSE], tgt[train], lgb_p)
      if (is.null(m0)) next
      p0 <- as.numeric(predict(m0, f0[orig, , drop = FALSE]))
      yhat0 <- pmax(expm1(p0), 0)
      err0 <- yhat0 - tgt_raw[orig]

      mae0 <- mean(abs(err0), na.rm = TRUE)
      results[[length(results) + 1L]] <- tibble::tibble(
        station = stn, variable = v, h = h, method_id = "F0", scale = "raw",
        validity = "basic", mae = mae0, rel_mae = 1, ci_lo = 1, ci_hi = 1,
        n_origin = length(orig), n_train = length(train)
      )

      for (li in seq_len(nrow(listed))) {
        id <- listed$method_id[li]; sc <- listed$scale[li]
        entry <- entries[[id]]
        if (is.null(entry)) next
        if (isTRUE(listed$partial[li]) && !v %in% c("PM2.5", "PM10")) next
        path <- decomp_parquet_path(method_full_id(id, sc), stn, v)
        if (!file.exists(path)) next
        dec <- tryCatch(tibble::as_tibble(arrow::read_parquet(path)),
                        error = function(e) NULL)
        if (is.null(dec) || nrow(dec) != n) next
        comps <- decomp_component_names(entry, dec)
        comps <- intersect(c(comps, "resid"), names(dec))
        comps <- setdiff(comps, "n_imf_raw")
        if (!length(comps)) next
        C <- .comp_lags(dec, comps)
        X1 <- cbind(f0, C)
        for (val in c("basic", "strict")) {
          flag <- if (identical(val, "strict")) dec$valid_strict else dec$valid_basic
          flag[is.na(flag)] <- FALSE
          tr <- train[flag[train]]
          og <- orig[flag[orig]]
          if (length(tr) < 80L || length(og) < 5L) next
          m1 <- .fit_lgb_l1(X1[tr, , drop = FALSE], tgt[tr], lgb_p)
          if (is.null(m1)) next
          p1 <- as.numeric(predict(m1, X1[og, , drop = FALSE]))
          yhat1 <- pmax(expm1(p1), 0)
          err1 <- yhat1 - tgt_raw[og]
          p0b <- as.numeric(predict(m0, f0[og, , drop = FALSE]))
          err0b <- pmax(expm1(p0b), 0) - tgt_raw[og]
          mae1 <- mean(abs(err1), na.rm = TRUE)
          mae0b <- mean(abs(err0b), na.rm = TRUE)
          rel <- if (mae0b > 0) mae1 / mae0b else NA_real_
          ci <- .block_boot_ci(err1, err0b, as.integer(og),
                               block = as.integer(scfg$bootstrap_block %||% 7),
                               reps = as.integer(scfg$bootstrap_reps %||% 199))
          results[[length(results) + 1L]] <- tibble::tibble(
            station = stn, variable = v, h = h, method_id = id, scale = sc,
            validity = val, mae = mae1, rel_mae = rel,
            ci_lo = ci[1], ci_hi = ci[3],
            n_origin = length(og), n_train = length(tr)
          )
        }
      }
    }
    list(rows = results, embargo_ok = embargo_ok)
  }

  n_workers <- tryCatch(as.integer(future::nbrOfWorkers()), error = function(e) 1L)
  if (n_workers <= 1L && requireNamespace("future.apply", quietly = TRUE)) {
    n_w <- max(1L, min(8L, future::availableCores() - 1L))
    if (n_w > 1L) {
      old_plan <- future::plan()
      on.exit(future::plan(old_plan), add = TRUE)
      future::plan(future::multisession, workers = n_w)
      n_workers <- n_w
    }
  }
  decomp_log("screen pairs=", nrow(pairs), " methods=", nrow(listed),
             " workers=", n_workers)
  outs <- if (n_workers > 1L && requireNamespace("future.apply", quietly = TRUE)) {
    future.apply::future_lapply(
      seq_len(nrow(pairs)), screen_one_pair, future.seed = TRUE,
      future.packages = c("lightgbm", "arrow", "dplyr", "lubridate")
    )
  } else {
    lapply(seq_len(nrow(pairs)), screen_one_pair)
  }
  results <- unlist(lapply(outs, `[[`, "rows"), recursive = FALSE)
  embargo_ok <- all(vapply(outs, `[[`, TRUE, "embargo_ok"))
  res <- dplyr::bind_rows(results)
  attr(res, "embargo_ok") <- embargo_ok
  if (nrow(res)) {
    write_decomp_parquet(res, file.path(decomp_root(), "screen_results.parquet"))
    write_screen_md(res)
  }
  invisible(res)
}

.family_of <- function(id) {
  if (id == "F0") return("F0")
  if (startsWith(id, "coef_")) return("wavelet_coef")
  if (startsWith(id, "mra_")) return("MRA")
  if (startsWith(id, "emd") || startsWith(id, "ceemdan")) return("EMD")
  if (startsWith(id, "vmd")) return("VMD")
  if (startsWith(id, "mstl")) return("MSTL")
  if (startsWith(id, "ssa")) return("SSA")
  if (id == "ma_rem") return("dummy")
  "other"
}

write_screen_md <- function(res) {
  path <- file.path(decomp_root(), "SCREEN.md")
  con <- file(path, "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  cat("# Decomposition quick screen\n\n", file = con)
  cat("Relative MAE vs F0 (lags only). Geometric mean across station × pollutant.\n",
      "Train: t+h < screen_start. Origins: daily 23:00 IST in the screen window.\n\n",
      file = con)
  pooled <- res %>%
    dplyr::filter(.data$method_id != "F0") %>%
    dplyr::group_by(.data$method_id, .data$scale, .data$validity, .data$h) %>%
    dplyr::summarise(
      rel_gmean = exp(mean(log(pmax(.data$rel_mae, 1e-8)), na.rm = TRUE)),
      ci_lo = exp(mean(log(pmax(.data$ci_lo, 1e-8)), na.rm = TRUE)),
      ci_hi = exp(mean(log(pmax(.data$ci_hi, 1e-8)), na.rm = TRUE)),
      n = dplyr::n(), .groups = "drop"
    )
  cat("## Ranking (pooled relative MAE)\n\n", file = con)
  for (hh in sort(unique(pooled$h))) {
    cat(sprintf("### h = %s\n\n", hh), file = con)
    cat("| rank | method | scale | validity | rel_MAE | CI |\n|---|---|---|---|---|---|\n", file = con)
    sl <- pooled %>% dplyr::filter(.data$h == hh) %>% dplyr::arrange(.data$rel_gmean)
    for (i in seq_len(nrow(sl))) {
      cat(sprintf("| %d | %s | %s | %s | %.3f | [%.3f, %.3f] |\n",
                  i, sl$method_id[i], sl$scale[i], sl$validity[i],
                  sl$rel_gmean[i], sl$ci_lo[i], sl$ci_hi[i]), file = con)
    }
    cat("\n", file = con)
  }
  beat <- pooled %>% dplyr::filter(.data$ci_hi < 1)
  cat("## CI entirely below 1 (beats F0)\n\n", file = con)
  if (!nrow(beat)) cat("None.\n\n", file = con)
  else {
    cat("| method | scale | validity | h | rel_MAE |\n|---|---|---|---|---|\n", file = con)
    for (i in seq_len(nrow(beat))) {
      cat(sprintf("| %s | %s | %s | %s | %.3f |\n",
                  beat$method_id[i], beat$scale[i], beat$validity[i],
                  beat$h[i], beat$rel_gmean[i]), file = con)
    }
    cat("\n", file = con)
  }
  # paired basic vs strict, raw vs log
  cat("## Basic vs strict (median rel_MAE)\n\n", file = con)
  vs <- res %>% dplyr::filter(.data$method_id != "F0") %>%
    dplyr::group_by(.data$validity) %>%
    dplyr::summarise(med = stats::median(.data$rel_mae, na.rm = TRUE), .groups = "drop")
  for (i in seq_len(nrow(vs))) cat("- ", vs$validity[i], ": ", round(vs$med[i], 3), "\n", file = con, sep = "")
  cat("\n## Raw vs log (median rel_MAE)\n\n", file = con)
  rs <- res %>% dplyr::filter(.data$method_id != "F0") %>%
    dplyr::group_by(.data$scale) %>%
    dplyr::summarise(med = stats::median(.data$rel_mae, na.rm = TRUE), .groups = "drop")
  for (i in seq_len(nrow(rs))) cat("- ", rs$scale[i], ": ", round(rs$med[i], 3), "\n", file = con, sep = "")

  cat("\n## Shortlist\n\n", file = con)
  beat_cfg <- unique(beat[, c("method_id", "scale", "validity")])
  fam <- pooled %>% dplyr::mutate(family = vapply(.data$method_id, .family_of, ""))
  best_fam <- fam %>% dplyr::group_by(.data$family) %>%
    dplyr::slice_min(.data$rel_gmean, n = 1, with_ties = FALSE) %>% dplyr::ungroup()
  cat("Configs that beat F0 at one or more horizons, plus the best of each family.\n\n", file = con)
  cat("| method | scale | validity | family | why |\n|---|---|---|---|---|\n", file = con)
  if (nrow(beat_cfg)) {
    for (i in seq_len(nrow(beat_cfg))) {
      cat(sprintf("| %s | %s | %s | %s | beats F0 |\n",
                  beat_cfg$method_id[i], beat_cfg$scale[i], beat_cfg$validity[i],
                  .family_of(beat_cfg$method_id[i])), file = con)
    }
  }
  for (i in seq_len(nrow(best_fam))) {
    cat(sprintf("| %s | %s | %s | %s | best of family |\n",
                best_fam$method_id[i], best_fam$scale[i], best_fam$validity[i],
                best_fam$family[i]), file = con)
  }
  path
}

# Guard used by tests: perturbing y after selection_end must not change screen.
screen_uses_only_pre_selection <- function(long, cfg = decomp_cfg()) {
  # Returns the max timestamp used as a training target or scored origin target.
  times <- sort(unique(long$timestamp))
  cal <- .screen_calendar(times, decomp_selection_end(cfg, times),
                          cfg$screen$lookback_days %||% 60)
  cal$sel
}
