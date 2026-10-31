# Decomposition method registry and the Phase 1b engine.
# Adding a method: write a function (causal_full: x -> n×K; trailing: window -> W×K)
# and a config/decomp.yaml entry. Do not change this file.

DECOMP_POLLUTANTS <- c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO")
DECOMP_METVARS <- c(DECOMP_POLLUTANTS, "AT", "RH")

.decomp_cfg_cache <- NULL

decomp_cfg <- function(path = NULL) {
  if (!is.null(.GlobalEnv$.DECOMP_CFG) && is.null(path)) return(.GlobalEnv$.DECOMP_CFG)
  if (is.null(path)) path <- file.path(PROJECT_ROOT, "config", "decomp.yaml")
  cfg <- yaml::read_yaml(path)
  .GlobalEnv$.DECOMP_CFG <- cfg
  cfg
}

decomp_log <- function(...) {
  line <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ",
                 paste0(..., collapse = ""))
  cat(line, "\n", sep = "")
  logf <- file.path(PROJECT_ROOT, "store", "decomp", "decomp_log.txt")
  dir.create(dirname(logf), recursive = TRUE, showWarnings = FALSE)
  cat(line, "\n", file = logf, append = TRUE, sep = "")
}

decomp_policy <- function() {
  p <- file.path(PROJECT_ROOT, "store", "clean", "policy.yaml")
  if (!file.exists(p)) {
    return(list(exclude_training_row_if_frac_filled_24h_gt = 0.5,
                skip_origin_if_in_long_gap = TRUE))
  }
  yaml::read_yaml(p)
}

decomp_selection_end <- function(cfg = decomp_cfg(), times = NULL) {
  raw <- cfg$selection_end
  if (is.null(raw) || identical(raw, "null") || (is.character(raw) && !nzchar(raw))) {
    pp <- tryCatch(pp_cfg(), error = function(e) NULL)
    raw <- if (!is.null(pp)) pp$selection_end else "2023-07-01 00:00"
  }
  sel <- pp_parse_time(as.character(raw), "Asia/Kolkata")
  if (!is.null(times) && length(times)) {
    tmax <- max(times, na.rm = TRUE)
    if (is.finite(as.numeric(tmax)) && sel > tmax) sel <- tmax
  }
  sel
}

.decomp_fn <- function(entry) {
  if (!exists(entry$fn, envir = .GlobalEnv, inherits = TRUE))
    stop("Decomposition function not found: ", entry$fn,
         " — add it in R/31 or R/32 and keep the yaml `fn` in sync.")
  get(entry$fn, envir = .GlobalEnv, inherits = TRUE)
}

register_decomp_method <- function(entry) {
  cfg <- decomp_cfg()
  ids <- vapply(cfg$methods, function(m) m$id, character(1))
  if (entry$id %in% ids) {
    cfg$methods[[match(entry$id, ids)]] <- entry
  } else {
    cfg$methods[[length(cfg$methods) + 1L]] <- entry
  }
  .GlobalEnv$.DECOMP_CFG <- cfg
  invisible(entry)
}

decomp_methods <- function(cfg = decomp_cfg()) {
  cfg$methods
}

method_full_id <- function(id, scale) paste0(id, "__", scale)

method_scales <- function(variable) {
  if (variable %in% DECOMP_POLLUTANTS) c("raw", "log") else "raw"
}

method_variables <- function(entry, available) {
  want <- entry$variables %||% "pollutants"
  if (identical(want, "all")) intersect(DECOMP_METVARS, available)
  else intersect(DECOMP_POLLUTANTS, available)
}

apply_decomp_scale <- function(x, scale, variable) {
  x <- as.numeric(x)
  if (identical(scale, "log")) {
    if (!variable %in% DECOMP_POLLUTANTS)
      stop("log1p scale is only for pollutants; got ", variable)
    return(log1p(pmax(x, 0)))
  }
  x
}

filter_length <- function(filter) {
  switch(tolower(filter), haar = 2L, d4 = 4L, la8 = 8L, 2L)
}

warmup_length <- function(j, L) as.integer((2^j - 1L) * (L - 1L) + 1L)

pkg_versions <- function(pkgs) {
  inst <- rownames(installed.packages())
  out <- list()
  for (p in pkgs) {
    out[[p]] <- if (p %in% inst) as.character(utils::packageVersion(p)) else NA_character_
  }
  out
}

git_commit_hash <- function() {
  tryCatch({
    wd <- PROJECT_ROOT
    sys <- suppressWarnings(system(paste("git -C", shQuote(wd), "rev-parse HEAD"),
                                   intern = TRUE, ignore.stderr = TRUE))
    if (length(sys) && !grepl("fatal", sys[1], ignore.case = TRUE)) sys[1] else NA_character_
  }, error = function(e) NA_character_)
}

