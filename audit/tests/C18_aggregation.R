# C18: mean MASE dominated by SO2; ranking with median / drop SO2.
source("audit/tests/_lib.R")

scores <- readRDS(file.path(RES_DIR, "scores.rds"))
mean_all <- scores %>%
  dplyr::group_by(method) %>%
  dplyr::summarise(mean_MASE = mean(MASE, na.rm = TRUE),
                   median_MASE = median(MASE, na.rm = TRUE),
                   n = dplyr::n(), .groups = "drop") %>%
  dplyr::arrange(mean_MASE)
mean_noso2 <- scores %>%
  dplyr::filter(pollutant != "SO2") %>%
  dplyr::group_by(method) %>%
  dplyr::summarise(mean_MASE = mean(MASE, na.rm = TRUE),
                   median_MASE = median(MASE, na.rm = TRUE),
                   n = dplyr::n(), .groups = "drop") %>%
  dplyr::arrange(mean_MASE)
write_tbl(mean_all, "C18_mean_median_all.csv")
write_tbl(mean_noso2, "C18_mean_median_no_so2.csv")
print(mean_all)
cat("\nWithout SO2:\n")
print(mean_noso2)

so2_share <- scores %>%
  dplyr::group_by(pollutant) %>%
  dplyr::summarise(mean_MASE = mean(MASE, na.rm = TRUE), .groups = "drop")
print(so2_share)

top_mean <- mean_all$method[1]
top_med <- mean_all$method[order(mean_all$median_MASE)][1]
top_noso2 <- mean_noso2$method[1]
audit_info("best mean=", top_mean, " best median=", top_med,
           " best mean without SO2=", top_noso2)

audit_ok("C18_ranking_stable_to_median_and_drop_so2",
         identical(top_mean, top_med) && identical(top_mean, top_noso2),
         sprintf("mean winner=%s median winner=%s no-SO2 winner=%s",
                 top_mean, top_med, top_noso2))
