# Phase 2 test suite (extends tests/multivariate/run_tests.R, which still runs
# unchanged first). Must pass before any Phase 2 model is trained.
#   Rscript tests/multivariate/run_tests_phase2.R
# Writes TEST_SUMMARY.csv / .md to $MV_TEST_OUT_DIR (default results/multivariate/phase2/check/tests_phase2).

options(warn = 1)
if (!file.exists("R/40_mv_data.R")) stop("Run from the project root.")
LAYER <- c("R/40_mv_data.R", "R/41_mv_features.R", "R/43_mv_models.R", "R/44_mv_metrics.R",
           "R/45_mv_families.R", "R/46_mv_featsel.R", "R/47_mv_eval.R", "R/48_mv_runner.R")
for (f in LAYER) sys.source(f, envir = .GlobalEnv)

.res <- list()
expect <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)
mv_test <- function(id, name, code) {
  t0 <- proc.time()[["elapsed"]]
  r <- tryCatch({
    d <- force(code)
    list(pass = TRUE, detail = if (is.character(d)) paste(d, collapse = "; ") else "ok")
  }, error = function(e) list(pass = FALSE, detail = conditionMessage(e)))
  .res[[length(.res) + 1L]] <<- data.frame(id = id, test = name, pass = r$pass,
    seconds = round(proc.time()[["elapsed"]] - t0, 2), detail = r$detail, stringsAsFactors = FALSE)
  cat(sprintf("[%s] %-4s %s%s\n", if (r$pass) "PASS" else "FAIL", id, name,
              if (r$pass) "" else paste0("  -> ", r$detail)))
}

EC <- mv_exp_cfg(); cfg <- EC$base; E <- EC$exp
panel <- mv_load_panel(cfg)
L <- as.integer(cfg$lookback_h)
P <- panel$pollutants
small <- mv_dataset(cfg, panel, "B1", 744)         # smallest sample set, used for model tests
perturb_test <- function(ds) {
  set.seed(3)
  ds$blocks$test$y <- ds$blocks$test$y * 10 + stats::rnorm(length(ds$blocks$test$y), 0, 50)
  ds
}

mv_test("P01", "Constant-fill flags reproduce the 2,304 Phase 0 hours", {
  f <- mv_fill_hours(panel)
  expect(sum(f) == 2304, sprintf("%d fill hours", sum(f)))
  m <- utils::read.csv(file.path("results", "multivariate", "phase0", "proposed_quality_mask_cpcb.csv"),
                       stringsAsFactors = FALSE)
  ph0 <- toupper(as.character(m$is_constant_fill)) == "TRUE"
  expect(identical(f, ph0[match(mv_fmt_ts(panel$times), m$timestamp)]), "differs from Phase 0 CSV")
  r <- rle(f)
  sprintf("2304 hours in %d runs (%s h)", sum(r$values), paste(sort(unique(r$lengths[r$values])), collapse = "/"))
})

mv_test("P02", "Target argument: y = target(t+h), inputs unchanged", {
  for (tg in P) for (h in c(24L, 744L)) {
    a <- mv_dataset(cfg, panel, "B1", h, target = tg)
    b <- mv_dataset(cfg, panel, "B1", h)
    for (bl in names(a$blocks)) {
      expect(identical(a$blocks[[bl]]$X, b$blocks[[bl]]$X), "inputs depend on target")
      expect(identical(a$blocks[[bl]]$y, panel$X[a$blocks[[bl]]$target_idx, tg]), paste("y", tg, h, bl))
    }
    expect(identical(a$target, tg), "target recorded")
  }
  expect(identical(mv_dataset(cfg, panel, "B0", 24)$target, "PM2.5"), "default target")
  "six targets x two horizons"
})

