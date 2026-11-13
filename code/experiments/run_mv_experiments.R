# Multivariate forecasting, Phase 2 driver: complete raw B0 / B1 experiments.
#   Rscript code/experiments/run_mv_experiments.R --stage=check                   # tests, counts, hashes
#   Rscript code/experiments/run_mv_experiments.R --stage=smoke                   # Phase 1 config, all horizons
#   Rscript code/experiments/run_mv_experiments.R --stage=model --family=lightgbm # tune on validation + seeds
#   Rscript code/experiments/run_mv_experiments.R --stage=featsel                 # Stage C
#   Rscript code/experiments/run_mv_experiments.R --stage=targets                 # six targets, separate vs shared
#   Rscript code/experiments/run_mv_experiments.R --stage=report                  # tables, comparisons, plots
# UNMASKED throughout. Writes only under results/multivariate/phase2/.
# Every stage except check refuses to run until check has passed.

options(warn = 1)
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
# Runners live two folders below the project root.
if (length(file_arg)) setwd(normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "..", "..")))
if (!file.exists("code/R/multivariate/40_mv_data.R")) stop("Run from the project root.")

MV_LAYER <- c("code/R/multivariate/40_mv_data.R", "code/R/multivariate/41_mv_features.R", "code/R/multivariate/43_mv_models.R", "code/R/multivariate/44_mv_metrics.R",
              "code/R/multivariate/45_mv_families.R", "code/R/multivariate/46_mv_featsel.R", "code/R/multivariate/47_mv_eval.R", "code/R/multivariate/48_mv_runner.R")
for (f in MV_LAYER) sys.source(f, envir = .GlobalEnv)
sys.source("code/tests/multivariate/expected_counts.R", envir = .GlobalEnv)

args <- commandArgs(trailingOnly = TRUE)
arg_val <- function(key, default) {
  a <- grep(paste0("^--", key, "="), args, value = TRUE)
  if (!length(a)) return(default)
  strsplit(sub(paste0("^--", key, "="), "", a[1]), ",")[[1]]
}
stage <- arg_val("stage", "check")[1]

EC <- mv_exp_cfg()
E <- EC$exp; cfg <- EC$base
OUT <- E$output_dir
if (!identical(normalizePath(OUT, mustWork = FALSE),
               normalizePath(file.path("results", "multivariate", "phase2"), mustWork = FALSE)))
  stop("output_dir must be results/multivariate/phase2")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
H <- as.integer(arg_val("horizons", unlist(E$horizons)))
DESIGNS <- arg_val("designs", unlist(E$designs))
SEEDS <- as.integer(unlist(E$seeds))
L <- as.integer(cfg$lookback_h)

panel <- mv_load_panel(cfg)
fill <- mv_fill_hours(panel)
scales <- lapply(stats::setNames(panel$pollutants, panel$pollutants),
                 function(p) mv_block_scale(cfg, panel, "train", target = p)$scale)

log_line <- function(...) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...))
  cat(msg, "\n")
  cat(msg, "\n", file = file.path(OUT, "run_log.txt"), append = TRUE)
}

require_check <- function() {
  ok <- file.path(OUT, "check", "CHECK_PASSED")
  if (!file.exists(ok)) stop("Run --stage=check first (tests must pass before any model is trained).")
}

