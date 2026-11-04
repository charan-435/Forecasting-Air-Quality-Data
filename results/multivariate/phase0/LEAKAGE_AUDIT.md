# Phase 0 leakage and causality audit

Scope: the code paths that would feed B1/B2 (`R/20_ingest.R`, `R/21_quality.R`, `R/22_impute.R`, `R/23_store_clean.R`, `R/30` to `R/35`, `config/*.yaml`), and the legacy paths (`R/03_preprocess.R`, `R/04_modwt.R`, `R/06_models.R`, `R/09_hparams.R`, `run_*.R`) that must stay out of them. The full register with locations is in `leakage_risk_register.csv` (16 items).

## 1. Answers to the five questions

**Does imputation use future observations?**
Not inside the repository, for CPCB. The paper sources have `skip_preprocess: true`, so `skip_impute()` copies `value_masked` into `value_filled_causal` unchanged. There are no NA values to fill (see `DATA_AUDIT.md`).

The CPCB file arrives **already filled upstream**: 2,304 hours hold one constant vector close to the series mean. A mean over the whole period is a full-sample statistic, so these hours carry a small amount of future information as inputs. More importantly they are synthetic as targets. This is the main risk for this study (register L1).

Other imputation paths:
- `impute_hourly()` (`imputeTS::na_seadec` on the full series) is deprecated but still called by `prepare_series()` and `paper_preprocess_15min()`. It looks ahead (AUDIT F10). It must not feed B1/B2.
- The Phase 1a fills (M1 to M8 in `R/22_impute.R`) are causal step by step: each fill uses only earlier hours, or the same hour of another pollutant for M8. Their fitted parameters (M7 hour-of-day profile, M8 regression, method choice from the benchmark) use data before `selection_end = 2023-10-01`. That does not affect CPCB, which ends in July 2023 and skips imputation. It would matter for Delhi/Shillong 2023 data if the test block were placed before October.

**Is scaling fitted on training data only?**
The Phase 1a store and the decomposition store are unscaled, and decompositions are computed on raw values, so there is no full-series scaling upstream of B1/B2. The legacy `minmax_fit()` was called on train plus validation (AUDIT F12). For the new study, every scaler and transform (standardization for linear models, PCA, Sparse PCA, PLS, MI binning, per-target scaling in pooled models) must be fitted on the rows of the current fit only: train during selection, train plus validation for the final refit.

**Do decomposition features at time t use only observations at or before t?**
Yes, for the stored trailing method `mra_haar_J5`. Sampled bump tests on all six CPCB pollutants showed no change at t from bumps at t+1, t+24, t+168, t+336 or t+744. The value at t depends only on `x[t-2047 .. t]` (`DECOMPOSITION_AUDIT.md`, section 3).

No, for the legacy helpers. `haar_mra()`, `generic_mra()` and `haar_modwt()` apply a two-sided circular transform to whatever vector they receive. Called on a training vector, the components at t depend on `x[t+1 .. t+31]` (AUDIT F1). Called on the full series (`paper_wave_walkforward`), they also see test values (AUDIT F2).

**Does any full-series operation put future information into historical features?**
Not in the store path for CPCB. The operations that do, or did, are:

| Operation | Where | Effect | Relevant to B1/B2? |
|---|---|---|---|
| Upstream mean fill | `data/raw/CPCB.csv` | constant close to the series mean in 25.9% of hours | **Yes**, mask it |
| Two-sided circular MRA | `R/04_modwt.R`, `R/06_models.R` wave helpers | future hours inside components | Only if these helpers are called; do not call them |
| Full-series `na_seadec` | `R/03_preprocess.R` | fills use later hours | Only through v1 objects; do not use them |
| `choose_J()` on the full series | `run_experiments.R` | J chosen with test data; J stays 5 if the test is removed (AUDIT F11) | No, J = 5 is fixed |
| Decomposition screen and D3/D4 diagnostics | `R/34`, `R/33`; `selection_end` falls back to 2023-10-01, then is clipped to the CPCB end | method ranking scored on the last 60 days, which overlap the proposed test block | Only if screen results are used to pick a method. Treat J5 Haar as fixed a priori |
| Frozen hyperparameters | `results/hparams.rds` | tuned on a prefix that overlaps the 7/14/31-day tests (AUDIT F5) | Do not reuse |
| Causal quality flags (stuck, spike) | `R/21_quality.R` | causal by construction | Not applied to paper sources |

