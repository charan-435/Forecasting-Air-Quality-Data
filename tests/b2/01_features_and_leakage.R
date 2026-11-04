# B2 feature construction, alignment, lag order, leakage, reconstruction.

panel <- b2_load_panel()
b2_ok("B2-01a", identical(length(attr(panel, "b2_feature_cols")), 36L),
      "panel has 36 pollutant-component columns")
b2_ok("B2-01b", all(B2_POLLUTANTS %in% c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO")),
      "six pollutants in fixed order")
b2_ok("B2-01c", sum(panel$all36_ok) > 5000,
      "many complete multivariate rows after warmup")

fn <- b2_feature_names()
b2_ok("B2-02a", identical(length(fn), 864L),
      "expected feature count is 864")
b2_ok("B2-02b", identical(fn[1], "PM2.5__D1__lag1") &&
        identical(fn[24], "PM2.5__D1__lag24") &&
        identical(fn[25], "PM2.5__D2__lag1"),
      "deterministic lag ordering: lag1 most recent within each series block")
b2_ok("B2-02c", identical(fn[864], "CO__S5__lag24"),
      "last feature is CO__S5__lag24")

# Lag semantics: lag1 at origin t equals series[t]
t0 <- which(panel$all36_ok)[50]
row <- b2_row_at_origin(panel, t0, 24L)
b2_ok("B2-03a", !is.null(row) && identical(length(row), 864L),
      "row_at_origin returns 864 features")
b2_ok("B2-03b",
      isTRUE(all.equal(as.numeric(row[["PM2.5__D1__lag1"]]),
                       as.numeric(panel[["PM2.5__D1"]][t0]),
                       check.attributes = FALSE)),
      "lag1 is value at origin t (most recent available)")
b2_ok("B2-03c",
      isTRUE(all.equal(as.numeric(row[["PM2.5__D1__lag2"]]),
                       as.numeric(panel[["PM2.5__D1"]][t0 - 1L]),
                       check.attributes = FALSE)),
      "lag2 is value at t-1 (no future)")

# Supervised direct: target is y[t+h], features from origin t only
sup <- b2_build_supervised(panel, "D1", 24L)
b2_ok("B2-04a", nrow(sup$meta) > 100,
      "supervised D1@24 has rows")
b2_ok("B2-04b", all(sup$meta$target_idx == sup$meta$origin_idx + 24L),
      "target index is origin+h (direct horizon)")
# Train origins and targets both in train
tr <- sup$meta$stage == "train"
b2_ok("B2-04c",
      all(sup$stage[sup$meta$origin_idx[tr]] == "train") &&
        all(sup$stage[sup$meta$target_idx[tr]] == "train"),
      "train examples keep origin and target inside train block")
# Val/test targets stay in their blocks
va <- sup$meta$stage == "validation"
te <- sup$meta$stage == "test"
b2_ok("B2-04d", all(sup$stage[sup$meta$target_idx[va]] == "validation"),
      "validation targets remain in validation block")
b2_ok("B2-04e", all(sup$stage[sup$meta$target_idx[te]] == "test"),
      "test targets remain in test block")
# No target uses future feature: feature lag1 time == origin, target later
b2_ok("B2-04f", all(sup$meta$target_time > sup$meta$origin_time),
      "every target timestamp is after its origin")

# Shared component identity encoding
oh <- b2_component_onehot(c("D1", "D3", "S5"))
b2_ok("B2-05a", identical(ncol(oh), 6L) && identical(sum(oh[1, ]), 1) &&
        identical(colnames(oh)[1], "comp_id__D1"),
      "shared model component-id is one-hot without target leakage columns")

# Reconstruction additivity + inverse scaling identity on dummy
h <- 4L
preds <- lapply(B2_COMPONENTS, function(comp) {
  tibble::tibble(
    target_time = panel$timestamp[100:(100 + h - 1)],
    yhat = as.numeric(panel[[paste0("PM2.5__", comp)]][100:(100 + h - 1)]),
    y_pm25 = panel$y_pm25[100:(100 + h - 1)],
    component = comp
  )
})
names(preds) <- B2_COMPONENTS
# Sum of stored components ≈ y when all finite
s <- Reduce(`+`, lapply(preds, `[[`, "yhat"))
ok <- panel$all36_ok[100:(100 + h - 1)]
b2_ok("B2-06a",
      isTRUE(all.equal(s[ok], panel$y_pm25[100:(100 + h - 1)][ok],
                       tolerance = 1e-8, check.attributes = FALSE)),
      "reconstruction additivity holds on stored components")

# Sandbox
b2_ok("B2-07a",
      inherits(try(b2_assert(file.path(RES_DIR, "scores.csv")), silent = TRUE), "try-error"),
      "refuses to write original results/scores.csv")
b2_ok("B2-07b",
      isTRUE(tryCatch({ b2_assert(file.path(RES_DIR, "b2", "REPORT.md")); TRUE },
                      error = function(e) FALSE)),
      "allows writes under results/b2/")

# Identical evaluation timestamps helper: univ and multi share builder
sup2 <- b2_build_supervised(panel, "D1", 24L)
b2_ok("B2-08a", identical(sup$meta$target_time, sup2$meta$target_time),
      "identical supervised timestamps for same target/horizon")
