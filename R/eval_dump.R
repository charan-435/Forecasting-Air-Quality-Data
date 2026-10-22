source("R/load_all.R")
scores <- readRDS(file.path(RES_DIR, "scores.rds"))
wide <- scores %>%
  dplyr::select(sensor, pollutant, horizon, method, MASE) %>%
  tidyr::pivot_wider(names_from = method, values_from = MASE)
readr::write_csv(wide, file.path(RES_DIR, "mase_wide.csv"))
mcb <- tryCatch(mcb_from_table(scores), error = function(e) NULL)
if (!is.null(mcb)) {
  saveRDS(mcb, file.path(RES_DIR, "mcb.rds"))
  readr::write_csv(mcb, file.path(RES_DIR, "mcb.csv"))
  print(mcb)
}
cat("\nWave vs no-wave (mean MASE):\n")
print(
  scores %>%
    dplyr::mutate(wave = grepl("^wave", method),
                  family = gsub("^wave", "", method)) %>%
    dplyr::group_by(family, wave) %>%
    dplyr::summarise(mean_MASE = mean(MASE), n = dplyr::n(), .groups = "drop")
)
cat("\nRows:", nrow(scores), "\n")
print(wide %>% dplyr::filter(pollutant == "PM2.5"))
