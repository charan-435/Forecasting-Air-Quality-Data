# Paths, pollutants, horizons, and modelling defaults.

PROJECT_ROOT <- local({
  # Walk up from the calling file / working directory until we see data/raw.
  candidates <- c(getwd(), dirname(getwd()))
  for (p in candidates) {
    if (dir.exists(file.path(p, "data", "raw"))) return(normalizePath(p))
  }
  normalizePath(getwd())
})

RAW_DIR <- file.path(PROJECT_ROOT, "data", "raw")
PROC_DIR <- file.path(PROJECT_ROOT, "data", "processed")
RES_DIR <- file.path(PROJECT_ROOT, "results")

POLLUTANTS <- c("NO2", "O3", "CO", "SO2", "PM2.5", "PM10")
SENSORS <- c("CPCB", "ID1")
SEASONALITY <- 24L  # hourly data, daily cycle

HORIZONS <- list(
  `1d`  = 24L,
  `7d`  = 168L,
  `14d` = 336L,
  `31d` = 744L
)

# NAAQS / WHO guides used only for the extra decision-rule layer (not in the paper).
# India NAAQS 24-h: PM2.5 = 60 ug/m3, PM10 = 100 ug/m3.
# WHO 2021 24-h: PM2.5 = 15, PM10 = 45.
ALERT_THRESHOLDS <- list(
  `PM2.5` = list(who = 15, naaqs = 60, unit = "ug/m3"),
  PM10    = list(who = 45, naaqs = 100, unit = "ug/m3"),
  NO2     = list(who = 25, naaqs = 80, unit = "ug/m3"),
  O3      = list(who = 100, naaqs = 100, unit = "ug/m3"),
  SO2     = list(who = 40, naaqs = 80, unit = "ug/m3"),
  CO      = list(who = 4000, naaqs = 2000, unit = "ug/m3")
)

dir.create(PROC_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(RES_DIR, recursive = TRUE, showWarnings = FALSE)
