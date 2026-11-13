# Helpers used by the interactive report. Training stays in code/R/load_all.R.
report_helper_files <- c(
  "code/R/core/01_constants.R", "code/R/core/02_data.R", "code/R/core/03_preprocess.R",
  "code/R/preprocessing/20_ingest.R", "code/R/preprocessing/21_quality.R",
  "code/R/preprocessing/22_impute.R", "code/R/preprocessing/23_store_clean.R",
  "code/R/core/04_modwt.R", "code/R/core/05_features.R", "code/R/core/08_metrics.R",
  "code/R/core/10_eda_design.R", "code/R/reporting/result_tables.R",
  "code/R/reporting/shillong_plots.R"
)

load_report_helpers <- function() {
  # Load display packages explicitly so missing dependencies are clear.
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
    full_path <- file.path(PROJECT_ROOT, path)
    if (!file.exists(full_path)) stop("Missing report helper: ", full_path)
    sys.source(full_path, envir = .GlobalEnv)
  }
}