clean_series_hash <- function() {
  p <- file.path(PROJECT_ROOT, "store", "clean", "series.parquet")
  if (!file.exists(p)) return(NA_character_)
  inf <- file.info(p)
  digest::digest(list(size = inf$size, mtime = as.numeric(inf$mtime)), algo = "xxhash64")
}

decomp_input_hash <- function(cfg = decomp_cfg()) {
  digest::digest(list(
    series = clean_series_hash(),
    yaml = yaml::as.yaml(cfg),
    git = git_commit_hash()
  ), algo = "xxhash64")
}

read_clean_long <- function() {
  p <- file.path(PROJECT_ROOT, "store", "clean", "series.parquet")
  if (!file.exists(p)) stop("Missing ", p, " — run Rscript run_preprocess.R first.")
  tibble::as_tibble(arrow::read_parquet(p))
}

# ---- engine ----------------------------------------------------------------

.method_available <- function(entry) {
  fn_ok <- exists(entry$fn, envir = .GlobalEnv, inherits = TRUE)
  if (!fn_ok) return(FALSE)
  if (isTRUE(entry$optional)) {
    need <- switch(entry$fn,
      decomp_emd = "EMD",
      decomp_ceemdan = "Rlibeemd",
      decomp_vmd = "VMDecomp",
      decomp_ssa = "Rssa",
      decomp_mstl = "forecast",
      character()
    )
    if (length(need) && !need %in% rownames(installed.packages())) return(FALSE)
  }
  TRUE
}

run_decomp <- function(cfg = NULL, methods = NULL, force = FALSE,
                       do_diagnostics = TRUE, do_screen = TRUE) {
  if (is.null(cfg)) {
    .GlobalEnv$.DECOMP_CFG <- NULL
    cfg <- decomp_cfg()
  }
  .GlobalEnv$.DECOMP_CFG <- cfg
  dir.create(file.path(PROJECT_ROOT, "store", "decomp"), recursive = TRUE, showWarnings = FALSE)
  long <- read_clean_long()
  entries <- decomp_methods(cfg)
  if (!is.null(methods)) {
    entries <- Filter(function(m) m$id %in% methods, entries)
  }
  ih <- decomp_input_hash(cfg)
  decomp_log("=== decomp input_hash=", ih, " n_rows=", nrow(long), " ===")

  old_plan <- NULL
  n_w <- max(1L, min(8L, future::availableCores() - 1L))
  if (n_w > 1L && requireNamespace("future.apply", quietly = TRUE)) {
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)
    future::plan(future::multisession, workers = n_w)
    decomp_log("workers=", n_w)
  }

  for (entry in entries) {
    if (!.method_available(entry)) {
      decomp_log("SKIP ", entry$id, " (function or package missing)")
      next
    }
    fn <- .decomp_fn(entry)
    # D1 gate on a synthetic series once per method (both scales).
    for (sc in c("raw", "log")) {
      if (!d1_pass_synthetic(entry, fn, sc)) {
        decomp_log("D1 FAIL ", entry$id, "__", sc, " — not written")
        next
      }
      decomp_log("D1 pass ", entry$id, "__", sc)
      run_one_method_scale(long, entry, fn, sc, cfg, ih, force)
    }
  }

  if (isTRUE(do_diagnostics)) run_decomp_diagnostics(cfg = cfg)
  if (isTRUE(do_screen)) run_decomp_screen(cfg = cfg)
  invisible(TRUE)
}

