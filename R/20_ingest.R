# Ingest adapters and end-labelled hourly regularisation.
# Hour t = mean of readings in (t-1h, t]. Known at time t.

CANON_VARS <- c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO", "AT", "RH")

# Paper stays in store/clean (tests and the decomp store). Extra groups can
# pass an isolated directory so a Shiny switch does not overwrite paper.
pp_clean_dir <- function(active = NULL, store_dir = NULL) {
  if (!is.null(store_dir) && nzchar(store_dir)) return(store_dir)
  file.path(PROJECT_ROOT, "store", "clean")
}

pp_cfg <- function(path = NULL) {
  if (exists(".PP_CFG", envir = .GlobalEnv, inherits = FALSE) &&
      !is.null(.GlobalEnv$.PP_CFG) && is.null(path)) {
    return(.GlobalEnv$.PP_CFG)
  }
  if (is.null(path)) path <- file.path(PROJECT_ROOT, "config", "preprocess.yaml")
  if (!requireNamespace("yaml", quietly = TRUE))
    stop("Package 'yaml' is required.")
  cfg <- yaml::read_yaml(path)
  .GlobalEnv$.PP_CFG <- cfg
  cfg
}

pp_log <- function(...) {
  line <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ",
                 paste0(..., collapse = ""))
  cat(line, "\n", sep = "")
  logf <- file.path(PROJECT_ROOT, "store", "preprocess_log.txt")
  dir.create(dirname(logf), recursive = TRUE, showWarnings = FALSE)
  cat(line, "\n", file = logf, append = TRUE, sep = "")
}

# Indian CPCB wall-clock is d/m/y. ISO strings (selection_end) are y-m-d.
# Never try ymd first on "01-07-2022 00:00" — lubridate will accept it as 2001-07-20.
pp_parse_time <- function(x, tz) {
  if (inherits(x, "POSIXt")) return(lubridate::with_tz(x, tz))
  x <- as.character(x)
  iso <- grepl("^[0-9]{4}-", x)
  parsed <- rep(as.POSIXct(NA, tz = tz), length(x))
  if (any(iso)) {
    parsed[iso] <- lubridate::ymd_hms(x[iso], tz = tz, quiet = TRUE)
    miss <- iso & is.na(parsed)
    if (any(miss)) parsed[miss] <- lubridate::ymd_hm(x[miss], tz = tz, quiet = TRUE)
  }
  dmy <- !iso
  if (any(dmy)) {
    parsed[dmy] <- lubridate::dmy_hms(x[dmy], tz = tz, quiet = TRUE)
    miss <- dmy & is.na(parsed)
    if (any(miss)) parsed[miss] <- lubridate::dmy_hm(x[miss], tz = tz, quiet = TRUE)
  }
  parsed
}

.standard_name <- function(nm) {
  n <- gsub("\\s+", " ", trimws(nm))
  n <- gsub("\u00b5", "u", n)
  key <- tolower(gsub("[^a-z0-9]+", "", n))
  map <- c(
    pm25 = "PM2.5", pm25ugm3 = "PM2.5",
    pm10 = "PM10", pm10ugm3 = "PM10",
    no2 = "NO2", no2ugm3 = "NO2",
    so2 = "SO2", so2ugm3 = "SO2",
    o3 = "O3", ozone = "O3", ozoneugm3 = "O3",
    co = "CO", comgm3 = "CO", cougm3 = "CO",
    at = "AT", atc = "AT", temp = "AT", temperature = "AT",
    rh = "RH", rhpct = "RH", humidity = "RH"
  )
  if (key %in% names(map)) map[[key]] else NA_character_
}

.to_long <- function(df, station, source_id, time_col = "timestamp_raw") {
  val_cols <- names(df)[names(df) != time_col]
  tidyr::pivot_longer(
    df, cols = dplyr::all_of(val_cols),
    names_to = "variable", values_to = "value"
  ) %>%
    dplyr::mutate(
      station = station,
      source_id = source_id,
      value = as.numeric(.data$value)
    ) %>%
    dplyr::select(station, variable, timestamp_raw, value, source_id)
}

.drop_cloned_last_row <- function(raw) {
  if (nrow(raw) < 2L) return(raw)
  val_cols <- setdiff(names(raw), "timestamp_raw")
  a <- as.numeric(raw[1, val_cols])
  b <- as.numeric(raw[nrow(raw), val_cols])
  if (isTRUE(all.equal(a, b, check.attributes = FALSE))) {
    pp_log("dropped cloned last row (AUDIT F15)")
    raw[-nrow(raw), , drop = FALSE]
  } else {
    raw
  }
}

adapter_paper_cpcb_csv <- function(src) {
  # Force character so readr cannot guess ymd and turn 01-07-2022 into 2001-07-20.
  raw <- readr::read_csv(
    file.path(PROJECT_ROOT, src$path),
    col_types = readr::cols(Datetime = readr::col_character(),
                            .default = readr::col_double()),
    show_col_types = FALSE
  )
  raw <- raw %>%
    dplyr::rename(O3 = Ozone) %>%
    dplyr::mutate(timestamp_raw = lubridate::dmy_hm(Datetime, tz = src$tz)) %>%
    dplyr::select(timestamp_raw, dplyr::any_of(CANON_VARS))
  raw <- .drop_cloned_last_row(raw)
  .to_long(raw, src$station, src$id)
}

