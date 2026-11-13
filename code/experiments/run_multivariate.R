# Multivariate forecasting, Phase 1 driver (B0 / B1, direct fixed-horizon).
#   Rscript code/experiments/run_multivariate.R                       # smoke: B0 + B1, LightGBM, h = 24
#   Rscript code/experiments/run_multivariate.R --horizons=24,168 --designs=B0,B1
# Runs code/tests/multivariate/run_tests.R first and stops if any test fails.
# UNMASKED: all aligned hours are used (config quality_mask: none).
# Writes only to results/multivariate/phase1/.

options(warn = 1)
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
# Runners live two folders below the project root.
if (length(file_arg)) setwd(normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "..", "..")))
if (!file.exists("code/R/multivariate/40_mv_data.R")) stop("Run from the project root.")

LAYER <- c("code/R/multivariate/40_mv_data.R", "code/R/multivariate/41_mv_features.R", "code/R/multivariate/43_mv_models.R", "code/R/multivariate/44_mv_metrics.R")
for (f in LAYER) sys.source(f, envir = .GlobalEnv)
sys.source("code/tests/multivariate/expected_counts.R", envir = .GlobalEnv)

args <- commandArgs(trailingOnly = TRUE)
arg_val <- function(key, default) {
  a <- grep(paste0("^--", key, "="), args, value = TRUE)
  if (!length(a)) return(default)
  strsplit(sub(paste0("^--", key, "="), "", a[1]), ",")[[1]]
}

cfg <- mv_cfg()
out_dir <- cfg$output_dir
if (!identical(normalizePath(out_dir, mustWork = FALSE),
               normalizePath(file.path("results", "multivariate", "phase1"), mustWork = FALSE)))
  stop("output_dir must be results/multivariate/phase1")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
designs <- arg_val("designs", unlist(cfg$smoke$designs))
horizons <- as.integer(arg_val("horizons", unlist(cfg$smoke$horizons)))
family <- arg_val("family", cfg$smoke$family)[1]
stopifnot(all(horizons %in% as.integer(unlist(cfg$horizons))))

# ---- 1. tests must pass first ---------------------------------------------------
rs <- file.path(R.home("bin"), "Rscript")
status <- system2(rs, "code/tests/multivariate/run_tests.R")
if (!identical(as.integer(status), 0L))
  stop("Test suite failed (see ", file.path(out_dir, "TEST_SUMMARY.md"), "). No model was trained.")

# ---- 2. data, counts, manifests ---------------------------------------------------
panel <- mv_load_panel(cfg)
units <- mv_check_units(cfg, panel)
counts <- mv_sample_counts(cfg, panel$times)
expc <- mv_expected_counts(cfg)
cc <- merge(counts, expc, by = c("horizon_h", "block"), sort = FALSE)
cc$matches_expected <- cc$samples == cc$expected_samples &
  cc$eligible_origins == cc$expected_eligible_origins &
  cc$first_origin == cc$expected_first_origin & cc$last_origin == cc$expected_last_origin &
  cc$first_target == cc$expected_first_target & cc$last_target == cc$expected_last_target
cc <- cc[order(cc$horizon_h, match(cc$block, c("train", "validation", "test"))), ]
cc$refit_samples <- ifelse(cc$block == "test", NA,
                           ave(cc$samples * (cc$block != "test"), cc$horizon_h, FUN = sum))
utils::write.csv(cc[, c("horizon_h", "block", "block_start", "block_end", "block_hours",
                        "eligible_origins", "samples", "first_origin", "last_origin",
                        "first_target", "last_target", "earliest_lag_hour",
                        "expected_eligible_origins", "expected_samples", "matches_expected",
                        "refit_samples", "quality_mask")],
                 file.path(out_dir, "SAMPLE_COUNTS.csv"), row.names = FALSE)
if (!all(cc$matches_expected)) stop("Sample counts do not match the independent computation.")

for (d in c("B0", "B1"))
  utils::write.csv(mv_feature_manifest(cfg, d), file.path(out_dir, paste0("FEATURE_MANIFEST_", d, ".csv")),
                   row.names = FALSE)

pkg_ver <- function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "not installed"
pkgs <- c(R = as.character(getRversion()),
          vapply(c("lightgbm", "data.table", "yaml", "digest", "jsonlite", "arrow", "nanoparquet"),
                 pkg_ver, ""))
