# T1-Tuned safeguards: frozen mapping, validation-only HPO, DLinear knobs,
# same splits, no writes outside results/teammate_1/.

if (!exists("t1_tuned_mapping")) {
  sys.source("R/teammate_1/t1_tuned.R", envir = .GlobalEnv)
}

map <- t1_tuned_mapping()
t1_ok("T1T-01a", identical(names(map), T1_COMPONENTS),
      "tuned map covers D1-D5 and S5 in order")
t1_ok("T1T-01b", identical(unname(map), c("lgb", "lgb", "dlinear", "catboost",
                                          "sarima", "dlinear")),
      "architectures are frozen to the T1 smoke winners")
t1_ok("T1T-01c", !"xgb" %in% map,
      "XGBoost is not in the frozen map")

src <- paste(readLines("R/teammate_1/t1_tuned.R"), collapse = "\n")
t1_ok("T1T-01d",
      grepl("T1_TUNED_MAP", src) && !grepl("t1_select_best\\(", src),
      "tuned runner does not re-run architecture selection")

# Validation-only selection: better test / worse val must lose.
trials <- tibble::tibble(
  sensor = "CPCB", pollutant = "PM2.5", horizon = "1d", component = "D1",
  trial_id = c(0L, 1L, 2L),
  is_frozen = c(TRUE, FALSE, FALSE),
  stage = "validation",
  MASE = c(0.40, 0.50, 0.30),
  MAE = c(0.8, 0.9, 0.7)
)
# Attach unused test scores that would reverse the ranking if leaked.
trials$test_MASE <- c(0.10, 0.05, 9.0)
sel <- t1_tuned_select_hparams(trials)
t1_ok("T1T-02a", identical(as.integer(sel$trial_id), 2L),
      "selects the lowest validation MASE trial")
t1_ok("T1T-02b", isTRUE(sel$selected_on == "validation") && isFALSE(sel$used_test),
      "records validation-only selection")

trials_tie <- trials
trials_tie$MASE <- c(0.30, 0.30, 0.50)
sel_tie <- t1_tuned_select_hparams(trials_tie)
t1_ok("T1T-02c", isTRUE(sel_tie$is_frozen) && identical(as.integer(sel_tie$trial_id), 0L),
      "frozen T1 config wins validation ties")

test_rows <- trials
test_rows$stage <- "test"
t1_ok("T1T-02d",
      inherits(try(t1_tuned_select_hparams(test_rows), silent = TRUE), "try-error"),
      "refuses to select when only test rows are supplied")

# DLinear space contains only implemented knobs.
dlin <- t1_tuned_dlinear_candidates(smoke = FALSE)
t1_ok("T1T-03a", all(c("p", "kernel") %in% names(dlin)),
      "DLinear search includes p and kernel")
t1_ok("T1T-03b",
      !any(c("learning_rate", "epochs", "batch_size", "dropout",
             "weight_decay") %in% names(dlin)),
      "DLinear search does not invent lr/epochs/batch/dropout")
t1_ok("T1T-03c", any(dlin$p == 24L & dlin$kernel == 25L & dlin$is_frozen),
      "DLinear grid includes the T1 frozen (p=24, kernel=25)")

# LightGBM candidates include frozen and clamp illegal leaves.
frozen <- t1_tuned_frozen_tree_params()
lgb <- t1_tuned_lgb_candidates(4L, T1_SEED, frozen)
t1_ok("T1T-04a", isTRUE(lgb$is_frozen[1]) && identical(as.integer(lgb$trial_id[1]), 0L),
      "LightGBM trial 0 is the frozen T1 config")
t1_ok("T1T-04b", identical(as.integer(lgb$nrounds[1]), as.integer(frozen$nrounds)),
      "frozen LightGBM keeps T1 nrounds")
t1_ok("T1T-04c",
      identical(t1_tuned_lgb_clamp_leaves(3L, 63L), 8L),
      "num_leaves is clamped to 2^max_depth")

sar <- t1_tuned_sarima_candidates(smoke = TRUE)
t1_ok("T1T-05a", isTRUE(sar[[1]]$is_frozen) && isFALSE(sar[[1]]$seasonal),
      "SARIMA smoke starts from T1 frozen nonseasonal auto.arima")
sar_full <- t1_tuned_sarima_candidates(smoke = FALSE)
kinds <- vapply(sar_full, `[[`, character(1), "kind")
t1_ok("T1T-05b", any(kinds == "auto") && any(kinds == "fixed"),
      "SARIMA full search mixes auto.arima and bounded fixed orders")
has_season <- vapply(sar_full, function(z) {
  !isFALSE(z$seasonal) && !identical(z$seasonal, FALSE)
}, logical(1))
t1_ok("T1T-05c", any(has_season),
      "SARIMA full search includes seasonal candidates at period 24")

# Same train/val/test helper as T1.
series_all <- t1_load_prepared_series()
so <- series_all[["CPCB_PM2.5"]]
h <- 24L
sp_t1 <- t1_split_y(so, h)
sp_raw <- chrono_split_tvt(so$y, so$times, h, VAL_HOURS)
t1_ok("T1T-06a", identical(sp_t1$n_train, sp_raw$n_train) &&
        identical(sp_t1$n_val, sp_raw$n_val) &&
        identical(sp_t1$n_test, sp_raw$n_test),
      "T1-Tuned splits match chrono_split_tvt / T1")

