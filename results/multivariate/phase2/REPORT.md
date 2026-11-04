# Phase 2: raw multivariate forecasting (B0 vs B1), CPCB, UNMASKED

**All results in this report are UNMASKED.** Every aligned hour is used for training, selection and scoring, including the 2,304 upstream constant-fill hours. Breakdowns by constant-fill status are diagnostics computed from the same forecasts. They never filter training or selection rows.

Dataset: CPCB only. Target: PM2.5 (Sections 3–8), then all six pollutants (Section 9). Strategy: direct fixed-horizon, ŷ(t+h) = f_h(X_t), one model per horizon. No deep learning, no B2, no recursive or hybrid strategies, no other datasets.

## 1. Answers in brief

| # | Question | Answer |
|---|---|---|
| 1 | Does raw multivariate (B1) beat raw univariate (B0)? | **Not in general.** Across 6 families × 4 horizons, B1 is significantly better than B0 on test in 3 of 24 cells (the three tree models at h = 744; LightGBM 0.939 [0.889, 0.977]). It is significantly worse in 7 (the three tree models at h = 168, ridge, lasso and elastic net at h = 336, ridge at h = 744). The rest are indistinguishable. Validation gains at h = 24 (3–4% for trees) do not carry over to test. |
| 2 | Does any improvement persist across all four horizons? | **No.** The sign changes with horizon: B1 helps trees at h = 744, hurts them at h = 168 and is neutral at h = 24 and 336. At h = 168 and 744, lasso and elastic net pick an intercept-only model on validation, so B0 and B1 are the same forecast. |
| 3 | Which models benefit most from extra pollutants? | The tree models (LightGBM, XGBoost, CatBoost), and only at h = 744: test MAE ratios 0.94–0.96 with CIs below 1, the same direction on validation, and 5/5 seeds. Linear models gain nothing except through fill-state recognition at h = 24 (ridge, see 7). |
| 4 | Which pollutants carry the most useful information? | Trees spend most of their gain on PM10, CO and SO2. But in the ablations no single added pollutant improves validation by more than about 2% at any horizon (best: O3 at h = 24, −1.6%; CO at h = 336, −3.0%). The test effects of adding or dropping a pollutant often reverse the validation effects. SO2 takes 42–57% of tree importance at h = 168 and 336, yet dropping it *improves* test at h = 336 (0.936 [0.873, 0.975]). It acts as a slowly drifting level proxy, not a predictor. |
| 5 | Does feature selection or dimensionality reduction improve generalisation? | **No.** The validation-selected variant at each horizon (correlation top-48, B1 − PM2.5, PLS scores + LightGBM, MI top-24) never improves test over the full 144-lag B1. At h = 336 and h = 744 it is significantly worse (1.087 [1.044, 1.155] and 1.046 [1.015, 1.093]). The selected feature sets are unstable between the train fit and the train + validation refit (Jaccard 0.14–0.50 for elastic-net selection, 0.20 for correlation top-k at h = 168). Unpenalised PCR and PLS regression fail badly at long horizons because they cannot shrink to the mean. |
| 6 | Separate or shared target models? | **Separate**, on the validation evidence. Separate B1 has the lowest mean MASE over the six targets on validation at every horizon. The shared B1 model (with own-lag slot) is never significantly better than separate B1 on validation in any of the 24 target × horizon cells, and is worse in 16. On test the picture is mixed (shared better in 5, worse in 7). The shared model is consistently poor for NO2, the lowest-variance target (test ratios 1.16–1.63), and helps SO2 at h = 744. |
| 7 | How much do constant-fill observations matter? | **A lot at h = 24, and they flip the sign.** 40–52% of test targets are constant fill. At h = 24, B1 beats B0 by 27–48% on fill targets (it recognises the six-pollutant freeze) but is neutral to 8% worse on non-fill targets. At h = 168, B1 is 19–31% *worse* on fill targets. The unmasked headline ratio therefore mixes two opposite effects. The h = 744 B1 gain for trees is the only one that also holds on non-fill targets alone (LightGBM 0.936 [0.88, 0.97]). |

