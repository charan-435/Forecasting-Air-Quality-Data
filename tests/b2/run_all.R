file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  this <- dirname(normalizePath(sub("^--file=", "", file_arg)))
  setwd(file.path(this, "..", ".."))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

sys.source("tests/b2/_lib.R", envir = .GlobalEnv)
cat("\n==== 01_features_and_leakage.R ====\n")
sys.source("tests/b2/01_features_and_leakage.R", envir = .GlobalEnv)
cat("\n==== B2 TEST SUMMARY ====\n")
cat("PASS", length(B2_PASSES), " FAIL", length(B2_FAILS), "\n")
if (length(B2_FAILS)) {
  cat("Failed:\n", paste0("  - ", B2_FAILS, collapse = "\n"), "\n")
  quit(status = 1)
}
quit(status = 0)
