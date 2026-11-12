# Section 8 walk-forward protocol: full-series MODWT + teacher forcing + test-residual bands.
source("docs/audit/tests/_lib.R")

src <- paste(readLines("R/core/06_models.R"), collapse = "\n")
full_modwt <- grepl("wt <- haar_modwt\\(y, J\\)", src)
tf <- grepl("y     <- c\\(y, y_future\\[i\\]\\)", src)
pp <- paste(readLines("scripts/experiments/run_paper_protocol.R"), collapse = "\n")
test_band <- grepl("quantile\\(abs\\(split\\$y_test - yhat\\)", pp)

p8 <- if (file.exists(file.path(RES_DIR, "paper_protocol.rds")))
  readRDS(file.path(RES_DIR, "paper_protocol.rds")) else NULL
if (!is.null(p8$scores)) {
  write_tbl(p8$scores, "X_paper_protocol_scores.csv")
  print(p8$scores)
}

rmd <- paste(readLines("analysis.Rmd"), collapse = "\n")
label_no_leak <- grepl("Test window \\(this horizon, no leakage\\)", rmd)

audit_ok("X_walkforward_modwt_train_only", !full_modwt,
         "paper_wave_walkforward() Haar-MODWT the full series (test in the circular filter)")
audit_ok("X_walkforward_no_teacher_forcing", !tf,
         "walkforward_tree_forecast() appends actual y_future (teacher forcing)")
audit_ok("X_walkforward_band_not_test_fitted", !test_band,
         "scripts/experiments/run_paper_protocol.R 95% band from |Y_test - yhat| (coverage by construction)")
audit_ok("X_rmd_does_not_label_cache_as_no_leakage", !label_no_leak,
         "analysis.Rmd labels the recursive cache path 'Test window (this horizon, no leakage)'")
