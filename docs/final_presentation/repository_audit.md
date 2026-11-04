# Comprehensive Repository Audit

**Scope:** Read-only audit of saved repository code, configurations, logs, reports and result artifacts.  
**No new experiments were run and no existing experiment pipeline files were modified.**

## 1. Executive summary

This project forecasts hourly air quality and compares raw, multivariate, decomposed, component-wise and recursive forecasting approaches across CPCB Delhi-style data and two Shillong CAAQMS stations.

### Project evolution
1. A paper-oriented CPCB recursive WaveCatBoost bake-off was implemented, but a repository audit found leak and protocol limitations in its `scores.csv` and paper-protocol notebook paths.
2. A causal Phase 1a preprocessing/store pipeline was added for hourly data and applied to CPCB and Shillong.
3. CPCB raw B0/B1 direct fixed-horizon experiments compared PM2.5 univariate lags with six-pollutant lags.
4. CPCB Phase 2 extended this to six model families, pollutant ablations, feature selection/dimensionality reduction and separate/shared targets.
5. A full Shillong architecture study compared undecomposed A*, decomposed B*, and intercomponent/cross-pollutant C* models with direct fixed horizons and multiple families.
6. A second-stage Shillong extension module for PCA and direct/recursive/hybrid comparison was created, but saved evidence currently contains tests only; the run and report stages were not completed.
7. The proposed PCA and direct/recursive/hybrid final experiment remains proposed or partial at the implementation-test stage, not a completed numerical study.

## 2. Repository structure

| Area | Purpose |
|---|---|
| `R/00_packages.R`–`R/09_hparams.R` | Legacy paper-oriented data, preprocessing, MODWT/MRA, models, metrics, conformal and tuning |
| `R/20_ingest.R`–`R/23_store_clean.R` | CAAQMS/CPCB ingestion, quality masks, causal imputation and clean stores |
| `R/30_decomp_registry.R`–`R/35_decomp_io.R` | Decomposition registry, causal/trailing implementations and artifacts |
| `R/40_mv_data.R`–`R/49_mv_stages.R` | CPCB Phase 1/2 multivariate datasets, features, families, evaluation and orchestration |
| `R/50_sh_data.R`–`R/55_sh_report.R` | Shillong data/panel, features, experiments, stages and reporting |
| `R/60_ss_core.R`–`R/62_ss_report.R` | Second-stage PCA/strategy implementation and reporting |
| `run_experiments.R`, `run_paper_protocol.R`, `run_conformal.R` | Legacy/reproduction CPCB experiments and conformity calculations |
| `run_preprocess.R`, `run_decomp.R` | Causal store/decomposition entry points |
| `run_multivariate.R`, `run_mv_experiments.R` | CPCB raw multivariate phases |
| `run_shillong_arch.R` | Shillong architecture study |
| `run_second_stage.R` | Uncompleted PCA/direct/recursive/hybrid extension |
| `data/raw/`, `data/processed/` | Raw and intermediate datasets |
| `store/clean/`, `store/shillong/clean/` | Prepared hourly stores |
| `store/shillong/quality/`, `store/quality/` | Imputation-quality artifacts |
| `results/multivariate/` | CPCB multivariate audits, manifests and numerical results |
| `results/shillong_arch/` | Shillong full architecture study |
| `results/second_stage/` | Extension tests and incomplete module evidence |
| `modwt_report/` | MODWT methodology notes, figures and LaTeX tables |
| `audit/` | Legacy implementation leak/control audit |
| `tests/` | Multivariate, Shillong and second-stage invariants |

## 3. Data and preprocessing

### CPCB paper/hourly data
- Source: `data/raw/CPCB.csv` and `ID1.csv` are reported as end-labelled hourly paper datasets.
- Modelling store: `store/clean/series.parquet`; PM2.5 range 0.280–66.80 µg/m³, median 11.884 µg/m³; source PM2.5/PM10/NO2/SO2/O3 plus CO.
- No quality masking/imputation is applied to the paper CPCB CSV by `config/preprocess.yaml`.
- Aligned period: 2022-07-01 00:00 through 2023-07-05 23:00, 8,880 hourly rows.
- The multivariate unmasked Phase 1/2 studies intentionally retain 2,304 upstream constant-filled observations documented by Phase 0.
- CPCB/ID1 decomposition stores were not available at the time of the Phase 0 audit; leakage-safe trailing calculation was verified by sampled recomputation.