adapter_paper_id1_csv <- function(src) {
  raw <- readr::read_csv(
    file.path(PROJECT_ROOT, src$path),
    col_types = readr::cols(Datetime = readr::col_character(),
                            .default = readr::col_guess()),
    show_col_types = FALSE
  )
  drop <- intersect(names(raw), c("...1", "Unnamed: 0", "id", "X", "X1"))
  raw <- raw %>%
    dplyr::select(-dplyr::any_of(drop)) %>%
    dplyr::rename(AT = Temp) %>%
    dplyr::mutate(timestamp_raw = lubridate::dmy_hm(Datetime, tz = src$tz)) %>%
    dplyr::select(timestamp_raw, dplyr::any_of(CANON_VARS))
  .to_long(raw, src$station, src$id)
}

adapter_vonter_parquet <- function(src) {
  path <- file.path(PROJECT_ROOT, src$path)
  if (!file.exists(path))
    stop("Raw extract missing: ", path)
  raw <- arrow::read_parquet(path)
  names(raw) <- gsub("\u00b5", "u", names(raw))
  if (!is.null(src$station_id) && "Station ID" %in% names(raw)) {
    raw <- raw[raw[["Station ID"]] == src$station_id, , drop = FALSE]
  }
  ts <- raw[["Timestamp"]]
  if (!inherits(ts, "POSIXt")) ts <- lubridate::as_datetime(ts)
  # Vonter tags the clock as UTC; CAAQMS stamps are IST wall clock. Keep the
  # clock and attach src$tz so 15-min bins stay on the hour in Asia/Kolkata.
  clock <- format(ts, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
  ts <- lubridate::as_datetime(clock, tz = src$tz)
  pick <- function(pat) {
    nm <- grep(pat, names(raw), value = TRUE)
    if (!length(nm)) return(rep(NA_real_, nrow(raw)))
    raw[[nm[1]]]
  }
  df <- tibble::tibble(
    timestamp_raw = ts,
    `PM2.5` = pick("^PM2.5"),
    PM10    = pick("^PM10"),
    NO2     = pick("^NO2"),
    SO2     = pick("^SO2"),
    CO      = pick("^CO"),
    O3      = pick("^Ozone|^O3"),
    AT      = pick("^AT"),
    RH      = pick("^RH")
  )
  .to_long(df, src$station, src$id)
}

adapter_synthetic <- function(src) {
  # Used by tests: src$data is already a long tibble.
  src$data
}

run_adapter <- function(src) {
  fn <- switch(src$adapter,
    paper_cpcb_csv = adapter_paper_cpcb_csv,
    paper_id1_csv = adapter_paper_id1_csv,
    vonter_parquet = adapter_vonter_parquet,
    synthetic = adapter_synthetic,
    stop("Unknown adapter: ", src$adapter)
  )
  fn(src)
}

.convert_units <- function(long, src, cfg) {
  warnings <- character()
  canon <- cfg$canonical_units
  src_u <- src$units
  if (is.null(src_u)) return(list(data = long, warnings = warnings))
  long$value_canon <- long$value
  for (v in unique(long$variable)) {
    from <- src_u[[v]]
    to <- canon[[v]]
    if (is.null(from) || is.null(to) || identical(from, to)) next
    idx <- long$variable == v
    if (identical(from, "ug/m3") && identical(to, "mg/m3")) {
      long$value_canon[idx] <- long$value[idx] / 1000
    } else if (identical(from, "mg/m3") && identical(to, "ug/m3")) {
      long$value_canon[idx] <- long$value[idx] * 1000
    } else {
      warnings <- c(warnings, sprintf("%s: no converter %s -> %s", v, from, to))
    }
  }
  long$value <- long$value_canon
  long$value_canon <- NULL
  bounds <- cfg$bounds
  for (v in intersect(unique(long$variable), names(bounds))) {
    med <- stats::median(long$value[long$variable == v], na.rm = TRUE)
    lo <- bounds[[v]][[1]]; hi <- bounds[[v]][[2]]
    if (is.finite(med) && (med > 100 * hi || (hi > 0 && med > 0 && med < lo / 100 && lo > 0))) {
      warnings <- c(warnings, sprintf(
        "%s/%s median %.4g is >100x off bounds [%s, %s]",
        src$station, v, med, lo, hi))
    }
  }
  list(data = long, warnings = warnings)
}

.dedup_timestamps <- function(long) {
  key <- paste(long$station, long$variable, long$timestamp_raw)
  dups <- duplicated(key) | duplicated(key, fromLast = TRUE)
  n_dup <- sum(dups)
  if (!n_dup) {
    long$is_duplicate_ts <- FALSE
    return(list(data = long, n_dup_rows = 0L))
  }
  long <- long %>%
    dplyr::group_by(station, variable, timestamp_raw) %>%
    dplyr::summarise(
      is_duplicate_ts = dplyr::n() > 1L,
      value = mean(.data$value, na.rm = TRUE),
      source_id = dplyr::first(.data$source_id),
      .groups = "drop"
    )
  long$value[is.nan(long$value)] <- NA_real_
  list(data = long, n_dup_rows = as.integer(n_dup))
}

.hour_end <- function(ts) {
  fl <- lubridate::floor_date(ts, "hour")
  on_hour <- abs(as.numeric(ts) - as.numeric(fl)) < 1e-6
  ce <- lubridate::ceiling_date(ts, "hour")
  dplyr::if_else(on_hour, ts, ce)
}

regularize_hourly <- function(long, src, cfg) {
  tz_out <- "Asia/Kolkata"
  ts <- long$timestamp_raw
  ts <- lubridate::with_tz(ts, tz_out)
  n_na <- sum(is.na(ts))
  if (n_na) {
    keep <- !is.na(ts)
    long <- long[keep, , drop = FALSE]
    ts <- ts[keep]
    if (!nrow(long)) stop("all timestamps failed to parse for ", src$station %||% src$id)
  }
  freq <- as.integer(src$native_freq_min %||% 60L)
  if (identical(src$time_label, "start")) {
    ts <- ts + lubridate::minutes(freq)
  }
  long$hour <- .hour_end(ts)
  n_expected <- as.integer(round(60 / freq))
  hourly <- long %>%
    dplyr::group_by(station, variable, hour) %>%
    dplyr::summarise(
      n_sub_valid = sum(is.finite(.data$value)),
      n_sub_expected = n_expected,
      value_hourly_raw = if (sum(is.finite(.data$value)))
        mean(.data$value[is.finite(.data$value)]) else NA_real_,
      is_duplicate_ts = any(.data$is_duplicate_ts),
      source_id = dplyr::first(.data$source_id),
      .groups = "drop"
    ) %>%
    dplyr::rename(timestamp = hour) %>%
    dplyr::mutate(timestamp = lubridate::with_tz(.data$timestamp, "Asia/Kolkata")) %>%
    dplyr::distinct(.data$station, .data$variable, .data$timestamp, .keep_all = TRUE)
  cov <- hourly$n_sub_valid / pmax(hourly$n_sub_expected, 1L)
  hourly$is_low_coverage <- cov < cfg$min_subhour_coverage
  hourly$value_hourly_raw[hourly$is_low_coverage] <- NA_real_

  fill_one <- function(sv) {
    sv <- sv %>%
      dplyr::arrange(.data$timestamp) %>%
      dplyr::distinct(.data$timestamp, .keep_all = TRUE)
    tmin <- min(sv$timestamp)
    tmax <- max(sv$timestamp)
    span_h <- as.numeric(difftime(tmax, tmin, units = "hours"))
    if (!is.finite(span_h) || span_h > 5 * 366 * 24)
      stop("hourly span for ", sv$station[1], "/", sv$variable[1],
           " is ", round(span_h), " h — likely a timestamp parse error")
    grid <- tibble::tibble(
      timestamp = lubridate::with_tz(seq(tmin, tmax, by = "1 hour"), "Asia/Kolkata")
    )
    out <- dplyr::left_join(grid, sv, by = "timestamp")
    out$station[is.na(out$station)] <- sv$station[1]
    out$variable[is.na(out$variable)] <- sv$variable[1]
    out$source_id[is.na(out$source_id)] <- sv$source_id[1]
    out$n_sub_expected[is.na(out$n_sub_expected)] <- n_expected
    out$n_sub_valid[is.na(out$n_sub_valid)] <- 0L
    out$is_low_coverage[is.na(out$is_low_coverage)] <- FALSE
    out$is_duplicate_ts[is.na(out$is_duplicate_ts)] <- FALSE
    out$is_na_source <- is.na(out$value_hourly_raw) & !out$is_low_coverage
    out
  }
  keys <- paste(hourly$station, hourly$variable, sep = "\r")
  dplyr::bind_rows(lapply(split(hourly, keys), fill_one))
}

ingest_source <- function(src, cfg = pp_cfg()) {
  pp_log("ingest ", src$id, " adapter=", src$adapter)
  raw <- run_adapter(src)
  raw$timestamp_raw <- lubridate::with_tz(raw$timestamp_raw, "Asia/Kolkata")
  n_na_ts <- sum(is.na(raw$timestamp_raw))
  if (n_na_ts) {
    pp_log("WARN ", src$id, " dropped ", n_na_ts, " rows with unparsed timestamps")
    raw <- raw[!is.na(raw$timestamp_raw), , drop = FALSE]
  }
  conv <- .convert_units(raw, src, cfg)
  if (length(conv$warnings)) {
    for (w in conv$warnings) pp_log("WARN ", w)
  }
  ded <- .dedup_timestamps(conv$data)
  pp_log(src$id, " duplicate raw timestamps averaged: ", ded$n_dup_rows)
  hourly <- regularize_hourly(ded$data, src, cfg)
  list(hourly = hourly, warnings = conv$warnings, n_dup = ded$n_dup_rows)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
