# Cross-frequency EDA for CPCB PM2.5 Haar MRA components.
# Writes only under results/intercomponent_eda/. Does not train forecasting models.
#
# Usage (project root):
#   Rscript run_intercomponent_eda.R

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

source("R/load_all.R")
sys.source("R/teammate_1/t1_pipeline.R", envir = .GlobalEnv)
sys.source("R/teammate_1/intercomponent_eda.R", envir = .GlobalEnv)

message("Starting intercomponent EDA. No forecasting models will be trained.")
eda_run("CPCB", "PM2.5")
message("Intercomponent EDA finished.")