run_one_method_scale <- function(long, entry, fn, scale, cfg, input_hash, force) {
  mid <- method_full_id(entry$id, scale)
  stations <- unique(long$station)
  avail_vars <- unique(long$variable)
  vars <- method_variables(entry, avail_vars)
  if (identical(scale, "log")) vars <- intersect(vars, DECOMP_POLLUTANTS)
  if (!length(vars)) return(invisible(NULL))

  jobs <- expand.grid(station = stations, variable = vars, stringsAsFactors = FALSE)
  n_series <- nrow(jobs)
  n_times <- as.integer(median(vapply(stations, function(s) {
    length(unique(long$timestamp[long$station == s]))
  }, integer(1))))

  partial <- FALSE
  proj <- benchmark_method(long, entry, fn, scale, cfg)
  decomp_log(mid, " projected hours=", round(proj$hours, 3),
             " s_per_1k=", round(proj$s_per_1k, 3))
  if (isTRUE(proj$hours > as.numeric(cfg$max_hours_per_method_scale %||% 6))) {
    vars <- intersect(vars, c("PM2.5", "PM10"))
    jobs <- expand.grid(station = stations, variable = vars, stringsAsFactors = FALSE)
    partial <- TRUE
    decomp_log(mid, " CAP -> PM2.5/PM10 only (partial)")
  }

  man_path <- decomp_manifest_path(mid)
  if (!force && file.exists(man_path)) {
    man <- tryCatch(jsonlite::fromJSON(man_path, simplifyVector = TRUE),
                    error = function(e) NULL)
    if (!is.null(man) && identical(man$input_hash, input_hash) &&
        isTRUE(man$complete) && !isTRUE(man$partial != partial)) {
      decomp_log(mid, " manifest hash match — skip")
      return(invisible(NULL))
    }
  }

  t0 <- proc.time()[3]
  max_add <- 0
  done <- list()
  todo <- integer(0)
  for (i in seq_len(nrow(jobs))) {
    stn <- jobs$station[i]; v <- jobs$variable[i]
    out_p <- decomp_parquet_path(mid, stn, v)
    if (!force && file.exists(out_p) && file.exists(man_path)) {
      man <- tryCatch(jsonlite::fromJSON(man_path, simplifyVector = TRUE),
                      error = function(e) NULL)
      if (!is.null(man) && identical(man$input_hash, input_hash)) {
        decomp_log("skip existing ", mid, " ", stn, " ", v)
        done[[length(done) + 1L]] <- list(station = stn, variable = v)
        next
      }
    }
    todo <- c(todo, i)
  }

  do_one <- function(i) {
    stn <- jobs$station[i]; v <- jobs$variable[i]
    sv <- long %>% dplyr::filter(.data$station == !!stn, .data$variable == !!v) %>%
      dplyr::arrange(.data$timestamp)
    res <- compute_decomp_series(sv, entry, fn, scale, cfg)
    if (is.null(res)) {
      return(list(ok = FALSE, station = stn, variable = v, max_add = NA_real_, n = 0L))
    }
    write_decomp_parquet(res$df, decomp_parquet_path(mid, stn, v))
    list(ok = TRUE, station = stn, variable = v, max_add = res$max_add, n = nrow(res$df))
  }

  n_workers <- tryCatch(as.integer(future::nbrOfWorkers()), error = function(e) 1L)
  use_par <- length(todo) > 1L && n_workers > 1L &&
    requireNamespace("future.apply", quietly = TRUE)

  outs <- if (use_par) {
    future.apply::future_lapply(
      todo, do_one, future.seed = TRUE,
      future.packages = c("arrow", "dplyr", "waveslim", "forecast")
    )
  } else {
    lapply(todo, do_one)
  }

  for (o in outs) {
    if (!isTRUE(o$ok)) {
      decomp_log("FAIL compute ", mid, " ", o$station, " ", o$variable)
      next
    }
    max_add <- max(max_add, o$max_add, na.rm = TRUE)
    done[[length(done) + 1L]] <- list(station = o$station, variable = o$variable)
    decomp_log("wrote ", mid, " ", o$station, " ", o$variable, " rows=", o$n)
  }
  elapsed <- proc.time()[3] - t0
  write_decomp_manifest(entry, scale, cfg, input_hash, done, partial, elapsed, max_add)
  invisible(elapsed)
}

