# A6: J / p / clipping chosen on which data?
source("docs/audit/tests/_lib.R")

exp <- paste(readLines("scripts/experiments/run_experiments.R"), collapse = "\n")
j_full <- grepl("choose_J\\(series\\[\\[pm_key\\]\\]\\$y\\)", exp)
eda_full <- grepl("jpick <- choose_J\\(y\\)", exp)

# choose_J on full vs train-only: does J_elbow change?
packed <- readRDS(file.path(PROC_DIR, "series.rds"))
s <- packed$series$CPCB_PM2.5
j_all <- choose_J(s$y)
h31 <- HORIZONS[["31d"]]
j_tr <- choose_J(s$y[seq_len(length(s$y) - h31)])
audit_info("choose_J full series: J_paper=", j_all$J_paper, " J_elbow=", j_all$J_elbow)
audit_info("choose_J minus 31d test: J_paper=", j_tr$J_paper, " J_elbow=", j_tr$J_elbow)

# pacf_cutoff: used in analysis.Rmd EDA, default p comes from hparams/grid not pacf.
feat <- paste(readLines("R/core/05_features.R"), collapse = "\n")
p_from_pacf <- grepl("pacf_cutoff", feat)
exp_uses_pacf <- grepl("pacf_cutoff", exp)

# Clipping bounds are hardcoded, not fit on data.
clip_hardcoded <- grepl("PM2.5` = 1000", paste(readLines("R/core/03_preprocess.R"), collapse = "\n"))

write_tbl(j_all$energy, "A6_energy_full.csv")

audit_ok("A6_choose_J_on_train_only", !j_full,
         "scripts/experiments/run_experiments.R calls choose_J on the full CPCB PM2.5 series")
audit_ok("A6_J_elbow_stable_if_test_dropped",
         identical(j_all$J_elbow, j_tr$J_elbow),
         sprintf("J_elbow full=%s vs train-minus-31d=%s (capped at 5 either way)",
                 j_all$J_elbow, j_tr$J_elbow))
audit_ok("A6_p_not_from_full_series_pacf", !exp_uses_pacf,
         "bake-off does not call pacf_cutoff on the full series")
audit_ok("A6_clip_bounds_hardcoded", clip_hardcoded,
         "physical caps are constants, not estimated from test data")
