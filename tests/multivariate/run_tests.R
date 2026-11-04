# Phase 1 test suite for the multivariate B0/B1 pipeline. Must pass before any
# model is trained (run_multivariate.R calls it first).
#   Rscript tests/multivariate/run_tests.R
# Writes TEST_SUMMARY.csv / TEST_SUMMARY.md to the configured output dir and
# exits with status 1 if any test fails. Plain base R; no testthat needed.

options(warn = 1)
if (!file.exists("R/40_mv_data.R")) stop("Run from the project root.")
LAYER <- c("R/40_mv_data.R", "R/41_mv_features.R", "R/43_mv_models.R", "R/44_mv_metrics.R")
for (f in LAYER) sys.source(f, envir = .GlobalEnv)
sys.source("tests/multivariate/expected_counts.R", envir = .GlobalEnv)

.res <- list()
expect <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)
mv_test <- function(id, required, name, code) {
  t0 <- proc.time()[["elapsed"]]
  r <- tryCatch({
    d <- force(code)
    list(pass = TRUE, detail = if (is.character(d)) paste(d, collapse = "; ") else "ok")
  }, error = function(e) list(pass = FALSE, detail = conditionMessage(e)))
  .res[[length(.res) + 1L]] <<- data.frame(
    id = id, required_item = required, test = name, pass = r$pass,
    seconds = round(proc.time()[["elapsed"]] - t0, 2), detail = r$detail,
    stringsAsFactors = FALSE)
  cat(sprintf("[%s] %-4s %s%s\n", if (r$pass) "PASS" else "FAIL", id, name,
              if (r$pass) "" else paste0("  -> ", r$detail)))
}

cfg <- mv_cfg()
H <- as.integer(unlist(cfg$horizons))
P <- unlist(cfg$data$pollutants)
L <- as.integer(cfg$lookback_h)
panel <- mv_load_panel(cfg)
tz <- panel$tz
blk <- mv_blocks(cfg, panel$times)
sec <- function(s) as.numeric(as.POSIXct(strptime(s, "%Y-%m-%d %H:%M", tz = tz)))
long <- mv_read_parquet(file.path(cfg$data$source))
long <- long[long$station == cfg$data$station, ]
ds_cache <- list()
get_ds <- function(design, h) {
  k <- paste(design, h)
  if (is.null(ds_cache[[k]])) ds_cache[[k]] <<- mv_dataset(cfg, panel, design, h)
  ds_cache[[k]]
}
fill_vec <- panel$X[1, ]                          # row 1 is a constant-fill hour (Phase 0)
is_fill <- apply(panel$X, 1, function(r) all(abs(r - fill_vec) < 1e-12))

# ---------------------------------------------------------------------------
mv_test("T01", "1", "Timestamp alignment across all six pollutants", {
  ref <- sort(as.numeric(long$timestamp[long$variable == P[1]]))
  for (p in P) {
    tp <- sort(as.numeric(long$timestamp[long$variable == p]))
    expect(identical(tp, ref), paste("instants differ for", p))
    # values joined into the panel equal the store values at the same instant
    sv <- long[long$variable == p, ]
    m <- match(as.numeric(panel$times), as.numeric(sv$timestamp))
    expect(!anyNA(m), paste("unmatched instants for", p))
    expect(identical(panel$X[, p], as.numeric(sv[[cfg$data$value_column]][m])),
           paste("joined values differ for", p))
  }
  expect(identical(as.numeric(panel$times), ref), "panel times differ from store instants")
  sprintf("%d identical instants for %s", length(ref), paste(P, collapse = ","))
})

mv_test("T02", "2", "No duplicate timestamps", {
  expect(anyDuplicated(as.numeric(panel$times)) == 0, "panel has duplicates")
  for (p in P) expect(anyDuplicated(as.numeric(long$timestamp[long$variable == p])) == 0,
                      paste("duplicates in", p))
  "0 duplicates in the panel and in each pollutant"
})

