# Phase 1 smoke experiment: B0 vs B1, LightGBM, h = 24 (UNMASKED)

**All metrics are UNMASKED.** The validation and test blocks include the upstream constant-fill hours: 336 of 1,464 validation targets and 936 of 2,208 test targets at h = 24. This is one run with one seed and an untuned starting configuration, so it says nothing yet about whether multivariate inputs help.

## 1. Setup

| Item | Value |
|---|---|
| Target | CPCB PM2.5, original scale |
| Designs | B0 (24 PM2.5 lags), B1 (144 lags of six pollutants) |
| Horizon | 24 h, direct fixed-horizon model ŷ(t+24) = f(X_t) |
| Split | S3, unmasked (train 3,066 / validation 1,464 / test 2,208 samples) |
| Model | LightGBM 4.7.0. Configured: objective regression, learning rate 0.05, at most 160 rounds, max depth 6, 31 leaves, feature fraction 0.8, bagging fraction 0.8, bagging freq 1, early stopping 30, 1 thread, seed 2026. Added for determinism: `metric = l2`, `deterministic = TRUE`, `force_col_wise = TRUE` |
| Selection | fit on train, early stopping on validation (l2) |
| Final fit | refit on train plus validation (4,530 samples) with the selected iteration count frozen, then a single test prediction |
| Inputs | original values, identity transform, nothing fitted on validation or test |
| MASE scale | seasonal-naive (lag 24) MAE of the train-block PM2.5 series: 4.1124 (3,089 pairs) |
| Intervals | 95% moving-block bootstrap, block 168 h, 999 replicates, seed 7 |

The run took about 1 s per design after the 22 tests passed. Selected iterations: **B0 39** (training stopped at 69), **B1 49** (stopped at 79). Both stopped early, well below the 160-round cap.

## 2. Results (`SMOKE_RESULTS.csv`)

| Design | Block | n | MAE [95% CI] | RMSE [95% CI] | MASE [95% CI] |
|---|---|---|---|---|---|
| B0 | train (in-sample) | 3,066 | 3.204 | 4.561 | 0.779 |
| B1 | train (in-sample) | 3,066 | 2.405 | 3.446 | 0.585 |
| B0 | validation | 1,464 | 6.015 [4.073, 7.103] | 8.741 [6.660, 9.852] | 1.463 [0.990, 1.727] |
| B1 | validation | 1,464 | 5.825 [4.008, 6.821] | 8.251 [6.416, 9.259] | 1.416 [0.975, 1.659] |
| B0 | test | 2,208 | 4.340 [2.768, 5.642] | 7.214 [4.948, 8.836] | 1.055 [0.673, 1.372] |
| B1 | test | 2,208 | 4.429 [2.748, 5.806] | 7.094 [5.072, 8.540] | 1.077 [0.668, 1.412] |

MAE and RMSE are in µg/m³. Test MASE with the train plus validation denominator (4.9768): B0 0.872, B1 0.890.

Paired B1 vs B0 on identical samples (`SMOKE_COMPARISON.csv`):

| Block | MAE ratio B1/B0 [95% CI] | MAE difference B1 − B0 [95% CI] | Share of bootstrap replicates with ratio < 1 |
|---|---|---|---|
| validation | 0.968 [0.908, 1.051] | −0.190 [−0.555, 0.257] | 0.73 |
| test | 1.020 [0.924, 1.183] | +0.089 [−0.342, 0.684] | 0.27 |

## 3. B0 vs B1 on validation

On validation, B1 has a 3.2% lower MAE and a 5.6% lower RMSE than B0. The paired interval for the MAE ratio (0.91 to 1.05) includes 1, so this run does not separate the two designs. B1 also fits the training block much more closely (in-sample MAE 2.40 against 3.20) while gaining little on validation, which points to the extra 120 columns adding capacity more than signal at this setting. That is a hypothesis to test with tuning and repeated seeds, not a conclusion.

## 4. Diagnostics (not primary results)

`diagnostics/SMOKE_DIAGNOSTICS.csv`, produced by `diagnostics/smoke_diagnostics.R`, splits the same errors by whether the target hour is a Phase 0 constant-fill hour. It also adds a seasonal-naive reference, ŷ(t+24) = y(t). Nothing in it was used for fitting or selection.

| Block | Forecast | MAE, all targets | MAE, constant-fill targets | MAE, other targets |
|---|---|---|---|---|
| validation | B0 | 6.015 (n = 1,464) | 0.754 (n = 336) | 7.582 (n = 1,128) |
| validation | B1 | 5.825 | 0.756 | 7.335 |
| validation | seasonal naive | 6.656 | 0.690 | 8.433 |
| test | B0 | 4.340 (n = 2,208) | 1.052 (n = 936) | 6.760 (n = 1,272) |
| test | B1 | 4.429 | 0.785 | 7.110 |
| test | seasonal naive | 4.216 | 0.468 | 6.973 |

