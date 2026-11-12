# Helpers used by the interactive report. Training stays in R/load_all.R.
report_helper_files <- c(
  "R/core/01_constants.R", "R/core/02_data.R", "R/core/03_preprocess.R",
  "R/preprocessing/20_ingest.R", "R/preprocessing/21_quality.R",
  "R/preprocessing/22_impute.R", "R/preprocessing/23_store_clean.R",
  "R/core/04_modwt.R", "R/core/05_features.R", "R/core/08_metrics.R",
  "R/core/10_eda_design.R", "R/reporting/result_tables.R",
  "R/reporting/shillong_plots.R"
)

load_report_helpers <- function() {
  # Explicit imports let rsconnect discover packages before server startup.
  # No packages are downloaded or models trained while serving this report.
  library(readr)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(purrr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
  library(plotly)
  library(shiny)
  library(DT)
  library(forecast)
  library(tseries)
  library(urca)
  library(imputeTS)
  library(zoo)
  library(scales)
  library(jsonlite)
  library(yaml)
  library(arrow)
  library(digest)
  # EMD is used by the small illustrative decomposition panel.
  library(EMD)
  for (path in report_helper_files) {
    if (!file.exists(path)) stop("Missing report helper: ", path)
    sys.source(path, envir = .GlobalEnv)
  }
}
