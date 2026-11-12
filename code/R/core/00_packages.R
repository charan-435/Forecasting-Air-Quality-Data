# Packages for the WaveCatBoost analysis.
# CatBoost is not on CRAN; try GitHub binary, else fall back to XGBoost.

.project_packages <- c(
  "readr", "dplyr", "tidyr", "tibble", "purrr", "stringr",
  "lubridate", "ggplot2", "plotly", "shiny", "DT",
  "forecast", "tseries", "urca", "imputeTS", "zoo",
  "xgboost", "lightgbm", "waveslim",
  "future", "future.apply", "furrr", "scales", "jsonlite",
  "yaml", "arrow", "digest", "knitr"
)

ensure_packages <- function(pkgs = .project_packages, install_missing = getOption("ats.install_missing", TRUE)) {
  available <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  missing <- pkgs[!available]
  if (length(missing) && install_missing) {
    install.packages(missing, repos = "https://cloud.r-project.org", dependencies = TRUE)
  }
  # Wavelet calls use waveslim:: explicitly, so its startup hook is unnecessary.
  available <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  if (any(!available)) stop("Missing packages: ", paste(pkgs[!available], collapse = ", "))
  attach <- setdiff(pkgs, "waveslim")
  invisible(lapply(attach, function(p) {
    suppressPackageStartupMessages(library(p, character.only = TRUE))
  }))
}

has_catboost <- function() {
  requireNamespace("catboost", quietly = TRUE)
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
if (isTRUE(getOption("ats.install_missing", TRUE)) && !requireNamespace("EMD", quietly = TRUE)) {
  try(install.packages("EMD", repos = "https://cloud.r-project.org"), silent = TRUE)
}
if (requireNamespace("EMD", quietly = TRUE)) {
  suppressPackageStartupMessages(library(EMD))
}
CATBOOST_AVAILABLE <- has_catboost() ||
  (isTRUE(getOption("ats.install_missing", TRUE)) && try_install_catboost())
if (CATBOOST_AVAILABLE) {
  suppressPackageStartupMessages(library(catboost))
} else {
  message("CatBoost R package is not available. WaveCatBoost / CatBoost will use XGBoost as a documented fallback.")
}
