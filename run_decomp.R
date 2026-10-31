# Leak-free decomposition store.
#   Rscript run_decomp.R
#   Rscript run_decomp.R --skip-screen --skip-diag
#   Rscript run_decomp.R coef_haar_J10

options(warn = 1)
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

args <- commandArgs(trailingOnly = TRUE)
skip_screen <- "--skip-screen" %in% args
skip_diag <- "--skip-diag" %in% args
method_args <- setdiff(args, c("--skip-screen", "--skip-diag", "--force"))
force <- "--force" %in% args
if (!length(method_args)) method_args <- NULL

need <- c("arrow", "yaml", "digest", "jsonlite", "future", "future.apply", "lightgbm")
miss <- setdiff(need, rownames(installed.packages()))
if (length(miss)) install.packages(miss, repos = "https://cloud.r-project.org")

source("R/load_all.R")
run_decomp(methods = method_args, force = force,
           do_diagnostics = !skip_diag, do_screen = !skip_screen)