### Shillong
- `data/raw/shillong/shillong_15min_2023.parquet` contains 35,040 start-labelled 15-minute rows per station for 2023.
- Phase 1a shifts start-labelled intervals, then labels hour `t` with the mean of the end-contained slots `(t-1h,t]`.
- An hour needs at least 75% valid 15-minute coverage (`min_subhour_coverage = 0.75`).
- Result: 8,760 end-labelled hours per station/variable from 2023-01-01 01:00 to 2024-01-01 00:00.
- Quality masks include negatives, bounds, six-hour frozen runs, low coverage and PM2.5/PM10 ratio `>1.1`. Masked hours are filled causally; targets are scored only when observed and unmasked.
- Lumpyngngad: PM2.5 masked 1,955 hours; PM10 4,296; NO2 2,284; O3 609. PM10 is retained/dropped depending on station availability rules, NO2 is dropped due to late availability, O3 is explicitly excluded because of a sensor/calibration regime jump of about 0.6–1.0 to 47 µg/m³ near the test block.
- JN Stadium: data reporting begins 2023-07-26/PM2.5 starts 2023-07-27 12:00; roughly 4,950 pre-reporting hours are missing. It has only July–December usable history.

## 4. Train/validation/test protocols

### CPCB raw multivariate Phase 2
- Source configuration: `config/multivariate.yaml`, `config/multivariate_experiments.yaml`.
- Split: train 2022-09-24 07:00–2023-01-31 23:00; validation 2023-02-01–2023-04-03; test 2023-04-04–2023-07-05.
- Horizons: 24, 168, 336 and 744 hours.
- Direct fixed-horizon: one model predicts `PM2.5(t+h)` from lags at origin `t`.
- Lookback: 24 hours; values at `t` through `t-23`.
- B0: PM2.5 only (24 features). B1: PM2.5, PM10, NO2, SO2, O3 and CO (144 features).
- Same target timestamps and origins for B0/B1; no quality exclusion.
- Validation selects configuration and early stopping/penalty. Final fit uses train + validation, freezes the selected iteration count/λ, then predicts test once.

### Shillong architecture study
- Lumpyngngad train 2023-01-01 01:00–2023-07-31 23:00; validation August–September; test October–2024-01-01 00:00.
- JN Stadium train 2023-07-28–September; validation October; test November–2024-01-01.
- One origin/sample is scored only if the target hour is unmasked and the origin policy passes.
- All 14 architecture feature sets use identical target timestamps within station/horizon.
- Direct fixed-horizon models only: `ŷ(t+h)=f_h(X_t)`.
- Validation chooses architecture/family/configuration and is therefore optimistic; test is reported as the unbiased estimate.

## 5. Decomposition

### Shillong causal Haar MODWT/MRA
- Implementation: `R/31_decomp_causal.R`, `decomp_coef_haar`.
- Additive pyramid: `x = D1 + ... + D5 + S5`, with `J=5`.
- D1 2–4 h, D2 4–8 h, D3 8–16 h, D4 16–32 h, D5 32–64 h and S5 >64 h.
- Uses a causal filter/state without future observations at the origin. Low warm-up requirement is reported as 31 hours relative to the five-level filter.
- Test/check code verifies reconstruction and separate/shared component handling.

### CPCB trailing-window MRA
- Separate implementation in `R/32_decomp_trailing.R`: `decomp_mra_haar`, 2,048-hour trailing window, `J=5`.
- Each component at `t` comes from the last-window MRA endpoint. It is causal because values after `t` are excluded, but circular wrap causes the endpoint to depend on the 31 most recent and 31 oldest hours of the window.
- Additivity was verified to approximately 1e-14; warm-up is 2,047 rows and the first valid component is 2022-09-24 07:00.
- The CPCB trailing implementation and Shillong causal implementation are not equivalent and must not be conflated.

## 6. Architecture inventory

