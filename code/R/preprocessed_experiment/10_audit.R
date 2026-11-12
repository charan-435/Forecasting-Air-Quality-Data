# Phase 1a: audit CPCB hourly data before changing values.

# One row per hour x pollutant from the Phase 1a store.
pe_load_source <- function(cfg) {
  x <- arrow::read_parquet(file.path(PROJECT_ROOT, cfg$source$series))
  x <- x[x$station == cfg$station & x$variable %in% cfg$pollutants, ]
  x <- x[order(x$variable, x$timestamp), ]
  tibble::as_tibble(x)
}

pe_wide <- function(long, value = "value_hourly_raw") {
  w <- tidyr::pivot_wider(long[, c("timestamp", "variable", value)],
                          names_from = "variable", values_from = dplyr::all_of(value))
  w[order(w$timestamp), ]
}

# Complete six-pollutant vectors that occur at >= min_hours distinct hours within
# `period` (logical over the wide rows). Real readings never repeat jointly.
pe_fill_codes <- function(wide, pollutants, period, min_hours) {
  key <- do.call(paste, c(lapply(pollutants, function(v) sprintf("%.10g", wide[[v]])), sep = "|"))
  complete <- stats::complete.cases(wide[, pollutants])
  tab <- table(key[period & complete])
  codes <- names(tab)[tab >= min_hours]
  list(key = key, codes = codes, is_code = complete & key %in% codes)
}

