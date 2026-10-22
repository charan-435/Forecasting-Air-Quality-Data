# Quick checks: data load, Haar reconstruction, one LightGBM 12-step forecast.

source("R/load_all.R")
stopifnot(file.exists(file.path(RAW_DIR, "CPCB.csv")))

raw <- load_raw_datasets()
stopifnot(nrow(raw$CPCB) > 8000, nrow(raw$ID1) > 8000)
stopifnot(abs(sampling_hours(raw$CPCB$Datetime) - 1) < 1e-6)

series <- prepare_all_series(raw)
s <- series[["CPCB_PM2.5"]]
x <- s$y[1:256]
mra <- haar_mra(x, 5)
err <- max(abs(mra_reconstruct(mra) - x))
cat("MRA reconstruction max error:", signif(err, 4), "\n")
stopifnot(err < 1e-8)

pick <- choose_J(s$y)
cat("J paper:", pick$J_paper, " J elbow:", pick$J_elbow, "\n")

sp <- chrono_split(s$y, s$times, 24)
pr <- default_tree_params()
pr$nrounds <- 40L
pr$early_stopping <- 10L
sc <- minmax_fit(sp$y_train)
ytr <- minmax_apply(sp$y_train, sc)
fc <- fit_and_forecast("lgb", ytr, h = 12, params = pr, J = 3)
yhat <- minmax_invert(fc$yhat, sc)
cat("LGB 12-step MASE:", round(mase(sp$y_train, sp$y_test[1:12], yhat), 3), "\n")
cat("SMOKE OK\n")
