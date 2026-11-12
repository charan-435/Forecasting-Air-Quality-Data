# A3: imputation runs on the full series before the split.
source("docs/audit/tests/_lib.R")

src <- paste(readLines("R/core/03_preprocess.R"), collapse = "\n")
order_ok <- grepl("y <- impute_hourly\\(y\\)", src) &&
  grepl("prepare_series <- function", src)

# Prove na_seadec / na_interpolation uses future points: bump a later NA-neighbour.
set.seed(2)
x <- as.numeric(stats::arima.sim(list(ar = 0.8), n = 240))
x[100] <- NA_real_
imp1 <- impute_hourly(x)
x2 <- x
x2[120] <- x2[120] + 20  # 20 hours after the gap, still in-series
imp2 <- impute_hourly(x2)
future_used <- abs(imp1[100] - imp2[100]) > 1e-8
audit_info("Gap at t=100: imputed value changes by ",
           signif(abs(imp1[100] - imp2[100]), 3),
           " when Y[120] is bumped (na_seadec/interpolation look-ahead).")

# How many raw NAs / clipped points sit in each test window and in the 744h pre-origin.
raw <- load_raw_datasets()
rows <- list()
for (sensor in names(raw)) {
  df <- raw[[sensor]]
  for (p in POLLUTANTS) {
    if (!p %in% names(df)) next
    v <- as.numeric(df[[p]])
    v2 <- clip_impossible(v, p)
    na_raw <- !is.finite(v)
    na_clip <- !is.finite(v2)
    n <- length(v)
    for (hn in names(HORIZONS)) {
      h <- HORIZONS[[hn]]
      if (h >= n) next
      test_idx <- (n - h + 1):n
      pre_idx <- max(1L, n - h - 744L + 1L):(n - h)
      rows[[length(rows) + 1L]] <- tibble::tibble(
        sensor = sensor, pollutant = p, horizon = hn,
        n_test = h,
        na_raw_test = sum(na_raw[test_idx]),
        na_clip_test = sum(na_clip[test_idx]),
        na_raw_pre744 = sum(na_raw[pre_idx]),
        na_clip_pre744 = sum(na_clip[pre_idx]),
        na_raw_all = sum(na_raw),
        na_clip_all = sum(na_clip)
      )
    }
  }
}
tab <- dplyr::bind_rows(rows)
write_tbl(tab, "A3_imputed_counts.csv")
audit_info("Series with any NA/clip in a test window: ",
           sum(tab$na_raw_test + tab$na_clip_test > 0), " / ", nrow(tab))

audit_ok("A3_impute_after_split", !order_ok,
         "prepare_series() imputes the full series before chrono_split")
audit_ok("A3_imputer_ignores_future", !future_used,
         "impute_hourly() does not use Y after a gap")
audit_ok("A3_no_imputed_test_targets",
         sum(tab$na_raw_test + tab$na_clip_test) == 0,
         sprintf("imputed/clipped hours scored as test targets: raw=%s clip=%s",
                 sum(tab$na_raw_test), sum(tab$na_clip_test)))