**The finding that matters most for the next phase:** at h ≥ 168 none of these raw-lag models has demonstrable skill over a constant. On validation, a train-mean climatology is within ±2.5% of the best tree model at h = 168, 336 and 744 (it beats it at h = 168). On test, climatology beats every validation-selected model at those horizons (for example h = 744: climatology 3.97 against 4.29–4.57 for B0/B1 trees). Lasso and elastic net confirm this independently by choosing an intercept-only model at h = 168 and 744. The B0 vs B1 question at long horizons is therefore a comparison between two near-constant forecasts.

## 2. Audit of the Phase 1 implementation

All 22 Phase 1 tests pass on this machine (R 4.5.2, lightgbm 4.7.0, arrow 26.0.0). The Phase 1 smoke predictions at h = 24 reproduce to 5 × 10⁻¹⁴ (`smoke/PHASE1_REPRODUCTION.csv`), and the h = 24 dataset hashes are bit-identical to Phase 1. No Phase 1 artifact was modified.

| Finding | Action |
|---|---|
| Alignment, ordering, cell values, leakage, block membership, sample counts, test-label isolation and reproducibility are correct and tested. | Kept unchanged. |
| The bootstrap block length is fixed at 168 h for every horizon, with no justification. | Replaced by a data-driven block length per comparison (Section 10). |
| The target is hard-coded in `mv_dataset()` and `mv_block_scale()`. | Added an optional `target` argument; the default behaviour is identical. |
| The transform contract passes `X` only, but PLS and correlation/MI/EN selection need `y`. | `fit(X_fit, y_fit = NULL)`; existing transforms are unchanged. |
| The refit can only freeze an iteration count, but penalised linear models need λ frozen. | Families may return `refit_params` (λ, number of PLS components), which are frozen into the refit. |
| `tests/multivariate/run_tests.R` always writes into `phase1/`, so rerunning it overwrites smoke artifacts. | `MV_TEST_OUT_DIR` override added. The one accidental overwrite during the audit was restored from `multivariate_phase1_b0_b1.zip`. |
| The fill split existed only as an ad-hoc h = 24 script. | `mv_fill_hours()` reproduces the 2,304 Phase 0 hours from the data (test P01) and is applied at every horizon. |
| Validation scores are optimistic, because early stopping and configuration selection use the validation block. | Kept by design (the protocol allows it). Validation numbers here are selection scores; **test is the only unbiased estimate**. |
| `Rscript -e` segfaults on this machine when arrow is loaded. | Not a pipeline issue. All runs use script files. |
| xgboost ≥ 3 moved the evaluation log into attributes and uses an inclusive `iterationrange`. | Handled in `R/45_mv_families.R`, checked by test P04. |
| Besides the 2,304 constant-fill hours, there are 107 further hours in four all-six frozen runs (35, 24, 24 and 24 h) at other values. | Phase 0 counts these as "stuck runs", not constant fill. They are kept in the non-fill group here, consistent with Phase 0. |

New code: `R/45_mv_families.R` (xgboost, catboost, ridge, lasso, elastic net, OLS, PLS), `R/46_mv_featsel.R` (train-fitted selection and projection transforms), `R/47_mv_eval.R` (fill groups, references, block length, DM test, pooled dataset), `R/48_mv_runner.R`, `R/49_mv_stages.R`, `run_mv_experiments.R`, `config/multivariate_experiments.yaml`, and `tests/multivariate/run_tests_phase2.R` (18 tests, all passing).

## 3. Data and samples (verified from the unmasked prepared data)

CPCB, `store/clean/series.parquet`, `value_filled_causal`: 8,880 hourly rows from 2022-07-01 00:00 to 2023-07-05 23:00 IST. All six pollutants are on identical instants, with no gaps and no NA. S3 blocks: train 2022-09-24 07:00 to 2023-01-31 23:00; validation 2023-02-01 to 2023-04-03; test 2023-04-04 to 2023-07-05. Counts match the independent calendar computation (`check/SAMPLE_COUNTS_UNMASKED.csv`).

