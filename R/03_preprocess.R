# Imputation, clipping of impossible values, train-only min-max, chronological splits.

clip_impossible <- function(x, pollutant) {
  x[x < 0] <- NA_real_
  # Crude physical caps: sensor faults, not genuine spikes.
  cap <- switch(pollutant,
    `PM2.5` = 1000, PM10 = 2000, NO2 = 2000, O3 = 2000,
    SO2 = 2000, CO = 1e6, 1e6
  )
  x[x > cap] <- NA_real_
  x
}

# DEPRECATED for the Phase 1a store. Full-series na_seadec looks ahead
# (AUDIT F10). Use value_filled_causal from R/22_impute.R.
# Kept so v1 run_experiments.R still reproduces archived scores.
impute_hourly <- function(x, period = SEASONALITY) {
  x <- as.numeric(x)
  if (!anyNA(x)) return(x)
  # Seasonal Kalman if the gap pattern is short enough; linear fallback.
  out <- tryCatch(
    imputeTS::na_seadec(stats::ts(x, frequency = period), algorithm = "interpolation"),
    error = function(e) imputeTS::na_interpolation(x, option = "linear")
  )
  as.numeric(out)
}

# DEPRECATED for the Phase 1 store. Fits on whatever vector is passed; the
# v1 caller used y_fit (train+val). Use get_origin_stats() min/max instead
# (AUDIT F12). Kept so v1 run_experiments.R still reproduces archived scores.
minmax_fit <- function(x) {
  x <- x[is.finite(x)]
  list(min = min(x), max = max(x))
}

minmax_apply <- function(x, fit) {
  rng <- fit$max - fit$min
  if (!is.finite(rng) || rng == 0) return(rep(0, length(x)))
  (x - fit$min) / rng
}

minmax_invert <- function(x, fit) {
  x * (fit$max - fit$min) + fit$min
}

# Chronological train / val / test. Test is the last h hours and never enters
# the scaler, Haar MRA, or hyperparameter grid. Val is the last val_hours of
# what remains (early stopping only). Train is everything before val.
chrono_split_tvt <- function(y, times, h, val_hours = VAL_HOURS) {
  y <- as.numeric(y)
  n <- length(y)
  if (h >= n) stop("Horizon is longer than the series.")
  n_test <- as.integer(h)
  n_fit  <- n - n_test
  n_val  <- as.integer(val_hours)
  n_val  <- min(n_val, max(24L, floor(n_fit * 0.15)))
  if (n_val >= n_fit) n_val <- max(24L, floor(n_fit / 5))
  n_train <- n_fit - n_val
  i_tr <- seq_len(n_train)
  i_va <- (n_train + 1L):n_fit
  i_te <- (n_fit + 1L):n
  list(
    y_train = y[i_tr], y_val = y[i_va], y_test = y[i_te],
    t_train = times[i_tr], t_val = times[i_va], t_test = times[i_te],
    y_fit = y[seq_len(n_fit)], t_fit = times[seq_len(n_fit)],
    n_train = n_train, n_val = n_val, n_test = n_test
  )
}

# DEPRECATED for the Phase 1 store. Nested last-h test windows (AUDIT F3).
# Use get_origins() / config/store.yaml. Kept so v1 run_experiments.R still
# reproduces archived scores.
# Bake-off helper: "train" = pre-test window (train+val). Test is still held out.
chrono_split <- function(y, times, h, val_hours = VAL_HOURS) {
  sp <- chrono_split_tvt(y, times, h, val_hours)
  list(
    y_train = sp$y_fit,
    y_test  = sp$y_test,
    t_train = sp$t_fit,
    t_test  = sp$t_test
  )
}

