# B2 decomposed multivariate forecasting (CPCB UNMASKED).
# Writes only under results/b2/.
#
#   Rscript run_b2.R smoke
#   Rscript run_b2.R stageA
#   Rscript run_b2.R full

args <- commandArgs(trailingOnly = TRUE)
mode <- if (!length(args)) "smoke" else tolower(args[[1]])
if (mode %in% c("--smoke", "-q")) mode <- "smoke"
if (mode %in% c("--full")) mode <- "full"
if (mode %in% c("--stagea", "stagea")) mode <- "stageA"
if (mode %in% c("--stageb", "stageb")) mode <- "stageB"

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

source("R/load_all.R")
sys.source("R/teammate_1/t1_pipeline.R", envir = .GlobalEnv)
sys.source("R/b2/b2_config.R", envir = .GlobalEnv)
sys.source("R/b2/b2_features.R", envir = .GlobalEnv)
sys.source("R/b2/b2_models.R", envir = .GlobalEnv)
sys.source("R/b2/b2_pipeline.R", envir = .GlobalEnv)

message("Starting B2 (", mode, "). T1/B1/stored decomps will not be written.")
b2_run(mode)
message("B2 finished.")
