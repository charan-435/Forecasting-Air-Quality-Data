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

chrono_split <- function(y, times, h) {
  n <- length(y)
  if (h >= n) stop("Horizon is longer than the series.")
  list(
    y_train = y[seq_len(n - h)],
    y_test  = y[(n - h + 1):n],
    t_train = times[seq_len(n - h)],
    t_test  = times[(n - h + 1):n]
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