| ID | Raw/decomp | Structure | Variables | Covariates | Status |
|---|---|---|---|---|---|
| A0 | Raw | PM2.5 lags only, one model | 24 lags | No | Completed |
| A1 | Raw | PM2.5 lags + origin covariates/calendar | 24 + covariates | Yes | Completed |
| A2 | Raw | All used pollutant lags | 72 Lumpyngngad / 120 JN | No | Completed |
| A3 | Raw | A2 + origin covariates/calendar | 79 / 130 | Yes | Completed |
| B0 | Decomp | Separate component model; own component lags | 24 | No | Completed |
| B1 | Decomp | Shared component model; own slot + component ID | 25 | No | Completed |
| B2 | Decomp | Separate component own lags + covariates | 31 / 34 | Yes | Completed |
| B3 | Decomp | Shared component + component ID + covariates | 32 / 35 | Yes | Completed |
| C1_sep | Decomp | Separate target component models with target-pyramid intercomponent lags | 144 | No | Completed |
| C1_sh | Decomp | Shared target component model with intercomponent lags | 169 shared features | No | Completed |
| C2_sep | Decomp | Separate models using all components of all used pollutants | 432 Lumpyngngad / 720 JN | No | Completed |
| C2_sh | Decomp | Shared cross-pollutant component model | +25 shared slot | No | Completed |
| C3_sep | Decomp | C2_sep + covariates | 439 / 730 | Yes | Completed |
| C3_sh | Decomp | C2_sh + covariates | + covariates | Yes | Completed |

CPCB B0/B1 names mean raw, not decomposed, designs in the Phase 1/2 CPCB studies. This differs from the Shillong B0/B1 decomposition labels. Legacy `B2`/`B3` also belong to the original CPCB decomposition discussion, not the Phase 1/2 raw report.

## 7. Models and training

Completed model families:
- **LightGBM:** stage-one Shillong model; learning rate 0.05, num iterations up to 2,000, 100-round early stopping; grid leaves/min-data-in-leaf.
- **LightGBM/XGBoost/CatBoost/ridge/lasso/elastic net:** CPCB and Shillong family studies.
- **XGBoost:** eta 0.05, subsample/colsample 0.8, up to 2,000/3,000 rounds depending study; validation grid/early stopping.
- **CatBoost:** learning rate 0.05, depth/l2 grids, early stopping.
- **Ridge/Lasso/Elastic Net:** standardised features, train-fitted transforms, validation-selected λ; elastic-net grids include α 0.1/0.5/0.9.
- **ARIMA/SARIMA and WaveSARIMA:** present in legacy paper-oriented CPCB code/results, but they should not be merged with direct fixed-horizon Phase 1/2 findings.
- **DLinear/OLS:** supported in some multivariate/model utilities and papers; no evidence indicates it was a major completed benchmark in the audited numerical reports.

## 8. Forecast strategies

- **Direct fixed horizon:** CPCB Phase 1/2 and the full Shillong architecture study. One model per horizon; no recursive feedback.
- **Legacy CPCB recursive:** `run_experiments.R`/Wave notebooks calculate nested or recursive multi-step outputs from an origin. These scores are protocol-specific and are identified as affected by test leakage/hyperparameter overlap/circular MRA limitations.
- **Hybrid/recursive extension:** implemented in `R/60_ss_core.R` and tests only. Numerical run artifacts are absent from `results/second_stage`.
- **PCA:** code/tests exist in the second-stage extension, using a train-fitted PCA; no completed numerical PCA strategy results are saved in this extension.

## 9. Key numerical results

### CPCB Phase 2 B0/B1, seed means
The `report/HORIZON_COMPARISON_B0_B1.csv` file is the authoritative detailed table. Headline PM2.5 test MAE:

| Horizon | B0 test MAE | B1 test MAE | Notable result |
|---|---:|---:|---|
| 24 | Family-dependent | Family-dependent | XGBoost B1 validation winner 5.668; test MAE 4.207 |
| 168 | 5.266–5.346 typical | 5.281–5.720 typical | Tree B1 harms at 168; elastic net intercept-only |
| 336 | 5.102–5.825 | 5.183–5.956 | Mixed; validation Lasso B1 but test 5.389 |
| 744 | 4.330–4.565 | 4.288–4.409 | Trees benefit at 744, linear models mostly intercept-only/flat |