| h | Train | Validation | Test | Refit (train + val) | Fill targets: val / test | Test fill share |
|---|---|---|---|---|---|---|
| 24 | 3,066 | 1,464 | 2,208 | 4,530 | 336 / 936 | 42% |
| 168 | 2,922 | 1,320 | 2,064 | 4,242 | 288 / 816 | 40% |
| 336 | 2,754 | 1,152 | 1,896 | 3,906 | 168 / 768 | 41% |
| 744 | 2,346 | 744 | 1,488 | 3,090 | 168 / 768 | 52% |

The constant-fill hours fall in 12 runs (144, 168 and 600 h) on fixed calendar days. The June 2023 run of 600 h sits inside the test block.

## 4. Protocol

- **Selection.** For each family, design and horizon, a configuration grid is fitted on train. Early stopping (trees) or the penalty path (linear) uses validation, and the configuration with the lowest validation MAE wins. Grids: LightGBM 24 + the Phase 1 smoke configuration; XGBoost 16; CatBoost 4; elastic net α ∈ {0.1, 0.5, 0.9}; ridge and lasso λ path only (`config/multivariate_experiments.yaml`, `report/SELECTED_CONFIGS.csv`).
- **Final fit.** Refit on train + validation samples with the selected iteration count, λ or component count frozen, then predict test once. Test labels are never passed to any fit, selection or transform (tests T15, P03, P06, P11, P13).
- **Seeds.** Stochastic families use 5 seeds (2026–2030), tuned with seed 2026. Comparisons use the seed-mean forecast. Per-seed paired differences are reported separately (`PAIRED_B1_VS_B0_PER_SEED.csv`). Linear models are deterministic.
- **Scaling.** Linear models use a standardiser fitted on the fitting rows only (train for selection, train + validation for the refit). Trees are unscaled.
- **Metrics.** MAE, RMSE, and MASE with the seasonal-naive (lag 24) MAE of the train-block series of the same pollutant as denominator (PM2.5: 4.112).
- **References.** Seasonal naive (ŷ = y(t) for every h here), climatology (train mean for validation; train + validation mean for test), hour-of-day climatology.
- Single-threaded throughout (`num_threads`/`nthread`/`thread_count` = 1). Independent stages run as parallel processes.

## 5. Stage A and B: B0 vs B1 for six model families (PM2.5)

Seed-mean forecasts, MAE in µg/m³ (`report/HORIZON_COMPARISON_B0_B1.csv`):