What this shows about the unmasked numbers:

- On the unmasked test block, the seasonal-naive reference has the lowest overall MAE (4.22). That is because 42% of test targets are constant fill, where copying the value from 24 hours earlier is exact inside a fill block.
- Constant-fill targets have very small errors for every method, so the unmasked test MAE is heavily diluted. On the non-fill test targets, B0 (6.76) beats the naive reference (6.97) and B1 (7.11).
- B1 does better than B0 on test fill targets (0.785 against 1.052) and worse on the others. This matches the Phase 0 warning: when all six pollutants freeze together, a multivariate model can recognise the fill state. In the unmasked test, that recognition and genuine forecasting skill pull in opposite directions.
- On validation, both LightGBM designs beat the naive reference on both target groups.

## 5. What the smoke run establishes

- Both feature matrices are built correctly. The 22 automated tests passed before training: alignment, ordering, cell values, future-perturbation leakage, block membership, retention, counts, no test-label use, reproducibility.
- LightGBM trains, early-stops on validation, refits on train plus validation with frozen iterations, and predicts the test block.
- Validation and test metrics, bootstrap intervals and the paired comparison are generated and saved under `results/multivariate/phase1/` only. No existing outputs were touched.

## 6. Problems and deviations

1. **Parquet reader.** `arrow` could not be installed in the build sandbox because CRAN was blocked, so this run read the store with `nanoparquet` 0.5.2. The values and instants were verified bit-identical to pyarrow. On your machine the layer will use `arrow`.
2. **lightgbm build.** lightgbm 4.7.0 was built from CRAN's GitHub mirror, on R 4.3.3. Your R 4.5/4.6 with a different lightgbm version may give slightly different metrics. Dataset hashes should be identical.
3. **lightgbm `current_iter()` overwrites its own return value.** The R package fills an integer in place, so an earlier fit's recorded iteration count was overwritten by a later fit. Before the fix, B0 showed "39 iterations run" instead of 69. Predictions and the refit round count were not affected (they use `best_iter`). Fixed by copying the value, with regression test T22.
4. **Refit set.** The refit uses train samples plus validation samples, each within its own block. Samples whose origin is in train and target in validation (24 at h = 24, 744 at h = 744) are left out, following "no target may cross a block boundary".
5. **MASE denominator.** The primary denominator is the train block for every block, as specified. Phase 0 had suggested scaling test scores by the refit data, so that version is reported too (`MASE_refit_scale`).
6. **Bootstrap utility.** The existing `.block_boot_ci()` in `R/34_decomp_screen.R` removes duplicate resampled origins, so it is not a with-replacement bootstrap, and it only returns an MAE ratio. I wrote a standard moving-block bootstrap in `R/44_mv_metrics.R` instead, using 168-hour blocks.
7. **Optimistic validation.** Early stopping uses the same validation block that is then reported, so validation scores are slightly optimistic for both designs alike.

## 7. Next steps

1. **Re-run locally.** In your R environment, from the project root: `Rscript run_multivariate.R`. Check for 22/22 tests, `DATASET_HASHES.csv` hashes equal to this run, and metrics close to the table above.
2. **Repeated seeds.** Before comparing designs, repeat B0/B1 at h = 24 over 5 seeds (for example 2026 to 2030) to measure seed variance. The current B1 − B0 validation gap (−0.19 µg/m³) may be within seed noise.
3. **All four horizons.** Three small driver changes are needed first:
   - make the output file prefix configurable (`RESULTS_` instead of `SMOKE_`), so smoke outputs are not overwritten;
   - make the bootstrap block length depend on the horizon (for example max(168, h)), and record that at h = 744 the test has only 1,488 overlapping origins, so its intervals will be wide;
   - add per-horizon timing to the run metadata.

   Then run `Rscript run_multivariate.R --horizons=24,168,336,744 --designs=B0,B1`.
4. **XGBoost and CatBoost.** Add each with `mv_register_family()` (fit and predict functions only). Feature construction does not change. Make CatBoost list `catboost` as its package, so it stops if that is missing. Extend T20 to the new registry and add one reproducibility test per family.
5. **Tuning.** Tune each family on the validation block only, with a small grid on learning rate, leaves/depth, feature fraction and minimum leaf size. Then refit with frozen iterations as now. Test results stay read-only until the configuration is fixed.
6. **Later phases, in order.** Linear and projection families using the `mv_transform_*()` fit/apply contract (standardize first, then Ridge, Lasso, Elastic Net, PCA, PLS); the other five target pollutants; B2 once the `mra_haar_J5__raw` store has passed `check_decomp_store.R`; then the recursive, direct and hybrid comparison on the shortlisted architectures.
7. **Masked results.** Because the unmasked test is 42 to 52% constant fill, a clearly labelled secondary analysis with the Phase 0 mask is worth considering when results are written up. This does not change the primary unmasked design.
