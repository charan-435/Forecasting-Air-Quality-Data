# A4: min-max fit is train-only; inversion before metrics.
source("audit/tests/_lib.R")

exp <- paste(readLines("run_experiments.R"), collapse = "\n")
fit_train <- grepl("sc <- minmax_fit\\(split\\$y_train\\)", exp)
invert_before_score <- grepl("minmax_invert\\(yhat, sc\\)", exp) &&
  grepl("score_forecast\\(split\\$y_train, split\\$y_test, yhat\\)", exp)

# Empirical: scaler from train does not equal scaler from train+test.
packed <- readRDS(file.path(PROC_DIR, "series.rds"))
s <- packed$series$CPCB_PM2.5
h <- 24L
n <- length(s$y)
ytr <- s$y[seq_len(n - h)]
yte <- s$y[(n - h + 1):n]
sc_tr <- minmax_fit(ytr)
sc_all <- minmax_fit(s$y)
audit_info("CPCB PM2.5 1d: train min/max=", sc_tr$min, "/", sc_tr$max,
           " full-series min/max=", sc_all$min, "/", sc_all$max)

audit_ok("A4_code_fits_on_train", fit_train,
         "run_experiments.R minmax_fit(split$y_train)")
audit_ok("A4_invert_before_metrics", invert_before_score,
         "yhat inverted before score_forecast()")
# Not a failure if they differ — that's the point of train-only.
audit_ok("A4_train_scaler_defined", is.finite(sc_tr$min) && is.finite(sc_tr$max),
         "train scaler is finite")