At h=744, LightGBM, XGBoost and CatBoost B1/B0 ratios are below 1 (0.939/0.960/0.954 respectively with bootstrap intervals excluding 1 in the saved report). At h=168 the same three ratios are significantly above 1. The smallest validation/test evidence and climatology comparisons are retained in `results/multivariate/phase2/report/`.

### Shillong Lumpyngngad PM2.5
LightGBM test MAE in µg/m³:

| Horizon | A0 | A2 | A3 | B0 | C2_sep | Persistence | A2 MASE |
|---|---:|---:|---:|---:|---:|---:|---:|
| 24 | 9.84 | 9.11 | 9.04 | 10.38 | 9.54 | 10.03 | 0.54 |
| 168 | 15.64 | 10.94 | 10.82 | 14.21 | 10.45 | 13.28 | 0.65 |
| 336 | 16.82 | 12.29 | 12.51 | 16.09 | 13.90 | 15.70 | 0.73 |
| 744 | 13.10 | 11.42 | 12.31 | 15.69 | 13.06 | 14.65 | 0.68 |

A2 significantly beats A0 at every Lumpyngngad horizon in paired test MAE. The ratio A2/A0 was 0.93, 0.70, 0.73 and 0.87 at 24/168/336/744 h.

### Shillong JN Stadium PM2.5
Test MAE:

| Horizon | A0 | A1 | A2 | A3 | B0 | C2_sh | Persistence |
|---|---:|---:|---:|---:|---:|---:|---:|
| 24 | 23.77 | 21.43 | 23.88 | 23.28 | 22.97 | 21.62 | 21.57 |
| 168 | 32.14 | 25.82 | 33.19 | 31.54 | 32.79 | 33.08 | 28.92 |
| 336 | 30.56 | 29.04 | 27.32 | 26.93 | 31.96 | 26.30 | 33.37 |
| 744 | 32.20 | 34.13 | 30.56 | 30.03 | 33.69 | 30.73 | 29.92 |

No architecture is reliably better than A0 at all horizons. JN MASE is 2.5–4.1 because the training scale is 8.49 µg/m³ and the November–December test season is substantially higher.

## 10. Results files and provenance
- Shillong main report: `results/shillong_arch/REPORT.md`
- Shillong level/component/family tables: `results/shillong_arch/report/*.csv`
- Bootstrap/paired comparisons: `results/shillong_arch/report/PAIRED_COMPARISONS.csv`
- CPCB Phase 2 report: `results/multivariate/phase2/REPORT.md`
- CPCB model/horizon/feature-selection tables: `results/multivariate/phase2/report/*.csv`
- CPCB Phase 1 smoke/results: `results/multivariate/phase1/`
- Legacy scores and audit: `results/scores.csv`, `audit/AUDIT.md`
- Phase 0 decomposition/causality audit: `results/multivariate/phase0/`

## 11. Metrics and uncertainty
- MAE: mean absolute target error in original concentration units.
- RMSE: square root of mean squared target error.
- MASE: MAE divided by training-block seasonal-naive MAE.
- CPCB PM2.5 Phase 2 seasonal-naive denominator: 4.1124 µg/m³.
- Lumpyngngad PM2.5 seasonal-naive denominator: 16.88 µg/m³.
- JN Stadium PM2.5 denominator: 8.49 µg/m³.
- Persistence equals seasonal-naive for horizons that are multiples of 24 in the studied protocols.
- Climatology and hour-of-day climatology are stored as benchmark references.
- Shillong paired comparisons use 999 moving-block bootstrap replicates with data-driven block length and report ratios/differences and 95% intervals.
- CPCB Phase 2 similarly reports moving-block bootstrap intervals and seed summaries.
- Conformal prediction is not verified as part of the audited completed direct studies. The legacy conformal implementation has known limitations and low/invalid coverage in the repository audit; it must not be presented as conformal evidence for these main studies.

## 12. Scientific findings