mv_test("T03", "data", "8,880 hours, no missing values, chronological, units", {
  expect(nrow(panel$X) == 8880, "row count")
  expect(all(is.finite(panel$X)), "non-finite values")
  expect(all(diff(as.numeric(panel$times)) == 3600), "not strictly hourly ascending")
  expect(mv_fmt_ts(panel$times[1], tz) == "2022-07-01 00:00", "start")
  expect(mv_fmt_ts(panel$times[8880], tz) == "2023-07-05 23:00", "end")
  u <- mv_check_units(cfg, panel)
  expect(all(u$pass), "unit check")
  expect(identical(colnames(panel$X), P), "panel column order")
  sprintf("n=8880, 0 NA, hourly ascending; CO median %.4f mg/m3", stats::median(panel$X[, "CO"]))
})

mv_test("T04", "3", "Feature counts: 24 (B0) and 144 (B1)", {
  for (h in H) {
    expect(ncol(get_ds("B0", h)$blocks$train$X) == 24, paste("B0 h", h))
    expect(ncol(get_ds("B1", h)$blocks$train$X) == 144, paste("B1 h", h))
    for (b in c("validation", "test")) {
      expect(ncol(get_ds("B0", h)$blocks[[b]]$X) == 24, "B0 block width")
      expect(ncol(get_ds("B1", h)$blocks[[b]]$X) == 144, "B1 block width")
    }
  }
  "B0=24, B1=144 for every horizon and block"
})

