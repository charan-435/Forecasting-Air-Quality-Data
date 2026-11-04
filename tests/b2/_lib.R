if (!isTRUE(get0(".B2_LIB", ifnotfound = FALSE))) {
  if (!file.exists("R/load_all.R")) {
    if (file.exists("../../R/load_all.R")) setwd("../..")
    else if (file.exists("../R/load_all.R")) setwd("..")
  }
  source("R/load_all.R")
  sys.source("R/teammate_1/t1_pipeline.R", envir = .GlobalEnv)
  sys.source("R/b2/b2_config.R", envir = .GlobalEnv)
  sys.source("R/b2/b2_features.R", envir = .GlobalEnv)
  sys.source("R/b2/b2_models.R", envir = .GlobalEnv)
  sys.source("R/b2/b2_pipeline.R", envir = .GlobalEnv)
  B2_FAILS <<- character()
  B2_PASSES <<- character()
  b2_ok <- function(id, cond, msg) {
    ok <- isTRUE(cond)
    cat(sprintf("%s %s: %s\n", if (ok) "PASS" else "FAIL", id, msg))
    if (ok) B2_PASSES <<- c(B2_PASSES, id) else B2_FAILS <<- c(B2_FAILS, id)
    ok
  }
  .B2_LIB <- TRUE
}
