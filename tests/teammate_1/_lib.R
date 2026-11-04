# Shared assertions for T1 tests. Run from project root.

if (!isTRUE(get0(".T1_LIB", ifnotfound = FALSE))) {
  if (!file.exists("R/load_all.R")) {
    if (file.exists("../../R/load_all.R")) setwd("../..")
    else if (file.exists("../R/load_all.R")) setwd("..")
  }
  source("R/load_all.R")
  sys.source("R/teammate_1/t1_pipeline.R", envir = .GlobalEnv)
  T1_FAILS <<- character()
  T1_PASSES <<- character()
  t1_ok <- function(id, cond, msg) {
    ok <- isTRUE(cond)
    cat(sprintf("%s %s: %s\n", if (ok) "PASS" else "FAIL", id, msg))
    if (ok) T1_PASSES <<- c(T1_PASSES, id) else T1_FAILS <<- c(T1_FAILS, id)
    ok
  }
  .T1_LIB <- TRUE
}
