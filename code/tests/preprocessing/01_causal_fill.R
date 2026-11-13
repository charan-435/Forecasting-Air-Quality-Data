# Checks that filling a gap does not use observations from later hours.

source("code/tests/preprocessing/_lib.R")
set.seed(7)
tz <- "Asia/Kolkata"
n <- 400L
times <- seq(as.POSIXct("2023-01-01 00:00:00", tz = tz), by = "hour", length.out = n)
y <- 20 + 5 * sin(2 * pi * seq_len(n) / 24) + rnorm(n, 0, 0.3)
y[c(50:55, 120:140, 250:252)] <- NA_real_
ks <- c(1L, 5L, 24L, 200L)
tsamp <- sample(which(!is.finite(y) & seq_len(n) < n - 201L), 20, replace = TRUE)

helpers <- list(PM10 = y + 5 + rnorm(n, 0, 0.2), NO2 = y)
m7 <- fit_m7(y, times, which(times < as.POSIXct("2023-06-01", tz = tz)))
m8 <- fit_m8(tibble::tibble(`PM2.5` = y, PM10 = helpers$PM10),
             "PM2.5", "PM10", times, seq_len(n))

for (m in paste0("M", 1:8)) {
  mb <- as.list(setNames(rep(m, 4), c("1-3", "4-24", "25-72", ">72")))
  h <- helpers
  use_m7 <- if (m == "M7") m7 else NULL
  use_m8 <- if (m == "M8") m8 else NULL
  base <- apply_fills(y, times, mb, h, use_m7, use_m8)
  base_frac24 <- .frac_filled_trailing(!is.na(base$fill_method), 24L)
  base_frac168 <- .frac_filled_trailing(!is.na(base$fill_method), 168L)
  worst <- 0
  for (t0 in tsamp) {
    for (k in ks) {
      yp <- y
      yp[t0 + k] <- (if (is.finite(yp[t0 + k])) yp[t0 + k] else 0) + 50
      hp <- helpers
      hp$PM10[t0 + k] <- (if (is.finite(hp$PM10[t0 + k])) hp$PM10[t0 + k] else 0) + 50
      new <- apply_fills(yp, times, mb, hp, use_m7, use_m8)
      nf24 <- .frac_filled_trailing(!is.na(new$fill_method), 24L)
      nf168 <- .frac_filled_trailing(!is.na(new$fill_method), 168L)
      d <- c(
        abs(base$filled[t0] - new$filled[t0]),
        abs(base$book$gap_len_sofar[t0] - new$book$gap_len_sofar[t0]),
        abs(base_frac24[t0] - nf24[t0]),
        abs(base_frac168[t0] - nf168[t0])
      )
      worst <- max(worst, d, na.rm = TRUE)
    }
  }
  p1a_ok(paste0("causal_", m), worst < 1e-9,
         sprintf("%s max delta at t vs t+k = %s", m, format(worst, scientific = TRUE)))
}

# Quality flags at t ignore a bump at t+k
hourly <- tibble::tibble(
  station = "S", variable = "PM2.5", timestamp = times,
  value_hourly_raw = y, n_sub_valid = 4L, n_sub_expected = 4L,
  is_duplicate_ts = FALSE, is_low_coverage = FALSE,
  is_na_source = !is.finite(y)
)
q0 <- quality_hourly(hourly, .p1a_cfg())
t_obs <- sample(which(is.finite(y) & seq_len(n) < n - 201L), 20)
flag_delta <- 0
for (t0 in t_obs) {
  for (k in ks) {
    h1 <- hourly
    h1$value_hourly_raw[t0 + k] <- (if (is.finite(h1$value_hourly_raw[t0 + k]))
      h1$value_hourly_raw[t0 + k] else 0) + 50
    q1 <- quality_hourly(h1, .p1a_cfg())
    cols <- c("is_out_of_bounds", "is_negative", "is_stuck", "is_spike", "is_masked")
    flag_delta <- max(flag_delta, max(abs(
      as.numeric(unlist(q0[t0, cols])) - as.numeric(unlist(q1[t0, cols]))
    ), na.rm = TRUE))
  }
}
p1a_ok("causal_flags", flag_delta < 1e-12, sprintf("quality flags delta=%s", flag_delta))
