# Checks that the quality rules flag invalid and suspicious readings.

source("code/tests/preprocessing/_lib.R")
tz <- "Asia/Kolkata"
n <- 80L
times <- seq(as.POSIXct("2023-01-01 00:00:00", tz = tz), by = "hour", length.out = n)
pm25 <- 20 + 0.05 * seq_len(n)
pm10 <- 30 + 0.05 * seq_len(n)
pm25[10] <- 5000          # out of bounds
pm25[11] <- -3            # negative
pm25[20:29] <- 7          # 10-hour stuck
pm25[40] <- 40            # PM2.5 > 1.1 * PM10 (pm10 stays ~32; 40 > 1.1*32)
pm25[60] <- 200           # spike vs trailing median ~23
pm10[60] <- 250           # keep PM2.5/PM10 ratio valid so the spike is not masked
hourly <- dplyr::bind_rows(
  tibble::tibble(station = "S", variable = "PM2.5", timestamp = times,
                 value_hourly_raw = pm25, n_sub_valid = 4L, n_sub_expected = 4L,
                 is_duplicate_ts = FALSE, is_low_coverage = FALSE, is_na_source = FALSE,
                 source_id = "syn"),
  tibble::tibble(station = "S", variable = "PM10", timestamp = times,
                 value_hourly_raw = pm10, n_sub_valid = 4L, n_sub_expected = 4L,
                 is_duplicate_ts = FALSE, is_low_coverage = FALSE, is_na_source = FALSE,
                 source_id = "syn")
)
q <- quality_hourly(hourly, .p1a_cfg())
p <- q %>% dplyr::filter(variable == "PM2.5")
p1a_ok("fault_oob", isTRUE(p$is_out_of_bounds[10]) && is.na(p$value_masked[10]), "oob flagged and masked")
p1a_ok("fault_neg", isTRUE(p$is_negative[11]) && is.na(p$value_masked[11]), "negative flagged and masked")
# Causal stuck: flag only once the trailing run is already >= 6 hours.
p1a_ok("fault_stuck",
       !any(p$is_stuck[20:24]) && all(p$is_stuck[25:29]) &&
         all(is.na(p$value_masked[25:29])) && !any(p$is_stuck[c(19, 30)]),
       "stuck flags from the 6th consecutive hour onward")
p1a_ok("fault_ratio", isTRUE(p$is_pm_ratio[40]) &&
         isTRUE(q$is_pm_ratio[q$variable == "PM10" & q$timestamp == times[40]]),
       "PM ratio masks both PM2.5 and PM10")
p1a_ok("fault_spike_flag_only", isTRUE(p$is_spike[60]) && is.finite(p$value_masked[60]) &&
         !p$is_masked[60], "spike flagged but not masked")
p1a_ok("fault_clean_untouched", is.finite(p$value_masked[5]) && !p$is_masked[5],
       "an ordinary hour is not masked")
