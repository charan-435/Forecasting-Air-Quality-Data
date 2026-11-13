# Leak-free hourly preprocessing.
#   Rscript code/preprocessing/run_preprocess.R             # uses code/config/preprocess.yaml `active`
#   Rscript code/preprocessing/run_preprocess.R paper       # paper CSVs, skip quality/imputation
#   Rscript code/preprocessing/run_preprocess.R shillong    # 15-min CPCB Shillong, full causal pipeline

options(warn = 1)
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "..", "..")))
}
if (!file.exists("code/R/load_all.R")) stop("Run from the project root.")

args <- commandArgs(trailingOnly = TRUE)
active_arg <- if (length(args) && args[[1]] %in% c("paper", "shillong")) args[[1]] else NULL

need <- c("arrow", "yaml", "digest", "future", "future.apply")
miss <- setdiff(need, rownames(installed.packages()))
if (length(miss)) install.packages(miss, repos = "https://cloud.r-project.org")

source("code/R/load_all.R")
run_preprocess(active = active_arg)