### Strong findings
- At Lumpyngngad, A2/A3 multivariate lag models materially improve over raw PM2.5 lags at every horizon.
- Decomposition does not improve the Lumpyngngad level forecast over strong raw multivariate models.
- Separate component models generally outperform shared models for reconstructed level, although shared models can improve some components.
- Other pollutant lags provide little reliable benefit in CPCB B0/B1 raw Phase 2; only trees show horizon-specific small gains.

### Weak/mixed findings
- Covariates help some JN forecasts but hurt Lumpyngngad long horizons.
- Separate/shared decomposed comparisons vary by horizon and station.
- Feature-selection and PCA/PCR methods do not improve CPCB B1 validation/test generalisation.
- Other pollutant targets show station/horizon-specific mixed behavior.

### Negative findings
- Long-horizon CPCB raw models have no robust skill over climatology/constant-level behavior.
- Decomposition is not a universal improvement.
- The old legacy recursive/paper-protocol CPCB scores are affected by circular decomposition, origin overlap or leakage and should not be presented as a valid reproduction.

### Inconclusive
- JN cross-pollutant effects are not consistent enough to generalise.
- Direct/recursive/hybrid comparison is not numerically completed.
- A causal/decomposed CPCB product store and preprocessed-clipped experiments remain incomplete in Phase 0 artifacts.

## 13. Limitations and unfinished work

### Completed
- Causal Shillong preprocessing and architecture study.
- CPCB Phase 1/2 raw B0/B1 direct experiments.
- CPCB Phase 0 data/decomposition audits and leak checks.
- Legacy CPCB recursive bake-off artifacts, with known protocol limitations documented rather than treated as trustworthy reproduction.
- Second-stage validation/stability tests for PCA/recursive/hybrid code.

### Partially completed
- Legacies of WaveCatBoost, conformal, paper-protocol and MCB outputs contain results but fail documented audit invariants.
- Second-stage code has tests but no numerical run/report output.
- Other-pollutant and feature family results exist, but some studies lack comparable complete coverage across all family/architecture cells.

### Proposed/not run
- New final direct/recursive/hybrid controlled comparison.
- PCA + direct/recursive/hybrid full numerical experiment.
- CPCB isolated preprocessed/clipped experiment, if not represented by `store/clean` and raw Phase 2 artifacts.
- A final unified cross-dataset robust comparison.

### Remaining implementation gaps
- Production-ready rolling-origin evaluation.
- Multi-year or multi-station data coverage.
- Alternative decomposition levels/methods beyond the completed studies.
- Deep learning and transformers.
- Conformal prediction based on clean held-out calibration.
- External meteorological forecasts.
- Cross-station transfer/generalisation.

## 14. Figures and visualisations

| Artifact | Displayed content | Suitability |
|---|---|---|
| `results/shillong_arch/report/plots/best_by_horizon.png` | Best architecture/results by station/horizon | Final PPT |
| `level_mase_by_arch.png` | MASE comparison by architecture | Final PPT |
| `paired_ratios.png` | Bootstrap paired ratios | Final PPT |
| `ratio_vs_A0_heatmap.png` | Architecture gains/losses relative to A0 | Final PPT |
| `component_mase.png` | Component-level performance | Appendix/technical slide |
| `results/multivariate/phase2/report/plots/targets_test_mase.png` | CPCB target/horizon MASE | Final PPT |
| `val_test_mae_by_horizon.png` | Validation/test divergence | Final PPT |
| `pca_cumulative_variance.png` | PCA variance | Appendix |
| `featsel_ratio_vs_b1.png` | Feature-selection comparison | Appendix |
| `results/shillong/` | Raw Shillong time-series, coverage and decomposition plots | Final data-methodology narrative |
| `assets/` | MODWT equations, conceptual diagrams and MRA illustrations | Appendix or methodology slides |

## 15. Presentation-ready methodology

