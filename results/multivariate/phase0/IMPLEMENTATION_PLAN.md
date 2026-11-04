# Phase 0 implementation plan

## 1. Readiness

| Item | B1 (raw multivariate) | B2 (decomposed multivariate) |
|---|---|---|
| Pollutant data | Ready. Six pollutants, 8,880 aligned hours, no NA | Ready |
| Data quality | **Needs the Phase 0 mask**: 25.9% of hours are an upstream constant fill | Same |
| Decomposition | Not needed | **Not in the upload.** Verify the local store with `check_decomp_store.R`, or generate it |
| Leakage | Safe if built from `store/clean` with the block rules | Safe if built from the trailing store; legacy MRA helpers must not be used |
| Split | Proposed (S3) | Same split |
| Model code | Not ready: the existing fitters are univariate and build their own lags | Same |

## 2. What needs fixing or deciding before any model runs

1. **Decomposition store.** Run `Rscript results/multivariate/phase0/check_decomp_store.R mra_haar_J5__raw CPCB` on the local copy. If files are missing, or the recompute check shows a non-zero deviation, regenerate with `Rscript run_decomp.R mra_haar_J5 --skip-screen --skip-diag` and run the checker again.
2. **Fill mask (your decision).** Recommended: adopt `proposed_quality_mask_cpcb.csv` as an overlay. Fill hours are never targets, and the policy.yaml origin rules apply to the mask. The alternative is to keep fill hours as targets for paper comparability, with those scores reported only as secondary. The mask leaves `store/clean` unchanged.
3. **Split (your decision).** Recommended: S3 (train to 2023-01-31 23:00, validation to 2023-04-03 23:00, test to 2023-07-05 23:00). S1 gives more training data, but only 144 test samples at h = 744.
4. **T1 row count.** Confirm whether T1 used the 8,881-row CSV (8,521 + 336 + 24) or the 8,880-row store. That affects how far T1 numbers can serve as the univariate reference. B0 on the new split gives a clean univariate reference either way.
5. **Forecast strategy (later, your decision).** A direct strategy is the simplest leakage-safe choice for multivariate inputs. A recursive one requires forecasting all 6 (B1) or all 36 (B2) series jointly.

## 3. How the existing code supports each model family

Details: `model_family_support.csv`.

| Family | Package | In repo package list | Existing code | What Phase 1 needs |
|---|---|---|---|---|
| LightGBM | lightgbm | yes | `fit_lgb` (univariate) | generic wrapper on an external X; seed; early stopping on validation |
| XGBoost | xgboost | yes | `fit_xgb` (univariate, unseeded) | same wrapper; set seed |
| CatBoost | catboost (GitHub binary) | optional | `fit_cat` (univariate; silent XGBoost fallback) | same wrapper; stop if missing; native categorical target id |
| Linear regression | stats | base | none | `lm.fit` with QR rank check |
| Ridge, Lasso, Elastic Net | glmnet | **no** | none | add glmnet; choose λ, α on validation, not `cv.glmnet` random folds |
| PCA | stats::prcomp | base | none | fit on fitting rows; choose ncomp on validation |
| Sparse PCA | elasticnet or sparsepca | **no** | none | add package |
| PLS | pls | **no** | none | add pls; choose ncomp on validation |
| Mutual-information selection | praznik (or kNN estimator) | **no** | none | add package; rank on training rows only |
| Model-based selection | glmnet, lightgbm | lightgbm only | none | Lasso path or gain importance inside the training block |
| Decomposition reader | arrow | yes | `get_decomp`, `get_decomp_multi` | multi-pollutant join by instant with assertions |
| Metrics | base | yes | `mase`, `mae`, `rmse` | masked variants; B2 reconstruction before scoring |

No deep learning is introduced, and no Python is needed.

## 4. Separate and pooled models

**Separate models.** Loop over (design, target, horizon, family). Every model for a given horizon shares the same X rows. Only y changes.
- B1: 6 targets × 4 horizons = 24 models per family (4 while PM2.5 is the only target).
- B2: 36 component targets × 4 horizons = 144 models per family (24 for PM2.5). Each pollutant's forecast is the sum of its six component forecasts.
- B0-raw and B0-comp references: the same counts with the single-pollutant columns.

