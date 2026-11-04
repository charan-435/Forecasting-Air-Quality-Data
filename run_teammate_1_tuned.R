# T1-Tuned: component-wise hyperparameter search with frozen T1 architectures.
# Writes only under results/teammate_1/tuned/. Does not touch original T1,
# WaveCatBoost, or T2.
#
# Usage (project root):
#   Rscript run_teammate_1_tuned.R          # CPCB PM2.5 1d, real search budget
#   Rscript run_teammate_1_tuned.R cpcb
#   Rscript run_teammate_1_tuned.R smoke    # tiny budget
#   Rscript run_teammate_1_tuned.R full     # CPCB+ID1, four horizons

args <- commandArgs(trailingOnly = TRUE)
mode <- if (!length(args)) {
  "cpcb"
} else {
  tolower(args[[1]])
}
if (mode %in% c("--smoke", "-q", "quick")) mode <- "smoke"
if (mode %in% c("--full")) mode <- "full"
if (mode %in% c("--cpcb", "default")) mode <- "cpcb"

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

source("R/load_all.R")
sys.source("R/teammate_1/t1_pipeline.R", envir = .GlobalEnv)
sys.source("R/teammate_1/t1_tuned.R", envir = .GlobalEnv)

if (!dir.exists(file.path(RES_DIR, "teammate_1", "tuned"))) {
  dir.create(file.path(RES_DIR, "teammate_1", "tuned"), recursive = TRUE)
}

message("Starting T1-Tuned (", mode, "). Original T1 / results/ / T2 will not be written.")
t1_tuned_run(mode)
message("T1-Tuned finished.")
