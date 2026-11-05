# Shared audit helpers. Source from the project root or from docs/audit/tests/.

if (!isTRUE(get0(".AUDIT_LIB", ifnotfound = FALSE))) {
  root <- getwd()
  if (!file.exists(file.path(root, "R", "load_all.R"))) {
    if (file.exists(file.path(root, "..", "..", "..", "R", "load_all.R"))) {
      setwd(file.path(root, "..", "..", ".."))
    } else if (file.exists(file.path(root, "..", "R", "load_all.R"))) {
      setwd(file.path(root, ".."))
    }
  }
  PROJECT_ROOT_AUDIT <- normalizePath(getwd())
  source("R/load_all.R")
  AUDIT_DIR <- file.path(PROJECT_ROOT_AUDIT, "docs", "audit")
  AUDIT_OUT <- file.path(AUDIT_DIR, "impact")
  dir.create(AUDIT_OUT, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(AUDIT_DIR, "tests"), showWarnings = FALSE)

  AUDIT_FAILS <<- character()
  AUDIT_PASSES <<- character()

  audit_ok <- function(id, cond, msg) {
    ok <- isTRUE(cond)
    cat(sprintf("%s %s: %s\n", if (ok) "PASS" else "FAIL", id, msg))
    if (ok) AUDIT_PASSES <<- c(AUDIT_PASSES, id)
    else AUDIT_FAILS <<- c(AUDIT_FAILS, id)
    ok
  }

  audit_info <- function(...) cat("INFO ", ..., "\n", sep = "")

  write_tbl <- function(x, name) {
    p <- file.path(AUDIT_OUT, name)
    if (inherits(x, "data.frame")) readr::write_csv(x, p) else saveRDS(x, p)
    p
  }

  .AUDIT_LIB <- TRUE
}
