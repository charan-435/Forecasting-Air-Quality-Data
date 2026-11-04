source("tests/phase1a/_lib.R")
path <- file.path(PROJECT_ROOT, "store", "clean", "series.parquet")
need_rebuild <- TRUE
if (file.exists(path)) {
  d0 <- tibble::as_tibble(arrow::read_parquet(path, col_select = "timestamp"))
  yr <- as.integer(format(min(d0$timestamp), "%Y"))
  need_rebuild <- yr < 2020 || yr > 2025
}
if (need_rebuild) {
  cat("INFO 07_grid: running paper preprocess to create the store\n")
  run_preprocess(active = "paper", force = TRUE)
}
d <- tibble::as_tibble(arrow::read_parquet(path))
ok <- TRUE
msg <- "ok"
for (stn in unique(d$station)) {
  for (v in unique(d$variable[d$station == stn])) {
    ts <- sort(d$timestamp[d$station == stn & d$variable == v])
    if (anyDuplicated(ts)) { ok <- FALSE; msg <- paste(stn, v, "duplicates"); break }
    tz <- lubridate::tz(ts[1])
    if (!identical(tz, "Asia/Kolkata")) { ok <- FALSE; msg <- paste("tz", tz); break }
    dh <- as.numeric(diff(ts), units = "hours")
    if (any(abs(dh - 1) > 1e-6)) { ok <- FALSE; msg <- paste(stn, v, "gap"); break }
  }
}
p1a_ok("grid_hourly_ist", ok, msg)