stage_meta <- function(dir, extra = list()) {
  jsonlite::write_json(c(list(
    stage = stage, run_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
    args = args, quality_mask = "none (UNMASKED)", package_versions = as.list(mv_pkg_versions()),
    git_commit = mv_git_commit(), host = Sys.info()[["sysname"]],
    config_sha256 = list(base = mv_file_sha256(E$base_config),
                         experiments = mv_file_sha256("code/config/multivariate_experiments.yaml")),
    code_sha256 = as.list(vapply(c(MV_LAYER, "code/experiments/run_mv_experiments.R"), mv_file_sha256, ""))), extra),
    file.path(dir, "RUN_METADATA.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)
}

# ---- check ------------------------------------------------------------------------------
if (stage == "check") {
  d <- file.path(OUT, "check"); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(d, "CHECK_PASSED"))
  rs <- file.path(R.home("bin"), "Rscript")
  Sys.setenv(MV_TEST_OUT_DIR = file.path(d, "tests_phase1"))
  s1 <- system2(rs, "code/tests/multivariate/run_tests.R")
  Sys.setenv(MV_TEST_OUT_DIR = file.path(d, "tests_phase2"))
  s2 <- system2(rs, "code/tests/multivariate/run_tests_phase2.R")
  Sys.unsetenv("MV_TEST_OUT_DIR")
  if (!identical(as.integer(s1), 0L) || !identical(as.integer(s2), 0L))
    stop("Test suite failed; see ", d, ". No model was trained.")

  counts <- mv_sample_counts(cfg, panel$times)
  expc <- mv_expected_counts(cfg)
  cc <- merge(counts, expc, by = c("horizon_h", "block"), sort = FALSE)
  cc$matches_expected <- cc$samples == cc$expected_samples &
    cc$first_origin == cc$expected_first_origin & cc$last_target == cc$expected_last_target
  if (!all(cc$matches_expected)) stop("sample counts disagree with the calendar computation")
  fc <- list()
  for (h in as.integer(unlist(cfg$horizons))) {
    s <- mv_samples(cfg, panel$times, h)
    for (b in c("train", "validation", "test")) {
      si <- s[s$block == b, ]
      g <- mv_fill_groups(fill, si$origin_idx, si$target_idx, L)
      fc[[length(fc) + 1L]] <- data.frame(horizon_h = h, block = b, samples = nrow(si),
        constant_fill_targets = sum(g$constant_fill_target), non_fill_targets = sum(g$non_fill_target),
        clean_samples = sum(g$clean), pct_fill_targets = round(100 * mean(g$constant_fill_target), 1))
    }
  }
  fc <- do.call(rbind, fc)
  cc <- merge(cc, fc, by = c("horizon_h", "block", "samples"), sort = FALSE)
  cc <- cc[order(cc$horizon_h, match(cc$block, c("train", "validation", "test"))), ]
  mv_write_csv(cc, file.path(d, "SAMPLE_COUNTS_UNMASKED.csv"))
  hs <- do.call(rbind, lapply(as.integer(unlist(cfg$horizons)), function(h)
    do.call(rbind, lapply(c("B0", "B1"), function(ds) mv_dataset_hashes(mv_dataset(cfg, panel, ds, h))))))
  mv_write_csv(hs, file.path(d, "DATASET_HASHES.csv"))
  fr <- rle(fill)
  mv_write_csv(data.frame(start = mv_fmt_ts(panel$times[cumsum(fr$lengths) - fr$lengths + 1L][fr$values]),
                          end = mv_fmt_ts(panel$times[cumsum(fr$lengths)][fr$values]),
                          hours = fr$lengths[fr$values]), file.path(d, "CONSTANT_FILL_RUNS.csv"))
  stage_meta(d, list(fill_hours = sum(fill), scales = scales))
  writeLines(format(Sys.time(), tz = "UTC"), file.path(d, "CHECK_PASSED"))
  log_line("check passed: both test suites, counts verified, hashes written")
}

# ---- smoke: Phase 1 configuration at all four horizons ----------------------------------
if (stage == "smoke") {
  require_check()
  d <- file.path(OUT, "smoke"); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  p <- cfg$model$params; seed <- as.integer(cfg$model$seed)
  preds <- list(); info <- list()
  for (h in H) for (ds_name in DESIGNS) {
    ds <- mv_dataset(cfg, panel, ds_name, h)
    r <- mv_select_and_refit("lightgbm", ds, p, seed)
    preds[[paste(ds_name, h)]] <- mv_pred_frame(ds, r, "smoke")
    info[[paste(ds_name, h)]] <- data.frame(design = ds_name, horizon_h = h, best_iter = r$best_iter,
                                            iterations_run = r$iterations_run, hit_cap = r$iterations_run >= p$num_iterations,
                                            elapsed_s = round(r$elapsed_s, 2))
    log_line(sprintf("smoke %s h=%d best_iter=%d ran=%d", ds_name, h, r$best_iter, r$iterations_run))
  }
  pr <- do.call(rbind, preds)
  saveRDS(pr, file.path(d, "predictions.rds"))
  mv_write_csv(do.call(rbind, info), file.path(d, "SMOKE_RUNS.csv"))
  mt <- mv_metric_table(pr, panel, fill, L, scales)
  mv_write_csv(mt, file.path(d, "SMOKE_METRICS.csv"))
  # reproduction of the Phase 1 h = 24 smoke predictions on this machine
  old <- file.path("results", "multivariate", "phase1", "SMOKE_PREDICTIONS.csv")
  if (file.exists(old) && 24L %in% H) {
    o <- utils::read.csv(old, stringsAsFactors = FALSE)
    rep_rows <- list()
    for (ds_name in intersect(DESIGNS, unique(o$design))) for (b in c("validation", "test")) {
      a <- o[o$design == ds_name & o$block == b, ]
      n <- pr[pr$design == ds_name & pr$horizon_h == 24 & pr$block == b, ]
      rep_rows[[paste(ds_name, b)]] <- data.frame(design = ds_name, block = b, n = nrow(n),
        same_targets = identical(a$y, n$y), max_abs_pred_diff = max(abs(a$yhat - n$yhat)))
    }
    mv_write_csv(do.call(rbind, rep_rows), file.path(d, "PHASE1_REPRODUCTION.csv"))
  }
  stage_meta(d)
}

# ---- model: validation grid search, then multi-seed refits ----------------------------------
if (stage == "model") {
  require_check()
  fams <- arg_val("family", "lightgbm")
  for (family in fams) {
    fcfg <- E$families[[family]]
    if (is.null(fcfg)) stop("no config for family ", family)
    d <- file.path(OUT, "models", family); dir.create(d, recursive = TRUE, showWarnings = FALSE)
    tf <- mv_family_transform(fcfg)
    cands <- mv_candidates(fcfg)
    seeds <- if (family %in% mv_stochastic_families()) SEEDS else SEEDS[1]
    tun <- list(); sel <- list(); preds <- list(); info <- list(); imps <- list()
    for (h in H) for (ds_name in DESIGNS) {
      ds <- mv_dataset(cfg, panel, ds_name, h)
      t0 <- proc.time()[["elapsed"]]
      tu <- mv_tune(family, ds, cands, as.integer(E$tuning_seed), tf)
      tun[[paste(ds_name, h)]] <- cbind(family = family, design = ds_name, horizon_h = h, tu$table)
      sel[[paste(ds_name, h)]] <- data.frame(family = family, design = ds_name, horizon_h = h,
        candidate = tu$best, val_MAE_tuning = min(tu$table$val_MAE),
        params = as.character(jsonlite::toJSON(tu$params, auto_unbox = TRUE, digits = NA)))
      fr <- mv_final_runs(family, ds, tu$params, seeds, tf, "model", list(variant = "raw"))
      preds[[paste(ds_name, h)]] <- fr$pred; info[[paste(ds_name, h)]] <- fr$info
      imps[[paste(ds_name, h)]] <- fr$importance
      log_line(sprintf("%s %s h=%d best=%s valMAE=%.3f (%d candidates, %d seeds, %.0f s)", family, ds_name, h,
                       tu$best, min(tu$table$val_MAE), length(cands), length(seeds),
                       proc.time()[["elapsed"]] - t0))
    }
    pr <- do.call(rbind, preds)
    saveRDS(pr, file.path(d, "predictions.rds"))
    mv_write_csv(do.call(rbind, tun), file.path(d, "TUNING.csv"))
    mv_write_csv(do.call(rbind, sel), file.path(d, "SELECTED.csv"))
    mv_write_csv(do.call(rbind, info), file.path(d, "RUNS.csv"))
    if (length(imps)) mv_write_csv(do.call(rbind, imps), file.path(d, "IMPORTANCE.csv"))
    mt <- mv_metric_table(rbind(pr, transform(mv_seed_mean(pr), seed = "mean")[, names(pr)]),
                          panel, fill, L, scales)
    mv_write_csv(mt, file.path(d, "METRICS.csv"))
    stage_meta(d, list(family = family, seeds = seeds, n_candidates = length(cands),
                       transform = tf$name, selection = "validation MAE of the train-only fit"))
  }
}

if (stage %in% c("featsel", "targets", "report")) {
  sys.source(file.path("code", "R", "multivariate", "49_mv_stages.R"), envir = .GlobalEnv)
  mv_run_stage(stage)
}
