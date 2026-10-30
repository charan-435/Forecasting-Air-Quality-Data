# Load (and optionally install) packages used by the WaveCatBoost R analysis.
# CatBoost is not on CRAN; we try a GitHub binary and fall back to XGBoost.

.project_packages <- c(
  "readr", "dplyr", "tidyr", "tibble", "purrr", "stringr",
  "lubridate", "ggplot2", "plotly", "shiny", "DT",
  "forecast", "tseries", "urca", "imputeTS", "zoo",
  "xgboost", "lightgbm", "waveslim",
  "future", "furrr", "scales", "jsonlite"
)

ensure_packages <- function(pkgs = .project_packages, install_missing = TRUE) {
  inst <- rownames(installed.packages())
  missing <- setdiff(pkgs, inst)
  if (length(missing) && install_missing) {
    install.packages(missing, repos = "https://cloud.r-project.org", dependencies = TRUE)
  }
  invisible(lapply(intersect(pkgs, rownames(installed.packages())), function(p) {
    suppressPackageStartupMessages(library(p, character.only = TRUE))
  }))
}

has_catboost <- function() {
  "catboost" %in% rownames(installed.packages())
}

try_install_catboost <- function() {
  if (has_catboost()) return(TRUE)
  ver <- "1.2.8"
  url <- sprintf(
    "https://github.com/catboost/catboost/releases/download/v%s/catboost-R-windows-x86_64-%s.tgz",
    ver, ver
  )
  ok <- FALSE
  try({
    if (!"remotes" %in% rownames(installed.packages())) {
      install.packages("remotes", repos = "https://cloud.r-project.org")
    }
    remotes::install_url(url, INSTALL_opts = c("--no-multiarch", "--no-test-load"))
    ok <- has_catboost()
  }, silent = TRUE)
  ok
}

ensure_packages()
# EMD is only used in the extension section; skip quietly if CRAN is unreachable.
if (!"EMD" %in% rownames(installed.packages())) {
  try(install.packages("EMD", repos = "https://cloud.r-project.org"), silent = TRUE)
}
if ("EMD" %in% rownames(installed.packages())) {
  suppressPackageStartupMessages(library(EMD))
}
CATBOOST_AVAILABLE <- has_catboost() || try_install_catboost()
if (CATBOOST_AVAILABLE) {
  suppressPackageStartupMessages(library(catboost))
} else {
  message("CatBoost R package is not available. WaveCatBoost / CatBoost will use XGBoost as a documented fallback.")
}