git <- tryCatch(suppressWarnings(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
                error = function(e) NA_character_)
git <- if (length(git)) git[1] else NA_character_

# ---- 3. smoke runs ------------------------------------------------------------------
seed <- as.integer(cfg$model$seed)
params <- cfg$model$params
sc_train <- mv_block_scale(cfg, panel, "train")
sc_refit <- mv_block_scale(cfg, panel, c("train", "validation"))
results <- list(); preds <- list(); hashes <- list(); runs <- list(); dsets <- list()
for (h in horizons) for (d in designs) {
  ds <- mv_dataset(cfg, panel, d, h)
  dsets[[paste(d, h)]] <- ds
  hashes[[paste(d, h)]] <- mv_dataset_hashes(ds)
  run <- mv_select_and_refit(family, ds, params, seed)
  runs[[paste(d, h)]] <- run
  results[[paste(d, h)]] <- mv_score(cfg, ds, run, sc_train, sc_refit)
  for (b in c("train", "validation", "test")) {
    bk <- ds$blocks[[b]]
    preds[[paste(d, h, b)]] <- data.frame(
      design = d, horizon_h = h, block = b, origin = mv_fmt_ts(bk$origin_ts),
      target = mv_fmt_ts(bk$target_ts), y = bk$y, yhat = run$pred[[b]],
      stringsAsFactors = FALSE)
  }
  cat(sprintf("%s h=%d: best_iter=%d (ran %d, early stop %s), %.1f s\n", d, h, run$best_iter,
              run$iterations_run, run$early_stopped, run$elapsed_s))
}
res <- do.call(rbind, results)
utils::write.csv(res, file.path(out_dir, "SMOKE_RESULTS.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, preds), file.path(out_dir, "SMOKE_PREDICTIONS.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, hashes), file.path(out_dir, "DATASET_HASHES.csv"), row.names = FALSE)

# paired B1 vs B0 on identical samples (validation and test)
cmp <- list()
if (all(c("B0", "B1") %in% designs)) for (h in horizons) for (b in c("validation", "test")) {
  a <- dsets[[paste("B1", h)]]$blocks[[b]]; z <- dsets[[paste("B0", h)]]$blocks[[b]]
  if (!identical(a$origin_ts, z$origin_ts) || !identical(a$y, z$y))
    stop("B0 and B1 samples differ; paired comparison invalid")
  bs <- cfg$metrics$bootstrap
  pc <- mv_bootstrap_paired(a$y, runs[[paste("B1", h)]]$pred[[b]], runs[[paste("B0", h)]]$pred[[b]],
                            bs$block_h, bs$reps, bs$seed, bs$level)
  cmp[[paste(h, b)]] <- cbind(data.frame(horizon_h = h, block = b, comparison = "B1 vs B0",
                                         n = length(a$y), stringsAsFactors = FALSE), pc)
}
if (length(cmp)) utils::write.csv(do.call(rbind, cmp), file.path(out_dir, "SMOKE_COMPARISON.csv"),
                                  row.names = FALSE)

# ---- 4. configs, manifests, metadata ---------------------------------------------
eff <- .mv_lgb_params(params, seed)
model_cfg <- list(
  family = family, package = "lightgbm", package_version = pkgs[["lightgbm"]],
  seed = seed, note = "Starting configuration taken from T1; not tuned for multivariate inputs.",
  config_params = params, effective_lightgbm_params = eff,
  max_rounds = params$num_iterations, early_stopping_rounds = params$early_stopping_rounds,
  selection = "fit on train samples; early stopping on validation samples (l2)",
  final_fit = "refit on train + validation samples with the selected iteration count frozen",
  test_use = "scored once after the refit; never used for fitting or selection",
  transform = "identity (original values, no scaling)",
  strategy = cfg$strategy, quality_mask = cfg$quality_mask,
  smoke_selected = lapply(runs, function(r) list(design = r$design, horizon_h = r$h,
                                                 best_iter = r$best_iter,
                                                 iterations_run = r$iterations_run,
                                                 early_stopped = r$early_stopped,
                                                 best_validation_l2 = r$best_val_l2,
                                                 refit_rounds = r$refit_rounds,
                                                 n_refit = r$n_refit)))
yaml::write_yaml(model_cfg, file.path(out_dir, "MODEL_CONFIG.yaml"))

bl <- mv_blocks(cfg, panel$times)
manifest <- list(
  experiment = cfg$experiment, created = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
  quality_mask = "none (UNMASKED: includes 2,304 upstream constant-fill hours)",
  data_source = c(panel$source, list(rows = nrow(panel$X))),
  pollutant_order = panel$pollutants, units = cfg$data$units,
  unit_check = units,
  timestamps = list(timezone = panel$tz, first = mv_fmt_ts(panel$times[1]),
                    last = mv_fmt_ts(panel$times[nrow(panel$X)]), n = nrow(panel$X),
                    step_seconds = 3600),
  split = list(name = cfg$split$name, first_origin = cfg$split$first_origin,
               blocks = bl[, c("block", "start", "end", "start_idx", "end_idx", "hours")]),
  lookback_h = cfg$lookback_h, horizons = unlist(cfg$horizons), horizons_run = horizons,
  target = cfg$target, strategy = cfg$strategy,
  designs = lapply(c(B0 = "B0", B1 = "B1"), function(d) list(
    pollutants = mv_design_pollutants(cfg, d),
    n_features = length(mv_feature_names(mv_design_pollutants(cfg, d), cfg$lookback_h)),
    feature_names = mv_feature_names(mv_design_pollutants(cfg, d), cfg$lookback_h))),
  seed = seed, bootstrap = cfg$metrics$bootstrap,
  mase_scale = list(primary = sc_train, refit_alternative = sc_refit),
  package_versions = as.list(pkgs), git_commit = git,
  config_sha256 = mv_file_sha256("code/config/multivariate.yaml"),
  code_sha256 = as.list(vapply(c(LAYER, "code/experiments/run_multivariate.R", "code/tests/multivariate/run_tests.R",
                                 "code/tests/multivariate/expected_counts.R"), mv_file_sha256, "")))
jsonlite::write_json(manifest, file.path(out_dir, "DATASET_MANIFEST.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = NA)
jsonlite::write_json(list(
  run_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"), designs = designs, horizons = horizons,
  family = family, seed = seed, tests_passed = TRUE,
  elapsed_s = lapply(runs, `[[`, "elapsed_s"), host = Sys.info()[["sysname"]],
  package_versions = as.list(pkgs), git_commit = git,
  outputs = sort(list.files(out_dir))), file.path(out_dir, "RUN_METADATA.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = NA)
cat("Wrote", out_dir, "\n")