| Family | h | Val B0 | Val B1 | Test B0 | Test B1 | Test B1/B0 [95% CI] |
|---|---|---|---|---|---|---|
| LightGBM | 24 | 5.892 | 5.691 | 4.336 | 4.476 | 1.032 [0.936, 1.158] |
| | 168 | 7.482 | 7.488 | 5.335 | 5.650 | **1.059 [1.011, 1.136]** |
| | 336 | 8.083 | 8.308 | 5.812 | 5.949 | 1.024 [0.959, 1.108] |
| | 744 | 6.313 | 6.214 | 4.565 | 4.288 | **0.939 [0.889, 0.977]** |
| XGBoost | 24 | 5.890 | 5.668 | 4.363 | 4.207 | 0.964 [0.892, 1.067] |
| | 168 | 7.485 | 7.434 | 5.346 | 5.720 | **1.070 [1.013, 1.160]** |
| | 336 | 8.025 | 8.218 | 5.825 | 5.956 | 1.022 [0.974, 1.093] |
| | 744 | 6.270 | 6.127 | 4.536 | 4.355 | **0.960 [0.925, 0.995]** |
| CatBoost | 24 | 5.933 | 5.670 | 4.269 | 4.232 | 0.991 [0.896, 1.134] |
| | 168 | 7.537 | 7.562 | 5.364 | 5.667 | **1.057 [1.012, 1.126]** |
| | 336 | 8.185 | 8.255 | 5.641 | 5.809 | 1.030 [0.969, 1.116] |
| | 744 | 6.290 | 6.203 | 4.556 | 4.345 | **0.954 [0.914, 0.981]** |
| Ridge | 24 | 6.051 | 6.221 | 4.034 | 3.867 | 0.959 [0.915, 1.003] |
| | 168 | 7.273 | 7.273 | 5.266 | 5.281 | 1.003 [0.991, 1.017] |
| | 336 | 8.034 | 8.004 | 5.106 | 5.183 | **1.015 [1.001, 1.041]** |
| | 744 | 6.154 | 6.154 | 4.346 | 4.409 | **1.014 [1.006, 1.027]** |
| Lasso | 24 | 5.926 | 5.927 | 4.055 | 4.031 | 0.994 [0.988, 1.004] |
| | 168 / 744 | intercept only | = B0 | 5.266 / 4.330 | = B0 | 1.000 |
| | 336 | 8.013 | 7.961 | 5.102 | 5.389 | **1.056 [1.015, 1.133]** |
| Elastic net | 24 | 5.925 | 5.924 | 4.059 | 4.032 | 0.993 [0.986, 1.004] |
| | 168 / 744 | intercept only | = B0 | 5.266 / 4.330 | = B0 | 1.000 |
| | 336 | 8.014 | 7.964 | 5.102 | 5.387 | **1.056 [1.015, 1.133]** |
| *Seasonal naive* | 24 / 168 / 336 / 744 | 6.66 / 10.48 / 11.45 / 9.32 | | 4.22 / 6.40 / 7.10 / 6.38 | | |
| *Climatology* | 24 / 168 / 336 / 744 | 7.26 / 7.39 / 8.21 / 6.19 | | 5.02 / 5.17 / 4.90 / 3.97 | | |

Bold: the 95% interval excludes 1 (ridge at h = 336 only just: lower bound 1.001). The significant results are stable across seeds: at h = 168, 0/5 seeds favour B1 on test for all three tree families; at h = 744, 5/5 do. At h = 24 the seeds favour B1 on validation 5/5 for every tree family, but on test only 0/5 (LightGBM), 4/5 (CatBoost) and 5/5 (XGBoost).

**Validation-selected PM2.5 model per horizon (Stages A/B):**

| h | Validation winner | Val MAE | Test MAE | Test, seasonal naive / climatology |
|---|---|---|---|---|
| 24 | XGBoost B1 | 5.668 | 4.207 | 4.215 / 5.019 |
| 168 | Elastic net (intercept only; B0 = B1) | 7.270 | 5.266 | 6.399 / 5.173 |
| 336 | Lasso B1 | 7.961 | 5.389 | 7.103 / 4.900 |
| 744 | Ridge / lasso / elastic net (intercept only) | 6.154 | 4.33–4.41 | 6.383 / 3.967 |

At h = 24 the validation winner merely ties seasonal naive on test. The lowest test MAE at h = 24 is ridge B1 (3.867, MASE 0.940), but ridge ranks last on validation, so it could not have been chosen. Validation and test rank the families differently at every horizon. Test MAE is 25–40% below validation MAE for every model, because the test block is easier: 40–52% fill, and lower monsoon concentrations.

## 6. Overfitting and stability of the extra pollutant features

`report/GENERALISATION_GAP.csv`, `report/SEED_SUMMARY.csv`:

- At h = 24, B1 trees fit train much more closely than B0 (LightGBM train MAE 2.37 against 3.03; validation/train ratio 2.41 against 1.94). They also use more boosting rounds (LightGBM 267 against 51, CatBoost 352 against 262), but gain only 3–4% on validation and nothing on test. The extra 120 columns mostly add capacity.
- At h ≥ 168 every early-stopped tree uses 4–37 rounds at learning rate 0.05, which is a heavily shrunk, near-constant forecast. The small validation/test differences between B0 and B1 there are differences in how they deviate from a constant.
- The seed SD of test MAE is larger for B1 than for B0 in 11 of the 12 tree-family × horizon cells, by up to about 6× (for example XGBoost h = 336: 0.140 against 0.055; LightGBM h = 168: 0.046 against 0.008). Extra inputs make the fitted function less stable.

