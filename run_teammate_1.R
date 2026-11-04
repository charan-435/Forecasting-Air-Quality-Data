# T1 frequency-specific model selection.
# Writes only under results/teammate_1/. Does not touch original WaveCatBoost or T2.
#
# Usage (project root):
#   Rscript run_teammate_1.R smoke
#   Rscript run_teammate_1.R
#   Rscript run_teammate_1.R full

args <- commandArgs(trailingOnly = TRUE)
mode <- if (!length(args) || tolower(args[[1]]) %in% c("smoke", "--smoke", "-q", "quick")) {
  "smoke"
} else if (tolower(args[[1]]) %in% c("full", "--full")) {
  "full"
} else {
  tolower(args[[1]])
}

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

source("R/load_all.R")
sys.source("R/teammate_1/t1_pipeline.R", envir = .GlobalEnv)

if (!dir.exists(file.path(RES_DIR, "teammate_1"))) {
  dir.create(file.path(RES_DIR, "teammate_1"), recursive = TRUE)
}

message("Starting T1 (", mode, "). Original results/ and T2 paths will not be written.")
t1_run(mode)
message("T1 finished.")