fam_params <- function(f) {
  p <- E$families[[f]]$base
  g <- E$families[[f]]$grid
  for (k in names(g)) p[[k]] <- g[[k]][[1]]
  p$num_iterations <- min(p$num_iterations %||% 1L, 300L)
  p
}
for (fam in c("xgboost", "catboost", "ridge", "lasso", "elasticnet", "pls")) {
  local({
    f <- fam
    mv_test(paste0("P03-", f), paste(f, ": no test-label use, reproducible, refit frozen"), {
      p <- if (f == "pls") list(max_ncomp = 20L) else fam_params(f)
      tf <- if (f %in% mv_linear_families()) mv_transform_standardize() else mv_transform_identity()
      r1 <- mv_select_and_refit(f, small, p, 2026L, tf)
      r2 <- mv_select_and_refit(f, perturb_test(small), p, 2026L, tf)
      r3 <- mv_select_and_refit(f, small, p, 2026L, tf)
      for (b in c("train", "validation", "test")) {
        expect(identical(r1$pred[[b]], r2$pred[[b]]), paste(b, "depends on test labels"))
        expect(identical(r1$pred[[b]], r3$pred[[b]]), paste(b, "not reproducible"))
      }
      expect(all(is.finite(r1$pred$test)), "non-finite predictions")
      if (f %in% c("ridge", "lasso", "elasticnet"))
        expect(is.numeric(r1$refit_params$lambda) && r1$refit_params$lambda > 0, "lambda not frozen")
      if (f == "pls") expect(r1$refit_rounds == r1$best_iter, "ncomp not frozen")
      if (f %in% c("xgboost", "catboost")) expect(r1$refit_rounds == r1$best_iter, "rounds not frozen")
      sprintf("best_iter=%s refit=%s", r1$best_iter, r1$refit_rounds)
    })
  })
}

mv_test("P04", "XGBoost predicts with exactly best_iter rounds", {
  tr <- small$blocks$train; va <- small$blocks$validation
  p <- fam_params("xgboost")
  a <- .mv_xgb_fit(tr$X, tr$y, va$X, va$y, p, 1L, 300L, TRUE)
  b <- .mv_xgb_fit(tr$X, tr$y, NULL, NULL, p, 1L, a$best_iter, FALSE)
  pa <- .mv_xgb_predict(a, va$X); pb <- .mv_xgb_predict(b, va$X)
  expect(max(abs(pa - pb)) < 1e-6, sprintf("max diff %.3g", max(abs(pa - pb))))
  expect(abs(mean((pa - va$y)^2) - a$best_score) < 1e-3 * a$best_score, "best score mismatch")
  sprintf("best_iter=%d; truncated model == model trained for best_iter rounds", a$best_iter)
})

mv_test("P05", "CatBoost refit uses exactly best_iter trees", {
  tr <- small$blocks$train; va <- small$blocks$validation
  p <- fam_params("catboost")
  a <- .mv_cat_fit(tr$X, tr$y, va$X, va$y, p, 1L, 300L, TRUE)
  b <- .mv_cat_fit(tr$X, tr$y, NULL, NULL, p, 1L, a$best_iter, FALSE)
  expect(b$best_iter == a$best_iter, "tree count")
  sprintf("best_iter=%d", a$best_iter)
})

mv_test("P06", "Transforms are fitted on fitting rows only", {
  ds <- mv_dataset(cfg, panel, "B1", 24)
  tfs <- list(mv_transform_corr_topk(24), mv_transform_mi_topk(24), mv_transform_enet_select(0.5, 0.5),
              mv_transform_pca(8), mv_transform_pls(5),
              mv_transform_chain(mv_transform_corr_topk(48), mv_transform_pca(4)),
              mv_transform_columns(mv_pollutant_columns(ds$feature_names, c("PM2.5", "CO"))))
  out <- character(0)
  for (tf in tfs) {
    r1 <- mv_select_and_refit("ridge", ds, list(alpha = 0, nlambda = 50), 1L, tf)
    ds2 <- perturb_test(ds); ds2$blocks$test$X <- ds2$blocks$test$X * 3 + 100
    r2 <- mv_select_and_refit("ridge", ds2, list(alpha = 0, nlambda = 50), 1L, tf)
    expect(identical(r1$transform_info, r2$transform_info), paste(tf$name, "fitted info depends on test rows"))
    expect(identical(r1$pred$validation, r2$pred$validation), paste(tf$name, "validation preds depend on test"))
    # selection-fit info must not depend on validation rows either
    ds3 <- ds; ds3$blocks$validation$X <- ds3$blocks$validation$X + 50; ds3$blocks$validation$y <- -ds3$blocks$validation$y
    f1 <- tf$fit(ds$blocks$train$X, ds$blocks$train$y); f3 <- tf$fit(ds3$blocks$train$X, ds3$blocks$train$y)
    expect(identical(f1$info, f3$info), paste(tf$name, "selection fit depends on validation"))
    out <- c(out, sprintf("%s:%d", tf$name, r1$n_inputs))
  }
  pc <- mv_transform_pca(8)$fit(ds$blocks$train$X)
  Z <- pc$apply(ds$blocks$train$X)
  expect(max(abs(colMeans(Z))) < 1e-8, "PCA scores not centred on fitting rows")
  paste(out, collapse = " ")
})

