# Load shared helpers for the original benchmark and the interactive report.
# Run from the project root. The first file also checks/installs dependencies.

local({
  this_dir <- file.path(getwd(), "R")
  if (!dir.exists(this_dir) && dir.exists("R")) this_dir <- "R"
  # Keep the order explicit: settings and data helpers come before models.
  # The isolated cleaned-CPCB modules are loaded by their own experiment runner.
  files <- c(
    "core/00_packages.R", "core/01_constants.R", "core/02_data.R", "core/03_preprocess.R",
    "preprocessing/20_ingest.R", "preprocessing/21_quality.R", "preprocessing/22_impute.R", "preprocessing/23_store_clean.R",
    "decomposition/30_decomp_registry.R", "decomposition/31_decomp_causal.R", "decomposition/32_decomp_trailing.R",
    "decomposition/33_decomp_diagnostics.R", "decomposition/34_decomp_screen.R", "decomposition/35_decomp_io.R",
    "core/04_modwt.R", "core/05_features.R", "core/06_models.R", "core/07_conformal.R",
    "core/08_metrics.R", "core/09_hparams.R", "core/10_eda_design.R"
  )
  for (f in files) {
    path <- file.path(this_dir, f)
    if (!file.exists(path)) stop("Missing helper: ", path)
    sys.source(path, envir = .GlobalEnv)
  }
})
