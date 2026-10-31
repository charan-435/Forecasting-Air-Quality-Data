# Write the clean hourly store, policy, and a table-only quality report.

CLEAN_COLS <- c(
  "station", "variable", "timestamp",
  "value_hourly_raw", "n_sub_valid", "n_sub_expected",
  "value_masked", "value_filled_causal", "fill_method",
  "gap_id", "gap_len_sofar", "hours_since_observed", "in_long_gap",
  "frac_filled_24h", "frac_filled_168h",
  "is_na_source", "is_low_coverage", "is_duplicate_ts",
  "is_out_of_bounds", "is_negative", "is_stuck", "is_pm_ratio", "is_spike",
  "is_masked", "is_scorable"
)

.pp_write_parquet <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".tmp")
  arrow::write_parquet(df, tmp, compression = "zstd")
  if (file.exists(path)) unlink(path)
  ok <- file.rename(tmp, path)
  if (!isTRUE(ok) && file.exists(tmp)) {
    file.copy(tmp, path, overwrite = TRUE)
    unlink(tmp)
  }
  path
}

write_policy <- function(cfg, path = NULL, store_dir = NULL) {
  if (is.null(path))
    path <- file.path(pp_clean_dir(cfg$active, store_dir), "policy.yaml")
  pol <- list(
    target_must_be_scorable = TRUE,
    exclude_training_row_if_frac_filled_24h_gt = 0.5,
    skip_origin_if_frac_filled_24h_gt = 0.25,
    skip_origin_if_in_long_gap = TRUE,
    long_gap_hours = cfg$long_gap_hours,
    min_daily_hours = cfg$min_daily_hours,
    notes = list(
      "A training or evaluation target must be is_scorable.",
      "Exclude a training row if frac_filled_24h at its input time is > 0.5.",
      "Skip a forecast origin if frac_filled_24h at the origin is > 0.25, or if in_long_gap is true at the origin."
    )
  )
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(pol, path)
  path
}