compute_decomp_series <- function(sv, entry, fn, scale, cfg) {
  x <- apply_decomp_scale(sv$value_filled_causal, scale, sv$variable[1])
  n <- length(x)
  is_filled <- !is.na(sv$fill_method)
  frac24 <- as.numeric(sv$frac_filled_24h)
  in_long <- as.logical(sv$in_long_gap)
  in_long[is.na(in_long)] <- FALSE
  frac24[is.na(frac24)] <- 0
  pol <- decomp_policy()
  thr <- as.numeric(pol$exclude_training_row_if_frac_filled_24h_gt %||% 0.5)

  if (identical(entry$family, "causal_full")) {
    M <- fn(x, entry$params %||% list())
    if (is.null(dim(M))) M <- matrix(M, ncol = 1)
    comps <- colnames(M)
    if (is.null(comps) || any(!nzchar(comps)))
      stop(entry$id, " did not name its columns")
    L <- filter_length(entry$params$filter %||% "haar")
    J <- as.integer(entry$params$J)
    warmup <- matrix(FALSE, n, ncol(M))
    colnames(warmup) <- comps
    for (j in seq_len(J)) {
      Lj <- warmup_length(j, L)
      wcol <- paste0("W", j); vcol <- paste0("V", j)
      if (wcol %in% comps) warmup[, wcol] <- seq_len(n) >= Lj
      if (vcol %in% comps) warmup[, vcol] <- seq_len(n) >= Lj
    }
    Lj_deep <- warmup_length(J, L)
    valid_wu <- seq_len(n) >= Lj_deep
    support <- Lj_deep
    frac_w <- .frac_filled_support(is_filled, support)
    df <- tibble::as_tibble(M)
    for (cn in comps) df[[paste0("valid_warmup_", cn)]] <- warmup[, cn]
    df$timestamp <- sv$timestamp
    df$valid_warmup <- valid_wu
    df$frac_filled_window <- frac_w
  } else {
    W <- as.integer(entry$params$window_h %||% cfg$window_h %||% 2048L)
    pad <- as.integer(entry$params$pad %||% 0L)
    ckpt <- file.path(decomp_root(), "_ckpt", entry$id, sv$station[1],
                      sv$variable[1], "partial.rds")
    dir.create(dirname(ckpt), recursive = TRUE, showWarnings = FALSE)
    .GlobalEnv$.DECOMP_CKPT_PATH <- ckpt
    on.exit({ .GlobalEnv$.DECOMP_CKPT_PATH <- NULL }, add = TRUE)
    M <- run_trailing_series(x, fn, entry$params %||% list(), W, pad,
                             station = sv$station[1], variable = sv$variable[1])
    comps <- colnames(M)
    df <- tibble::as_tibble(M)
    df$timestamp <- sv$timestamp
    df$valid_warmup <- seq_len(n) >= W
    df$frac_filled_window <- .frac_filled_support(is_filled, W)
    df$frac_filled_window[!df$valid_warmup] <- NA_real_
  }

  if (isTRUE(entry$additive)) {
    x_hat <- .reconstruct_row(df, entry)
    df$resid <- x - x_hat
    max_add <- max(abs(df$resid[is.finite(df$resid) & df$valid_warmup]), na.rm = TRUE)
    if (!is.finite(max_add)) max_add <- 0
  } else {
    max_add <- NA_real_
  }

  df$valid_basic <- df$valid_warmup
  df$valid_strict <- df$valid_warmup & (frac24 <= thr) & !in_long
  df$valid_strict[is.na(df$valid_strict)] <- FALSE
  list(df = df, max_add = max_add)
}

.frac_filled_support <- function(is_filled, support) {
  n <- length(is_filled)
  cs <- c(0, cumsum(as.numeric(is_filled)))
  out <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    lo <- max(1L, i - support + 1L)
    out[i] <- (cs[i + 1L] - cs[lo]) / (i - lo + 1L)
  }
  out
}

.reconstruct_row <- function(df, entry) {
  comps <- decomp_component_names(entry, df)
  if (!length(comps)) return(rep(NA_real_, nrow(df)))
  mat <- as.matrix(df[, comps, drop = FALSE])
  rowSums(mat, na.rm = FALSE)
}

decomp_component_names <- function(entry, df = NULL) {
  if (!is.null(entry$component_names) && length(entry$component_names))
    return(unlist(entry$component_names))
  if (!is.null(df)) {
    drop <- c("timestamp", "valid_warmup", "valid_basic", "valid_strict",
              "frac_filled_window", "resid", "n_imf_raw")
    drop <- c(drop, grep("^valid_warmup_", names(df), value = TRUE))
    return(setdiff(names(df), drop))
  }
  J <- as.integer(entry$params$J %||% 0L)
  switch(entry$fn,
    decomp_coef_haar =, decomp_coef_modwt =
      c(paste0("W", seq_len(J)), paste0("V", seq_len(J))),
    decomp_mra_haar =, decomp_mra_waveslim =
      c(paste0("D", seq_len(J)), paste0("S", J)),
    decomp_emd =, decomp_ceemdan = c(paste0("IMF", 1:6), "RES"),
    decomp_vmd = c(paste0("M", seq_len(as.integer(entry$params$K %||% 6L)))),
    decomp_mstl = c("TREND", "SEAS24", "SEAS168", "REM"),
    decomp_ssa = c(paste0("RC", 1:8), "REM"),
    decomp_ma_rem = c("MA", "REM"),
    character()
  )
}