prepare_series <- function(df, pollutant, sensor) {
  sub <- df %>%
    dplyr::filter(.data$sensor == !!sensor) %>%
    dplyr::arrange(.data$Datetime)
  raw_y <- as.numeric(sub[[pollutant]])
  n_missing <- sum(!is.finite(raw_y))
  y <- clip_impossible(raw_y, pollutant)
  n_impossible <- sum(!is.finite(y) & is.finite(raw_y))
  y <- impute_hourly(y)
  list(
    times = sub$Datetime,
    y = as.numeric(y),
    y_raw = raw_y,
    n_missing = n_missing,
    n_impossible = n_impossible,
    pollutant = pollutant,
    sensor = sensor
  )
}

prepare_all_series <- function(raw_list) {
  out <- list()
  for (sensor in names(raw_list)) {
    df <- raw_list[[sensor]]
    for (p in POLLUTANTS) {
      if (!p %in% names(df)) next
      key <- paste(sensor, p, sep = "_")
      out[[key]] <- prepare_series(df, p, sensor)
    }
  }
  out
}

# Paper preprocess for a 15-min station (letter: missing values → hourly mean).
# Min-max is applied later, train-only, after the chronological split.
# CPCB / ID1 skip this: they are already hourly.

new_dataset_paths <- function() {
  list(
    raw  = file.path(RAW_DIR, "shillong", "shillong_15min_2023.parquet"),
    csv  = file.path(PROC_DIR, "SHILLONG.csv"),
    meta = file.path(PROC_DIR, "SHILLONG_preprocess.rds")
  )
}

.load_shillong_csv <- function(path) {
  df <- readr::read_csv(
    path,
    col_types = readr::cols(Datetime = readr::col_character(),
                            .default = readr::col_double()),
    show_col_types = FALSE
  )
  if ("Ozone" %in% names(df) && !"O3" %in% names(df)) {
    df <- dplyr::rename(df, O3 = Ozone)
  }
  df %>%
    dplyr::mutate(Datetime = lubridate::dmy_hm(Datetime), sensor = NEW_SENSOR) %>%
    dplyr::select(Datetime, dplyr::any_of(c(POLLUTANTS, "AT", "RH")), sensor)
}