write_wide_and_daily <- function(long, cfg, store_dir = NULL) {
  out_dir <- pp_clean_dir(cfg$active, store_dir)
  long$station <- as.character(long$station)
  long$variable <- as.character(long$variable)
  stations <- unique(long$station)
  extras <- list.files(out_dir, pattern = "^(wide|daily)_.+\\.parquet$")
  for (f in extras) {
    st <- sub("^(wide|daily)_(.+)\\.parquet$", "\\2", f)
    if (!st %in% stations) unlink(file.path(out_dir, f))
  }
  for (stn in stations) {
    sv <- long[long$station == stn, ]
    wide_val <- sv %>%
      dplyr::select(timestamp, variable, value_filled_causal) %>%
      tidyr::pivot_wider(names_from = variable, values_from = value_filled_causal)
    wide_mask <- sv %>%
      dplyr::select(timestamp, variable, is_masked) %>%
      tidyr::pivot_wider(names_from = variable, values_from = is_masked,
                         names_glue = "{variable}_is_masked")
    wide <- dplyr::left_join(wide_val, wide_mask, by = "timestamp")
    wide$station <- stn
    .pp_write_parquet(wide, file.path(out_dir, paste0("wide_", stn, ".parquet")))
    daily <- sv %>%
      dplyr::mutate(day = as.Date(.data$timestamp, tz = "Asia/Kolkata")) %>%
      dplyr::filter(.data$is_scorable) %>%
      dplyr::group_by(station, variable, day) %>%
      dplyr::summarise(
        n_hours = dplyr::n(),
        value = mean(.data$value_masked, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::filter(.data$n_hours >= cfg$min_daily_hours)
    .pp_write_parquet(daily, file.path(out_dir, paste0("daily_", stn, ".parquet")))
  }
}

.gap_report <- function(long) {
  # total gap length for the quality report only — not stored on rows
  g <- long %>%
    dplyr::filter(!is.na(gap_id)) %>%
    dplyr::group_by(station, variable, gap_id) %>%
    dplyr::summarise(len = dplyr::n(), .groups = "drop")
  if (!nrow(g)) {
    return(list(hist = tibble::tibble(), n_station_wide = 0L, n_single = 0L, gaps = g))
  }
  hist <- g %>%
    dplyr::mutate(bucket = .gap_bucket(len)) %>%
    dplyr::count(station, variable, bucket, name = "n_gaps")
  # station-wide: same gap hours missing on all variables
  miss <- long %>%
    dplyr::group_by(station, timestamp) %>%
    dplyr::summarise(
      n_var = dplyr::n(),
      n_miss = sum(.data$is_masked),
      .groups = "drop"
    )
  n_wide <- sum(miss$n_miss == miss$n_var & miss$n_miss > 0)
  n_single <- sum(miss$n_miss > 0 & miss$n_miss < miss$n_var)
  list(hist = hist, n_station_wide = n_wide, n_single = n_single, gaps = g)
}

write_data_quality_md <- function(long, stuck_dist, bench, choice, warnings,
                                  n_dup, skipped, path = NULL) {
  if (is.null(path)) path <- file.path(PROJECT_ROOT, "store", "DATA_QUALITY.md")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  cat("# Data quality (tables only, no plots)\n\n", file = con)
  cat("Hour **t** is the mean of readings in **(t − 1h, t]** (end-labelled, IST).\n",
      "Paper sources skip quality/imputation (`skip_preprocess: true`).\n\n",
      file = con, sep = "")
  if (length(skipped)) {
    cat("Skipped preprocess for: ", paste(skipped, collapse = ", "), "\n\n", file = con)
  }
  if (length(warnings)) {
    cat("## Warnings\n\n", file = con)
    for (w in warnings) cat("- ", w, "\n", file = con, sep = "")
    cat("\n", file = con)
  }
  cat("Duplicate raw timestamps averaged: ", as.integer(n_dup), "\n\n", file = con, sep = "")

  cat("## Period and missing share\n\n", file = con)
  cat("| station | variable | start | end | n | pct_masked |\n|---|---|---|---|---|---|\n", file = con)
  cov <- long %>%
    dplyr::group_by(station, variable) %>%
    dplyr::summarise(
      start = min(timestamp), end = max(timestamp), n = dplyr::n(),
      pct_masked = round(100 * mean(is_masked), 2), .groups = "drop"
    )
  for (i in seq_len(nrow(cov))) {
    cat(sprintf("| %s | %s | %s | %s | %d | %.2f |\n",
                cov$station[i], cov$variable[i],
                format(cov$start[i], "%Y-%m-%d %H:%M"),
                format(cov$end[i], "%Y-%m-%d %H:%M"),
                cov$n[i], cov$pct_masked[i]), file = con)
  }

  cat("\n## Missingness by month (%)\n\n", file = con)
  cat("| station | variable | month | n | pct_masked |\n|---|---|---|---|---|\n", file = con)
  mon <- long %>%
    dplyr::mutate(month = format(timestamp, "%Y-%m")) %>%
    dplyr::group_by(station, variable, month) %>%
    dplyr::summarise(n = dplyr::n(), pct_masked = round(100 * mean(is_masked), 1),
                     .groups = "drop")
  for (i in seq_len(nrow(mon))) {
    cat(sprintf("| %s | %s | %s | %d | %.1f |\n",
                mon$station[i], mon$variable[i], mon$month[i],
                mon$n[i], mon$pct_masked[i]), file = con)
  }

  cat("\n## Missingness by hour-of-day (%)\n\n", file = con)
  cat("| station | variable |", paste0("h", 0:23, collapse = " | "), "|\n", file = con)
  cat("|---|---|", paste(rep("---", 24), collapse = "|"), "|\n", file = con)
  hod <- long %>%
    dplyr::mutate(h = lubridate::hour(timestamp)) %>%
    dplyr::group_by(station, variable, h) %>%
    dplyr::summarise(pct = round(100 * mean(is_masked), 1), .groups = "drop") %>%
    tidyr::pivot_wider(names_from = h, values_from = pct, names_prefix = "h")
  hcols <- paste0("h", 0:23)
  for (c in hcols) if (!c %in% names(hod)) hod[[c]] <- NA
  for (i in seq_len(nrow(hod))) {
    cat("| ", hod$station[i], " | ", hod$variable[i], " | ",
        paste(sprintf("%.1f", as.numeric(hod[i, hcols])), collapse = " | "),
        " |\n", file = con, sep = "")
  }

  gr <- .gap_report(long)
  cat("\n## Gap-length counts (report only; total length is not in the store)\n\n", file = con)
  cat("| station | variable | bucket | n_gaps |\n|---|---|---|---|\n", file = con)
  if (nrow(gr$hist)) {
    for (i in seq_len(nrow(gr$hist))) {
      cat(sprintf("| %s | %s | %s | %d |\n",
                  gr$hist$station[i], gr$hist$variable[i],
                  gr$hist$bucket[i], gr$hist$n_gaps[i]), file = con)
    }
  }
  cat("\nStation-wide missing hours: ", gr$n_station_wide,
      " ; single-variable missing hours: ", gr$n_single, "\n\n", file = con, sep = "")

  cat("## Flag counts\n\n", file = con)
  flags <- c("is_na_source", "is_low_coverage", "is_duplicate_ts", "is_out_of_bounds",
             "is_negative", "is_stuck", "is_pm_ratio", "is_spike", "is_masked")
  cat("| station | variable |", paste(flags, collapse = " | "), "|\n|---|---|",
      paste(rep("---", length(flags)), collapse = "|"), "|\n", file = con)
  fc <- long %>%
    dplyr::group_by(station, variable) %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(flags), ~ sum(.x, na.rm = TRUE)),
                     .groups = "drop")
  for (i in seq_len(nrow(fc))) {
    cat("| ", fc$station[i], " | ", fc$variable[i], " | ",
        paste(as.integer(unlist(fc[i, flags])), collapse = " | "),
        " |\n", file = con, sep = "")
  }

  spikes <- long %>% dplyr::filter(is_spike) %>%
    dplyr::mutate(day = as.Date(timestamp, tz = "Asia/Kolkata")) %>%
    dplyr::count(station, variable, day, name = "n_spike")
  cat("\n## Spike flags by date\n\n", file = con)
  if (!nrow(spikes)) cat("None.\n\n", file = con)
  else {
    cat("| station | variable | day | n_spike |\n|---|---|---|---|\n", file = con)
    for (i in seq_len(min(nrow(spikes), 200L))) {
      cat(sprintf("| %s | %s | %s | %d |\n", spikes$station[i], spikes$variable[i],
                  as.character(spikes$day[i]), spikes$n_spike[i]), file = con)
    }
    if (nrow(spikes) > 200L) cat("\n_(truncated)_\n", file = con)
    cat("\n", file = con)
  }

  if (!is.null(stuck_dist) && nrow(stuck_dist)) {
    cat("## Stuck-run length distribution (for stuck_hours overrides)\n\n", file = con)
    cat("| station | variable | n_runs | p50 | p90 | p99 | max | n_ge_default |\n|---|---|---|---|---|---|---|---|\n",
        file = con)
    for (i in seq_len(nrow(stuck_dist))) {
      cat(sprintf("| %s | %s | %s | %s | %s | %s | %s | %s |\n",
                  stuck_dist$station[i], stuck_dist$variable[i],
                  stuck_dist$n_runs[i], stuck_dist$p50[i], stuck_dist$p90[i],
                  stuck_dist$p99[i], stuck_dist$max_run[i],
                  stuck_dist$n_ge_default[i]), file = con)
    }
    cat("\n", file = con)
  }

  cat("## Imputation choices\n\n", file = con)
  if (is.null(choice) || !length(choice)) {
    cat("Skipped (paper dataset) or fallback M4.\n\n", file = con)
  } else {
    cat("| variable | 1-3 | 4-24 | 25-72 | >72 |\n|---|---|---|---|---|\n", file = con)
    vars <- unique(sub("\\|.*", "", names(choice)))
    for (v in vars) {
      cat(sprintf("| %s | %s | %s | %s | %s |\n", v,
                  choice[[paste(v, "1-3", sep = "|")]] %||% "",
                  choice[[paste(v, "4-24", sep = "|")]] %||% "",
                  choice[[paste(v, "25-72", sep = "|")]] %||% "",
                  choice[[paste(v, ">72", sep = "|")]] %||% ""), file = con)
    }
    cat("\n", file = con)
  }
  if (!is.null(bench) && nrow(bench)) {
    cat("## Imputation benchmark MAE\n\n", file = con)
    cat("| station | variable | method | bucket | n | mae | mae_log1p |\n|---|---|---|---|---|---|---|\n",
        file = con)
    b2 <- bench %>% dplyr::filter(method != "M4_simult")
    for (i in seq_len(nrow(b2))) {
      cat(sprintf("| %s | %s | %s | %s | %d | %.4f | %.4f |\n",
                  b2$station[i], b2$variable[i], b2$method[i], b2$bucket[i],
                  b2$n[i], b2$mae[i], b2$mae_log1p[i]), file = con)
    }
    cat("\n", file = con)
  }
  path
}