d1_pass_synthetic <- function(entry, fn, scale, tol = 1e-9) {
  set.seed(7)
  W <- as.integer(entry$params$window_h %||% decomp_cfg()$window_h %||% 256L)
  W_syn <- min(W, 256L)
  J <- as.integer(entry$params$J %||% 1L)
  L <- filter_length(entry$params$filter %||% "haar")
  need <- warmup_length(J, L) + 250L
  n <- if (identical(entry$family, "trailing")) W_syn + 220L else max(400L, need)
  W <- if (identical(entry$family, "trailing")) W_syn else W
  x <- 20 + 5 * sin(2 * pi * seq_len(n) / 24) + rnorm(n, 0, 0.2)
  x <- pmax(x, 0)
  if (identical(scale, "log")) x <- log1p(x)
  bump <- if (identical(scale, "log")) 0.5 else 50
  tsamp <- unique(pmin(pmax(c(W + 10L, as.integer(n / 2), n - 205L)), n - 201L))
  if (identical(entry$family, "trailing")) tsamp <- tsamp[tsamp >= W]
  if (!length(tsamp)) return(TRUE)
  ks <- c(1L, 5L, 24L, 200L)
  for (t0 in tsamp) {
    base <- .decomp_at_t(x, t0, entry, fn, W)
    if (is.null(base) || !all(is.finite(base))) next
    for (k in ks) {
      xp <- x
      xp[t0 + k] <- xp[t0 + k] + bump
      new <- .decomp_at_t(xp, t0, entry, fn, W)
      if (is.null(new)) return(FALSE)
      if (max(abs(base - new), na.rm = TRUE) > tol) return(FALSE)
    }
  }
  TRUE
}

.decomp_at_t <- function(x, t, entry, fn, W) {
  if (identical(entry$family, "causal_full")) {
    M <- fn(x, entry$params %||% list())
    if (is.null(dim(M))) M <- matrix(M, ncol = 1)
    return(as.numeric(M[t, ]))
  }
  pad <- as.integer(entry$params$pad %||% 0L)
  lo <- t - W + 1L
  if (lo < 1L) return(NULL)
  win <- x[lo:t]
  xx <- if (pad > 0L) c(win, ar_forecast_ls(win, pad)) else win
  p2 <- entry$params %||% list()
  p2$.t <- t
  M <- tryCatch(fn(xx, p2), error = function(e) NULL)
  if (is.null(M)) return(NULL)
  if (is.null(dim(M))) M <- matrix(M, ncol = 1)
  as.numeric(M[length(win), ])
}

benchmark_method <- function(long, entry, fn, scale, cfg) {
  n_win <- as.integer(cfg$n_benchmark_windows %||% 50L)
  sv <- long %>%
    dplyr::filter(.data$variable %in% DECOMP_POLLUTANTS) %>%
    dplyr::group_by(.data$station, .data$variable) %>%
    dplyr::filter(dplyr::n() == max(dplyr::n())) %>%
    dplyr::ungroup()
  if (!nrow(sv)) sv <- long
  one <- sv %>% dplyr::filter(.data$station == sv$station[1],
                              .data$variable == sv$variable[1]) %>%
    dplyr::arrange(.data$timestamp)
  x <- apply_decomp_scale(one$value_filled_causal, scale, one$variable[1])
  n <- length(x)
  n_stn <- length(unique(long$station))
  n_var <- length(method_variables(entry, unique(long$variable)))
  if (identical(scale, "log")) n_var <- min(n_var, length(DECOMP_POLLUTANTS))
  n_w <- max(1L, min(8L, future::availableCores() - 1L))

  if (identical(entry$family, "causal_full")) {
    t0 <- proc.time()[3]
    invisible(fn(x, entry$params %||% list()))
    dt <- max(proc.time()[3] - t0, 1e-6)
    s_per_1k <- dt / n * 1000
    hours <- dt * n_stn * n_var / n_w / 3600
    return(list(s_per_1k = s_per_1k, hours = hours))
  }
  W <- as.integer(entry$params$window_h %||% cfg$window_h %||% 2048L)
  W <- min(W, n)
  pad <- as.integer(entry$params$pad %||% 0L)
  starts <- unique(as.integer(seq(W, n, length.out = min(n_win, max(1L, n - W + 1L)))))
  t0 <- proc.time()[3]
  for (t in starts) {
    win <- x[(t - W + 1L):t]
    xx <- if (pad > 0L) c(win, ar_forecast_ls(win, pad)) else win
    try(fn(xx, entry$params %||% list()), silent = TRUE)
  }
  dt <- max(proc.time()[3] - t0, 1e-6)
  per <- dt / length(starts)
  n_ts <- max(1L, n - W + 1L)
  s_per_1k <- per * 1000
  hours <- per * n_ts * n_stn * n_var / n_w / 3600
  list(s_per_1k = s_per_1k, hours = hours)
}
