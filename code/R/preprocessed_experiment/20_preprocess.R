# Phase 1b: mask bad values, causal impute, write cleaned store.
# Same steps as run_preprocess() but writes only under the experiment store
# so we do not overwrite code/config/imputation_choice.yaml.

PE_REASONS <- c("fill_code", "negative", "out_of_bounds", "stuck", "pm_ratio")

pe_rule_table <- function(cfg, pp) {
  data.frame(
    rule = PE_REASONS,
    source = c("this experiment (learned on training block)", "kaisen code/config/preprocess.yaml",
               "kaisen code/config/preprocess.yaml bounds", "kaisen stuck_hours (causal .flag_stuck)",
               "kaisen pm_ratio_max"),
    definition = c(
      sprintf("complete six-pollutant vector seen at >= %d distinct training hours", cfg$validity$fill_code_min_hours),
      "value < 0",
      "value outside [lower, upper] (per pollutant, see pollutant table)",
      sprintf("hour t where the run of identical values ending at t is >= %d h (start of a run is not rewritten)",
              as.integer(pp$stuck_hours$default)),
      sprintf("PM2.5 > %.2f x PM10 in the same hour; both PM values", pp$pm_ratio_max)),
    justification = c(
      "Synthetic fills (column-mean-like constants written into all six pollutants at once); sensors with 6+ decimal places cannot repeat a joint vector",
      "Concentrations cannot be negative",
      "Physically implausible for ambient air (repository bounds)",
      "A sensor reporting an identical averaged value for >= 6 h is frozen",
      "PM2.5 is a size fraction of PM10, so PM2.5 > PM10 beyond 10% instrument tolerance is impossible"),
    type = "invalid-value removal (not statistical outlier treatment)",
    action = "set to NA; causal fill as model input only; never a scored target",
    stringsAsFactors = FALSE)
}

pe_preprocess <- function(cfg) {
  pp <- pp_cfg()
  P <- cfg$pollutants
  out <- pe_dir(cfg, "results", "preprocessing")
  long <- pe_load_source(cfg)
  w <- pe_wide(long)
  times <- w$timestamp
  train_end <- pe_time(cfg$split$train_end, cfg)
  fc <- pe_fill_codes(w, P, times <= train_end, cfg$validity$fill_code_min_hours)
  pm_bad <- is.finite(w$`PM2.5`) & is.finite(w$PM10) & w$`PM2.5` > pp$pm_ratio_max * w$PM10

  parts <- list()
  for (v in P) {
    sv <- long[long$variable == v, ]
    stopifnot(identical(as.numeric(sv$timestamp), as.numeric(times)))
    y <- sv$value_hourly_raw
    b <- pp$bounds[[v]]
    f <- cbind(
      fill_code = fc$is_code,
      negative = is.finite(y) & y < 0,
      out_of_bounds = is.finite(y) & (y < b[[1]] | y > b[[2]]),
      stuck = .flag_stuck(y, .stuck_limit(v, pp)),
      pm_ratio = if (v %in% c("PM2.5", "PM10")) pm_bad else rep(FALSE, length(y)))
    reason <- apply(f, 1, function(r) if (any(r)) PE_REASONS[which(r)[1]] else NA_character_)
    sv$is_fill_code <- f[, "fill_code"]
    sv$is_negative <- f[, "negative"]
    sv$is_out_of_bounds <- f[, "out_of_bounds"]
    sv$is_stuck <- f[, "stuck"]
    sv$is_pm_ratio <- f[, "pm_ratio"]
    sv$is_spike <- .flag_spike(y, as.integer(pp$spike$window_h), as.numeric(pp$spike$k_mad))
    sv$invalid_reason <- reason
    sv$is_masked <- !is.na(reason) | !is.finite(y)
    sv$value_masked <- ifelse(sv$is_masked, NA_real_, y)
    sv$is_scorable <- !sv$is_masked
    parts[[v]] <- sv
  }
  hourly <- dplyr::bind_rows(parts)

  cfg_train <- pp
  cfg_train$selection_end <- format(train_end + 3600, "%Y-%m-%d %H:%M")
  sel <- pp_parse_time(cfg_train$selection_end, cfg$tz)
  set.seed(cfg$seed)
  bench <- benchmark_imputation(hourly, cfg_train, n_art = as.integer(cfg$imputation$n_artificial_gaps))
  allowed <- unlist(cfg$imputation$methods)
  choice <- choose_imputation(bench[bench$method %in% allowed, ], fallback = cfg$imputation$fallback)
  # No M7/M8 fits: only parameter-free past-only methods are used (see config).
  filled <- impute_station(hourly, cfg_train, choice, m7_fits = list(), m8_fits = list())
  filled <- filled[order(filled$variable, filled$timestamp), ]
  # Hours before a pollutant's first valid observation have no past to fill from.
  filled$no_history <- !is.finite(filled$value_filled_causal)
  pe_write_csv(bench, file.path(out, "imputation_benchmark_training_block.csv"))

  sdir <- pe_dir(cfg, "store", "clean")
  arrow::write_parquet(filled, file.path(sdir, "series.parquet"))
  pe_write_csv(bench, file.path(sdir, "imputation_benchmark.csv"))
  yaml::write_yaml(choice, file.path(sdir, "imputation_choice.yaml"))
  pe_write_csv(data.frame(code = paste0("F", seq_along(fc$codes)), vector = fc$codes),
               file.path(sdir, "fill_codes.csv"))
  man <- list(
    dataset = "CPCB six pollutants, invalid values -> NA, kaisen causal fill",
    rows = nrow(filled), stations = cfg$station, variables = P,
    source = cfg$source$series,
    source_sha256 = digest::digest(file = file.path(PROJECT_ROOT, cfg$source$series), algo = "sha256"),
    train_end = cfg$split$train_end, selection_end_used = cfg_train$selection_end,
    output_sha256 = digest::digest(file = file.path(sdir, "series.parquet"), algo = "sha256"),
    provenance = pe_provenance(cfg, "preprocess"))
  pe_write_json(man, file.path(sdir, "manifest.json"))

  pe_preprocess_report(cfg, pp, long, filled, choice, out)
  pe_log(cfg, "preprocess: masked ", sum(filled$is_masked), " of ", nrow(filled),
         " pollutant-hours; store ", file.path(cfg$paths$store, "clean", "series.parquet"))
  invisible(filled)
}