pe_audit <- function(cfg) {
  out <- pe_dir(cfg, "results", "data_audit")
  pp <- pp_cfg()
  long <- pe_load_source(cfg)
  P <- cfg$pollutants
  w <- pe_wide(long)
  train_end <- pe_time(cfg$split$train_end, cfg)
  val_end <- pe_time(cfg$split$val_end, cfg)
  block <- ifelse(w$timestamp <= train_end, "train", ifelse(w$timestamp <= val_end, "val", "test"))

  # Schema and time axis
  steps <- as.numeric(diff(w$timestamp), units = "hours")
  schema <- data.frame(
    item = c("source", "station", "rows (hours)", "first hour", "last hour", "time zone",
             "hourly steps all 1 h", "duplicate hours", "variables", "store columns",
             "existing quality flags set (any)", "value_filled_causal == value_hourly_raw"),
    value = c(cfg$source$series, cfg$station, nrow(w), format(min(w$timestamp)),
              format(max(w$timestamp)), attr(w$timestamp, "tzone"), all(steps == 1),
              sum(duplicated(w$timestamp)), paste(sort(unique(long$variable)), collapse = ", "),
              paste(names(long), collapse = ", "),
              any(long$is_stuck | long$is_spike | long$is_out_of_bounds | long$is_negative |
                    long$is_pm_ratio | long$is_masked),
              isTRUE(all.equal(long$value_hourly_raw, long$value_filled_causal))))
  # Raw CSV: row count and the cloned last row (AUDIT F15)
  raw <- readr::read_csv(file.path(PROJECT_ROOT, cfg$source$raw_csv), show_col_types = FALSE,
                         col_types = readr::cols(Datetime = "c", .default = "d"))
  num <- intersect(c("PM2.5", "PM10", "NO2", "SO2", "Ozone", "O3", "CO"), names(raw))
  last_eq_first <- isTRUE(all.equal(unlist(raw[nrow(raw), num]), unlist(raw[1, num]),
                                    check.attributes = FALSE))
  schema <- rbind(schema, data.frame(
    item = c("raw CSV rows", "raw CSV last row == first row (AUDIT F15)", "raw CSV last Datetime"),
    value = c(nrow(raw), last_eq_first, raw$Datetime[nrow(raw)])))
  pe_write_csv(schema, file.path(out, "schema.csv"))

  # Distribution and extremes
  qs <- c(0, .001, .01, .05, .25, .5, .75, .95, .99, .999, 1)
  stats_tab <- do.call(rbind, lapply(P, function(v) {
    y <- w[[v]]
    data.frame(pollutant = v, unit_in_config = sensor_source(cfg$station, pp)$units[[v]] %||% NA,
               n = length(y), n_na = sum(!is.finite(y)), n_zero = sum(y == 0, na.rm = TRUE),
               n_negative = sum(y < 0, na.rm = TRUE), mean = mean(y, na.rm = TRUE),
               sd = stats::sd(y, na.rm = TRUE),
               t(setNames(stats::quantile(y, qs, na.rm = TRUE), paste0("q", qs * 100))),
               check.names = FALSE)
  }))
  pe_write_csv(stats_tab, file.path(out, "summary_raw.csv"))

  # Fill codes (learned on the training period) and where they occur
  fc <- pe_fill_codes(w, P, block == "train", cfg$validity$fill_code_min_hours)
  codes <- do.call(rbind, lapply(seq_along(fc$codes), function(i) {
    hit <- fc$key == fc$codes[i]
    vals <- as.numeric(strsplit(fc$codes[i], "|", fixed = TRUE)[[1]])
    data.frame(code = paste0("F", i), t(setNames(vals, P)), hours_total = sum(hit),
               hours_train = sum(hit & block == "train"), hours_val = sum(hit & block == "val"),
               hours_test = sum(hit & block == "test"), first = format(min(w$timestamp[hit])),
               last = format(max(w$timestamp[hit])),
               mean_like = paste(sprintf("%.3f", vals - colMeans(w[, P])), collapse = " "),
               check.names = FALSE)
  }))
  pe_write_csv(codes, file.path(out, "fill_codes.csv"))
  r <- rle(fc$is_code)
  e <- cumsum(r$lengths); s <- e - r$lengths + 1
  blocks <- data.frame(start = format(w$timestamp[s]), end = format(w$timestamp[e]),
                       hours = r$lengths)[r$values, ]
  pe_write_csv(blocks, file.path(out, "fill_code_blocks.csv"))
  monthly <- as.data.frame(table(month = format(w$timestamp, "%Y-%m"), fill_code = fc$is_code))
  pe_write_csv(tidyr::pivot_wider(monthly, names_from = "fill_code", values_from = "Freq",
                                  names_prefix = "fill_code_"),
               file.path(out, "fill_code_hours_by_month.csv"))

  # Existing repository rules (code/config/preprocess.yaml), audited on the raw values
  rules <- do.call(rbind, lapply(P, function(v) {
    y <- w[[v]]
    b <- pp$bounds[[v]]
    data.frame(pollutant = v, kaisen_lower = b[[1]], kaisen_upper = b[[2]],
               below_lower = sum(y < b[[1]], na.rm = TRUE), above_upper = sum(y > b[[2]], na.rm = TRUE),
               negative = sum(y < 0, na.rm = TRUE),
               stuck_ge_limit_causal = sum(.flag_stuck(y, .stuck_limit(v, pp))),
               stuck_ge_limit_outside_fill_codes = sum(.flag_stuck(ifelse(fc$is_code, NA, y),
                                                                   .stuck_limit(v, pp))),
               spike_flag_kaisen = sum(.flag_spike(y, as.integer(pp$spike$window_h),
                                                   as.numeric(pp$spike$k_mad))),
               spike_masked_by_kaisen = isTRUE(pp$spike$mask))
  }))
  pm_bad <- w$`PM2.5` > pp$pm_ratio_max * w$PM10
  rules$pm_ratio_hours <- ifelse(rules$pollutant %in% c("PM2.5", "PM10"), sum(pm_bad, na.rm = TRUE), NA)
  rules$pm_ratio_hours_outside_fill_codes <- ifelse(rules$pollutant %in% c("PM2.5", "PM10"),
                                                    sum(pm_bad & !fc$is_code, na.rm = TRUE), NA)
  pe_write_csv(rules, file.path(out, "existing_rules_audit.csv"))
  sr <- stuck_run_distribution(long %>% dplyr::mutate(station = cfg$station), pp)
  pe_write_csv(sr, file.path(out, "exact_repeat_runs.csv"))
  pe_write_json(pe_provenance(cfg, "audit"), file.path(out, "provenance.json"))
  pe_log(cfg, "audit: ", nrow(w), " hours; ", length(fc$codes), " fill codes covering ",
         sum(fc$is_code), " hours; PM ratio violations ", sum(pm_bad, na.rm = TRUE))
  invisible(list(wide = w, fill = fc, block = block))
}
