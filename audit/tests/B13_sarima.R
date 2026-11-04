# B13: SARIMA seasonal settings and any NA / fallback rows.
source("audit/tests/_lib.R")

src <- paste(readLines("R/06_models.R"), collapse = "\n")
seasonal_true <- grepl("seasonal = TRUE", src) && grepl("frequency = season", src)
wave_seasonal_false <- grepl("wave_fit_sarima", src) &&
  grepl("seasonal = FALSE", src)

scores <- readRDS(file.path(RES_DIR, "scores.rds"))
sar <- dplyr::filter(scores, method %in% c("sarima", "wavesarima"))
n_na <- sum(!is.finite(sar$MASE))
n_all <- nrow(scores)
n_na_all <- sum(!is.finite(scores$MASE))
write_tbl(tibble::tibble(
  n_scores = n_all, n_mase_na = n_na_all,
  n_sarima_rows = nrow(sar), n_sarima_na = n_na
), "B13_sarima_na.csv")

audit_info("scores rows=", n_all, " MASE NA=", n_na_all,
           " expected 2*6*4*9=432")
audit_ok("B13_sarima_is_seasonal_freq24", seasonal_true,
         "fit_sarima_auto uses ts(frequency=24) and seasonal=TRUE")
audit_ok("B13_wavesarima_nonseasonal_on_details", wave_seasonal_false,
         "wave_fit_sarima sets seasonal=FALSE on each MRA component")
audit_ok("B13_no_na_mase_in_scores", n_na_all == 0,
         sprintf("%s / %s score rows have NA MASE", n_na_all, n_all))