mv_test("P07", "Pooled dataset: alignment, own slot, train-only scaling, no future inputs", {
  h <- 168L
  pds <- mv_pooled_dataset(cfg, panel, h, P)
  base <- mv_dataset(cfg, panel, "B1", h)
  for (b in names(pds$blocks)) {
    pb <- pds$blocks[[b]]; n <- length(base$blocks[[b]]$y)
    expect(nrow(pb$X) == 6 * n, paste(b, "row count"))
    expect(all(as.numeric(pb$target_ts) - as.numeric(pb$origin_ts) == 3600 * h), "offset")
    for (j in seq_along(P)) {
      k <- pb$target == P[j]
      expect(sum(k) == n && all(pb$X[k, "target_id"] == j - 1L), paste("target id", P[j]))
      expect(identical(pb$y_raw[k], panel$X[pb$target_idx[k], P[j]]), paste("y_raw", P[j]))
      expect(max(abs(pb$y[k] * pds$stats$sd[[P[j]]] + pds$stats$mu[[P[j]]] - pb$y_raw[k])) < 1e-9, "y scaling")
      own <- pb$X[k, paste0("own__lag", sprintf("%02d", 0:23))]
      same <- pb$X[k, paste0(P[j], "__lag", sprintf("%02d", 0:23))]
      expect(max(abs(own - same)) == 0, paste("own slot", P[j]))
      expect(identical(pb$origin_idx[k], base$blocks[[b]]$origin_idx), "origins")
    }
  }
  bl <- mv_blocks(cfg, panel$times)
  pp <- panel; pp$X[(bl$end_idx[1] + 1L):nrow(pp$X), ] <- pp$X[(bl$end_idx[1] + 1L):nrow(pp$X), ] * 5 + 9
  expect(identical(mv_pooled_stats(cfg, pp), mv_pooled_stats(cfg, panel)), "scaling uses non-train hours")
  # future perturbation after a test origin leaves its pooled inputs unchanged
  o <- pds$blocks$test$origin_idx[1]
  pp <- panel; pp$X[(o + 1L):nrow(pp$X), ] <- -1
  p2 <- mv_pooled_dataset(cfg, pp, h, P, stats = pds$stats)
  k <- which(pds$blocks$test$origin_idx == o)
  expect(identical(p2$blocks$test$X[k, ], pds$blocks$test$X[k, ]), "future observations leak into pooled X")
  expect(is.null(pds$target), "pooled ds$target must be NULL (partial matching guard)")
  p0 <- mv_pooled_dataset(cfg, panel, h, P, include_all = FALSE)
  expect(identical(colnames(p0$blocks$test$X), c("target_id", paste0("own__lag", sprintf("%02d", 0:23)))),
         "pooled_B0 columns")
  expect(identical(p0$blocks$test$y, pds$blocks$test$y), "pooled_B0 targets")
  sprintf("h=%d: %d train rows, %d columns (pooled_B0: %d)", h, nrow(pds$blocks$train$X),
          ncol(pds$blocks$train$X), ncol(p0$blocks$train$X))
})

mv_test("P08", "Pooled LightGBM: categorical target id, reproducible, no test-label use", {
  pds <- mv_pooled_dataset(cfg, panel, 744L, P)
  p <- utils::modifyList(fam_params("lightgbm"), list(categorical_feature = "target_id"))
  r1 <- mv_select_and_refit("lightgbm", pds, p, 2026L)
  pd2 <- pds; pd2$blocks$test$y <- rev(pd2$blocks$test$y)
  r2 <- mv_select_and_refit("lightgbm", pd2, p, 2026L)
  expect(identical(r1$pred$test, r2$pred$test), "test labels used")
  sprintf("best_iter=%d", r1$best_iter)
})

