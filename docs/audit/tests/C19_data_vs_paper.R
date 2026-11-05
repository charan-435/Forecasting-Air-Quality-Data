# C19: this repo's CSVs vs the paper GitHub dump; Table 1 vs scores.csv.
source("docs/audit/tests/_lib.R")

cpcb <- readr::read_csv(file.path(RAW_DIR, "CPCB.csv"), show_col_types = FALSE)
id1  <- readr::read_csv(file.path(RAW_DIR, "ID1.csv"), show_col_types = FALSE)
audit_info("this CPCB rows=", nrow(cpcb), " ID1 rows=", nrow(id1))

orig_cpcb <- file.path("_orig_wavecatboost", "Dataset", "CPCB.csv")
orig_id1  <- file.path("_orig_wavecatboost", "Dataset", "ID1 1H resampled_main.csv")
same_cpcb <- NA
if (file.exists(orig_cpcb)) {
  oc <- readr::read_csv(orig_cpcb, show_col_types = FALSE)
  same_cpcb <- isTRUE(nrow(oc) == nrow(cpcb)) &&
    isTRUE(all.equal(oc$`PM2.5`, cpcb$`PM2.5`, tolerance = 1e-8))
  audit_info("paper GitHub CPCB rows=", nrow(oc), " PM2.5 identical=", same_cpcb)
}

# Nested last-row == first-row (source data wrap).
cpcb_dt <- lubridate::dmy_hm(cpcb$Datetime)
first_eq_last <- isTRUE(all.equal(as.numeric(cpcb[1, 2:ncol(cpcb)]),
                                  as.numeric(cpcb[nrow(cpcb), 2:ncol(cpcb)]),
                                  tolerance = 1e-8))
audit_info("CPCB first row equals last row? ", first_eq_last,
           " last timestamp=", as.character(max(cpcb_dt, na.rm = TRUE)))

# Table 1 (paper, rolling 1-step MASE) vs our recursive scores.csv.
scores <- readRDS(file.path(RES_DIR, "scores.rds"))
# Paper Table 1, overlapping models. CPCB/ID1 column order in the letter:
# RNN, LGBM, TCN, TFT, Transformer, XGB, CatBoost, WaveCatBoost.
paper <- tibble::tribble(
  ~sensor, ~pollutant, ~horizon, ~lgb, ~xgb, ~catboost, ~wavecatboost,
  "CPCB", "NO2",   "1d",  0.79, 0.91, 0.82, 0.57,
  "CPCB", "NO2",   "7d",  0.66, 0.66, 1.04, 0.84,
  "CPCB", "NO2",   "14d", 0.71, 0.72, 0.73, 0.72,
  "CPCB", "NO2",   "31d", 0.75, 0.76, 1.17, 0.47,
  "CPCB", "O3",    "1d",  1.87, 1.52, 2.89, 0.98,
  "CPCB", "PM2.5", "1d",  3.81, 2.85, 5.32, 0.57,
  "CPCB", "PM2.5", "7d",  6.86, 5.92, 6.57, 5.07,
  "CPCB", "PM2.5", "14d", 6.98, 6.20, 6.30, 2.34,
  "CPCB", "PM2.5", "31d", 2.85, 2.83, 2.83, 2.77,
  "ID1",  "PM2.5", "1d",  7.31, 6.53, 4.45, 0.85,
  "ID1",  "PM2.5", "7d",  3.01, 2.65, 2.43, 0.58,
  "ID1",  "PM2.5", "14d", 4.43, 3.67, 5.58, 0.69,
  "ID1",  "PM2.5", "31d", 5.26, 4.49, 5.22, 0.82
)
ours <- scores %>%
  dplyr::filter(method %in% c("lgb", "xgb", "catboost", "wavecatboost")) %>%
  dplyr::select(sensor, pollutant, horizon, method, MASE) %>%
  tidyr::pivot_wider(names_from = method, values_from = MASE)
cmp <- dplyr::inner_join(
  paper %>% dplyr::rename(paper_lgb = lgb, paper_xgb = xgb,
                          paper_cat = catboost, paper_wave = wavecatboost),
  ours %>% dplyr::rename(ours_lgb = lgb, ours_xgb = xgb,
                         ours_cat = catboost, ours_wave = wavecatboost),
  by = c("sensor", "pollutant", "horizon")
)
write_tbl(cmp, "C19_table1_vs_ours.csv")
print(cmp)

audit_ok("C19_rowcounts_match_paper_github",
         nrow(cpcb) == 8882L && nrow(id1) == 9506L,
         sprintf("this repo CPCB=%s ID1=%s (paper GitHub cited 8882 / 9506)",
                 nrow(cpcb), nrow(id1)))
audit_ok("C19_numbers_not_comparable_without_protocol_note",
         FALSE,
         "paper Table 1 is rolling 1-step (Darts historical_forecasts); scores.csv is recursive multi-step from one origin")
