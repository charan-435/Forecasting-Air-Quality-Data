# Past-only hourly quality flags. Masking writes NA into value_masked.

.stuck_limit <- function(variable, cfg) {
  sh <- cfg$stuck_hours
  if (!is.null(sh[[variable]])) as.integer(sh[[variable]]) else as.integer(sh$default)
}

# Causal: flag hour t only if the trailing run ending at t is already
# >= min_len. The start of a freeze is not rewritten later.
.flag_stuck <- function(x, min_len) {
  n <- length(x)
  out <- rep(FALSE, n)
  if (n == 0L || min_len < 2L) return(out)
  run <- 0L
  prev <- NA_real_
  for (i in seq_len(n)) {
    if (is.finite(x[i]) && is.finite(prev) && x[i] == prev) {
      run <- run + 1L
    } else if (is.finite(x[i])) {
      run <- 1L
    } else {
      run <- 0L
      prev <- NA_real_
      next
    }
    prev <- x[i]
    if (run >= min_len) out[i] <- TRUE
  }
  out
}

.flag_spike <- function(x, window_h, k_mad) {
  n <- length(x)
  out <- rep(FALSE, n)
  k <- k_mad * 1.4826
  for (i in seq_len(n)) {
    lo <- max(1L, i - window_h)
    hi <- i - 1L
    if (hi < lo || !is.finite(x[i])) next
    w <- x[lo:hi]
    w <- w[is.finite(w)]
    if (length(w) < 5L) next
    med <- stats::median(w)
    md <- stats::mad(w, constant = 1)
    if (!is.finite(md)) next
    if (md == 0) {
      out[i] <- is.finite(x[i]) && x[i] != med
    } else {
      out[i] <- abs(x[i] - med) > k * md
    }
  }
  out
}

stuck_run_distribution <- function(hourly, cfg) {
  dplyr::bind_rows(lapply(split(hourly, list(hourly$station, hourly$variable), drop = TRUE), function(sv) {
    x <- sv$value_hourly_raw[order(sv$timestamp)]
    r <- rle(ifelse(is.finite(x), as.character(x), NA_character_))
    lens <- r$lengths[!is.na(r$values)]
    tibble::tibble(
      station = sv$station[1], variable = sv$variable[1],
      n_runs = length(lens),
      p50 = if (length(lens)) stats::median(lens) else NA_real_,
      p90 = if (length(lens)) as.numeric(stats::quantile(lens, 0.9)) else NA_real_,
      p99 = if (length(lens)) as.numeric(stats::quantile(lens, 0.99)) else NA_real_,
      max_run = if (length(lens)) max(lens) else 0L,
      n_ge_default = sum(lens >= .stuck_limit(sv$variable[1], cfg))
    )
  }))
}

quality_hourly <- function(hourly, cfg = pp_cfg()) {
  hourly <- hourly %>% dplyr::arrange(station, variable, timestamp)
  hourly$is_na_source[is.na(hourly$is_na_source)] <- FALSE
  hourly$is_low_coverage[is.na(hourly$is_low_coverage)] <- FALSE
  hourly$is_duplicate_ts[is.na(hourly$is_duplicate_ts)] <- FALSE
  hourly$is_out_of_bounds <- FALSE
  hourly$is_negative <- FALSE
  hourly$is_stuck <- FALSE
  hourly$is_pm_ratio <- FALSE
  hourly$is_spike <- FALSE
  bounds <- cfg$bounds
  w_h <- as.integer(cfg$spike$window_h)
  k_mad <- as.numeric(cfg$spike$k_mad)
  keys <- paste(hourly$station, hourly$variable, sep = "\r")
  for (k in unique(keys)) {
    ii <- which(keys == k)
    x <- hourly$value_hourly_raw[ii]
    v <- hourly$variable[ii][1]
    hourly$is_negative[ii] <- is.finite(x) & x < 0
    if (v %in% names(bounds)) {
      lo <- bounds[[v]][[1]]; hi <- bounds[[v]][[2]]
      hourly$is_out_of_bounds[ii] <- is.finite(x) & (x < lo | x > hi)
    } else {
      hourly$is_out_of_bounds[ii] <- is.finite(x) & x < 0
    }
    hourly$is_stuck[ii] <- .flag_stuck(x, .stuck_limit(v, cfg))
    hourly$is_spike[ii] <- .flag_spike(x, w_h, k_mad)
  }

  # PM2.5 / PM10 ratio: mask both at that station-hour
  pm <- hourly %>%
    dplyr::filter(variable %in% c("PM2.5", "PM10")) %>%
    dplyr::select(station, timestamp, variable, value_hourly_raw) %>%
    tidyr::pivot_wider(names_from = variable, values_from = value_hourly_raw)
  if (all(c("PM2.5", "PM10") %in% names(pm))) {
    bad <- is.finite(pm$`PM2.5`) & is.finite(pm$PM10) &
      pm$`PM2.5` > cfg$pm_ratio_max * pm$PM10
    keys <- paste(pm$station[bad], pm$timestamp[bad])
    hit <- hourly$variable %in% c("PM2.5", "PM10") &
      paste(hourly$station, hourly$timestamp) %in% keys
    hourly$is_pm_ratio[hit] <- TRUE
  }

  mask <- hourly$is_na_source | hourly$is_low_coverage |
    hourly$is_out_of_bounds | hourly$is_negative |
    hourly$is_stuck | hourly$is_pm_ratio
  if (isTRUE(cfg$spike$mask)) mask <- mask | hourly$is_spike
  hourly$is_masked <- mask | !is.finite(hourly$value_hourly_raw)
  hourly$value_masked <- hourly$value_hourly_raw
  hourly$value_masked[hourly$is_masked] <- NA_real_
  hourly$is_scorable <- !hourly$is_masked
  hourly
}

skip_quality <- function(hourly) {
  hourly$is_out_of_bounds <- FALSE
  hourly$is_negative <- FALSE
  hourly$is_stuck <- FALSE
  hourly$is_pm_ratio <- FALSE
  hourly$is_spike <- FALSE
  hourly$is_low_coverage[is.na(hourly$is_low_coverage)] <- FALSE
  hourly$is_na_source[is.na(hourly$is_na_source)] <- FALSE
  hourly$is_duplicate_ts[is.na(hourly$is_duplicate_ts)] <- FALSE
  hourly$is_masked <- !is.finite(hourly$value_hourly_raw)
  hourly$value_masked <- hourly$value_hourly_raw
  hourly$is_scorable <- is.finite(hourly$value_hourly_raw)
  hourly
}