## 7. Which pollutants contribute (Q4)

Share of B1 importance (refit models, mean of seeds; `IMPORTANCE_BY_POLLUTANT.csv`):

| | h = 24 | 168 | 336 | 744 |
|---|---|---|---|---|
| LightGBM: PM2.5 / PM10 / SO2 / CO | 33 / 33 / 18 / 10% | 6 / 20 / 56 / 14% | 9 / 14 / 51 / 17% | 4 / 21 / 34 / 9% (NO2 22%) |
| Ridge, \|standardised coefficient\|: PM2.5 / PM10 / SO2 / CO | 28 / 21 / 15 / 24% | 25 / 23 / 33 / 15% | 22 / 17 / 37 / 17% | 30 / 27 / 19 / 18% |

Pollutant ablations (LightGBM with the B1 configuration, then a small validation re-tune; `FEATSEL_COMPARISON.csv`). Validation MAE relative to B0 (adding one pollutant) or to B1 (dropping one):

| h | Best single addition to B0 (val) | Most harmful removal from B1 (val) | Removal that helps most (val) |
|---|---|---|---|
| 24 | +O3: −1.6% | −PM2.5: +2.5% | −PM10: −0.2% |
| 168 | +O3: −0.2% | −SO2: +0.8% | −PM2.5: −0.3% |
| 336 | +CO: −3.0% | −SO2: +1.5% | −O3: −4.5% |
| 744 | +PM10: −0.9% | −PM10: +0.3% | −CO: −0.4% |

All effects are within about ±4.5% on validation. On test they frequently reverse. Removing SO2 at h = 336 hurts validation by 1.5% but improves test by 6.4% (0.936 [0.873, 0.975]). Adding O3 at h = 24 helps validation 1.6% and test 4.2%, but removing O3 from B1 at h = 336 helps validation and hurts test. **No pollutant is a robust source of information across horizons and blocks.** PM10 and CO are the most consistently used. The large SO2 share at h = 168 and 336 is best read as the tree latching onto a slowly varying level indicator that does not generalise across seasons.

## 8. Stage C: feature selection and dimensionality reduction (Q5)

**Why these methods.** Stage A/B showed (i) a growing train/validation gap for B1, (ii) gain concentrated in 2–3 pollutants, and (iii) 24 highly collinear lags per pollutant (the first principal component of the 144 standardised lags explains 34–36% of the variance and 16 components about 80%, `FEATSEL_PCA_VARIANCE.csv`). That justifies relevance filters (correlation, MI), embedded selection (elastic-net non-zeros), wrapper selection (RFE), pollutant-group ablations, and projections (PCA, PLS) for both trees and linear learners. Each transform is fitted on the fitting rows only. Its size (k, number of components, penalty) is chosen on validation and frozen for the refit.

Validation-selected variant per horizon, against B1 with all 144 lags (LightGBM), test paired:

| h | Selected on validation | Inputs | Val ratio | Test ratio [95% CI] |
|---|---|---|---|---|
| 24 | correlation top-k | 48 | 0.992 | 0.995 [0.941, 1.060] |
| 168 | B1 − PM2.5 | 120 | 0.997 | 1.014 [0.995, 1.034] |
| 336 | PLS scores + LightGBM | 16 | 0.923 | **1.087 [1.044, 1.155]** |
| 744 | MI top-k | 24 | 0.992 | **1.046 [1.015, 1.093]** |

Other observations:

- RFE (dropping the lowest-gain 20% per step, `FEATSEL_RFE_PATH.csv`, `plots/rfe_path.png`) keeps all 144 inputs at h = 24 and 168. At h = 336 and 744 it picks 32 and 14 inputs, with test ratios 1.004 and 1.006.
- Elastic-net selection keeps 11, 4, 3 and 1 inputs. The kept set changes when refitted on train + validation (Jaccard 0.50, 0.25, 0.14, 1.00). Selection is unstable and driven by the λ that validation picked.
- Unpenalised PCR and PLS regression look good on test at h = 24 (0.874 and 0.885 against B1 LightGBM) but rank last on validation. They are 6–21% worse than B1 on test at h ≥ 168, and 49–58% worse than B1 on validation at h = 744, because they cannot shrink to the mean.