pe_preprocess_report <- function(cfg, pp, long, filled, choice, out) {
  P <- cfg$pollutants
  rules <- pe_rule_table(cfg, pp)
  pe_write_csv(rules, file.path(out, "rules.csv"))
  n <- nrow(filled) / length(P)

  pol <- do.call(rbind, lapply(P, function(v) {
    f <- filled[filled$variable == v, ]
    b <- pp$bounds[[v]]
    cnt <- vapply(PE_REASONS, function(r) sum(f$invalid_reason == r, na.rm = TRUE), numeric(1))
    any_flag <- vapply(c("is_fill_code", "is_negative", "is_out_of_bounds", "is_stuck", "is_pm_ratio"),
                       function(cn) sum(f[[cn]]), numeric(1))
    data.frame(
      pollutant = v, lower_bound = b[[1]], upper_bound = b[[2]],
      lower_reason = "concentration cannot be negative (kaisen bounds)",
      upper_reason = "repository physical bound; none of the CPCB values reaches it",
      hours = n, masked = sum(f$is_masked), masked_pct = round(100 * mean(f$is_masked), 2),
      t(setNames(cnt, paste0("n_", PE_REASONS))),
      t(setNames(any_flag, paste0("flagged_", sub("^is_", "", names(any_flag))))),
      clipped_to_bound = 0, converted_to_na = sum(f$is_masked),
      imputed = sum(!is.na(f$fill_method) & is.finite(f$value_filled_causal)),
      left_na_no_history = sum(f$no_history),
      spike_flag_info_only = sum(f$is_spike),
      check.names = FALSE)
  }))
  pe_write_csv(pol, file.path(out, "pollutant_rules_counts.csv"))

  imp <- filled[!is.na(filled$fill_method), ]
  imp$bucket <- .gap_bucket(imp$gap_len_sofar)
  imp_tab <- as.data.frame(table(pollutant = imp$variable, bucket = imp$bucket, method = imp$fill_method))
  imp_tab <- imp_tab[imp_tab$Freq > 0, ]
  pe_write_csv(imp_tab, file.path(out, "imputation_by_bucket_method.csv"))
  gaps <- do.call(rbind, lapply(P, function(v) {
    f <- filled[filled$variable == v, ]
    gl <- .real_gap_lengths(f$value_masked)
    data.frame(pollutant = v, n_gaps = length(gl), longest_gap_h = if (length(gl)) max(gl) else 0,
               gaps_gt_72h = sum(gl > 72), hours_in_long_gaps = sum(f$in_long_gap),
               imputed = sum(!is.na(f$fill_method) & is.finite(f$value_filled_causal)),
               left_na_no_history = sum(f$no_history),
               first_model_input = format(min(f$timestamp[is.finite(f$value_filled_causal)])),
               methods_by_bucket = paste(sprintf("%s:%s", c("1-3", "4-24", "25-72", ">72"),
                                                 vapply(c("1-3", "4-24", "25-72", ">72"), function(bk)
                                                   choice[[paste(v, bk, sep = "|")]] %||% cfg$imputation$fallback,
                                                   character(1))), collapse = " "))
  }))
  pe_write_csv(gaps, file.path(out, "imputation_counts.csv"))

  summ <- function(y) c(n = sum(is.finite(y)), mean = mean(y, na.rm = TRUE), sd = stats::sd(y, na.rm = TRUE),
                        min = min(y, na.rm = TRUE), q01 = unname(stats::quantile(y, .01, na.rm = TRUE)),
                        median = stats::median(y, na.rm = TRUE),
                        q99 = unname(stats::quantile(y, .99, na.rm = TRUE)), max = max(y, na.rm = TRUE))
  ba <- do.call(rbind, lapply(P, function(v) {
    f <- filled[filled$variable == v, ]
    rbind(data.frame(pollutant = v, series = "before (raw store values)", t(summ(f$value_hourly_raw))),
          data.frame(pollutant = v, series = "after: valid observations", t(summ(f$value_masked))),
          data.frame(pollutant = v, series = "after: model input (with causal fills)",
                     t(summ(f$value_filled_causal))))
  }))
  pe_write_csv(ba, file.path(out, "summary_before_after.csv"))

  # Plots
  pdir <- pe_dir(cfg, "results", "preprocessing", "plots")
  d <- rbind(data.frame(pollutant = filled$variable, value = filled$value_hourly_raw, series = "before"),
             data.frame(pollutant = filled$variable, value = filled$value_masked, series = "after (valid only)"))
  d <- d[is.finite(d$value) & d$value > 0, ]
  g <- ggplot2::ggplot(d, ggplot2::aes(value, colour = series)) +
    ggplot2::geom_density(adjust = 0.8) + ggplot2::scale_x_log10() +
    ggplot2::facet_wrap(~pollutant, scales = "free") +
    ggplot2::labs(title = "CPCB pollutant distributions before and after invalid-value removal",
                  subtitle = "Density on a log scale; the spikes in 'before' are the synthetic fill constants",
                  x = "value (log scale)", y = "density") +
    ggplot2::theme_minimal(base_size = 10) + ggplot2::theme(legend.position = "bottom")
  ggplot2::ggsave(file.path(pdir, "distribution_before_after.png"), g, width = 10, height = 6, dpi = 120)

  ts <- filled
  ts$status <- ifelse(is.na(ts$invalid_reason), "valid", ts$invalid_reason)
  g2 <- ggplot2::ggplot(ts, ggplot2::aes(timestamp)) +
    ggplot2::geom_line(ggplot2::aes(y = value_filled_causal), colour = "grey55", linewidth = 0.2) +
    ggplot2::geom_point(data = ts[ts$status != "valid", ],
                        ggplot2::aes(y = value_hourly_raw, colour = status), size = 0.35) +
    ggplot2::facet_wrap(~variable, ncol = 1, scales = "free_y") +
    ggplot2::labs(title = "CPCB: invalid observations (coloured, raw value) and the model-input series (grey, with causal fills)",
                  x = NULL, y = NULL, colour = "removed because") +
    ggplot2::theme_minimal(base_size = 9) + ggplot2::theme(legend.position = "bottom")
  ggplot2::ggsave(file.path(pdir, "timeseries_affected.png"), g2, width = 12, height = 11, dpi = 120)

  cnt <- as.data.frame(table(pollutant = filled$variable, reason = filled$invalid_reason))
  g3 <- ggplot2::ggplot(cnt, ggplot2::aes(pollutant, Freq, fill = reason)) +
    ggplot2::geom_col() +
    ggplot2::labs(title = "Invalid values removed per pollutant (by first matching rule)",
                  x = NULL, y = "hours") +
    ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(pdir, "removed_counts.png"), g3, width = 7, height = 4, dpi = 120)
  invisible(TRUE)
}

