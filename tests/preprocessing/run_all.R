# Rscript tests/preprocessing/run_all.R   (from the project root)

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  this <- dirname(normalizePath(sub("^--file=", "", file_arg)))
  setwd(file.path(this, "..", ".."))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

scripts <- c(
  "01_causal_fill.R", "02_labelling.R", "03_coverage.R", "04_faults.R",
  "06_selection_end.R", "07_grid.R", "08_schema.R", "05_scoring_guard.R",
  "09_e2e.R"
)
P1A_FAILS <<- character()
P1A_PASSES <<- character()
for (s in scripts) {
  cat("\n==== ", s, " ====\n", sep = "")
  sys.source(file.path("tests", "preprocessing", s), envir = .GlobalEnv)
}
cat("\n==== SUMMARY ====\n")
cat("PASS", length(P1A_PASSES), " FAIL", length(P1A_FAILS), "\n")
if (length(P1A_FAILS)) {
  cat("Failed:\n", paste0("  - ", P1A_FAILS, collapse = "\n"), "\n")
  quit(status = 1)
}
quit(status = 0)
