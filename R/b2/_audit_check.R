source("R/load_all.R")
sys.source("R/teammate_1/t1_pipeline.R", envir = .GlobalEnv)
pols <- c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO")
series <- t1_load_prepared_series()
cat("series keys:", paste(names(series), collapse = ","), "\n")
for (p in pols) {
  d <- t1_load_stored_components("CPCB", p)
  ncomp <- sum(stats::complete.cases(d[, c("D1", "D2", "D3", "D4", "D5", "S5")]))
  cat(sprintf("%s: rows=%s complete6=%s range=%s..%s\n", p, nrow(d), ncomp,
              as.character(min(d$timestamp)), as.character(max(d$timestamp))))
}
so <- series[["CPCB_PM2.5"]]
sp <- chrono_split_tvt(so$y, so$times, 24L, VAL_HOURS)
cat("PM2.5 n=", length(so$y), " train/val/test=", sp$n_train, sp$n_val, sp$n_test, "\n")