paper_preprocess_15min <- function(raw_path = NULL, station_id = "site_5131") {
  if (is.null(raw_path)) raw_path <- new_dataset_paths()$raw
  if (!file.exists(raw_path)) {
    stop("15-min source missing: ", raw_path)
  }
  raw <- arrow::read_parquet(raw_path)
  names(raw) <- gsub("\u00b5", "u", names(raw))
  if ("Station ID" %in% names(raw)) {
    raw <- raw[as.character(raw[["Station ID"]]) == station_id, , drop = FALSE]
  }
  if (!nrow(raw)) stop("No rows for station_id=", station_id)

  ts <- raw[["Timestamp"]]
  if (!inherits(ts, "POSIXt")) ts <- lubridate::as_datetime(ts)
  # Vonter stamps UTC; CAAQMS values are IST wall clock.
  clock <- format(ts, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
  ts <- lubridate::as_datetime(clock, tz = "Asia/Kolkata")

  pick <- function(pat) {
    nm <- grep(pat, names(raw), value = TRUE)
    if (!length(nm)) return(rep(NA_real_, nrow(raw)))
    as.numeric(raw[[nm[[1]]]])
  }
  co <- pick("^CO")
  # Source CO is mg/m3; CPCB.csv is ug/m3. Convert so units match the letter files.
  if (is.finite(stats::median(co, na.rm = TRUE)) &&
      stats::median(co, na.rm = TRUE) < 50) {
    co <- co * 1000
  }

  df15 <- tibble::tibble(
    Datetime = ts,
    NO2 = pick("^NO2"),
    O3 = pick("^Ozone|^O3"),
    CO = co,
    SO2 = pick("^SO2"),
    AT = pick("^AT"),
    RH = pick("^RH"),
    `PM2.5` = pick("^PM2.5"),
    PM10 = pick("^PM10")
  )
  n_15 <- nrow(df15)
  n_na_15 <- vapply(intersect(POLLUTANTS, names(df15)), function(p) {
    as.integer(sum(!is.finite(df15[[p]])))
  }, integer(1))

  for (p in intersect(POLLUTANTS, names(df15))) {
    df15[[p]] <- clip_impossible(df15[[p]], p)
  }
  n_clip <- vapply(intersect(POLLUTANTS, names(df15)), function(p) {
    as.integer(sum(!is.finite(df15[[p]])))
  }, integer(1)) - n_na_15

  # Letter: x_hour = (x1+x2+x3+x4)/4. Mean of available 15-min samples in the hour.
  df15$hour <- lubridate::floor_date(df15$Datetime, "hour")
  val_cols <- intersect(c(POLLUTANTS, "AT", "RH"), names(df15))
  hourly <- df15 %>%
    dplyr::group_by(.data$hour) %>%
    dplyr::summarise(
      dplyr::across(dplyr::all_of(val_cols), ~{
        v <- .x[is.finite(.x)]
        if (length(v)) mean(v) else NA_real_
      }),
      n_sub = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::rename(Datetime = hour)

  rng <- range(hourly$Datetime, na.rm = TRUE)
  grid <- tibble::tibble(
    Datetime = seq(rng[[1]], rng[[2]], by = "1 hour")
  )
  hourly <- dplyr::left_join(grid, hourly, by = "Datetime")
  n_hourly <- nrow(hourly)
  n_na_hour <- vapply(intersect(POLLUTANTS, names(hourly)), function(p) {
    as.integer(sum(!is.finite(hourly[[p]])))
  }, integer(1))

  for (p in val_cols) {
    if (any(is.finite(hourly[[p]]))) {
      hourly[[p]] <- impute_hourly(hourly[[p]])
    }
  }
  n_na_after <- vapply(intersect(POLLUTANTS, names(hourly)), function(p) {
    as.integer(sum(!is.finite(hourly[[p]])))
  }, integer(1))

  hourly$sensor <- NEW_SENSOR
  hourly$n_sub <- NULL

  meta <- list(
    sensor = NEW_SENSOR,
    station = "Lumpyngngad, Shillong - Meghalaya PCB",
    station_id = station_id,
    source = raw_path,
    n_15min = n_15,
    n_hourly = n_hourly,
    n_na_15min = n_na_15,
    n_clipped = n_clip,
    n_na_hourly_before_impute = n_na_hour,
    n_na_after_impute = n_na_after,
    start = min(hourly$Datetime),
    end = max(hourly$Datetime),
    steps = c(
      "clip negatives / absurd caps to NA",
      "hourly mean of 15-min samples (paper x_hour)",
      "seasonal interpolation, period 24 (remaining NAs)"
    ),
    skip_minmax = TRUE
  )
  list(hourly = hourly, meta = meta)
}

ensure_new_dataset <- function(force = FALSE) {
  paths <- new_dataset_paths()
  if (!isTRUE(force) && file.exists(paths$csv)) {
    hourly <- .load_shillong_csv(paths$csv)
    meta <- if (file.exists(paths$meta)) readRDS(paths$meta) else NULL
    return(list(hourly = hourly, meta = meta, from_cache = TRUE, skipped = FALSE))
  }
  if (!file.exists(paths$raw)) {
    warning("SHILLONG 15-min parquet not found at ", paths$raw, "; skipping.")
    return(list(hourly = NULL, meta = NULL, from_cache = FALSE, skipped = TRUE))
  }
  message("Paper preprocess: 15-min SHILLONG (Lumpyngngad) → hourly CSV")
  out <- paper_preprocess_15min(paths$raw)
  save_df <- out$hourly %>%
    dplyr::mutate(Datetime = format(.data$Datetime, "%d-%m-%Y %H:%M")) %>%
    dplyr::select(Datetime, dplyr::any_of(c(POLLUTANTS, "AT", "RH")))
  dir.create(dirname(paths$csv), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(save_df, paths$csv)
  saveRDS(out$meta, paths$meta)
  message("Wrote ", paths$csv, "  n=", nrow(out$hourly))
  list(hourly = out$hourly, meta = out$meta, from_cache = FALSE, skipped = FALSE)
}