mv_test("P09", "Block length and DM test behave sensibly", {
  set.seed(1); n <- 2000
  wn <- stats::rnorm(n); ar <- as.numeric(stats::arima.sim(list(ar = 0.95), n))
  bw <- mv_pw_block_length(wn)$b; ba <- mv_pw_block_length(ar)$b
  expect(ba > 3 * bw, sprintf("AR(0.95) %.1f vs white noise %.1f", ba, bw))
  expect(identical(mv_pw_block_length(ar), mv_pw_block_length(ar)), "not deterministic")
  cb <- mv_choose_block(ar, 744L)
  expect(cb$block >= 24 && cb$block <= floor(n / 5), "floor/cap not applied")
  dm0 <- mv_dm_test(stats::rnorm(500), 24)
  dm1 <- mv_dm_test(stats::rnorm(500, 1), 24)
  expect(dm0[["p"]] > 0.01 && dm1[["p"]] < 1e-6, "DM size/power")
  pc <- mv_paired_compare(1:300 + 0, 1:300 + 1, 1:300 + 2, 24L, reps = 99L)
  expect(abs(pc$mae_ratio - 0.5) < 1e-12, "ratio")
  sprintf("PW white noise %.1f, AR(0.95) %.1f; chosen %d (cap %d)", bw, ba, cb$block, cb$cap)
})

mv_test("P10", "Seasonal naive equals the value at the origin for h = 24k", {
  for (h in as.integer(unlist(cfg$horizons))) {
    ds <- mv_dataset(cfg, panel, "B0", h)
    sn <- mv_seasonal_naive(panel, ds$blocks$test$origin_idx, h, "PM2.5")
    expect(identical(sn, unname(ds$blocks$test$X[, "PM2.5__lag00"])), paste("h", h))
  }
  "seasonal naive uses only the origin-hour observation"
})

mv_test("P11", "Tuning never reads test labels", {
  cands <- mv_candidates(list(base = fam_params("lightgbm"), grid = list(num_leaves = c(7, 15))))
  a <- mv_tune("lightgbm", small, cands, 2026L, mv_transform_identity())
  b <- mv_tune("lightgbm", perturb_test(small), cands, 2026L, mv_transform_identity())
  a$table$seconds <- b$table$seconds <- 0
  expect(identical(a$table, b$table) && identical(a$best, b$best), "tuning depends on test labels")
  paste("best", a$best)
})

mv_test("P12", "Family registry: new families present, unknown names still fail", {
  expect(all(c("lightgbm", "xgboost", "catboost", "ridge", "lasso", "elasticnet", "ols", "pls") %in% mv_families()),
         "missing families")
  e <- tryCatch({ mv_family("svm"); "" }, error = function(e) conditionMessage(e))
  expect(grepl("not implemented", e), "unknown family accepted")
  paste(mv_families(), collapse = ",")
})

mv_test("P13", "RFE and transform tuning use train/validation only", {
  OUT <- tempdir(); E <- EC$exp                     # globals expected by R/49
  sys.source("R/49_mv_stages.R", envir = environment())
  p <- fam_params("lightgbm")
  a <- mv_rfe("lightgbm", small, p, 2026L, 0.5, 30L)
  b <- mv_rfe("lightgbm", perturb_test(small), p, 2026L, 0.5, 30L)
  expect(identical(a, b), "RFE depends on test labels")
  expect(all(diff(a$path$n_inputs) < 0) && min(a$path$n_inputs) >= 30, "RFE path")
  tfs <- list(k12 = mv_transform_corr_topk(12), k48 = mv_transform_corr_topk(48))
  t1 <- mv_tune_transforms("lightgbm", small, tfs, p, 2026L)
  t2 <- mv_tune_transforms("lightgbm", perturb_test(small), tfs, p, 2026L)
  expect(identical(t1, t2), "transform tuning depends on test labels")
  sprintf("RFE path %s", paste(a$path$n_inputs, collapse = ">"))
})

res <- do.call(rbind, .res)
out_dir <- Sys.getenv("MV_TEST_OUT_DIR", file.path(EC$exp$output_dir, "check", "tests_phase2"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, file.path(out_dir, "TEST_SUMMARY.csv"), row.names = FALSE)
writeLines(c("# Phase 2 test execution summary", "",
             sprintf("Run: %s. R %s.", format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"), getRversion()),
             sprintf("Result: **%d / %d passed**. Quality mask: none (UNMASKED).", sum(res$pass), nrow(res)), "",
             "| ID | Test | Result | Detail |", "|---|---|---|---|",
             sprintf("| %s | %s | %s | %s |", res$id, res$test, ifelse(res$pass, "PASS", "**FAIL**"),
                     gsub("\\|", "/", res$detail))),
           file.path(out_dir, "TEST_SUMMARY.md"))
cat(sprintf("\n%d / %d tests passed\n", sum(res$pass), nrow(res)))
if (!all(res$pass)) quit(status = 1)
