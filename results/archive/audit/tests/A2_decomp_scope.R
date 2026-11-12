# A2: is MODWT/MRA applied only to training data, per horizon split?
source("docs/audit/tests/_lib.R")

# Bake-off path (scores.csv): wave_fit_components(y_train) — train only.
src <- paste(readLines("R/core/06_models.R"), collapse = "\n")
train_only_fit <- grepl("wave_fit_components <- function\\(y_train", src) &&
  grepl("generic_mra\\(y_train, J", src)
train_only_fc <- grepl("generic_mra\\(y_train, wave_fit\\$J", src)

# choose_J in run_experiments uses the FULL series.
exp <- paste(readLines("scripts/experiments/run_experiments.R"), collapse = "\n")
j_full <- grepl("choose_J\\(series\\[\\[pm_key\\]\\]\\$y\\)", exp)

# paper protocol: haar_modwt(y) on the full series including test.
pp <- paste(readLines("R/core/06_models.R"), collapse = "\n")
full_modwt <- grepl("wt <- haar_modwt\\(y, J\\)", pp) &&
  grepl("paper_wave_walkforward", pp)

audit_ok("A2_bakeoff_mra_on_train_arg", train_only_fit && train_only_fc,
         "wave_fit_components/wave_forecast_components take y_train")
# choose_J on full series is a model-selection leak (also A6).
audit_ok("A2_choose_J_not_on_full_series", !j_full,
         "scripts/experiments/run_experiments.R choose_J(series$y) uses the full CPCB PM2.5 series")
audit_ok("A2_paper_protocol_not_full_series", !full_modwt,
         "paper_wave_walkforward() runs Haar MODWT on the full y (test included)")

# Empirical: train-only MRA at the origin does not change if TEST values change.
packed <- readRDS(file.path(PROC_DIR, "series.rds"))
s <- packed$series$CPCB_PM2.5
h <- 168L
n <- length(s$y)
ytr <- s$y[seq_len(n - h)]
yte <- s$y[(n - h + 1):n]
m1 <- haar_mra(ytr, 5L)
ytr2 <- ytr  # identical train
# Perturb only test
s2 <- s$y; s2[(n - h + 1):n] <- s2[(n - h + 1):n] + 50
m2 <- haar_mra(s2[seq_len(n - h)], 5L)
# train slice unchanged, so MRA must match
audit_ok("A2_train_only_mra_ignores_test_values",
         max(abs(m1$S - m2$S), abs(m1$D$D1 - m2$D$D1)) < 1e-12,
         "Haar MRA on the train slice is invariant to test-set bumps")

# Full-series MODWT DOES change train-window coefficients when test is bumped.
wt1 <- haar_modwt(s$y, 5L)
wt2 <- haar_modwt(s2, 5L)
delta_train <- max(abs(wt2$V[seq_len(n - h)] - wt1$V[seq_len(n - h)]))
audit_info("Full-series V on train window moves by ", signif(delta_train, 3),
           " when test Y is +50 (paper_wave_walkforward leakage).")
audit_ok("A2_full_modwt_train_coeffs_ignore_test", delta_train < 1e-12,
         sprintf("full-series Haar V[train] change when test bumped = %g", delta_train))