**Is the trailing-window MRA suitable for forecasting?**
Yes for leakage: it is causal and additive, and B2 can use it as both features and targets. Its endpoint values are noisy, though. Through the circular wrap they depend on hours about 85 days back, and they correlate only 0.50 to 0.79 with the settled values. B2 results should be read with that in mind (register L7).

## 2. Multivariate-specific rules

These apply to every B1 and B2 run.

1. **Predictors stop at the origin.** For origin t, every predictor of every pollutant is taken at t, t-1, ..., t-23. Values of any pollutant at t+1 .. t+h, including the hour of the target itself, are never predictors.
2. **Forecasting strategy.** A direct strategy (one model per horizon) needs nothing beyond rule 1. A recursive strategy would need the other pollutants' future values at every step. Those must then be forecast as well (all 6 series for B1, all 36 component series for B2), never filled with observed values. The strategy choice is deferred, as the scope requires.
3. **Labels stay inside their block.** A training sample (t, t+h) needs t+h ≤ train end. A validation or test sample needs origin t ≥ block start and t+h ≤ block end. In the final refit, labels must end before the first test origin. With B2 targets taken from the trailing store, the label at t+h uses data up to t+h only, so no extra purge is needed. If settled (two-sided) components were ever used as targets, the purge would grow by 31 hours.
4. **Masked hours are never targets.** Constant-fill hours and all-six runs of 6 h or more cannot be training or evaluation targets. Origins follow `store/clean/policy.yaml`, applied to the new mask: skip an evaluation origin if more than 25% of its 24-hour lag window is flagged or if it sits more than 72 h into a flagged run; drop a training row if more than 50% of its window is flagged.
5. **All selection happens on validation.** λ, α, PCA/PLS component counts, feature subsets, tree hyperparameters and early-stopping rounds are chosen on the validation block, or on contiguous folds inside train with an h-hour purge. Never use `cv.glmnet` default random folds, and never fit a transform on the full matrix. The test block is read once, at the end.
6. **Join by instant.** Decomposition files store UTC instants. Join pollutants and components on the instant and assert row-for-row equality with `store/clean`, which `check_decomp_store.R` does.
7. **MASE scale.** Use the seasonal-naive (lag 24) MAE on training-block pairs where both hours are scorable. Including fill blocks would shrink the scale, since seasonal naive is exact inside a constant block.
8. **Label models honestly.** CatBoost must not fall back silently to XGBoost. Stop if `catboost` is missing, and log package versions with every run.

## 3. Severity summary

| Severity | Items |
|---|---|
| Critical | L1 upstream constant fill; L6 legacy two-sided helpers (if used); L11 future values of other pollutants |
| High | L8 decomposition screen window; L9 frozen hyperparameters; L10 label leakage across blocks; L12 shuffled CV or full-data transforms |
| Medium | L2 row count of T1 (cloned row); L4 scaling; L7 endpoint noise; L13 UTC/IST joins; L14 `valid_strict` gives no protection; L15 MASE scale |
| Low | L3 imputation (CPCB); L16 CatBoost fallback |
| OK | L5 trailing store is causal and additive |

## 4. Note on the T1 reference

The T1 outputs are not in the upload, so they could not be checked. One observation: 8,521 + 336 + 24 = 8,881, which is the raw CSV row count, not the store's 8,880. If T1 used that split on the raw file, its 24-hour test includes the cloned 2023-07-06 00:00 row (itself a fill row) and its 336-hour validation window (2023-06-21 01:00 to 2023-07-05 00:00) is 239/336 fill hours. If the same pattern was used for the longer horizons, the 744-hour test window is 601/744 fill (600/744 on the store's 8,880 rows). This is why the multivariate split below is not built on the T1 windows.