**Conclusion:** none of the six approaches improves generalisation in a way that validation could have detected. The full 144-lag B1 is not the problem. The lagged inputs carry little forecastable signal beyond the target's own level at h ≥ 168.

## 9. Six target pollutants: separate vs shared (Q6)

Designs (LightGBM; grid num_leaves {7, 15, 31} × min_data_in_leaf {20, 100}; 5 seeds; `targets/`):

- **separate_B0 / separate_B1:** one model per target, raw units.
- **pooled_B1_own:** one model for all six targets. Inputs are a categorical target id, the target's own 24 lags in a fixed slot, and all 144 lags. Inputs and target are standardised per pollutant with train-block statistics. Early stopping and selection use pooled validation error in standardised units (equal weight per target). Forecasts are mapped back to original units for scoring.
- **pooled_B1:** the same without the own-lag slot. **pooled_B0:** target id plus own lags only.

Every pooled row keeps its own target pollutant and target timestamp. Tests P07 and P08 check alignment, train-only scaling, absence of future inputs and test-label isolation.

Mean MASE over the six targets (`TARGETS_SUMMARY.csv`):

| h | Val: sep B0 | sep B1 | pooled B0 | pooled B1 | pooled B1+own | Test: sep B0 | sep B1 | pooled B0 | pooled B1 | pooled B1+own |
|---|---|---|---|---|---|---|---|---|---|---|
| 24 | 1.596 | **1.193** | 1.228 | 1.386 | 1.229 | 1.260 | 1.280 | **1.187** | 1.274 | 1.210 |
| 168 | 2.068 | **1.886** | 2.029 | 2.031 | 2.006 | **1.772** | 1.842 | 1.798 | 1.894 | 1.859 |
| 336 | 1.976 | **1.852** | 1.956 | 2.092 | 2.107 | 1.753 | 1.796 | **1.733** | 1.818 | 1.794 |
| 744 | 1.544 | **1.528** | 1.816 | 1.879 | 1.814 | 1.507 | 1.471 | 1.472 | 1.485 | **1.406** |

Paired comparisons over 24 target × horizon cells, counting cells whose 95% CI excludes 1 (`TARGETS_PAIRED.csv`):

| Comparison | Validation: better / worse | Test: better / worse |
|---|---|---|
| Separate B1 vs separate B0 | 6 / 2 | 4 / 4 |
| Shared B1 + own vs separate B1 | 0 / 16 | 5 / 7 |
| Shared B1 vs separate B1 | 0 / 16 | 1 / 13 |
| Shared B0 vs separate B0 | 4 / 10 | 5 / 5 |

- The own-lag slot is necessary for a shared multivariate model: without it, shared B1 is worse than separate B1 in 13/24 test cells.
- Shared models hurt NO2 at every horizon (test ratios against separate 1.16–1.63) and help SO2 at h = 744 (0.70). Per-target scaling cannot fully remove the differences in dynamics between pollutants.
- Separate B1 beats separate B0 on validation for most targets, but on test that is balanced (4 better, 4 worse). The PM2.5 conclusions generalise to the other pollutants.

Recommendation: keep **separate target-specific models**. Validation consistently prefers them, and the shared model's test gains are confined to a few cells and not detected on validation.

## 10. Uncertainty intervals and block length

Paired comparisons use the loss differential d_t = |e_B1,t| − |e_B0,t| on identical target timestamps, ordered by origin. Intervals are 95% moving-block bootstrap percentiles (999 replicates, seed 7) of the MAE ratio and difference. A Diebold–Mariano test with a Newey–West variance (Harvey–Leybourne–Newbold correction) is reported alongside.

**Block length** is chosen per comparison from the data, not fixed:

