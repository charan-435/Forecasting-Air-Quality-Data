source("tests/preprocessing/_lib.R")
tz <- "Asia/Kolkata"
# 15-min start-labelled: 00:00, 00:15, 00:30, 00:45 have values 1,2,3,4
# After +15min they end at 00:15..01:00 and belong to hour 01:00.
stamps <- seq(as.POSIXct("2023-01-01 00:00:00", tz = tz),
              as.POSIXct("2023-01-01 02:45:00", tz = tz), by = "15 min")
vals <- as.numeric(seq_along(stamps))
long <- tibble::tibble(
  station = "S", variable = "PM2.5", timestamp_raw = stamps,
  value = vals, source_id = "syn", is_duplicate_ts = FALSE
)
src <- list(native_freq_min = 15, time_label = "start", station = "S")
cfg <- .p1a_cfg()
h <- regularize_hourly(long, src, cfg)
h01 <- h$value_hourly_raw[h$timestamp == as.POSIXct("2023-01-01 01:00:00", tz = tz)]
# readings 00:00,00:15,00:30,00:45 -> 1,2,3,4
p1a_ok("label_end_hour", length(h01) == 1L && abs(h01 - mean(1:4)) < 1e-12,
       sprintf("hour 01:00 mean = %s (expect 2.5)", h01))

# start-labelled hourly: stamp 00:00 covers (00:00, 01:00], becomes 01:00
st2 <- tibble::tibble(
  station = "S", variable = "PM2.5",
  timestamp_raw = as.POSIXct("2023-01-01 00:00:00", tz = tz),
  value = 10, source_id = "syn", is_duplicate_ts = FALSE
)
h2 <- regularize_hourly(st2, list(native_freq_min = 60, time_label = "start"), cfg)
p1a_ok("label_hourly_shift",
       h2$timestamp[1] == as.POSIXct("2023-01-01 01:00:00", tz = tz) && h2$value_hourly_raw[1] == 10,
       paste("hourly start stamp 00:00 ->", format(h2$timestamp[1])))

# future 15-min reading must not enter hour t
long2 <- long
long2$value[long2$timestamp_raw == as.POSIXct("2023-01-01 01:00:00", tz = tz)] <- 999
h3 <- regularize_hourly(long2, src, cfg)
h01b <- h3$value_hourly_raw[h3$timestamp == as.POSIXct("2023-01-01 01:00:00", tz = tz)]
p1a_ok("label_no_future", abs(h01b - h01) < 1e-12,
       "hour 01:00 ignores a start-labelled stamp at 01:00 (next interval)")
