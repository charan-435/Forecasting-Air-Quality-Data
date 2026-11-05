# EDA → modelling design. Train-window only; no test used for decisions.
# (No energy-by-level plots; multi-scale evidence uses band amplitudes.)

.eda_finite <- function(y) {
  y <- as.numeric(y)
  y[is.finite(y)]
}

eda_seasonal_strength <- function(y, times, season = SEASONALITY) {
  y <- as.numeric(y)
  times <- as.POSIXct(times)
  ok <- is.finite(y) & !is.na(times)
  y <- y[ok]
  times <- times[ok]
  hod <- lubridate::hour(times)
  dow <- lubridate::wday(times, week_start = 1)
  mu_h <- tapply(y, hod, mean, na.rm = TRUE)
  mu_d <- tapply(y, dow, mean, na.rm = TRUE)
  hod_amp <- as.numeric(diff(range(mu_h, na.rm = TRUE)))
  dow_amp <- as.numeric(diff(range(mu_d, na.rm = TRUE)))
  list(
    hod_amp = hod_amp,
    dow_amp = dow_amp,
    season = as.integer(season),
    prefer_S = if (isTRUE(hod_amp >= dow_amp)) {
      as.integer(season)
    } else {
      as.integer(7L * season)
    }
  )
}

eda_acf_at <- function(y, lags = c(1L, 24L), max_lag = 72L) {
  y <- .eda_finite(y)
  ac <- stats::acf(y, lag.max = max(max_lag, max(lags)), plot = FALSE,
                   na.action = stats::na.pass)
  vals <- setNames(rep(NA_real_, length(lags)), paste0("acf_", lags))
  for (k in lags) {
    vals[[paste0("acf_", k)]] <- as.numeric(ac$acf[k + 1L])
  }
  vals
}

eda_snaive_resid <- function(y, season = SEASONALITY) {
  y <- as.numeric(y)
  n <- length(y)
  if (n <= season) {
    return(list(resid = numeric(0), sd_ratio = NA_real_,
                acf1 = NA_real_, leftover = FALSE))
  }
  pred <- c(rep(NA_real_, season), y[seq_len(n - season)])
  resid <- (y - pred)[is.finite(y - pred)]
  sd_y <- stats::sd(y, na.rm = TRUE)
  sd_r <- stats::sd(resid, na.rm = TRUE)
  ac1 <- if (length(resid) > 2L) {
    as.numeric(stats::acf(resid, lag.max = 1L, plot = FALSE)$acf[2L])
  } else {
    NA_real_
  }
  list(
    resid = resid,
    sd_ratio = if (is.finite(sd_y) && sd_y > 0) sd_r / sd_y else NA_real_,
    acf1 = ac1,
    leftover = isTRUE(is.finite(ac1) && abs(ac1) > 0.2)
  )
}

# Band amplitude ratios (MAD / spike size), not energy shares — multi-scale motivation.
# Haar D1 MAD is often small even when spikes matter; also track a high abs quantile.
eda_mra_amplitudes <- function(y, J = 5L, filter = "haar") {
  y <- .eda_finite(y)
  mra <- generic_mra(y, J, filter = filter)
  mad_y <- stats::mad(y, constant = 1, na.rm = TRUE)
  if (!is.finite(mad_y) || mad_y <= 0) mad_y <- stats::sd(y, na.rm = TRUE)
  d1 <- mra$D[[1]]
  mad_d1 <- stats::mad(d1, constant = 1, na.rm = TRUE)
  mad_s  <- stats::mad(mra$S, constant = 1, na.rm = TRUE)
  spike_d1 <- as.numeric(stats::quantile(abs(d1), probs = 0.99, na.rm = TRUE, names = FALSE))
  list(
    mad_y = mad_y,
    mad_D1 = mad_d1,
    mad_S = mad_s,
    amp_D1 = if (is.finite(mad_y) && mad_y > 0) mad_d1 / mad_y else NA_real_,
    amp_S  = if (is.finite(mad_y) && mad_y > 0) mad_s / mad_y else NA_real_,
    spike_D1 = if (is.finite(mad_y) && mad_y > 0) spike_d1 / mad_y else NA_real_,
    J = as.integer(J),
    filter = filter
  )
}

