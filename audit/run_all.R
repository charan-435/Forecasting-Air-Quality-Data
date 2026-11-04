# Run every audit/tests/*.R (except _lib.R) from the project root.
# Usage: Rscript audit/run_all.R

root <- getwd()
if (!file.exists(file.path(root, "R", "load_all.R"))) {
  stop("Run from the project root so R/load_all.R is visible.")
}

source("audit/tests/_lib.R")
tests <- sort(list.files("audit/tests", pattern = "^[A-Z].*\\.R$", full.names = TRUE))
cat("Running ", length(tests), " audit tests\n", sep = "")

for (f in tests) {
  cat("\n======== ", basename(f), " ========\n", sep = "")
  ok <- tryCatch({
    sys.source(f, envir = .GlobalEnv)
    TRUE
  }, error = function(e) {
    cat("ERROR ", basename(f), ": ", e$message, "\n", sep = "")
    AUDIT_FAILS <<- c(AUDIT_FAILS, paste0("ERROR:", basename(f)))
    FALSE
  })
}

cat("\n======== SUMMARY ========\n")
cat("PASS ", length(unique(AUDIT_PASSES)), ": ",
    paste(unique(AUDIT_PASSES), collapse = ", "), "\n", sep = "")
cat("FAIL ", length(unique(AUDIT_FAILS)), ": ",
    paste(unique(AUDIT_FAILS), collapse = ", "), "\n", sep = "")
writeLines(c(
  paste("PASS", unique(AUDIT_PASSES)),
  paste("FAIL", unique(AUDIT_FAILS))
), file.path("audit", "impact", "run_all_summary.txt"))
if (length(AUDIT_FAILS)) quit(status = 1) else quit(status = 0)
