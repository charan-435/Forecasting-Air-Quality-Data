# Second-stage Shillong experiments: PCA inputs and direct / recursive / hybrid
# forecasting on top of the original architecture study (run_shillong_arch.R).
#
#   Rscript run_second_stage.R --stage=tests     # tests/second_stage/run_tests.R
#   Rscript run_second_stage.R --stage=smoke     # light config, one station, all strategies
#   Rscript run_second_stage.R --stage=run --station=Lumpyngngad --archs=A2 --pca=none,0.9
#   Rscript run_second_stage.R --stage=report
# Options: --horizons=24,168 --archs=... --pca=...
# run requires tests/TESTS_PASSED and smoke/SMOKE_PASSED. Nothing outside
# results/second_stage is written; the original study's outputs are read only.

options(warn = 1, width = 200)
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  a <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(a)) sub(paste0("^--", name, "="), "", a[1]) else default
}
stage <- opt("stage", "tests")

SS_SOURCES <- c("R/40_mv_data.R", "R/41_mv_features.R", "R/43_mv_models.R", "R/44_mv_metrics.R",
                "R/45_mv_families.R", "R/47_mv_eval.R", "R/48_mv_runner.R",
                "R/50_sh_data.R", "R/51_sh_features.R", "R/53_sh_experiments.R",
                "R/55_sh_report.R", "R/60_ss_core.R", "R/61_ss_stages.R", "R/62_ss_report.R")
suppressMessages({
  source("R/load_all.R")
  for (f in SS_SOURCES) source(f)
  library(data.table)
})

scfg <- yaml::read_yaml("config/second_stage.yaml")
cfg <- yaml::read_yaml(scfg$base_config)
out <- scfg$output_dir
dir.create(out, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(out, "run_log.txt")
say <- function(...) {
  line <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", ...)
  cat(line, "\n"); cat(line, "\n", file = log_path, append = TRUE)
}
log_error <- function(st, a, p, msg) {
  path <- file.path(out, "ERRORS.csv")
  d <- data.frame(time = format(Sys.time()), station = st, arch = a, pca = p, error = msg)
  utils::write.table(d, path, sep = ",", row.names = FALSE, col.names = !file.exists(path),
                     append = file.exists(path), qmethod = "double")
}
need <- function(path, what) if (!file.exists(path)) stop(what, " missing: run that stage first (", path, ")")
split_arg <- function(x) strsplit(x, ",")[[1]]
pca_arg <- function(x) lapply(split_arg(x), function(p) if (p == "none") "none" else as.numeric(p))

write_meta <- function(dir, extra = list()) {
  files <- c("config/second_stage.yaml", scfg$base_config, "run_second_stage.R", SS_SOURCES,
             "tests/second_stage/run_tests.R")
  meta <- c(list(stage = stage, time = format(Sys.time()), git = mv_git_commit(),
                 packages = as.list(mv_pkg_versions()), args = args,
                 sha256 = as.list(vapply(files, function(f) digest::digest(file = f, algo = "sha256"), ""))),
            extra)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(meta, file.path(dir, "RUN_METADATA.json"), auto_unbox = TRUE, pretty = TRUE)
  file.copy(c("config/second_stage.yaml", scfg$base_config), dir, overwrite = TRUE)
}

load_station <- function(st) {
  long <- sh_read_long(cfg)
  panel <- sh_panel(cfg, long, st)
  splits <- sh_splits(cfg, st)
  list(panel = panel, splits = splits, avail = sh_available(cfg, panel, splits))
}

if (stage == "tests") {
  need(file.path(scfg$original_output_dir, "audit", "AUDIT_PASSED"), "original Shillong audit")
  dir <- file.path(out, "tests"); dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(dir, "TESTS_PASSED"))
  env <- new.env(parent = globalenv())
  env$cfg <- cfg; env$scfg <- scfg; env$load_station <- load_station
  sys.source("tests/second_stage/run_tests.R", envir = env)
  res <- env$SS_TEST_RESULTS
  mv_write_csv(res, file.path(dir, "TEST_RESULTS.csv"))
  say("tests: ", sum(res$pass), "/", nrow(res))
  write_meta(dir)
  if (all(res$pass)) writeLines(format(Sys.time()), file.path(dir, "TESTS_PASSED"))
  else stop("tests failed: ", paste(res$test[!res$pass], collapse = "; "))

} else if (stage == "smoke") {
  need(file.path(out, "tests", "TESTS_PASSED"), "tests")
  ss_stage_smoke(cfg, scfg, out, say, load_station)
  write_meta(file.path(out, "smoke"))

} else if (stage == "run") {
  need(file.path(out, "tests", "TESTS_PASSED"), "tests")
  need(file.path(out, "smoke", "SMOKE_PASSED"), "smoke")
  stations <- split_arg(opt("station", paste(cfg$stations, collapse = ",")))
  archs <- split_arg(opt("archs", paste(unlist(scfg$primary_architectures), collapse = ",")))
  pcas <- pca_arg(opt("pca", paste(unlist(scfg$pca), collapse = ",")))
  horizons <- as.integer(split_arg(opt("horizons", paste(cfg$horizons, collapse = ","))))
  for (st in stations) {
    S <- load_station(st)
    for (a in archs) for (p in pcas) {
      t0 <- Sys.time()
      ok <- tryCatch({
        ss_run_cell(cfg, scfg, S, a, p, out, say, horizons); TRUE
      }, error = function(e) {
        say("ERROR ", st, " ", a, " ", ss_pca_label(p), ": ", conditionMessage(e))
        log_error(st, a, ss_pca_label(p), conditionMessage(e)); FALSE
      })
      if (ok) say(sprintf("cell %s %s %s done in %.1f min", st, a, ss_pca_label(p),
                          as.numeric(difftime(Sys.time(), t0, units = "mins"))))
    }
  }
  write_meta(file.path(out, "runs"))

} else if (stage == "report") {
  ss_stage_report(cfg, scfg, out, say, load_station)
  write_meta(file.path(out, "report"))

} else stop("unknown stage ", stage)
