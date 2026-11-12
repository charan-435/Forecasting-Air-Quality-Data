# A8: conformal calibration vs test; U held constant; CPCB ~30% coverage.
source("docs/audit/tests/_lib.R")

src <- paste(readLines("R/core/07_conformal.R"), collapse = "\n")
u_constant <- grepl("u_test <- rep\\(u_cal\\[n\\], length\\(yhat_test\\)\\)", src)

rc <- paste(readLines("scripts/experiments/run_conformal.R"), collapse = "\n")
holdout_cal <- grepl("y_pre <- split\\$y_train", rc) &&
  grepl("fit_and_forecast\\(\\s*\"wavecatboost\"", rc)

conf <- readRDS(file.path(RES_DIR, "conformal.rds"))
packed <- readRDS(file.path(PROC_DIR, "series.rds"))

rows <- list()
for (sensor in names(conf)) {
  z <- conf[[sensor]]
  s <- packed$series[[paste(sensor, "PM2.5", sep = "_")]]
  n <- length(s$y)
  h <- length(z$y_test)
  half <- mean(z$upper - z$lower, na.rm = TRUE) / 2
  u <- if (!is.null(z$width) && !is.null(z$cq) && z$cq > 0) z$width / (2 * z$cq) else NA_real_
  # last cal hour = last train hour; check if that stretch is flat
  ytr <- s$y[seq_len(n - h)]
  tail168 <- tail(ytr, 168)
  rows[[sensor]] <- tibble::tibble(
    sensor = sensor,
    kappa = z$kappa,
    cq = z$cq,
    coverage_cal = z$coverage_cal,
    coverage_test = z$coverage_test,
    width = z$width,
    half_width = half,
    U_proxy = u,
    yhat_sd = stats::sd(z$yhat),
    yhat_range = diff(range(z$yhat)),
    cal_tail_sd = stats::sd(tail168),
    cal_tail_nunique = length(unique(round(tail168, 6))),
    test_start = as.character(min(z$t_test)),
    test_end = as.character(max(z$t_test))
  )
}
tab <- dplyr::bind_rows(rows)
write_tbl(tab, "A8_conformal_summary.csv")
print(tab)

cpcb <- conf$CPCB
audit_info("CPCB test coverage=", round(cpcb$coverage_test, 4),
           " kappa=", cpcb$kappa, " width=", round(cpcb$width, 3))

# Û constant across the horizon
widths <- cpcb$upper - cpcb$lower
audit_ok("A8_U_not_constant_across_h",
         stats::sd(widths) > 1e-8,
         sprintf("PI width unique values=%s sd=%g (code copies U_N to every test hour)",
                 length(unique(round(widths, 10))), stats::sd(widths)))

audit_ok("A8_cpcb_near_95_percent",
         cpcb$coverage_test >= 0.90,
         sprintf("CPCB 7d test coverage = %.1f%% (letter targets 95%%)",
                 100 * cpcb$coverage_test))

audit_ok("A8_calibration_is_true_forecast",
         holdout_cal,
         "scripts/experiments/run_conformal.R uses a hold-out recursive forecast for calibration (not in-sample)")

# Paper-protocol bands in section 8 use test residuals (quantile of |y-yhat|).
pp <- paste(readLines("scripts/experiments/run_paper_protocol.R"), collapse = "\n")
uses_test_resid <- grepl("quantile\\(abs\\(split\\$y_test - yhat\\)", pp)
audit_ok("A8_section8_band_not_from_test_residuals", !uses_test_resid,
         "scripts/experiments/run_paper_protocol.R sets the 95% band from |test residual| (coverage by construction)")
