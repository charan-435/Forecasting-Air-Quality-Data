# C15: one origin per horizon; nested tests; 14d vs 7d anomaly.
source("docs/audit/tests/_lib.R")

packed <- readRDS(file.path(PROC_DIR, "series.rds"))
s <- packed$series$CPCB_PM2.5
n <- length(s$y)
rows <- list()
for (hn in names(HORIZONS)) {
  h <- HORIZONS[[hn]]
  sp <- chrono_split(s$y, s$times, h)
  rows[[hn]] <- tibble::tibble(
    horizon = hn, h = h,
    train_n = length(sp$y_train),
    test_n = length(sp$y_test),
    test_start = as.character(min(sp$t_test)),
    test_end = as.character(max(sp$t_test)),
    origin = as.character(max(sp$t_train))
  )
}
tab <- dplyr::bind_rows(rows)
write_tbl(tab, "C15_split_windows.csv")
print(tab)

ends <- unique(tab$test_end)
audit_ok("C15_tests_do_not_all_share_the_last_timestamp",
         length(ends) > 1L,
         sprintf("all four tests end at: %s", paste(unique(tab$test_end), collapse = "; ")))
audit_ok("C15_more_than_one_origin_per_horizon",
         FALSE,
         "chrono_split uses a single origin (last n-h) per horizon — 4 origins total, nested")

scores <- readRDS(file.path(RES_DIR, "scores.rds"))
cmp <- scores %>%
  dplyr::filter(pollutant == "PM2.5") %>%
  dplyr::select(sensor, horizon, method, MASE) %>%
  tidyr::pivot_wider(names_from = horizon, values_from = MASE)
write_tbl(cmp, "C15_pm25_mase_by_horizon.csv")
cpcb7 <- median(scores$MASE[scores$sensor == "CPCB" & scores$horizon == "7d"], na.rm = TRUE)
cpcb14 <- median(scores$MASE[scores$sensor == "CPCB" & scores$horizon == "14d"], na.rm = TRUE)
audit_info("CPCB median MASE 7d=", round(cpcb7, 3), " 14d=", round(cpcb14, 3),
           " (14d nests the 7d week plus the previous week)")
audit_ok("C15_14d_not_easier_than_7d_on_cpcb",
         cpcb14 >= cpcb7,
         sprintf("CPCB median MASE 14d=%.3f vs 7d=%.3f (nested window, not more origins)",
                 cpcb14, cpcb7))
