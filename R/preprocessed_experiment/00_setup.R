# Setup for the CPCB preprocessed experiment: config, paths, logging, integrity guard.
# Shared R/ helpers are sourced unchanged; nothing here edits them.

pe_cfg <- function(path = file.path(PROJECT_ROOT, "config", "preprocessed_experiment.yaml")) {
  cfg <- yaml::read_yaml(path)
  cfg$.path <- path
  cfg
}

pe_dir <- function(cfg, kind = c("store", "results"), ...) {
  kind <- match.arg(kind)
  d <- file.path(PROJECT_ROOT, cfg$paths[[kind]], ...)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

pe_log_path <- function(cfg) file.path(pe_dir(cfg, "results"), "run_log.txt")

pe_log <- function(cfg, ...) {
  line <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ", paste0(..., collapse = ""))
  cat(line, "\n", sep = "")
  cat(line, "\n", file = pe_log_path(cfg), append = TRUE, sep = "")
}

# kaisen's pp_log()/decomp_log() append to store/preprocess_log.txt and
# store/decomp/decomp_log.txt. Within this R session only, send those lines to the
# experiment log instead, so no shared file is touched. The R/ files are not edited.
pe_redirect_shared_logs <- function(cfg) {
  assign("pp_log", function(...) pe_log(cfg, "[kaisen] ", ...), envir = .GlobalEnv)
  assign("decomp_log", function(...) pe_log(cfg, "[kaisen decomp] ", ...), envir = .GlobalEnv)
  invisible(TRUE)
}

pe_time <- function(x, cfg) lubridate::ymd_hm(x, tz = cfg$tz)

# ---- integrity guard ----------------------------------------------------------
# Hash every file outside .git and the experiment's own paths.

pe_protected_files <- function(cfg) {
  all <- list.files(PROJECT_ROOT, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  own <- c("^\\.git/", paste0("^", cfg$paths$store, "/"), paste0("^", cfg$paths$results, "/"),
           "^R/preprocessed_experiment/", "^tests/preprocessed_experiment/",
           "^config/preprocessed_experiment\\.yaml$", "^run_preprocessed_experiment\\.R$")
  keep <- !Reduce(`|`, lapply(own, function(p) grepl(p, all)))
  sort(all[keep])
}

pe_hash_files <- function(files) {
  vapply(files, function(f) digest::digest(file = file.path(PROJECT_ROOT, f), algo = "sha256"),
         character(1))
}

pe_guard_snapshot <- function(cfg) {
  files <- pe_protected_files(cfg)
  h <- pe_hash_files(files)
  path <- file.path(pe_dir(cfg, "results", "guard"), "hashes_before.json")
  jsonlite::write_json(list(created = format(Sys.time()), git = git_commit_hash(),
                            n_files = length(h), sha256 = as.list(h)),
                       path, auto_unbox = TRUE, pretty = TRUE)
  pe_log(cfg, "guard snapshot: ", length(h), " protected files -> ", path)
  invisible(h)
}

pe_guard_verify <- function(cfg, stage = "") {
  path <- file.path(pe_dir(cfg, "results", "guard"), "hashes_before.json")
  if (!file.exists(path)) stop("No guard snapshot; run the 'guard' phase first.")
  before <- unlist(jsonlite::read_json(path)$sha256)
  files <- pe_protected_files(cfg)
  now <- pe_hash_files(files)
  changed <- names(before)[names(before) %in% names(now) & before != now[names(before)]]
  removed <- setdiff(names(before), names(now))
  added <- setdiff(names(now), names(before))
  res <- data.frame(check = c("changed", "removed", "added"),
                    n = c(length(changed), length(removed), length(added)),
                    files = c(paste(changed, collapse = "; "), paste(removed, collapse = "; "),
                              paste(added, collapse = "; ")))
  out <- file.path(pe_dir(cfg, "results", "guard"),
                   paste0("verify_", if (nzchar(stage)) stage else "now", ".csv"))
  utils::write.csv(res, out, row.names = FALSE)
  ok <- !length(changed) && !length(removed) && !length(added)
  pe_log(cfg, "guard verify [", stage, "]: ", length(before), " files, changed=", length(changed),
         " removed=", length(removed), " added=", length(added), if (ok) " OK" else " FAIL")
  if (!ok) stop("Protected files changed: ", paste(c(changed, removed, added), collapse = ", "))
  invisible(TRUE)
}

# ---- reproducibility record ---------------------------------------------------

pe_provenance <- function(cfg, phase) {
  code <- c(list.files(file.path(PROJECT_ROOT, "R", "preprocessed_experiment"), full.names = TRUE),
            file.path(PROJECT_ROOT, "run_preprocessed_experiment.R"), cfg$.path)
  code <- code[file.exists(code)]
  list(
    phase = phase,
    time = format(Sys.time(), tz = "UTC", usetz = TRUE),
    git = git_commit_hash(),
    r_version = R.version.string,
    packages = pkg_versions(c("lightgbm", "arrow", "dplyr", "tidyr", "ggplot2", "digest",
                              "yaml", "lubridate", "future", "future.apply")),
    config_sha256 = digest::digest(file = cfg$.path, algo = "sha256"),
    code_sha256 = as.list(setNames(vapply(code, function(f) digest::digest(file = f, algo = "sha256"),
                                          character(1)),
                                   sub(paste0(PROJECT_ROOT, "/"), "", code, fixed = TRUE))),
    seed = cfg$seed,
    command = paste(c("Rscript run_preprocessed_experiment.R", commandArgs(trailingOnly = TRUE)),
                    collapse = " ")
  )
}

pe_write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
  path
}

pe_write_csv <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
  path
}
