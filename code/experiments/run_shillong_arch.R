# Shillong architecture comparison: undecomposed / decomposed, separate / shared,
# with / without non-lagged covariates, univariate / multivariate.
#
#   Rscript code/experiments/run_shillong_arch.R --stage=preprocess    # Phase 1a causal store -> data/processed/store/shillong/clean
#   Rscript code/experiments/run_shillong_arch.R --stage=audit         # Phase 1 data + decomposition audit, tests
#   Rscript code/experiments/run_shillong_arch.R --stage=smoke         # Phases 2-3: every architecture, PM2.5, h=24
#   Rscript code/experiments/run_shillong_arch.R --stage=full --station=Lumpyngngad --horizons=24
#   Rscript code/experiments/run_shillong_arch.R --stage=families --station=Lumpyngngad --horizons=24
#   Rscript code/experiments/run_shillong_arch.R --stage=targets --station=Lumpyngngad --horizons=24
#   Rscript code/experiments/run_shillong_arch.R --stage=sensitivity --station=Lumpyngngad
#   Rscript code/experiments/run_shillong_arch.R --stage=report
# Options: --target=PM2.5 --archs=A0,B0 --family=lightgbm --force
# Every stage after audit requires <output_dir>/audit/AUDIT_PASSED; full,
# families, targets and sensitivity also require smoke/SMOKE_PASSED.

options(warn = 1, width = 200)
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
# Runners live two folders below the project root.
if (length(file_arg)) setwd(normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "..", "..")))
if (!file.exists("code/R/load_all.R")) stop("Run from the project root.")

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  a <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(a)) sub(paste0("^--", name, "="), "", a[1]) else default
}
stage <- opt("stage", "audit")
force <- "--force" %in% args

suppressMessages({
  source("code/R/load_all.R")
  for (f in c("code/R/multivariate/40_mv_data.R", "code/R/multivariate/41_mv_features.R", "code/R/multivariate/43_mv_models.R", "code/R/multivariate/44_mv_metrics.R",
              "code/R/multivariate/45_mv_families.R", "code/R/multivariate/47_mv_eval.R", "code/R/multivariate/48_mv_runner.R",
              "code/R/shillong_architecture/50_sh_data.R", "code/R/shillong_architecture/51_sh_features.R", "code/R/shillong_architecture/52_sh_audit.R",
              "code/R/shillong_architecture/53_sh_experiments.R", "code/R/shillong_architecture/54_sh_stages.R", "code/R/shillong_architecture/55_sh_report.R"))
    source(f)
  library(data.table)
})