write_store_readme <- function(store_dir = NULL) {
  path <- file.path(pp_clean_dir("paper", store_dir), "README.md")
  writeLines(c(
    "# Clean hourly store (Phase 1a)",
    "",
    "Built by `Rscript run_preprocess.R` from `config/preprocess.yaml`.",
    "No plots. Tables live in `store/DATA_QUALITY.md`.",
    "",
    "## Time labelling",
    "",
    "Hour **t** is the mean of readings whose interval ends in **(t − 1h, t]**.",
    "A value stamped t is fully known at t. Start-labelled sources are shifted",
    "forward by their native interval before binning. All timestamps are `Asia/Kolkata`.",
    "",
    "Paper CSVs are already hourly and end-labelled; they are stored as-is",
    "(`skip_preprocess: true`). Quality flags stay false except source NA,",
    "and no causal fill is applied.",
    "",
    "## `series.parquet`",
    "",
    paste("-", CLEAN_COLS, collapse = "\n"),
    "",
    "- `value_filled_causal` is a model input only. Never score it.",
    "- `is_scorable = !is_masked`. Only scorable hours are evaluation targets.",
    "- `fill_method` is NA on observed hours. A non-NA fill_method is never scorable.",
    "- `gap_len_sofar` is causal (hours since the gap started). Total gap length is not stored.",
    "",
    "## Other files",
    "",
    "- `wide_<station>.parquet`: `value_filled_causal` plus `<var>_is_masked`.",
    "- `daily_<station>.parquet`: IST calendar-day mean of scorable hours, days with ≥ min_daily_hours.",
    "- `policy.yaml`: exclusion rules for later phases.",
    "- `../quality/imputation_benchmark.parquet` (raw sources only; not written for paper).",
    "",
    "## Dataset switch",
    "",
    "- `active: paper` — CPCB.csv / ID1.csv, already hourly; quality and imputation are skipped.",
    "- `active: delhi` — 15-min CPCB CAAQMS (ITO, R K Puram); full causal preprocess.",
    "- `active: shillong` — 15-min CPCB CAAQMS (Lumpyngngad, JN Stadium); full causal preprocess.",
    "",
    "Override: `Rscript run_preprocess.R paper`, `delhi`, or `shillong`."
  ), path)
  path
}