mv_test("T05", "4", "Deterministic feature-column ordering", {
  exp_names <- character(0)
  for (p in c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO"))
    for (k in 0:23) exp_names <- c(exp_names, sprintf("%s__lag%02d", p, k))
  ds1 <- get_ds("B1", 24)
  expect(identical(colnames(ds1$blocks$train$X), exp_names), "B1 names/order")
  expect(identical(ds1$feature_names, exp_names), "B1 feature_names")
  expect(identical(colnames(get_ds("B0", 24)$blocks$train$X), exp_names[1:24]), "B0 names")
  again <- mv_dataset(cfg, panel, "B1", 24)
  expect(identical(colnames(again$blocks$test$X), exp_names), "rebuild order")
  man <- mv_feature_manifest(cfg, "B1")
  expect(identical(man$feature, exp_names) && identical(man$position, 1:144), "manifest")
  sprintf("first %s, last %s", exp_names[1], exp_names[144])
})

mv_test("T06", "features", "X values equal the store value at origin minus lag", {
  set.seed(11)
  for (h in H) for (d in c("B0", "B1")) {
    ds <- get_ds(d, h)
    for (b in names(ds$blocks)) {
      bk <- ds$blocks[[b]]
      ii <- unique(c(1, length(bk$y), sample(length(bk$y), 40)))
      for (i in ii) {
        jj <- sample(ncol(bk$X), min(20, ncol(bk$X)))
        for (j in jj) {
          nm <- colnames(bk$X)[j]
          p <- sub("__lag.*$", "", nm); k <- as.integer(sub("^.*__lag", "", nm))
          want_t <- as.numeric(bk$origin_ts[i]) - 3600 * k
          r <- match(want_t, as.numeric(panel$times))
          expect(identical(unname(bk$X[i, j]), unname(panel$X[r, p])), paste("mismatch", d, h, b, nm))
        }
      }
    }
  }
  "checked by timestamp lookup on sampled cells, all designs, horizons and blocks"
})

mv_test("T07", "5", "Perturbing observations after origin t leaves X(t) unchanged", {
  set.seed(5)
  pols <- P
  all_o <- unique(unlist(lapply(H, function(h) mv_samples(cfg, panel$times, h)$origin_idx)))
  edges <- c(blk$first_origin_idx, blk$end_idx - 24L, blk$end_idx - 744L)
  oo <- unique(c(edges, sample(all_o, 60)))
  base <- mv_build_X(panel, oo, pols, L)
  n_changed_future <- 0L
  for (t in oo) {
    pp <- panel
    fut <- seq.int(t + 1L, nrow(pp$X))
    if (length(fut) && t < nrow(pp$X))
      pp$X[fut, ] <- pp$X[fut, ] * 7 + 1000 + stats::rnorm(length(fut) * ncol(pp$X))
    x_new <- mv_build_X(pp, t, pols, L)
    if (!identical(unname(x_new[1, ]), unname(base[match(t, oo), ]))) n_changed_future <- n_changed_future + 1L
  }
  expect(n_changed_future == 0L, sprintf("%d origins changed after future perturbation", n_changed_future))
  # non-target pollutants only, and the hour just before the window
  t <- blk$first_origin_idx[3]
  pp <- panel; pp$X[(t + 1L):nrow(pp$X), c("PM10", "NO2", "SO2", "O3", "CO")] <- -999
  expect(identical(mv_build_X(pp, t, pols, L), mv_build_X(panel, t, pols, L)), "other pollutants' future leaked")
  pp <- panel; pp$X[t - L, ] <- pp$X[t - L, ] + 500
  expect(identical(mv_build_X(pp, t, pols, L), mv_build_X(panel, t, pols, L)), "t-24 entered X(t)")
  # sanity: the window itself is used
  pp <- panel; pp$X[t, "CO"] <- pp$X[t, "CO"] + 1
  expect(!identical(mv_build_X(pp, t, pols, L), mv_build_X(panel, t, pols, L)), "lag00 not used")
  pp <- panel; pp$X[t - (L - 1L), "PM10"] <- pp$X[t - (L - 1L), "PM10"] + 1
  expect(!identical(mv_build_X(pp, t, pols, L), mv_build_X(panel, t, pols, L)), "lag23 not used")
  sprintf("%d origins incl. block edges; future, other-pollutant and t-24 perturbations had no effect", length(oo))
})

mv_test("T08", "targets", "y(t,h) = PM2.5(t+h) and target - origin = h hours", {
  for (h in H) for (d in c("B0", "B1")) for (b in c("train", "validation", "test")) {
    bk <- get_ds(d, h)$blocks[[b]]
    expect(all(as.numeric(bk$target_ts) - as.numeric(bk$origin_ts) == 3600 * h), "offset")
    r <- match(as.numeric(bk$target_ts), as.numeric(panel$times))
    expect(identical(bk$y, panel$X[r, "PM2.5"]), paste("target values", d, h, b))
  }
  "all designs, horizons and blocks"
})

block_check <- function(b, h) {
  s <- mv_samples(cfg, panel$times, h); s <- s[s$block == b, ]
  i <- which(blk$block == b)
  ot <- as.numeric(panel$times[s$origin_idx]); tt <- as.numeric(panel$times[s$target_idx])
  lo <- sec(blk$start[i]); hi <- sec(blk$end[i])
  expect(all(ot >= lo & ot <= hi), paste(b, "origin outside block"))
  expect(all(tt >= lo & tt <= hi), paste(b, "target outside block"))
  lag_lo <- as.numeric(panel$times[s$origin_idx - (L - 1L)])
  floor_t <- if (b == "train") lo else sec(blk$start[i - 1L])
  expect(all(lag_lo >= floor_t), paste(b, "lags reach beyond the preceding block"))
  if (b == "train") expect(all(ot >= sec(cfg$split$first_origin)), "train origin before first origin")
  nrow(s)
}
mv_test("T09", "6", "Every training target stays in the training block", {
  paste(sapply(H, function(h) paste0("h", h, ":", block_check("train", h))), collapse = " ")
})
mv_test("T10", "7", "Every validation target stays in the validation block", {
  paste(sapply(H, function(h) paste0("h", h, ":", block_check("validation", h))), collapse = " ")
})
mv_test("T11", "8", "Every test target stays in the test block", {
  paste(sapply(H, function(h) paste0("h", h, ":", block_check("test", h))), collapse = " ")
})

mv_test("T12", "9", "All samples retained under the unmasked policy (incl. constant-fill)", {
  out <- character(0)
  for (h in H) {
    s <- mv_samples(cfg, panel$times, h)
    for (i in seq_len(nrow(blk))) {
      si <- s[s$block == blk$block[i], ]
      full <- seq.int(blk$first_origin_idx[i], blk$end_idx[i] - h)
      expect(identical(si$origin_idx, full), paste("origins dropped", blk$block[i], h))
      for (d in c("B0", "B1")) {
        bk <- get_ds(d, h)$blocks[[blk$block[i]]]
        expect(identical(bk$origin_idx, full) && length(bk$y) == length(full) &&
                 nrow(bk$X) == length(full), paste("dataset rows dropped", d, blk$block[i], h))
        expect(sum(is_fill[bk$target_idx]) == sum(is_fill[(blk$first_origin_idx[i] + h):blk$end_idx[i]]),
               paste("fill targets dropped from dataset", d, blk$block[i], h))
      }
      # constant-fill targets in the block's target range are all present
      tr <- (blk$first_origin_idx[i] + h):blk$end_idx[i]
      expect(sum(is_fill[si$target_idx]) == sum(is_fill[tr]), "fill targets dropped")
      if (h == 24) out <- c(out, sprintf("%s: %d fill targets kept", blk$block[i], sum(is_fill[si$target_idx])))
    }
  }
  expect(sum(is_fill) == 2304, "fill-hour count differs from Phase 0 (2,304)")
  paste(out, collapse = "; ")
})

mv_test("T13", "10", "No quality-mask exclusion or origin threshold is applied", {
  expect(identical(cfg$quality_mask, "none"), "config quality_mask")
  tmp <- tempfile(fileext = ".yaml")
  y <- cfg; y$quality_mask <- "phase0"; yaml::write_yaml(y, tmp)
  err <- tryCatch({ mv_cfg(path = basename(tmp), root = dirname(tmp)); "" },
                  error = function(e) conditionMessage(e))
  expect(grepl("quality_mask: none", err), "a masked config was accepted")
  src <- c(LAYER, "run_multivariate.R")
  bad <- c("proposed_quality_mask", "frac_flagged", "is_scorable", "target_scorable",
           "origin_allowed", "train_row_allowed", "policy.yaml", "is_masked", "frac_filled")
  for (f in src[file.exists(src)]) {
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    hit <- bad[vapply(bad, function(b) grepl(b, txt, fixed = TRUE), logical(1))]
    expect(!length(hit), paste(f, "references", paste(hit, collapse = ",")))
  }
  # an origin whose whole 24-h window is constant fill is still a test sample
  o <- match(sec("2023-06-15 00:00"), as.numeric(panel$times))
  s <- mv_samples(cfg, panel$times, 24)
  expect(o %in% s$origin_idx[s$block == "test"], "fill-window origin missing")
  expect(all(is_fill[(o - 23):o]), "chosen origin is not a full-fill window")
  "config enforced; no mask identifiers in pipeline code; full-fill origin 2023-06-15 00:00 kept"
})

mv_test("T14", "11", "Sample counts match the independent calendar computation", {
  got <- mv_sample_counts(cfg, panel$times)
  exp <- mv_expected_counts(cfg)
  m <- merge(got, exp, by = c("horizon_h", "block"))
  expect(nrow(m) == 3 * length(H), "rows")
  expect(all(m$samples == m$expected_samples), "samples")
  expect(all(m$eligible_origins == m$expected_eligible_origins), "eligible origins")
  for (k in c("first_origin", "last_origin", "first_target", "last_target"))
    expect(all(m[[k]] == m[[paste0("expected_", k)]]), k)
  paste(sprintf("h%d %s=%d", m$horizon_h, substr(m$block, 1, 3), m$samples), collapse = " ")
})

lgb_ok <- requireNamespace("lightgbm", quietly = TRUE)
pr <- cfg$model$params; seed <- as.integer(cfg$model$seed)

mv_test("T15", "12", "No test labels are used in fitting or validation-based selection", {
  expect(lgb_ok, "lightgbm not installed")
  ds <- get_ds("B1", 24)
  r1 <- mv_select_and_refit("lightgbm", ds, pr, seed)
  ds2 <- ds
  set.seed(3)
  ds2$blocks$test$y <- ds$blocks$test$y * 10 + stats::rnorm(length(ds$blocks$test$y), 0, 50)
  r2 <- mv_select_and_refit("lightgbm", ds2, pr, seed)
  expect(r1$best_iter == r2$best_iter, "best iteration depends on test labels")
  for (b in c("train", "validation", "test"))
    expect(identical(r1$pred[[b]], r2$pred[[b]]), paste(b, "predictions depend on test labels"))
  ds3 <- ds; ds3$blocks$test$y <- rep(NA_real_, length(ds$blocks$test$y))
  r3 <- mv_select_and_refit("lightgbm", ds3, pr, seed)
  expect(identical(r1$pred$test, r3$pred$test), "fit fails or changes without test labels")
  sprintf("best_iter=%d unchanged; predictions identical with perturbed or NA test labels", r1$best_iter)
})

mv_test("T16", "repro", "Reproducibility with a fixed seed", {
  expect(lgb_ok, "lightgbm not installed")
  ds <- get_ds("B0", 24)
  a <- mv_select_and_refit("lightgbm", ds, pr, seed)
  b <- mv_select_and_refit("lightgbm", ds, pr, seed)
  expect(a$best_iter == b$best_iter, "best_iter")
  for (k in names(a$pred)) expect(identical(a$pred[[k]], b$pred[[k]]), paste(k, "predictions"))
  h1 <- mv_dataset_hashes(ds); h2 <- mv_dataset_hashes(mv_dataset(cfg, panel, "B0", 24))
  expect(identical(h1, h2), "dataset hashes")
  sprintf("identical predictions and dataset hashes across two runs (seed %d)", seed)
})

mv_test("T17", "leak", "Legacy two-sided MRA and full-series imputation are not loaded", {
  for (fn in c("haar_mra", "generic_mra", "haar_modwt", "impute_hourly", "minmax_fit",
               "paper_wave_walkforward", "wave_fit_components", "prepare_series"))
    expect(!exists(fn, envir = .GlobalEnv), paste(fn, "is defined"))
  for (f in c(LAYER, "run_multivariate.R")[file.exists(c(LAYER, "run_multivariate.R"))]) {
    txt <- readLines(f, warn = FALSE)
    code <- sub("#.*$", "", txt)                       # ignore comments
    expect(!any(grepl("source\\([^)]*R/[0-3][0-9]_", code)), paste(f, "sources a legacy R file"))
    expect(!any(grepl("na_seadec|imputeTS|data/raw/CPCB.csv", code)), paste(f, "uses legacy data/imputation"))
  }
  "none of the legacy helpers exist after loading the layer; no legacy source() calls"
})

mv_test("T18", "metrics", "MASE scale matches R/08_metrics.R and a brute-force loop", {
  sc <- mv_block_scale(cfg, panel, "train")
  i0 <- blk$start_idx[1]; i1 <- blk$end_idx[1]
  y <- panel$X[i0:i1, "PM2.5"]
  bf <- 0; for (t in 25:length(y)) bf <- bf + abs(y[t] - y[t - 24]); bf <- bf / (length(y) - 24)
  expect(abs(sc$scale - bf) < 1e-12, "brute force")
  e8 <- new.env(); assign("SEASONALITY", 24L, envir = e8)
  sys.source("R/08_metrics.R", envir = e8)
  set.seed(2); yy <- stats::runif(50, 5, 40); yh <- yy + stats::rnorm(50)
  expect(abs(e8$mase(y, yy, yh) - mv_point_metrics(yy, yh, sc$scale)[["MASE"]]) < 1e-12, "R/08 mase")
  expect(sc$n_pairs == 3089, "pairs")
  sprintf("scale %.6f from %d pairs (%s to %s)", sc$scale, sc$n_pairs, sc$from, sc$to)
})

mv_test("T19", "transform", "Train-fitted transform contract (fit sees fitting rows only)", {
  ds <- get_ds("B1", 24)
  st <- mv_transform_standardize()$fit(ds$blocks$train$X)
  st2 <- mv_transform_standardize()$fit(ds$blocks$train$X)
  Xv <- ds$blocks$validation$X
  expect(identical(st$apply(Xv), st2$apply(Xv)), "standardizer not deterministic")
  expect(max(abs(colMeans(st$apply(ds$blocks$train$X)))) < 1e-8, "train not centred")
  expect(identical(st$center, colMeans(ds$blocks$train$X)), "center not from train")
  id <- mv_transform_identity()$fit(ds$blocks$train$X)
  expect(identical(id$apply(Xv), Xv), "identity changes X")
  "standardize/identity fitted on train only; reused unchanged on later blocks"
})

mv_test("T20", "family", "Unregistered or missing families fail instead of falling back", {
  expect(identical(mv_families(), "lightgbm"), "unexpected registered families")
  for (f in c("catboost", "xgboost")) {
    e <- tryCatch({ mv_family(f); "" }, error = function(e) conditionMessage(e))
    expect(grepl("not implemented", e), paste(f, "did not fail"))
  }
  mv_register_family("fake_pkg_family", "packageThatDoesNotExist123",
                     function(...) stop("x"), function(...) stop("x"))
  e <- tryCatch({ mv_family("fake_pkg_family"); "" }, error = function(e) conditionMessage(e))
  rm("fake_pkg_family", envir = .mv_families)
  expect(grepl("No fallback", e), "missing package did not fail")
  "catboost/xgboost not registered -> error; missing package -> error"
})

mv_test("T21", "metrics", "Block bootstrap is seeded and brackets the point estimate", {
  set.seed(9); y <- stats::rnorm(500, 20, 5); yh <- y + stats::rnorm(500)
  a <- mv_bootstrap_metrics(y, yh, 3, 168, 199, 7); b <- mv_bootstrap_metrics(y, yh, 3, 168, 199, 7)
  expect(identical(a, b), "not deterministic")
  pm <- mv_point_metrics(y, yh, 3)
  expect(all(a$lo <= pm & pm <= a$hi), "CI does not contain the point estimate")
  ix <- mv_mbb_index(500, 168, 5, 1)
  expect(all(lengths(ix) == 500), "resample length")
  "deterministic; CI contains point estimates; resamples keep n"
})

mv_test("T22", "repro", "Recorded iteration counts are not overwritten by later fits", {
  expect(lgb_ok, "lightgbm not installed")
  ds <- get_ds("B0", 24); tr <- ds$blocks$train; va <- ds$blocks$validation
  f1 <- .mv_lgb_fit(tr$X, tr$y, va$X, va$y, pr, seed, pr$num_iterations, TRUE)
  r1 <- f1$iterations_run; b1 <- f1$best_iter
  f2 <- .mv_lgb_fit(tr$X, tr$y, NULL, NULL, pr, seed, 7L, FALSE)
  expect(f2$iterations_run == 7L, "second fit rounds")
  expect(f1$iterations_run == r1 && f1$best_iter == b1, "first fit's record changed after a second fit")
  expect(f1$iterations_run >= f1$best_iter, "iterations_run < best_iter")
  sprintf("first fit keeps iterations_run=%d, best_iter=%d after a 7-round fit", r1, b1)
})

# ---------------------------------------------------------------------------
res <- do.call(rbind, .res)
# MV_TEST_OUT_DIR lets later phases keep their own copy instead of rewriting Phase 1's.
out_dir <- Sys.getenv("MV_TEST_OUT_DIR", cfg$output_dir)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, file.path(out_dir, "TEST_SUMMARY.csv"), row.names = FALSE)
md <- c("# Phase 1 test execution summary", "",
        sprintf("Run: %s. R %s, lightgbm %s, parquet reader: %s.",
                format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"), getRversion(),
                if (lgb_ok) as.character(utils::packageVersion("lightgbm")) else "missing",
                panel$source$reader),
        sprintf("Result: **%d / %d passed**. Quality mask: none (UNMASKED).", sum(res$pass), nrow(res)), "",
        "| ID | Required item | Test | Result | Detail |", "|---|---|---|---|---|",
        sprintf("| %s | %s | %s | %s | %s |", res$id, res$required_item, res$test,
                ifelse(res$pass, "PASS", "**FAIL**"), gsub("\\|", "/", res$detail)))
writeLines(md, file.path(out_dir, "TEST_SUMMARY.md"))
cat(sprintf("\n%d / %d tests passed\n", sum(res$pass), nrow(res)))
if (!all(res$pass)) quit(status = 1)
