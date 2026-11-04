# Test performance must not influence model selection.
# Reconstructed predictions must use all six component forecasts.

metrics <- tibble::tibble(
  sensor = "CPCB", pollutant = "PM2.5",
  component = rep(T1_COMPONENTS, each = 4),
  model_id = rep(c("lgb", "xgb", "lgb", "xgb"), 6),
  model = rep(c("LightGBM", "XGBoost", "LightGBM", "XGBoost"), 6),
  stage = rep(c("validation", "validation", "test", "test"), 6),
  horizon = "1d",
  MASE = NA_real_,
  MAE = NA_real_,
  hyperparameters = "{}",
  random_seed = 7L
)
# Val: LightGBM wins D1 (0.2 vs 0.9). Test is the opposite (9 vs 0.1).
# If selection leaked test, D1 would pick XGBoost.
for (i in seq_len(nrow(metrics))) {
  comp_i <- match(metrics$component[i], T1_COMPONENTS)
  if (metrics$model_id[i] == "lgb" && metrics$stage[i] == "validation") {
    metrics$MASE[i] <- 0.20 + 0.01 * comp_i
  } else if (metrics$model_id[i] == "xgb" && metrics$stage[i] == "validation") {
    metrics$MASE[i] <- 0.90 + 0.01 * comp_i
  } else if (metrics$model_id[i] == "lgb" && metrics$stage[i] == "test") {
    metrics$MASE[i] <- 9.0
  } else {
    metrics$MASE[i] <- 0.10
  }
  metrics$MAE[i] <- metrics$MASE[i]
}

best <- t1_select_best(metrics)
t1_ok("T1-04a", all(best$model_id == "lgb"),
      "every component selects LightGBM from validation MASE")
t1_ok("T1-04b", all(best$selected_on == "validation"),
      "best_models records selected_on=validation")
t1_ok("T1-04c", all(!best$used_test),
      "selector flag used_test is FALSE")
t1_ok("T1-04d", !any(best$model_id == "xgb"),
      "test-winning XGBoost is not selected")

src <- paste(readLines("R/teammate_1/t1_pipeline.R"), collapse = "\n")
t1_ok("T1-04e",
      grepl("stage == \"validation\"|stage == \"val\"", src) &&
        grepl("stop\\(\"No validation metrics", src),
      "t1_select_best refuses to run without validation rows")

# Reconstruction identity: six named forecasts, sum used.
h <- 8L
item <- list(
  sensor = "CPCB", pollutant = "PM2.5", horizon = "1d",
  times = seq(as.POSIXct("2020-01-01", tz = "UTC"), by = "hour", length.out = h),
  components = list(
    D1 = rep(1, h), D2 = rep(2, h), D3 = rep(3, h),
    D4 = rep(4, h), D5 = rep(5, h), S5 = rep(6, h)
  ),
  selected = as.list(setNames(rep("lgb", 6), T1_COMPONENTS)),
  y_level = rep(21, h),
  y_true = rep(0, h)
)
series_dummy <- list(
  CPCB_PM2.5 = list(
    y = c(rep(10, 500), rep(21, h)),
    times = seq(as.POSIXct("2019-12-01", tz = "UTC"), by = "hour", length.out = 500 + h),
    sensor = "CPCB", pollutant = "PM2.5"
  )
)
recon <- t1_build_reconstructed(list(`CPCB|PM2.5|1d` = item), series_dummy)
got <- recon[[1]]
t1_ok("T1-04f", isTRUE(got$used_all_six),
      "reconstruction reports all six components")
t1_ok("T1-04g", isTRUE(all.equal(got$yhat, rep(21, h))),
      "Y_hat = D1+D2+D3+D4+D5+S5 (1+2+3+4+5+6=21)")
t1_ok("T1-04h", got$n_components_used == 6L,
      "n_components_used is 6")

item5 <- item
item5$components$S5 <- NULL
recon5 <- t1_build_reconstructed(list(a = item5), series_dummy)
t1_ok("T1-04i", !isTRUE(recon5[[1]]$used_all_six),
      "missing S5 is detected and not silently treated as complete")

# Write guard: T1 must refuse paths outside results/teammate_1/
ok_guard <- FALSE
tryCatch({
  t1_assert_output_dir(file.path(RES_DIR, "scores.csv"))
}, error = function(e) ok_guard <<- grepl("teammate_1", e$message))
t1_ok("T1-04j", isTRUE(ok_guard),
      "refuses to write original results/scores.csv")
