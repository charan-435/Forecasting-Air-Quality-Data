source("tests/preprocessing/_lib.R")
tz <- "Asia/Kolkata"
base <- as.POSIXct("2023-01-01 00:00:00", tz = tz)
# 4 slots for hour ending 01:00 after start-shift: 00:00, 00:15, 00:30, 00:45
make <- function(n_valid) {
  stamps <- base + lubridate::minutes(c(0, 15, 30, 45))
  val <- c(10, 20, 30, 40)
  val[(n_valid + 1):4] <- NA_real_
  tibble::tibble(station = "S", variable = "PM2.5", timestamp_raw = stamps,
                 value = val, source_id = "syn", is_duplicate_ts = FALSE)
}
cfg <- .p1a_cfg()
src <- list(native_freq_min = 15, time_label = "start")
h2 <- regularize_hourly(make(2), src, cfg)
h3 <- regularize_hourly(make(3), src, cfg)
t1 <- as.POSIXct("2023-01-01 01:00:00", tz = tz)
r2 <- h2[h2$timestamp == t1, ]
r3 <- h3[h3$timestamp == t1, ]
p1a_ok("cov_2of4_na", is.na(r2$value_hourly_raw) && isTRUE(r2$is_low_coverage),
       "2/4 readings -> NA + is_low_coverage")
p1a_ok("cov_3of4_mean", isTRUE(!r3$is_low_coverage) && abs(r3$value_hourly_raw - mean(c(10, 20, 30))) < 1e-12,
       sprintf("3/4 readings -> mean %s", r3$value_hourly_raw))
