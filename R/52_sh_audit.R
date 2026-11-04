# Shillong data and decomposition audit (Phase 1). Writes tables only.

sh_raw_15min_na <- function(cfg) {
  raw <- data.table::as.data.table(arrow::read_parquet(file.path(PROJECT_ROOT, cfg$raw_path)))
  names(raw) <- gsub("µ", "u", names(raw))
  pick <- c(`PM2.5` = "^PM2.5", PM10 = "^PM10", NO2 = "^NO2", SO2 = "^SO2", CO = "^CO",
            O3 = "^Ozone", AT = "^AT ", RH = "^RH ", WS = "^WS ", WD = "^WD ",
            RF = "^RF ", SR = "^SR ", BP = "^BP ")
  out <- list()
  for (st in names(SH_STATIONS)) {
    d <- raw[raw[["Station ID"]] == SH_STATIONS[[st]]]
    for (v in names(pick)) {
      nm <- grep(pick[[v]], names(d), value = TRUE)[1]
      x <- if (is.na(nm)) rep(NA_real_, nrow(d)) else d[[nm]]
      ok <- is.finite(x)
      out[[paste(st, v)]] <- data.frame(
        station = st, variable = v, source_column = nm %||% NA,
        n_15min = nrow(d), n_15min_na = sum(!ok),
        first_obs = if (any(ok)) format(min(d$Timestamp[ok]), "%Y-%m-%d %H:%M", tz = "UTC") else NA,
        last_obs = if (any(ok)) format(max(d$Timestamp[ok]), "%Y-%m-%d %H:%M", tz = "UTC") else NA,
        n_dup_ts = sum(duplicated(d$Timestamp)), stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, out)
}

# Monthly medians of observed hourly values, and the max/min ratio across
# months: a large ratio flags calibration or regime changes that stay inside
# the physical bounds (and so are not masked).
sh_audit_monthly_levels <- function(long) {
  d <- long[is.finite(value_hourly_raw),
            .(median = stats::median(value_hourly_raw), p99 = stats::quantile(value_hourly_raw, 0.99),
              n = .N), by = .(station, variable, month = format(timestamp, "%Y-%m"))]
  d <- d[n >= 72]
  d[, ratio_max_min_median := max(median) / max(min(median), 1e-9), by = .(station, variable)]
  d[order(station, variable, month)]
}

# Runs of identical consecutive observed hourly values (raw, before masking).
sh_constant_runs <- function(x, min_len) {
  r <- rle(ifelse(is.finite(x), format(x, digits = 15), NA_character_))
  ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1L
  keep <- !is.na(r$values) & r$lengths >= min_len
  data.frame(start = starts[keep], end = ends[keep], len = r$lengths[keep])
}

sh_audit_variables <- function(cfg, long, splits) {
  rows <- list()
  for (st in unique(long$station)) for (v in unique(long$variable)) {
    s <- long[station == st & variable == v][order(timestamp)]
    if (!nrow(s)) next
    obs <- is.finite(s$value_hourly_raw)
    sc <- s$is_scorable
    r <- data.frame(
      station = st, variable = v, n_hours = nrow(s),
      first_hour = format(min(s$timestamp)), last_hour = format(max(s$timestamp)),
      first_observed = if (any(obs)) format(min(s$timestamp[obs])) else NA,
      last_observed = if (any(obs)) format(max(s$timestamp[obs])) else NA,
      hourly_missing_raw = sum(!obs),
      low_coverage = sum(s$is_low_coverage), na_source = sum(s$is_na_source),
      negative = sum(s$is_negative), out_of_bounds = sum(s$is_out_of_bounds),
      stuck = sum(s$is_stuck), pm_ratio = sum(s$is_pm_ratio),
      spike_flag_not_masked = sum(s$is_spike & !s$is_masked),
      masked = sum(s$is_masked), scorable = sum(sc),
      filled_causal = sum(!is.na(s$fill_method)),
      missing_after_fill = sum(!is.finite(s$value_filled_causal)),
      in_long_gap = sum(s$in_long_gap),
      duplicate_ts = sum(s$is_duplicate_ts),
      const_runs_ge24h = nrow(sh_constant_runs(s$value_hourly_raw, 24L)),
      const_hours_ge24h = sum(sh_constant_runs(s$value_hourly_raw, 24L)$len),
      stringsAsFactors = FALSE)
    for (b in names(splits[[st]])) {
      w <- s$timestamp >= splits[[st]][[b]][1] & s$timestamp <= splits[[st]][[b]][2]
      r[[paste0("scorable_pct_", b)]] <- round(100 * mean(sc[w]), 1)
    }
    rows[[paste(st, v)]] <- r
  }
  out <- do.call(rbind, rows); rownames(out) <- NULL
  out
}

sh_audit_fill_methods <- function(long) {
  d <- long[!is.na(fill_method), .N, by = .(station, variable, fill_method)]
  d[order(station, variable, -N)]
}

sh_audit_alignment <- function(long) {
  do.call(rbind, lapply(split(long, long$station), function(s) {
    g <- s[, .(n = .N), by = timestamp][order(timestamp)]
    dt <- diff(as.numeric(g$timestamp)) / 3600
    data.frame(station = s$station[1], n_timestamps = nrow(g),
               variables = data.table::uniqueN(s$variable),
               all_variables_every_hour = all(g$n == data.table::uniqueN(s$variable)),
               contiguous_hourly = all(dt == 1), duplicate_station_hours =
                 sum(duplicated(s[, .(variable, timestamp)])),
               start = format(min(g$timestamp)), end = format(max(g$timestamp)))
  }))
}

# Hours on which every pollutant in `pols` is scorable, by block.
sh_audit_overlap <- function(panel, pols, splits) {
  sc <- as.matrix(panel$scorable[, pols, with = FALSE])
  all_ok <- rowSums(!sc) == 0
  ts <- panel$timestamps
  do.call(rbind, lapply(names(splits), function(b) {
    w <- ts >= splits[[b]][1] & ts <= splits[[b]][2]
    data.frame(station = panel$station, block = b, hours = sum(w),
               all_selected_pollutants_scorable = sum(all_ok & w),
               pct = round(100 * mean(all_ok[w]), 1),
               pollutants = paste(pols, collapse = ","))
  }))
}

sh_audit_covariates <- function(panel, splits) {
  m <- panel$met
  do.call(rbind, lapply(setdiff(names(m), "timestamp"), function(v) {
    r <- data.frame(station = panel$station, covariate = v,
                    pct_available_all = round(100 * mean(is.finite(m[[v]])), 1))
    for (b in names(splits)) {
      w <- m$timestamp >= splits[[b]][1] & m$timestamp <= splits[[b]][2]
      r[[paste0("pct_available_", b)]] <- round(100 * mean(is.finite(m[[v]][w])), 1)
    }
    r
  }))
}

# Additivity and energy of the causal Haar pyramid at several depths, on the
# training block of each pollutant (filled series = what the models see).
sh_audit_decomp <- function(panel, pols, train_range, depths = 3:8) {
  ts <- panel$timestamps
  w <- ts >= train_range[1] & ts <= train_range[2]
  out <- list()
  for (v in pols) {
    x <- panel$fill[[v]]
    for (J in depths) {
      M <- sh_decompose(x, J)
      ok <- w & rowSums(!is.finite(M)) == 0
      rec <- rowSums(M)
      vv <- apply(M[ok, , drop = FALSE], 2, stats::var)
      out[[paste(v, J)]] <- data.frame(
        station = panel$station, pollutant = v, J = J, warmup_h = 2^J - 1,
        max_abs_additivity_error = max(abs(rec[ok] - x[ok])),
        component = colnames(M), var_share_pct = round(100 * vv / sum(vv), 2),
        lag1_acf = round(apply(M[ok, , drop = FALSE], 2, function(z)
          stats::acf(z, lag.max = 1, plot = FALSE)$acf[2]), 3),
        lag24_acf = round(apply(M[ok, , drop = FALSE], 2, function(z)
          stats::acf(z, lag.max = 24, plot = FALSE)$acf[25]), 3))
    }
  }
  do.call(rbind, out)
}
