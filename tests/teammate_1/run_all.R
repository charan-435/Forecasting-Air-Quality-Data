# Rscript tests/teammate_1/run_all.R   (from the project root)

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  this <- dirname(normalizePath(sub("^--file=", "", file_arg)))
  setwd(file.path(this, "..", ".."))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

sys.source("tests/teammate_1/_lib.R", envir = .GlobalEnv)

scripts <- c(
  "01_stored_unchanged.R",
  "02_independent_inputs.R",
  "03_splits_and_leakage.R",
  "04_selection_and_recon.R",
  "05_tuned.R"
)
for (s in scripts) {
  cat("\n==== ", s, " ====\n", sep = "")
  sys.source(file.path("tests", "teammate_1", s), envir = .GlobalEnv)
}
cat("\n==== T1 TEST SUMMARY ====\n")
cat("PASS", length(T1_PASSES), " FAIL", length(T1_FAILS), "\n")
if (length(T1_FAILS)) {
  cat("Failed:\n", paste0("  - ", T1_FAILS, collapse = "\n"), "\n")
  quit(status = 1)
}
quit(status = 0)