write_clean_store <- function(long, cfg, stuck_dist, bench, choice, warnings,
                              n_dup, skipped, store_dir = NULL) {
  long$station <- as.character(long$station)
  long$variable <- as.character(long$variable)
  long <- long[, intersect(CLEAN_COLS, names(long))]
  miss <- setdiff(CLEAN_COLS, names(long))
  if (length(miss)) stop("clean series missing columns: ", paste(miss, collapse = ", "))
  clean_dir <- pp_clean_dir(cfg$active, store_dir)
  dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
  .pp_write_parquet(long, file.path(clean_dir, "series.parquet"))
  stns <- unique(long$station)
  stale <- list.files(clean_dir, pattern = "^(wide|daily)_.*\\.parquet$", full.names = TRUE)
  keep <- file.path(clean_dir, c(paste0("wide_", stns, ".parquet"),
                                 paste0("daily_", stns, ".parquet")))
  unlink(setdiff(stale, keep))
  write_wide_and_daily(long, cfg, store_dir = clean_dir)
  write_policy(cfg, store_dir = clean_dir)
  qdir <- if (identical(normalizePath(clean_dir, winslash = "/", mustWork = FALSE),
                        normalizePath(file.path(PROJECT_ROOT, "store", "clean"),
                                      winslash = "/", mustWork = FALSE))) {
    file.path(PROJECT_ROOT, "store", "quality")
  } else {
    file.path(dirname(clean_dir), "quality")
  }
  if (!is.null(bench) && nrow(bench)) {
    dir.create(qdir, recursive = TRUE, showWarnings = FALSE)
    .pp_write_parquet(bench, file.path(qdir, "imputation_benchmark.parquet"))
  }
  qd_md <- file.path(dirname(qdir), "DATA_QUALITY.md")
  write_data_quality_md(long, stuck_dist, bench, choice, warnings, n_dup, skipped,
                        path = qd_md)
  write_store_readme(store_dir = clean_dir)
  invisible(long)
}