# Independent lags still univariate.
X <- t1_independent_lags(seq_len(50), 6L)
t1_ok("T1T-07a", isTRUE(attr(X, "t1_source_is_univariate")) && ncol(X) == 6L,
      "tuned path still builds univariate lag1..lagp features")

# Output sandbox.
t1_ok("T1T-08a",
      inherits(try(t1_tuned_assert(file.path(RES_DIR, "scores.csv")),
                   silent = TRUE), "try-error"),
      "refuses to write original results/scores.csv")
ok_path <- file.path(RES_DIR, "teammate_1", "tuned", "report.md")
t1_ok("T1T-08b",
      isTRUE(tryCatch({ t1_tuned_assert(ok_path); TRUE },
                      error = function(e) FALSE)),
      "allows writes under results/teammate_1/tuned/")

t1_ok("T1T-09a",
      grepl("t1_load_stored_components", src) &&
        grepl("t1_load_prepared_series", src) &&
        grepl("t1_split_y", src) &&
        grepl("minmax_fit", src) &&
        grepl("t1_build_reconstructed", src) &&
        grepl("score_forecast", src),
      "tuned runner reuses T1 loaders, splits, scaling, recon, scoring")
t1_ok("T1T-09b",
      !grepl("generic_mra\\(", src) && !grepl("modwt\\(", src),
      "tuned runner does not recompute MODWT")

# Candidate comparison reads saved T1 scores and does not retune.
orig_metrics <- file.path(RES_DIR, "teammate_1", "component_metrics.csv")
orig_md5 <- if (file.exists(orig_metrics)) unname(tools::md5sum(orig_metrics)) else NA_character_
cmp <- t1_tuned_candidate_comparison()
orig_md5_after <- if (file.exists(orig_metrics)) unname(tools::md5sum(orig_metrics)) else NA_character_
t1_ok("T1T-10a", identical(orig_md5, orig_md5_after),
      "candidate comparison does not modify original T1 component_metrics.csv")
t1_ok("T1T-10b", nrow(cmp) == 30L &&
        identical(sort(unique(as.character(cmp$component))), sort(T1_COMPONENTS)) &&
        all(c("LightGBM", "XGBoost", "CatBoost", "SARIMA", "DLinear") %in% cmp$model),
      "comparison lists every saved T1 candidate on D1-D5 and S5")
untuned <- cmp[!cmp$is_frozen_assignment, , drop = FALSE]
t1_ok("T1T-10c", nrow(untuned) > 0L &&
        !any(is.finite(untuned$tuned_validation_MASE)) &&
        !any(is.finite(untuned$tuned_test_MASE)),
      "models outside the frozen map have N/A tuned scores")
d1_lgb <- cmp[cmp$component == "D1" & cmp$model_id == "lgb", , drop = FALSE]
d1_xgb <- cmp[cmp$component == "D1" & cmp$model_id == "xgb", , drop = FALSE]
t1_ok("T1T-10d", nrow(d1_lgb) == 1L && nrow(d1_xgb) == 1L &&
        isTRUE(all.equal(d1_lgb$original_validation_MASE, 0.41543899334815015)) &&
        isTRUE(all.equal(d1_lgb$original_test_MASE, 0.5412485618716072)) &&
        !is.finite(d1_xgb$tuned_validation_MASE) &&
        !is.finite(d1_xgb$tuned_test_MASE),
      "D1 original LightGBM scores match the saved file; D1 XGBoost is not tuned")
# A committed tuned score exists only when a post-selection test record is stored.
# Part-way validation trials must not be reported as the tuned result.
cache <- t1_tuned_load_cache()
has_d1_test <- any(grepl("\\|D1\\|lgb\\|test$", names(cache)))
has_d2_test <- any(grepl("\\|D2\\|lgb\\|test$", names(cache)))
d2_lgb <- cmp[cmp$component == "D2" & cmp$model_id == "lgb", , drop = FALSE]
t1_ok("T1T-10e",
      (has_d1_test && is.finite(d1_lgb$tuned_validation_MASE) &&
         is.finite(d1_lgb$tuned_test_MASE)) ||
        (!has_d1_test && !is.finite(d1_lgb$tuned_validation_MASE)),
      "D1 tuned cells follow the stored selected test record, or stay N/A")
t1_ok("T1T-10f",
      (has_d2_test && is.finite(d2_lgb$tuned_test_MASE)) ||
        (!has_d2_test && !is.finite(d2_lgb$tuned_validation_MASE) &&
           !is.finite(d2_lgb$tuned_test_MASE)),
      "incomplete D2 search is not reported as a tuned score")
t1_ok("T1T-10g", !grepl("t1_tuned_select_hparams\\(", 
                        paste(deparse(t1_tuned_candidate_comparison), collapse = "\n")) &&
        !grepl("t1_tuned_select_hparams\\(",
               paste(deparse(t1_tuned_committed_scores), collapse = "\n")),
      "comparison reporting does not re-select hyperparameters")