1. The Politis–White (2004) automatic block length, with the Patton–Politis–White (2009) correction, is estimated on d_t itself. That is the series whose dependence the bootstrap must preserve.
2. It is floored at 24 h, so a block always spans a full diurnal cycle.
3. It is capped so that at least 5 blocks fit in the sample (n/5).

The estimates came out at 24–100 h. None hit the cap. They do not grow with h, because d_t decorrelates much faster than the h − 1 overlap of the forecast windows would suggest. Since overlap theory argues for blocks up to h, every primary comparison also reports intervals at fixed blocks of 24, 168, 336 and 744 h (`ratio_lo_b*`, `ratio_hi_b*` in `PAIRED_B1_VS_B0.csv`). Every significant tree result at h = 168 and 744 stays significant at all four. At h = 744 the 744-h block leaves only 2 blocks in the test sample, so those intervals are too coarse to trust. **Effective sample size at long horizons is small:** the h = 744 test spans only about two non-overlapping monthly windows, and conclusions there rest on one test season.

## 11. Constant-fill influence (Q7)

Test MAE, PM2.5, LightGBM seed mean (`MODEL_METRICS.csv`; "clean" = neither the target nor any input hour is fill):

| h | Group | n | B0 | B1 | Seasonal naive | Climatology |
|---|---|---|---|---|---|---|
| 24 | all (primary) | 2,208 | 4.336 | 4.476 | 4.215 | 5.019 |
| | constant-fill targets | 936 | 0.998 | 0.604 | 0.468 | 1.697 |
| | non-fill targets | 1,272 | 6.792 | 7.326 | 6.973 | 7.464 |
| | clean | 1,131 | 6.619 | 7.274 | 6.826 | 7.389 |
| 744 | all (primary) | 1,488 | 4.565 | 4.288 | 6.383 | 3.967 |
| | constant-fill targets | 768 | 2.293 | 2.177 | 2.203 | 1.697 |
| | non-fill targets | 720 | 6.989 | 6.539 | 10.841 | 6.388 |

B1/B0 test ratio by group, all families (`PAIRED_B1_VS_B0.csv`):

| h | Fill targets | Non-fill targets |
|---|---|---|
| 24 | 0.52–0.73 for trees and ridge (B1 recognises the freeze); about 1.01 for lasso/EN | 0.99–1.08 |
| 168 | 1.05–1.31 (B1 worse) | 0.99–1.02 |
| 336 | 1.03–1.27 | 1.00–1.02 |
| 744 | 0.95–1.02 | 0.94–1.01 (trees 0.936–0.955, CIs below 1) |

Seasonal naive is exact inside a fill block at h = 24, so it has the best unmasked test MAE among the references there. That makes the unmasked h = 24 ranking largely a ranking of fill-state recognition. Climatology's fill-target error is constant across horizons (1.697), because the fill vector sits close to the series mean.

## 12. Deviations and limitations

1. Stage C tree variants start from the Stage A B1 LightGBM configuration and re-tune only num_leaves × min_data_in_leaf at the chosen k. A full re-tune per variant was not run.
2. The six-target stage uses LightGBM only, with a reduced 6-configuration grid. Stage A/B showed no family that is consistently better on validation, and LightGBM is about 20× faster than CatBoost.
3. Pooled scaling statistics come from train-block hours and are not refitted on train + validation. This is a fixed affine map; it is harmless for trees and keeps the units stable across fits.
4. Selection uses validation MAE, while early stopping and boosting objectives use squared error. This is the same for every design.
5. Feature-selection transforms are refitted on train + validation for the final model with k or λ frozen, as Phase 1 did with the standardiser. RFE is the exception: its column set is frozen from the train-only path.
6. One split (S3) and one station. The test block is a single April–July season with 40–52% fill, and validation/test rankings disagree throughout. Every test-level claim here rests on one season.

## 13. Remaining experiments

