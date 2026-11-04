if (!isTRUE(get0(".P1A_LIB", ifnotfound = FALSE))) {
  if (!file.exists("R/load_all.R")) {
    if (file.exists("../../R/load_all.R")) setwd("../..")
    else if (file.exists("../R/load_all.R")) setwd("..")
  }
  source("R/load_all.R")
  sys.source("R/20_ingest.R", envir = .GlobalEnv)
  sys.source("R/21_quality.R", envir = .GlobalEnv)
  sys.source("R/22_impute.R", envir = .GlobalEnv)
  sys.source("R/23_store_clean.R", envir = .GlobalEnv)
  P1A_FAILS <<- character()
  P1A_PASSES <<- character()
  p1a_ok <- function(id, cond, msg) {
    ok <- isTRUE(cond)
    cat(sprintf("%s %s: %s\n", if (ok) "PASS" else "FAIL", id, msg))
    if (ok) P1A_PASSES <<- c(P1A_PASSES, id) else P1A_FAILS <<- c(P1A_FAILS, id)
    ok
  }
  .P1A_LIB <- TRUE
}

.p1a_cfg <- function() {
  list(
    canonical_units = list(`PM2.5` = "ug/m3", PM10 = "ug/m3", NO2 = "ug/m3",
                           SO2 = "ug/m3", O3 = "ug/m3", CO = "mg/m3",
                           AT = "degC", RH = "pct"),
    bounds = list(`PM2.5` = list(0, 1000), PM10 = list(0, 2000), NO2 = list(0, 1000),
                  SO2 = list(0, 1000), O3 = list(0, 1000), CO = list(0, 50),
                  AT = list(-10, 50), RH = list(0, 100)),
    min_subhour_coverage = 0.75,
    min_daily_hours = 18,
    stuck_hours = list(default = 6),
    pm_ratio_max = 1.1,
    spike = list(window_h = 24, k_mad = 6, mask = FALSE),
    long_gap_hours = 72,
    selection_end = "2023-06-01 00:00",
    n_artificial_gaps = 40L
  )
}