# One-row summary + decision strings for the selected train window.
eda_design_summary <- function(y, times, season = SEASONALITY, J = 5L,
                               max_lag = 72L, filter = "haar") {
  y <- as.numeric(y)
  times <- as.POSIXct(times)
  stopifnot(length(y) == length(times))
  seas <- eda_seasonal_strength(y, times, season = season)
  ac <- eda_acf_at(y, lags = c(1L, season), max_lag = max_lag)
  p_cut <- pacf_cutoff(y, max_lag = max_lag)
  sn <- eda_snaive_resid(y, season = season)
  amp <- eda_mra_amplitudes(y, J = J, filter = filter)
  # Slow smooth always present; fast band justified by MAD or spike tail of D1.
  multi_scale <- isTRUE(
    is.finite(amp$amp_S) && amp$amp_S > 0.2 &&
      ((is.finite(amp$amp_D1) && amp$amp_D1 > 0.03) ||
         (is.finite(amp$spike_D1) && amp$spike_D1 > 0.15))
  )

  p_default <- as.integer(season)
  p_suggested <- as.integer(max(season, min(as.integer(p_cut), 2L * season)))
  tibble::tibble(
    n_train = sum(is.finite(y)),
    hod_amp = seas$hod_amp,
    dow_amp = seas$dow_amp,
    S = as.integer(seas$prefer_S),
    acf_lag1 = unname(ac[["acf_1"]]),
    acf_lagS = unname(ac[[paste0("acf_", season)]]),
    pacf_cutoff = as.integer(p_cut),
    p_lags = p_default,
    p_suggested = p_suggested,
    snaive_resid_sd_ratio = sn$sd_ratio,
    snaive_resid_acf1 = sn$acf1,
    amp_D1 = as.numeric(amp$amp_D1),
    spike_D1 = as.numeric(amp$spike_D1),
    amp_S = as.numeric(amp$amp_S),
    multi_scale = multi_scale,
    J = as.integer(J),
    filter = filter
  )
}

# Human-readable "EDA finding → pipeline choice" table.
eda_design_decisions <- function(summary_row) {
  s <- summary_row[1, , drop = FALSE]
  diurnal_strong <- isTRUE(s$hod_amp >= s$dow_amp)
  tibble::tibble(
    EDA_finding = c(
      if (diurnal_strong) {
        sprintf("Hour-of-day amplitude (%.2f) >= day-of-week (%.2f)",
                s$hod_amp, s$dow_amp)
      } else {
        sprintf("Day-of-week amplitude (%.2f) > hour-of-day (%.2f)",
                s$dow_amp, s$hod_amp)
      },
      sprintf("ACF at lag 1 = %.2f; at lag %d = %.2f",
              s$acf_lag1, SEASONALITY, s$acf_lagS),
      sprintf("PACF cutoff = %d h (95%% band)", s$pacf_cutoff),
      sprintf("Seasonal-naive residual sd / series sd = %.2f; resid ACF(1) = %.2f",
              s$snaive_resid_sd_ratio, s$snaive_resid_acf1),
      sprintf("Haar MRA: D1 MAD/Y = %.2f, D1 spike99/Y = %.2f, S%d MAD/Y = %.2f",
              s$amp_D1, s$spike_D1, s$J, s$amp_S)
    ),
    Pipeline_choice = c(
      sprintf("Seasonality S = %d for snaive / SARIMA / MASE (not S = 168)", s$S),
      sprintf("Lag features include persistence (lag 1) and daily cycle (lag %d)",
              SEASONALITY),
      sprintf("Bake-off lag window p = %d; PACF suggests trying p = %d",
              s$p_lags, s$p_suggested),
      if (isTRUE(s$snaive_resid_acf1 > 0.2) || isTRUE(s$snaive_resid_sd_ratio > 0.5)) {
        "Seasonal naive leaves structure → trees (and Wave*) on leftover dynamics"
      } else {
        "Seasonal naive is strong; keep it as the MASE baseline"
      },
      if (isTRUE(s$multi_scale)) {
        "Fast spikes (D1) and slow level (S) both matter → MODWT, one model per band, sum"
      } else {
        "Detail band weak vs Y → still show MRA; raw trees may be enough on this series"
      }
    )
  )
}
