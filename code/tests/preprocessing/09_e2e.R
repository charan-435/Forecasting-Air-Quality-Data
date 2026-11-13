# Runs the preprocessing steps together on synthetic station data.

source("code/tests/preprocessing/_lib.R")

tz <- "Asia/Kolkata"
stamps <- seq(as.POSIXct("2023-01-01 00:00:00", tz = tz),
              as.POSIXct("2023-01-05 23:45:00", tz = tz), by = "15 min")
a <- tibble::tibble(
  station = "A", variable = "PM2.5", timestamp_raw = stamps,
  value = 20 + rnorm(length(stamps)), source_id = "synA"
)
stamps_b <- seq(as.POSIXct("2023-01-01 00:00:00", tz = tz),
                as.POSIXct("2023-01-05 23:00:00", tz = tz), by = "1 hour")
b <- tibble::tibble(
  station = "B", variable = "PM2.5", timestamp_raw = stamps_b,
  value = 30 + rnorm(length(stamps_b)), source_id = "synB"
)
cfg <- .p1a_cfg()
cfg$active <- "syn"
cfg$sources <- list(
  list(id = "synA", group = "syn", path = "", adapter = "synthetic",
       station = "A", tz = tz, native_freq_min = 15, time_label = "start",
       skip_preprocess = FALSE, data = a,
       units = list(`PM2.5` = "ug/m3")),
  list(id = "synB", group = "syn", path = "", adapter = "synthetic",
       station = "B", tz = tz, native_freq_min = 60, time_label = "start",
       skip_preprocess = FALSE, data = b,
       units = list(`PM2.5` = "ug/m3"))
)
.GlobalEnv$.PP_CFG <- cfg
ok <- TRUE
msg <- "ok"
tryCatch({
  # Drive the same entry point as production, writing into a temp store root.
  old_root <- PROJECT_ROOT
  tmp <- tempfile("p1a_e2e")
  dir.create(tmp)
  assign("PROJECT_ROOT", tmp, envir = .GlobalEnv)
  dir.create(file.path(tmp, "data", "processed", "store", "clean"), recursive = TRUE)
  out <- run_preprocess(active = "syn", force = TRUE, cfg = cfg)
  ser <- file.path(tmp, "data", "processed", "store", "clean", "series.parquet")
  stopifnot(file.exists(ser))
  d <- tibble::as_tibble(arrow::read_parquet(ser))
  stopifnot(all(c("A", "B") %in% d$station))
  stopifnot(all(CLEAN_COLS %in% names(d)))
  assign("PROJECT_ROOT", old_root, envir = .GlobalEnv)
  unlink(tmp, recursive = TRUE)
}, error = function(e) {
  ok <<- FALSE
  msg <<- e$message
  if (exists("old_root")) assign("PROJECT_ROOT", old_root, envir = .GlobalEnv)
})
p1a_ok("e2e_two_station", ok, msg)
.GlobalEnv$.PP_CFG <- NULL