run_preprocess <- function(active = NULL, cfg_path = NULL, force = FALSE, cfg = NULL,
                           store_dir = NULL) {
  if (is.null(cfg)) {
    .GlobalEnv$.PP_CFG <- NULL
    cfg <- pp_cfg(cfg_path)
  }
  if (!is.null(active)) cfg$active <- active
  .GlobalEnv$.PP_CFG <- cfg
  sources <- Filter(function(s) identical(s$group, cfg$active), cfg$sources)
  if (!length(sources)) stop("No sources for active=", cfg$active)

  r_files <- c("R/20_ingest.R", "R/21_quality.R", "R/22_impute.R",
               "R/23_store_clean.R", "run_preprocess.R")
  hash <- digest::digest(list(
    active = cfg$active,
    yaml = yaml::as.yaml(cfg),
    code = lapply(r_files, function(f) {
      p <- file.path(PROJECT_ROOT, f)
      if (!file.exists(p)) return(NA)
      inf <- file.info(p)
      list(size = inf$size, mtime = as.numeric(inf$mtime))
    }),
    files = lapply(sources, function(s) {
      p <- file.path(PROJECT_ROOT, s$path)
      if (!nzchar(s$path %||% "") || !file.exists(p)) return(NA)
      inf <- file.info(p)
      list(size = inf$size, mtime = as.numeric(inf$mtime))
    })
  ), algo = "xxhash64")
  clean_dir <- pp_clean_dir(cfg$active, store_dir)
  hash_path <- file.path(clean_dir, ".preprocess_hash")
  out_path <- file.path(clean_dir, "series.parquet")
  if (!force && file.exists(out_path) && file.exists(hash_path) &&
      identical(readLines(hash_path, warn = FALSE)[1], hash)) {
    pp_log("unchanged hash ", hash, " — skip")
    return(invisible(hash))
  }

  pp_log("=== preprocess active=", cfg$active, " ===")
  pieces <- list()
  warnings <- character()
  n_dup <- 0L
  skipped <- character()
  stuck_dist <- NULL
  bench <- NULL
  choice <- NULL

  for (src in sources) {
    ing <- ingest_source(src, cfg)
    warnings <- c(warnings, ing$warnings)
    n_dup <- n_dup + ing$n_dup
    hourly <- ing$hourly
    if (isTRUE(src$skip_preprocess)) {
      pp_log(src$id, " skip_preprocess=true (already hourly / paper)")
      hourly <- skip_quality(hourly)
      hourly <- skip_impute(hourly, cfg)
      skipped <- c(skipped, src$id)
    } else {
      hourly <- quality_hourly(hourly, cfg)
      sd <- stuck_run_distribution(hourly, cfg)
      stuck_dist <- dplyr::bind_rows(stuck_dist, sd)
    }
    pieces[[src$id]] <- hourly
  }
  long <- dplyr::bind_rows(pieces)

  need_impute <- any(vapply(sources, function(s) !isTRUE(s$skip_preprocess), logical(1)))
  default_clean <- identical(
    normalizePath(clean_dir, winslash = "/", mustWork = FALSE),
    normalizePath(file.path(PROJECT_ROOT, "store", "clean"),
                  winslash = "/", mustWork = FALSE)
  )
  bench_path <- if (default_clean) {
    file.path(PROJECT_ROOT, "store", "quality", "imputation_benchmark.parquet")
  } else {
    file.path(dirname(clean_dir), "quality", "imputation_benchmark.parquet")
  }
  choice_path <- if (default_clean) {
    file.path(PROJECT_ROOT, "config", "imputation_choice.yaml")
  } else {
    file.path(clean_dir, "imputation_choice.yaml")
  }
  if (need_impute) {
    sel <- pp_parse_time(cfg$selection_end, "Asia/Kolkata")
    n_art <- as.integer(cfg$n_artificial_gaps %||% 500L)
    pp_log("imputation benchmark before ", format(sel), " n_art=", n_art)
    bench <- benchmark_imputation(long, cfg, n_art = n_art)
    choice <- choose_imputation(bench, fallback = "M4")
    write_imputation_choice(choice)
    filled <- list()
    for (stn in unique(long$station)) {
      st <- long %>% dplyr::filter(station == !!stn)
      times <- sort(unique(st$timestamp))
      train_idx <- which(times < sel)
      wide <- st %>%
        dplyr::select(timestamp, variable, value_masked) %>%
        tidyr::pivot_wider(names_from = variable, values_from = value_masked)
      m7_fits <- list(); m8_fits <- list()
      for (v in unique(st$variable)) {
        sv <- st %>% dplyr::filter(variable == !!v) %>% dplyr::arrange(timestamp)
        m7_fits[[v]] <- fit_m7(sv$value_masked, sv$timestamp,
                               which(sv$timestamp < sel))
        drv <- .m8_driver(v)
        m8_fits[[v]] <- if (!is.na(drv))
          fit_m8(wide, v, drv, times, train_idx) else NULL
      }
      filled[[stn]] <- impute_station(st, cfg, choice, m7_fits, m8_fits)
    }
    long <- dplyr::bind_rows(filled)
  } else {
    if (file.exists(bench_path)) unlink(bench_path)
    yaml::write_yaml(
      list(skipped = TRUE, note = "paper sources skip imputation"),
      choice_path
    )
  }

  long$is_scorable <- as.logical(long$is_scorable) & is.na(long$fill_method)
  write_clean_store(long, cfg, stuck_dist, bench, choice, warnings, n_dup, skipped,
                    store_dir = clean_dir)
  dir.create(dirname(hash_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(hash, hash_path)
  pp_log("wrote ", out_path, " rows=", nrow(long))
  invisible(long)
}