**One shared pooled model.** Per (design, horizon, family), stack the X rows once per target and add target identity (`FEATURE_DESIGN.md`, section 7):
- B1 pooled: 6 stacked blocks, identity with 6 levels.
- B2 pooled: 36 stacked blocks, identity as (pollutant, component), or 36 levels.
- Standardize y per target with training statistics. Invert per target before scoring. Score every target separately so the pooled and separate results line up row for row.
- Trees learn identity interactions themselves. For linear models, pooling with identity dummies shares one slope vector, which should be reported as a restricted model.

**Projection and selection.** Each one is a fitted step inside the pipeline (fit on fitting rows, apply to validation and test rows) and is chosen on validation:
- PCA and Sparse PCA on standardized X, followed by linear regression or trees on the scores.
- PLS directly on standardized X and y (one PLS per target, or PLS2 across targets for the pooled variant).
- MI selection: rank columns by mutual information with y on training rows, keep the top m, with m chosen on validation.
- Model-based selection: non-zero Lasso coefficients, or top-m LightGBM gain, from a training-block fit.

## 5. Code layout for the next phase (new files only)

```
config/multivariate.yaml        pollutants, lags, horizons, split dates, mask path, decomposition id, seeds
R/40_mv_data.R                  load store/clean + six decomposition files, join by instant, assert alignment, apply mask, assign blocks
R/41_mv_features.R              build B0 / B1 / B2 matrices and pooled stacks with fixed column names
R/42_mv_transforms.R            train-fitted scaler, PCA, Sparse PCA, PLS, MI and model-based selection (fit/apply pairs)
R/43_mv_models.R                fit_tabular() for lgb, xgb, catboost, lm, ridge, lasso, enet
R/44_mv_metrics.R               masked MASE / MAE / RMSE, B2 reconstruction
run_multivariate.R              driver, one (design, family, horizon) job per call, hashed cache key
tests/multivariate/             alignment, causality, block-boundary, scaler-rows and mask tests
results/multivariate/phase1/    outputs
```

Nothing under `R/00` to `R/35`, `config/preprocess.yaml`, `config/decomp.yaml`, `store/`, or the existing `results/` files is modified. The new code should not source `R/06_models.R` wave helpers or `R/03_preprocess.R` imputation, so legacy two-sided paths cannot slip in.

## 6. Next implementation steps, in order

1. Run `check_decomp_store.R`. Generate `mra_haar_J5__raw` only if needed. Commit the checker CSV to this folder.
2. Settle decisions 2 to 5 in section 2, and write them into `config/multivariate.yaml`.
3. Build the data layer (`R/40`, `R/41`). Write the B0/B1/B2 matrices for PM2.5 at the four horizons to `results/multivariate/phase1/data/`, with a manifest (mask version, split dates, column order, input hashes).
4. Write and pass these tests before fitting anything:
   - perturbing any value after the origin leaves X unchanged;
   - no training label after the train end;
   - every scaler and transform is fitted on fitting rows only;
   - B2 targets sum to the raw target (error ≤ 1e-10);
   - every row is scorable and passes the origin rule;
   - identical timestamps across all 7 sources (clean store plus six decomposition files).
5. Add the packages (glmnet, pls, elasticnet or sparsepca, praznik). Implement `fit_tabular()` and masked metrics. Run one smoke job (LightGBM, B1, PM2.5, h = 24) and check the sample counts against `split_proposal_S3_boundaries_and_counts.csv`.
6. Only then start the Phase 2 experiments: separate models first, pooled second, projections and selection third.

## 7. Recommendation

The data supports both B1 and B2. All six CPCB pollutants share a complete 8,880-hour grid, so no pollutant has to be dropped and nothing needs imputing.

Two things must be fixed first. The `mra_haar_J5__raw` store is not in the upload and must be verified or generated. And 25.9% of the hours are an upstream constant fill that the repository treats as real data. That fill also covers 600 of the last 744 hours, which makes the T1-style terminal test windows unusable for multivariate evaluation.

With the fill mask, the S3 split, and a new data layer that reads only `store/clean` and the trailing decomposition store, both designs can be built without leakage. Then: run the checker, confirm the mask and split, build and test the data layer, and only then fit models.