- **Not run (out of scope by instruction):** ID1, Shillong, Delhi; B2 (decomposition inputs); recursive and hybrid strategies; deep learning.
- **Recommended next:**
  - A secondary analysis with the Phase 0 quality mask, clearly labelled, because the unmasked h = 24 comparison is dominated by fill recognition.
  - Rolling-origin evaluation (several validation/test folds), to separate model effects from the single-season test.
  - Calendar and seasonal features (hour, day of week, month), plus a climatology-anchored target (forecast the deviation from climatology), because the models have no skill over climatology at h ≥ 168.
  - Retesting the B0/B1 question once those exist.
  - Repeating the separate-vs-shared comparison with CatBoost if a slower but stronger shared learner is wanted.

## 14. Reproduction

From the project root, R 4.5.2 (`C:/Program Files/R/R-4.5.2/bin/Rscript`). Use script files; `Rscript -e` segfaults with arrow on this machine.

```bash
Rscript run_mv_experiments.R --stage=check                       # 22 Phase 1 + 18 Phase 2 tests, counts, hashes (23 s)
Rscript run_mv_experiments.R --stage=smoke                       # Phase 1 config at 4 horizons (6 s)
Rscript run_mv_experiments.R --stage=model --family=lightgbm     # Stage A (59 s)
for f in xgboost catboost ridge lasso elasticnet; do              # Stage B, parallel processes (7.7 min; CatBoost is the long pole)
  Rscript run_mv_experiments.R --stage=model --family=$f & done; wait
for h in 24 168 336 744; do                                      # Stage C, needs Stage A + elastic net (2.9 min)
  Rscript run_mv_experiments.R --stage=featsel --horizons=$h & done; wait
for h in 24 168 336 744; do                                      # six targets, separate vs shared (3.5 min)
  Rscript run_mv_experiments.R --stage=targets --horizons=$h & done; wait
Rscript run_mv_experiments.R --stage=report                      # tables, paired bootstrap, plots (12.5 min)
```

Total wall time on a 16-core Windows machine: about 28 minutes. Every model runs single-threaded. Every stage writes `RUN_METADATA.json` with package versions (R 4.5.2, lightgbm 4.7.0, xgboost 3.2.1.1, catboost 1.2.8, glmnet 5.2, pls 2.9.0, arrow 26.0.0, data.table 1.18.0, ggplot2 4.0.1), the git commit, and SHA-256 hashes of the configs and code. Each stage except `check` refuses to run until `check/CHECK_PASSED` exists.

## 15. Artifact index (`results/multivariate/phase2/`)

| Path | Content |
|---|---|
| `check/` | Test summaries for both suites, `SAMPLE_COUNTS_UNMASKED.csv`, `DATASET_HASHES.csv`, `CONSTANT_FILL_RUNS.csv` |
| `smoke/` | Phase 1 configuration at all four horizons, Phase 1 reproduction check |
| `models/<family>/` | `TUNING.csv` (every candidate), `SELECTED.csv`, `RUNS.csv` (per seed), `METRICS.csv`, `IMPORTANCE.csv`, `predictions.rds` |
| `featsel/h<h>/` | Transform tuning, re-tune, RFE path, selected features (selection vs refit), PCA variance and loadings, predictions |
| `targets/h<h>/` | Tuning, runs and predictions for separate and pooled models |
| `report/` | `MODEL_METRICS.csv` (all groups), `HORIZON_COMPARISON_B0_B1.csv`, `PAIRED_B1_VS_B0.csv` (+ per seed), `PAIRED_VS_REFERENCES.csv`, `GENERALISATION_GAP.csv`, `SEED_SUMMARY.csv`, `IMPORTANCE_BY_POLLUTANT.csv` / `_BY_LAG.csv`, `FEATSEL_*.csv`, `TARGETS_*.csv` |
| `report/plots/` | `val_test_mae_by_horizon.png`, `paired_ratio_b1_b0.png`, `paired_diff_per_seed.png`, `test_mae_by_fill_group.png`, `importance_by_pollutant.png`, `featsel_ratio_vs_b1.png`, `rfe_path.png`, `pca_cumulative_variance.png`, `targets_test_mase.png` |
| `run_log.txt`, `*.log` | Stage logs |
