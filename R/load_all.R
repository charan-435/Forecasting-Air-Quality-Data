# Source every helper. Call from the project root or from analysis.Rmd.

local({
  this_dir <- file.path(getwd(), "R")
  if (!dir.exists(this_dir) && dir.exists("R")) this_dir <- "R"
  files <- c(
    "00_packages.R", "01_constants.R", "02_data.R", "03_preprocess.R",
    "04_modwt.R", "05_features.R", "06_models.R", "07_conformal.R",
    "08_metrics.R", "09_hparams.R"
  )
  for (f in files) {
    path <- file.path(this_dir, f)
    if (!file.exists(path)) stop("Missing helper: ", path)
    sys.source(path, envir = .GlobalEnv)
  }
})