cfg <- yaml::read_yaml("code/config/shillong_arch.yaml")
out <- cfg$output_dir
dir.create(out, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(out, "run_log.txt")
say <- function(...) {
  line <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", ...)
  cat(line, "\n"); cat(line, "\n", file = log_path, append = TRUE)
}
need <- function(path, what) if (!file.exists(path)) stop(what, " missing: run that stage first (", path, ")")

stations <- strsplit(opt("station", paste(cfg$stations, collapse = ",")), ",")[[1]]
horizons <- as.integer(strsplit(opt("horizons", paste(cfg$horizons, collapse = ",")), ",")[[1]])
family <- opt("family", "lightgbm")

write_meta <- function(dir, extra = list()) {
  files <- c("code/config/shillong_arch.yaml", "code/experiments/run_shillong_arch.R",
             list.files("code/R", recursive = TRUE, pattern = "^(4[0-9]|5[0-9])_.*\\.R$", full.names = TRUE))
  meta <- c(list(stage = stage, time = format(Sys.time()), git = mv_git_commit(),
                 packages = as.list(mv_pkg_versions()), args = args,
                 sha256 = as.list(vapply(files, mv_file_sha256, ""))),
            extra)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(meta, file.path(dir, "RUN_METADATA.json"), auto_unbox = TRUE, pretty = TRUE)
}

load_station <- function(st) {
  long <- sh_read_long(cfg)
  panel <- sh_panel(cfg, long, st)
  splits <- sh_splits(cfg, st)
  avail <- sh_available(cfg, panel, splits)
  list(panel = panel, splits = splits, avail = avail)
}

run_dir <- function(fam, st, target, h) file.path(out, "runs", fam, st, target, paste0("h", h))

run_cells <- function(st, targets, archs, fams, hs, cfg_run = cfg, tag = "full") {
  S <- load_station(st)
  for (target in targets) {
    if (!target %in% S$avail$pollutants) { say(st, " ", target, ": not available, skipped"); next }
    for (h in hs) {
      smp <- sh_samples(cfg_run, S$panel, S$splits, target, h, S$avail$pollutants)
      for (fam in fams) for (a in archs) {
        path <- file.path(run_dir(fam, st, target, h), paste0(a, ".rds"))
        if (file.exists(path) && !force) next
        r <- sh_run_arch(cfg_run, S$panel, S$avail, S$splits, smp, target, h, a, fam,
                         as.integer(unlist(cfg_run$seeds)), as.integer(cfg_run$tune_seed))
        dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
        saveRDS(r, path)
        lv <- sh_seed_mean(r$pred)[component == "LEVEL" & block == "validation"]
        say(sprintf("%s %s %s h=%d %s %s valMAE=%.3f n_val=%d (%.0f s)", tag, st, target, h,
                    fam, a, lv[, mean(abs(yhat - y))], nrow(lv), r$elapsed_s))
      }
    }
  }
}

if (stage == "preprocess") {
  t0 <- Sys.time()
  sh_build_clean_store(cfg, force = force)
  say("preprocess done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " s")

} else if (stage == "audit") {
  sh_stage_audit(cfg, out, say)
  write_meta(file.path(out, "audit"))

} else if (stage == "smoke") {
  need(file.path(out, "audit", "AUDIT_PASSED"), "audit")
  sh_stage_smoke(cfg, out, say, load_station)
  write_meta(file.path(out, "smoke"))

} else if (stage %in% c("full", "families", "targets")) {
  need(file.path(out, "audit", "AUDIT_PASSED"), "audit")
  need(file.path(out, "smoke", "SMOKE_PASSED"), "smoke")
  t0 <- Sys.time()
  for (st in stations) {
    if (stage == "full") {
      targets <- strsplit(opt("target", cfg$primary_target), ",")[[1]]
      archs <- strsplit(opt("archs", paste(unlist(cfg$architectures), collapse = ",")), ",")[[1]]
      run_cells(st, targets, archs, family, horizons)
    } else if (stage == "families") {
      sl <- sh_shortlist(cfg, out, st)
      say(st, " stage-2 shortlist: ", paste(sl, collapse = ", "))
      fams <- strsplit(opt("family", paste(unlist(cfg$stage2$families), collapse = ",")), ",")[[1]]
      run_cells(st, cfg$primary_target, sl, fams, horizons, tag = "families")
    } else {
      sl <- unique(c(unlist(cfg$targets_stage$archs_fixed), sh_shortlist(cfg, out, st)))
      S <- load_station(st)
      tg <- setdiff(S$avail$pollutants, cfg$primary_target)
      say(st, " targets: ", paste(tg, collapse = ", "), " | archs: ", paste(sl, collapse = ", "))
      run_cells(st, tg, sl, "lightgbm", horizons, tag = "targets")
    }
  }
  say(stage, " ", paste(stations, collapse = ","), " h=", paste(horizons, collapse = ","),
      " done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " s")
  write_meta(file.path(out, "runs"), list(last_stage = stage))

} else if (stage == "sensitivity") {
  need(file.path(out, "smoke", "SMOKE_PASSED"), "smoke")
  for (st in stations) sh_stage_sensitivity(cfg, out, say, load_station, st, horizons)

} else if (stage == "report") {
  sh_stage_report(cfg, out, say, load_station)
  write_meta(file.path(out, "report"))

} else stop("unknown stage ", stage)
