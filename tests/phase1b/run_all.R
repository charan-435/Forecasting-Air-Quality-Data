# Rscript tests/phase1b/run_all.R   (from the project root)

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  this <- dirname(normalizePath(sub("^--file=", "", file_arg)))
  setwd(file.path(this, "..", ".."))
}
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

scripts <- c(
  "01_causality.R", "02_additivity.R", "03_validity.R", "04_schema.R",
  "05_resume.R", "06_determinism.R", "07_screen_embargo.R", "08_dummy_method.R"
)
P1B_FAILS <<- character()
P1B_PASSES <<- character()
for (s in scripts) {
  cat("\n==== ", s, " ====\n", sep = "")
  sys.source(file.path("tests", "phase1b", s), envir = .GlobalEnv)
}
cat("\n==== SUMMARY ====\n")
cat("PASS", length(P1B_PASSES), " FAIL", length(P1B_FAILS), "\n")
if (length(P1B_FAILS)) {
  cat("Failed:\n", paste0("  - ", P1B_FAILS, collapse = "\n"), "\n")
  quit(status = 1)
}
quit(status = 0)