- **Hourly forecasting:** predict a pollutant concentration `h` hours ahead from a fixed origin using only observations available at that origin.
- **Causal preprocessing:** mask invalid/stuck/low-quality readings, then fill only from past information. Test targets remain observed/unmasked hours.
- **Multivariate forecasting:** build lag matrices for several pollutants to allow cross-pollutant dependencies.
- **Haar MODWT/MRA:** decompose a series into scale bands and sum component forecasts back to level.
- **Component-wise forecasting:** separate component models can tune model type/hyperparameters per scale; shared models pool component rows with an identity slot.
- **LightGBM:** histogram-gradient boosted trees capture nonlinear interactions and pollutant lag relationships.
- **XGBoost/CatBoost:** alternative gradient-boosted trees with regularised tree and categorical handling.
- **Ridge/Lasso/Elastic Net:** linear shrinkage baselines; they either stabilise correlated lags or remove weak coefficients.
- **Direct forecast:** lower cumulative error risk than recursive feedback, at the cost of one fit per horizon.
- **Recursive forecast:** repeats a one-step prediction and feeds it back; no completed controlled result is available in the current audit.
- **MASE:** concentration-scale-independent comparison against a 24-hour seasonal-naive denominator.
- **Bootstrap/DM:** assesses uncertainty in paired differences; it is not a future prediction interval or conformal interval.

## 16. Likely viva questions

1. What did the decomposition components represent physically in frequencies?
2. Why was validation used for tuning, architecture and early stopping?
3. How did the implementation prevent future inputs from entering lags?
4. Why can MASE differ substantially across CPCB and Shillong?
5. Why does a validation gain not imply a test gain?
6. Why is C2_sep not clearly better than A2 at Lumpyngngad?
7. Why is the JN result weaker?
8. How were imputed observations distinguished from true targets?
9. Why can constant-fill data produce apparently strong short-horizon results?
10. Why are legacy recursive and paper-protocol WaveCatBoost numbers not comparable to direct fixed-horizon results?
11. Why are bootstrap confidence intervals not conformal prediction intervals?
12. Why was test data kept isolated from transformation and model selection?

## 17. Final presentation summary

1. **Problem:** forecast hourly air pollutant concentrations across CPCB and Shillong stations at 1-day, 1-week, 2-week and 31-day horizons.
2. **Data:** one hourly CPCB paper dataset and two 15-minute Shillong stations aggregated to hourly causal stores.
3. **Pipeline:** ingest → quality/causal fill → chronological split → lag/meteorological features → decomposition → tuning/refit → direct forecasts → MAE/RMSE/MASE/paired bootstrap.
4. **Directions:** raw univariate/multivariate, 14 Shillong architectures, component-wise separate/shared models, model-family comparisons, feature selection, legacy recursive WaveCatBoost and a partial second-stage strategy/PCA module.
5. **Best:** Lumpyngngad A2/A3 raw multivariate lags are the robust PM2.5 architecture; A2 test MAE is 9.11/10.94/12.29/11.42 µg/m³ at 24/168/336/744 h. JN architecture gains are mixed.
6. **CPCB:** no persistent B0→B1 gain; trees gain at h=744, some h=168 losses, and linear long-horizon models become nearly constant.
7. **Scientific finding:** multivariate history helps strongly at one Shillong station but not all, decomposition and dimensionality reduction do not provide a universal gain, and station/season quality strongly affects generalisation.
8. **Non-results:** PCA/direct/recursive/hybrid comparisons, universal decomposition superiority, conformal performance and cross-station transfer are not completed evidence.
9. **Limitations:** short JN history, sensor/season shifts, legacy leakage/overlap caveats, constant-fill contamination, unverified missing-CPCB decomposition store and optimistic validation.
10. **Contribution:** an evidence-audited architecture and preprocessing framework with strict leakage checks and direct forecasts, plus clear separation between completed and merely proposed studies.

## Recommended slide narrative

1. Motivation and air-quality forecasting problem.
2. Two datasets and preprocessing differences.
3. Causal missingness/quality protocol.
4. Data splits and direct fixed-horizon forecasting.
5. Architecture families A/B/C.
6. Decomposition and component models.
7. Model families and validation protocol.
8. CPCB B0/B1 findings.
9. Lumpyngngad findings.
10. JN Stadium findings and station mismatch.
11. Decomposition, covariates, feature selection: gains versus limits.
12. Statistical evidence and methodological caveats.
13. Lessons and final contribution.
14. Limitations/future work.