pe_eligibility <- function(cfg, filled, W) {
  pol <- decomp_policy()
  h <- as.integer(cfg$forecast$horizon_h)
  y <- filled[filled$variable == cfg$target, ]
  y <- y[order(y$timestamp), ]
  n <- nrow(y)
  i <- seq_len(n - h)
  tgt <- i + h
  train_end <- pe_time(cfg$split$train_end, cfg)
  val_end <- pe_time(cfg$split$val_end, cfg)
  t_target <- y$timestamp[tgt]
  block <- ifelse(t_target <= train_end, "train", ifelse(t_target <= val_end, "val", "test"))
  frac <- y$frac_filled_24h[i]
  # Warm = a full trailing window of model inputs for every pollutant ends at the origin.
  s0 <- max(vapply(cfg$pollutants, function(v) {
    f <- filled[filled$variable == v, ]
    min(which(is.finite(f$value_filled_causal[order(f$timestamp)])))
  }, numeric(1)))
  warm <- i >= s0 + W - 1L
  base <- warm & y$is_scorable[tgt]
  keep_train <- base & frac <= as.numeric(pol$exclude_training_row_if_frac_filled_24h_gt)
  keep_eval <- base & frac <= as.numeric(pol$skip_origin_if_frac_filled_24h_gt) &
    !(isTRUE(pol$skip_origin_if_in_long_gap) & y$in_long_gap[i])
  data.frame(origin_idx = i, target_idx = tgt, origin = y$timestamp[i], target = t_target,
             block = block, warm = warm, target_scorable = y$is_scorable[tgt],
             frac_filled_24h = frac, in_long_gap = y$in_long_gap[i],
             eligible = ifelse(block == "train", keep_train, keep_eval))
}
