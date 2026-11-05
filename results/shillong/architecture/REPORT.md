# Shillong air-quality forecasting: architecture comparison

Two CPCB CAAQMS stations in Shillong (Lumpyngngad, JN Stadium), treated as separate datasets. Primary target PM2.5, extended to every usable pollutant. Horizons 24, 168, 336 and 744 h. Direct fixed-horizon models, ŷ(t+h) = f_h(X_t), one model per horizon, 24 h of input history. No deep learning, no recursive or hybrid strategies.

Validation numbers are selection scores (early stopping, configuration and architecture choice all use the validation block). **Test is the only unbiased estimate.** Every comparison below is paired on identical target timestamps, with 95% moving-block bootstrap intervals (999 replicates, data-driven block length 24–77 h; Section 10). A ratio is MAE(a) / MAE(b); "+" means the interval is entirely below 1 (a better), "−" entirely above 1 (a worse).

## 1. Executive summary

| # | Question | Answer |
|---|---|---|
| 1 | Best architecture for Lumpyngngad | **Undecomposed multivariate lags (A2, or A3 with covariates).** A2 beats raw univariate A0 on test at every horizon: 0.93 [0.88, 0.97], 0.70 [0.57, 0.82], 0.73 [0.62, 0.83], 0.87 [0.75, 0.96] at h = 24/168/336/744, and beats persistence at every horizon. A3 with a penalised linear learner (elastic net, ridge) was validation-selected at h = 168 and 336 and is within 2% of the lowest test error there (10.06 and 12.47 µg/m³ against 15.64 and 16.82 for A0). |
| 2 | Best architecture for JN Stadium | **None is reliably better than A0.** Differences are mostly within ±10% and change sign between validation and test. The one result that holds on both blocks is A3 at h = 336 (validation 0.85 [0.78, 0.91], test 0.88 [0.80, 0.97]). JN Stadium has 5 months of data, the test block (Nov–Dec) is a season the models never trained on, and test MASE is 2.5–4 for every model. |
| 3 | Does decomposition help? | **No.** Univariate decomposition (B0) is never significantly better than A0 on test and is 20% worse at Lumpyngngad h = 744. With cross-pollutant inputs, the decomposed C2_sep is no better than undecomposed A2 and is 13–14% worse at h = 336 and 744 (Lumpyngngad). |
| 4 | Does a shared component model help? | **Not at the reconstructed level.** B1 vs B0 is indistinguishable on test at Lumpyngngad and mixed at JN. Sharing helps the detail components (D2–D5, 3–20% lower component error) but not the slow S5 component, which dominates the level error. The shared cross-pollutant models (C2_sh, C3_sh) failed badly at Lumpyngngad h = 24 on test (1.58× the separate model) while looking normal on validation. |
| 5 | Do non-lagged covariates help? | **Not robustly.** At Lumpyngngad they help on validation (A1/A0 0.76–0.96) but hurt on test at long horizons (1.11 [1.02, 1.21] at h = 336, 1.26 [1.13, 1.42] at h = 744). At JN they help on test at h = 24–336 (0.80–0.95) but not on validation. Adding them to multivariate lags (A3 vs A2, C3 vs C2) changes MAE by under 8%. |
| 6 | Does multivariate lagged input help? | **Yes at Lumpyngngad, at every horizon on test**, and clearly more than covariates alone (A2/A1 test 0.66–0.94). At JN only at h = 336. |
| 7 | Does intercomponent forecasting help? | **Marginally.** C1_sep vs B0 at Lumpyngngad: test 0.95+, 1.09−, 1.05, 0.90+; validation better at h ≥ 168. Same pollutant, same information as B0 plus the other scales; the gain is small and inconsistent. |
| 8 | Does cross-pollutant decomposed modelling help? | **Yes over B0, not over A2.** C2_sep vs B0 at Lumpyngngad test: 0.92+, 0.74+, 0.86, 0.83+, almost all of it in the S5 component (0.71–0.79). The undecomposed A2 gets the same or more from the same pollutants with 6× fewer inputs. |
| 9 | Best architecture at each horizon | Table in Section 9. Validation picked the right kind of model (multivariate lags) at Lumpyngngad h = 24–336 and a worse decomposed model at h = 744. At JN validation and test winners differ at every horizon. |
| 10 | Consistent across stations? | **No.** Pollutant histories carry real forecast information at Lumpyngngad and almost none that generalises at JN Stadium. Decomposition does not help at either station. |

Three data problems shaped the study and are worth knowing before any further Shillong work: JN Stadium has no data before 26 July 2023; Lumpyngngad NO2 was "imputed" as a near-constant for 10 weeks before its first observation; and Lumpyngngad O3 reads 0.6–1.0 µg/m³ for ten months and then jumps to about 47 µg/m³ inside the test block. The last one silently broke the multivariate models in a first full run (Section 3.4); validation could not see it.

## 2. What was built

Nothing in `store/shillong/` existed when this study started, despite the task description. The repository had the Phase 1a causal preprocessing code with Shillong sources configured (`config/preprocess.yaml`, `run_preprocess.R shillong`) but its output store had never been produced. It was built once:

- `store/shillong/clean/` from `run_preprocess(active = "shillong", store_dir = "store/shillong/clean")`, 45 s. The function always writes `config/imputation_choice.yaml` (the paper store's file); the runner redirects that write into the Shillong store. `store/clean/series.parquet` and `config/imputation_choice.yaml` were checked byte-identical before and after.
- The decomposition reader (`R/30_decomp_registry.R`) is hard-wired to `store/clean`; the study calls the existing causal Haar function (`decomp_coef_haar`, `R/31_decomp_causal.R`) directly instead. Nothing was written to `store/decomp`.
- Model fitting reuses the multivariate interface from the CPCB work (`mv_select_and_refit`, `mv_tune`, the LightGBM/XGBoost/CatBoost/glmnet families and the paired bootstrap in `R/43–48`).

New code: `R/50_sh_data.R` (store build, panel, covariates, availability), `R/51_sh_features.R` (samples, every feature set, shared stacking), `R/52_sh_audit.R`, `R/53_sh_experiments.R` (fit, reconstruct, references, MASE), `R/54_sh_stages.R`, `R/55_sh_report.R`, `run_shillong_arch.R`, `config/shillong_arch.yaml`, `tests/shillong/run_tests.R` (34 tests). No existing file was modified.

## 3. Data audit

### 3.1 Source and hourly aggregation

`data/raw/shillong/shillong_15min_2023.parquet`: 35,040 15-min rows per station for 2023, no duplicate timestamps. The Phase 1a pipeline shifts the start-labelled 15-min stamps by +15 min and labels hour *t* with the mean of slots in (t − 1 h, t]; an hour needs at least 3 of 4 valid slots (`min_subhour_coverage` 0.75). Result: 8,760 end-labelled hours per station and variable (2023-01-01 01:00 to 2024-01-01 00:00 IST), on one contiguous grid, all variables present every hour (tests T01, T03).

Quality masks (causal): negative values, out-of-bounds, a stuck flag for runs of identical values of 6 h or more, the PM2.5 > 1.1 × PM10 ratio rule, and low coverage. The spike flag is computed but not used as a mask. Masked hours are causally imputed (`value_filled_causal`) and are inputs only; only observed, unmasked hours are scored.

| Station | Variable | Masked hours | Of which stuck | Scorable % (train / val / test) | Used |
|---|---|---|---|---|---|
| Lumpyngngad | PM2.5 | 1,955 | 3 | 73.0 / 88.7 / 81.1 | target, input |
| | SO2 | 558 | 0 | 91.8 / 98.7 / 94.4 | input, target |
| | CO | 542 | 0 | 92.1 / 98.8 / 94.4 | input, target |
| | PM10 | 4,296 | 2 | 62.3 / **4.8** / 55.5 | dropped (missing Jul–Oct) |
| | NO2 | 2,284 | 0 | 57.9 / 98.6 / 94.4 | dropped (no data before 14 Mar; 3.3) |
| | O3 | 609 | 0 | 91.1 / 97.8 / 94.3 | dropped (regime change; 3.4) |
| JN Stadium | PM2.5 | 5,962* | 0 | 85.9 / 70.6 / 62.9 | target, input |
| | PM10 | 5,814* | 0 | 83.4 / 72.0 / 74.9 | input, target |
| | NO2 | 5,562* | 0 | 89.2 / 74.1 / 83.4 | input, target |
| | SO2 | 5,560* | 0 | 89.2 / 74.1 / 83.5 | input, target |
| | CO | 5,525* | 0 | 89.2 / 74.1 / 85.9 | input, target |
| | O3 | 6,992* | 0 | **48.4 / 43.5 / 44.9** | dropped |

\* Including roughly 4,950 hours before the station started reporting (2023-07-26).

Rules (`config/shillong_arch.yaml`): a pollutant is used only if it is scorable on at least 50% of hours in each of train, validation and test, and first observed within the first 10% of the train block. Covariates need 50% availability in each block.

**Sensor freezes are negligible in Shillong.** No variable has a run of identical hourly values of 24 h or more (`audit/HOURLY_VARIABLES.csv`); the stuck flag fired on 5 hours in total. This is unlike CPCB, where 2,304 constant-fill hours dominated the h = 24 results.

Imputation (`audit/FILL_METHODS.csv`): PM2.5 gaps are filled with M8, a regression on PM10 at the same hour (falling back to seasonal persistence when PM10 is also missing); long PM10 gaps with last-value-carried-forward (M1); SO2 and O3 mainly with M1/M7 (a per-hour Kalman level). M8 is causal, but it means **imputed PM2.5 inputs already contain PM10 information**, which blurs the univariate/multivariate contrast at JN Stadium, where PM10 is an input.

### 3.2 JN Stadium starts in late July

JN Stadium has no observations for any variable before 2023-07-26 15:00 (PM2.5 from 07-27 12:00). Its usable record is about 5 months, of which roughly 25–37% of hours are masked. This forces short blocks (Section 4) and makes JN results much less certain than Lumpyngngad.

### 3.3 Fabricated NO2 at Lumpyngngad

Lumpyngngad NO2 has no observation before 2023-03-14 12:00, yet the store holds values for 1,739 of those hours (4.6–4.9 µg/m³, 49 distinct values): the imputer's regression constant, repeated seasonally. A causal imputer has nothing to carry forward before the first observation, so these are not measurements. The panel blanks every pollutant before its first observation, and the leading-gap rule then drops NO2 at Lumpyngngad. The alternative, keeping NO2 and starting all Lumpyngngad samples in mid-March, would have removed January–February, the winter regime closest to the October–December test block.

### 3.4 O3 calibration change at Lumpyngngad

| Month (2023) | Jan | Feb–Oct | Nov | Dec |
|---|---|---|---|---|
| O3 monthly median, µg/m³ | 0.96 | 0.59–0.78 | 0.63 (p99 72) | 47.5 (max 93) |

About 1 µg/m³ is not a plausible ambient ozone level, so the sensor was effectively dead or offset for ten months and then recalibrated or repaired inside the test block. The values stay within bounds and never freeze, so no mask fires. `audit/MONTHLY_LEVELS.csv` now records the max/min ratio of monthly medians for every variable: 80 for Lumpyngngad O3 and 20 for JN O3 (already dropped), at most 6.9 for anything else.

The first full run included Lumpyngngad O3. Its December values sit 136 training standard deviations out. Trees saturate, but the penalised linear models extrapolated to test MAE of 100–430 µg/m³ on A3 and C3_sep while their validation MAE was a normal 9–11, and validation selected one of them (lasso C3_sep at h = 168, test MAE 196). O3 was then excluded at Lumpyngngad (`exclude_pollutants` in the config, with the reason) and every affected run was redone. The original runs and report are kept in `archive_o3_included/`. It is a useful negative example: **a validation block cannot protect against an input whose regime changes after it.**

### 3.5 Covariates

Covariates are the station's own meteorology at the forecast origin, one value each, never lagged, plus the hour of day and day of week of the target timestamp (known in advance; for these horizons the target hour equals the origin hour). WS, WD, RF, SR and BP are not in the Phase 1a store, so they are aggregated from the raw 15-min file with the same hour-end rule and coverage threshold; wind direction is averaged as a unit vector (sin, cos). Missing covariate values stay missing (trees handle NA; linear models use a train-median fill).

| Station | Covariates used | Not available |
|---|---|---|
| Lumpyngngad | RH, WS, WD (sin, cos), RF | AT and BP never reported; SR only 37% of train hours |
| JN Stadium | AT, RH, WS, WD (sin, cos), RF, SR, BP | — |

Not used: ERA5 (`data/processed/era5_shillong_2023.parquet`). It is a reanalysis published days after the fact, so its value at the origin is not known at forecast time, and it would also be identical for both stations. Month of year is not used either: with one year of data, every test month is absent from training.

### 3.6 Decomposition

The causal additive Haar pyramid (`decomp_coef_haar`): D_j = W_j, S_J = V_J and x_t = Σ D_j,t + S_J,t exactly (maximum error 6 × 10⁻¹⁴, tests T15). Each component at t uses only x over [t − 2^J + 1, t], so it is causal by construction and its warmup is 2^J − 1 hours. The 2,048-h trailing-window MRA used for CPCB was not used: on one year of data it would discard the first three months, and its last-row value depends on periodic wrap-around.

Depth J = 5 (warmup 31 h). Training-block variance shares for PM2.5 (`audit/DECOMP_AUDIT.csv`):

| Station | D1 (2–4 h) | D2 (4–8 h) | D3 (8–16 h) | D4 (16–32 h) | D5 (32–64 h) | S5 (> 64 h) |
|---|---|---|---|---|---|---|
| Lumpyngngad | 8.0% | 7.8% | 10.7% | 12.8% | 5.9% | 54.7% |
| JN Stadium | 7.7% | 10.7% | 15.4% | 15.8% | 7.0% | 43.4% |

J = 5 separates sub-daily variability (D1–D3), the diurnal band (D4) and the synoptic level (S5) at negligible warmup cost. J = 3 merges the diurnal band into S3; J = 7 splits S5 further (S7 still holds 28–46%) at 127 h of warmup. Only J = 5 was modelled.

Note that decomposed inputs see more history than raw ones: 24 lags of a component reach back 24 + 31 = 55 hours of the raw series. The same holds for every decomposed architecture.

## 4. Protocol

**Blocks** (by target timestamp, inclusive, IST; `audit/SPLITS.csv`). Test starts at or after the imputation selection cutoff (2023-10-01), so no imputation model saw test hours.

| Station | Train | Validation | Test |
|---|---|---|---|
| Lumpyngngad | 01 Jan – 31 Jul (5,087 h) | 01 Aug – 30 Sep (1,464 h) | 01 Oct – 01 Jan 00:00 (2,209 h) |
| JN Stadium | 28 Jul – 30 Sep (1,560 h) | 01 – 31 Oct (744 h) | 01 Nov – 01 Jan 00:00 (1,465 h) |

**Samples.** One per origin t with target t + h. Kept when every input pollutant is finite over [t − 54, t], the target hour is scorable (observed, unmasked), and the origin passes the store policy for the target pollutant (at most 25% of the last 24 h filled, not inside a gap longer than 72 h). Because these conditions involve only the target pollutant and the shared input set, **all 14 architectures use exactly the same target timestamps** (tests T16; smoke checks). Training targets never pass the train end (T11, T12). Inputs at an origin may come from the previous block; they are past observations.

PM2.5 sample counts (train / validation / test):

| h | Lumpyngngad | JN Stadium |
|---|---|---|
| 24 | 2,948 / 1,241 / 1,512 | 1,153 / 456 / 665 |
| 168 | 2,631 / 1,185 / 1,417 | 948 / 371 / 696 |
| 336 | 2,351 / 1,264 / 1,340 | 828 / 525 / 599 |
| 744 | 2,080 / 1,157 / 1,319 | 591 / 416 / 606 |

**Architectures** (feature schemas in `report/FEATURE_SCHEMAS.csv.gz`; input counts for Lumpyngngad / JN):

| ID | Decomposed | Structure | Historical inputs | Covariates | Inputs |
|---|---|---|---|---|---|
| A0 | no | one model | target, 24 lags | – | 24 / 24 |
| A1 | no | one model | target, 24 lags | at origin | 31 / 34 |
| A2 | no | one model | every used pollutant, 24 lags | – | 72 / 120 |
| A3 | no | one model | every used pollutant | at origin | 79 / 130 |
| B0 | yes | one model per component | own component, 24 lags | – | 24 |
| B1 | yes | shared | own component (standardised slot) + component id | – | 25 |
| B2 | yes | per component | own component | at origin | 31 / 34 |
| B3 | yes | shared | own component + id | at origin | 32 / 35 |
| C1_sep / C1_sh | yes | per component / shared | all 6 components of the target | – | 144 / 169 |
| C2_sep / C2_sh | yes | per component / shared | all components of every used pollutant | – | 432 / 720 (+25 shared) |
| C3_sep / C3_sh | yes | per component / shared | as C2 | at origin | 439 / 730 (+25 shared) |

Shared models stack one row per (origin, component) with a categorical component id and the target component's own 24 lags in a fixed slot; the own slot and the target are standardised per component with training-block statistics and mapped back before reconstruction (T06, T07, T14). The C-shared models also carry the own slot, which adds no information but lets trees align components (it was necessary for shared models on CPCB).

**Reconstruction.** Each decomposed forecast is the sum of its six component forecasts, compared with the observed pollutant value. Smoke checks confirm that component truths sum to the observed level and that the reconstruction equals the sum of component forecasts (to 10⁻⁸) for every decomposed architecture at both stations.

**Fitting.** LightGBM (Stage 1) grid num_leaves {15, 31} × min_data_in_leaf {20, 100}, learning rate 0.05, feature/bagging fraction 0.8, up to 2,000 rounds with 100-round early stopping on validation. The configuration with the lowest validation MAE (tuned with seed 2026) is refitted on train + validation with the iteration count frozen and predicts test once. Seeds 2026–2028; comparisons use the seed-mean forecast. Separate decomposed models tune each component independently. Stage 2 families on shortlisted architectures: XGBoost (max_depth {4, 6}), CatBoost (depth {4, 6}), ridge, lasso, elastic net (α {0.1, 0.5, 0.9}; λ chosen on validation and frozen). Linear inputs: train-median fill, one-hot component id, train-fitted standardisation. All single-threaded.

**Metrics.** MAE, RMSE, MASE with the training-block seasonal-naive (24 h) MAE as denominator (PM2.5: 16.88 at Lumpyngngad, 8.49 at JN Stadium; components use their own scale). References: persistence, seasonal naive (identical to persistence here, because every horizon is a multiple of 24 h), train-mean climatology and hour-of-day climatology (refitted on train + validation for test).

## 5. PM2.5 results, Lumpyngngad

Test MAE, µg/m³, LightGBM seed mean (validation in `report/LEVEL_METRICS.csv`):

| | h = 24 | 168 | 336 | 744 |
|---|---|---|---|---|
| A0 raw univariate | 9.84 | 15.64 | 16.82 | 13.10 |
| A1 + covariates | 9.72 | 16.42 | 18.71 | 16.55 |
| **A2 multivariate lags** | 9.11 | 10.94 | **12.29** | **11.42** |
| **A3 A2 + covariates** | **9.04** | 10.82 | 12.51 | 12.31 |
| B0 decomposed, separate | 10.38 | 14.21 | 16.09 | 15.69 |
| B1 decomposed, shared | 10.44 | 13.90 | 15.20 | 15.39 |
| C1_sep intercomponent | 9.81 | 15.43 | 16.90 | 14.10 |
| C2_sep cross-pollutant | 9.54 | 10.45 | 13.90 | 13.06 |
| C3_sep C2 + covariates | 9.99 | **10.42** | 13.96 | 13.44 |
| C2_sh | 15.12 | 13.85 | 15.22 | 15.03 |
| Persistence | 10.03 | 13.28 | 15.70 | 14.65 |
| Hour-of-day climatology | 16.76 | 18.32 | 16.61 | 18.94 |

Test MASE of A2: 0.54, 0.65, 0.73, 0.68. A2 beats persistence at every horizon and train-mean climatology by 35–52%. Not every model clears climatology: at h = 336, A1 and B2 are no better than train-mean climatology (A1 0.99, interval spanning 1) and worse than hour-of-day climatology (18.7 and 18.2 against 16.6).

Paired test ratios (validation in brackets where it disagrees):

| Comparison | h = 24 | 168 | 336 | 744 |
|---|---|---|---|---|
| A1 vs A0 | 0.99 | 1.05 | 1.11− (val 0.89+) | 1.26− (val 0.76+) |
| A2 vs A0 | 0.93+ | 0.70+ | 0.73+ (val 0.96) | 0.87+ (val 0.99) |
| A2 vs A1 | 0.94+ | 0.67+ | 0.66+ | 0.69+ (val 1.30−) |
| A3 vs A2 | 0.99 | 0.99 | 1.02 (val 0.95+) | 1.08− (val 0.89+) |
| B0 vs A0 | 1.06 | 0.91 | 0.96 | 1.20− |
| C2_sep vs B0 | 0.92+ | 0.74+ | 0.86 | 0.83+ |
| C2_sep vs A2 | 1.05 | 0.96 (val 1.19−) | 1.13− | 1.14− |

The multivariate gain on test is large and holds at every horizon, but validation registers it significantly only at h = 168. The validation block (August–September, monsoon) is the low-concentration season; there is little level variation for other pollutants to explain. Covariates show the opposite pattern: they help on validation and hurt on test at long horizons, which is what a model fitting monsoon meteorology and then meeting post-monsoon conditions would do.

## 6. PM2.5 results, JN Stadium

| | h = 24 | 168 | 336 | 744 |
|---|---|---|---|---|
| A0 | 23.77 | 32.14 | 30.56 | 32.20 |
| A1 | 21.43 | **25.82** | 29.04 | 34.13 |
| A2 | 23.88 | 33.19 | 27.32 | 30.56 |
| A3 | 23.28 | 31.54 | 26.93 | **30.03** |
| B0 | 22.97 | 32.79 | 31.96 | 33.69 |
| C2_sh | **21.62** | 33.08 | 26.30 | 30.73 |
| C3_sh | 21.74 | 32.36 | **26.11** | 30.74 |
| Persistence | 21.57 | 28.92 | 33.37 | 29.92 |
| Hour-of-day climatology | 31.99 | 31.67 | 32.86 | 33.58 |

Test MASE is 2.5–4.1 for every model, because the training scale comes from August–September (MASE scale 8.5) while November–December PM2.5 is two to three times higher. Validation MAE is 10–19; test MAE is 21–34.

Paired test ratios: A1 vs A0 0.90+, 0.80+, 0.95+, 1.06− (validation: none significant). A2 vs A0 1.01, 1.03, 0.89+, 0.95. B0 vs A0 0.97, 1.02, 1.05, 1.05. C2_sh vs B0 0.94+, 1.01, 0.82+, 0.91+ (validation 1.07−, 1.16−, 1.12, 0.82+). Validation and test disagree in sign for most comparisons.

JN Stadium's training data cover only the end of the monsoon. The test block is winter, with levels outside anything in the training data, so every architecture is extrapolating. The station needs at least one full year before an architecture choice can be made with any confidence.

## 7. Decomposition, sharing and intercomponent information (Q3, Q4, Q7, Q8)

**Decomposition does not help on its own.** B0 vs A0 is never significantly better on test at either station. At Lumpyngngad the univariate decomposed model is 20% worse at h = 744.

**Cross-pollutant information helps the decomposed model, through the slow component.** Per-component test ratios C2_sep / B0 at Lumpyngngad (`report/COMPONENT_PAIRED.csv`):

| h | D1 | D2 | D3 | D4 | D5 | S5 |
|---|---|---|---|---|---|---|
| 24 | 0.96+ | 0.94+ | 0.89+ | 0.90+ | 0.92+ | 0.74+ |
| 168 | 0.98+ | 0.96+ | 0.95+ | 0.86+ | 0.92+ | 0.71+ |
| 744 | 0.99+ | 0.96+ | 0.98 | 0.96+ | 0.94+ | 0.74+ |

S5 carries 43–55% of the variance and most of the level error, so the 26–29% S5 gain is what moves the reconstruction. In the separate C2 models each component draws almost entirely on inputs at its own and neighbouring scales: S5 models put 94–97% of their gain on S5 inputs (`report/IMPORTANCE_BY_INPUT_COMPONENT.csv`). The undecomposed A2 reaches the same or better reconstructed accuracy with 72 inputs instead of 432.

**Intercomponent lags of the same pollutant (C1) add little.** C1_sep / B0 at Lumpyngngad test: 0.95+, 1.09−, 1.05, 0.90+. At JN: 0.97+, 1.05−, 0.96+, 0.93+.

**Sharing helps the detail components and not the level.** B1 / B0 per component at Lumpyngngad h = 168: D3 0.84+, D4 0.80+, D5 0.87+, S5 1.04. The reconstructed B1 vs B0 is 1.01, 0.98, 0.94, 0.98 on test, none significant, and worse on validation at h = 168 (1.06−). For cross-pollutant inputs, sharing is unstable at Lumpyngngad: C2_sh / C2_sep on test is 1.58−, 1.33−, 1.10, 1.15−, worse in every component at h = 24 and biased upward in S5 (mean forecast 29.5 against a truth of 22.0), with no sign of this on validation. At JN, C2_sh is better than C2_sep on test at three horizons (0.93+, 1.06−, 0.94+, 0.94+) but not on validation.

## 8. Covariates and multivariate inputs (Q5, Q6)

- **Multivariate lags beat covariate-only augmentation at Lumpyngngad** at every horizon on test (A2 / A1 0.94, 0.67, 0.66, 0.69, all significant).
- **Which pollutants.** In A3 at Lumpyngngad, SO2 lags take 70–76% of the gain at h ≥ 168 and PM2.5 its own 68% at h = 24 (`report/IMPORTANCE_BY_SOURCE.csv`). Lumpyngngad SO2 is a slowly drifting series (its climatology MASE is 13.8), so it works mainly as a level indicator. On CPCB the same role for SO2 did not generalise; here it does, but that rests on one test season. At JN, SO2 (39% at h = 336), CO and calendar fields share the importance; no pollutant dominates.
- **Covariates on top of multivariate lags** (A3 vs A2, C3 vs C2): within ±8% everywhere, mostly not significant.

## 9. Best architecture per horizon and model family

Validation-selected over all five families and the shortlisted architectures (A0, B0 plus the best undecomposed and best decomposed LightGBM architecture per station: A3 and C3_sh at Lumpyngngad, A3 at JN), `report/FAMILY_SELECTED.csv`:

| Station | h | Selected on validation | Test MAE | vs A0 LightGBM, test | Best on test (hindsight) |
|---|---|---|---|---|---|
| Lumpyngngad | 24 | A3, CatBoost | 8.95 | 0.91 [0.86, 0.97] | A3 / lasso 8.78 |
| | 168 | A3, elastic net | 10.06 | 0.64 [0.50, 0.79] | A3 / lasso 9.96 |
| | 336 | A3, ridge | 12.47 | 0.74 [0.59, 0.89] | A2 / LightGBM 12.29 |
| | 744 | C3_sh, XGBoost | 14.25 | 1.09 [0.99, 1.19] | A2 / LightGBM 11.42 |
| JN Stadium | 24 | B0, lasso | 22.17 | 0.93 [0.81, 1.09] | A0 / lasso 20.73 |
| | 168 | A3, lasso | 29.79 | 0.93 [0.83, 1.01] | A1 / LightGBM 25.82 |
| | 336 | A3, LightGBM | 26.93 | 0.88 [0.80, 0.97] | C3_sh / LightGBM 26.11 |
| | 744 | A0, XGBoost | 32.57 | 1.01 [1.00, 1.02] | A3 / LightGBM 30.03 |

- With O3 removed, penalised linear models on A3 are among the best at Lumpyngngad (lasso/elastic net 8.8, 10.0, 12.4, 12.1), competitive with or better than the trees. The linear A0 is also better than LightGBM A0 at h = 168 and 336 (13.4 and 14.4 against 15.6 and 16.8).
- The decomposed models (B0, C3_sh) gain nothing from changing family.
- At Lumpyngngad h = 744, validation preferred the decomposed C3_sh in every family, and that choice was 9% worse than A0 on test, while A2 was 13% better. Architecture selection on one monsoon validation block is unreliable at the longest horizon.

Seed variation is small relative to these differences: median seed SD of test MAE is 0.10 µg/m³ at Lumpyngngad and 0.21 at JN (maximum 0.77 and 2.0).

## 10. Uncertainty intervals

Loss differential d_t = |e_a,t| − |e_b,t| on identical target timestamps ordered by origin. Intervals: 95% moving-block bootstrap percentiles of the MAE ratio and difference (999 replicates, seed 7). Block length: Politis–White (2004) with the Patton–Politis–White (2009) correction, estimated on d_t, floored at 24 h and capped at n/5. Estimates came out at 24–77 h; none was capped. Every comparison also reports intervals at fixed blocks of 24 and 168 h (`ratio_lo_b*`, `ratio_hi_b*`) and a Diebold–Mariano test with HLN correction. Samples are not contiguous in time (masked targets and policy-skipped origins are absent), so blocks are blocks of consecutive samples, not of consecutive hours. At h = 744 the test block holds about two non-overlapping horizons, so long-horizon intervals are optimistic about how much independent evidence there is.

## 11. Other target pollutants

LightGBM, architectures A0, A2, A3, B0 and (Lumpyngngad) C3_sh. Test ratios vs A0 (`report/TARGETS_PAIRED.csv`):

| Station | Target | A2 | A3 | B0 |
|---|---|---|---|---|
| Lumpyngngad | CO | 0.98, 0.90+, 0.99, 0.99 | 0.96, 0.92+, 0.94+, 0.93+ | 1.03, 0.98, 0.99, 0.99 |
| | SO2 | 1.12−, 1.13−, 1.11−, 0.95 | 1.16−, 1.10−, 1.09−, 1.04 | 0.88+, 1.00, 0.82+, 0.90+ |
| JN Stadium | CO | 0.90+, 1.12−, 0.91+, 0.97+ | 0.91+, 1.01, 0.76+, 0.95+ | 0.98, 1.20−, 1.02, 0.96+ |
| | NO2 | 1.02, 0.94, 0.88+, 1.18− | 1.01, 0.95, 0.96, 1.08 | 1.04, 1.04, 1.06−, 1.08− |
| | PM10 | 0.97, 1.07−, 1.12, 0.95 | 0.99, 1.02, 1.10, 0.98 | 1.02, 1.04, 1.00, 1.02 |
| | SO2 | 1.05, 1.21−, 1.05, 0.77+ | 1.29−, 0.99, 1.07, 0.82+ | 1.55−, 0.95, 0.96, 0.87+ |

The PM2.5 pattern carries over only partly. CO at both stations gains modestly from other pollutants. Lumpyngngad SO2 is the one target where decomposition helps (B0 0.82–0.90 on test) and multivariate inputs hurt; it is the slowly drifting series that the PM2.5 models use as a level indicator. Lumpyngngad C3_sh is worse than A0 for SO2 at every horizon (1.08–1.30−).

## 12. Masking, imputation and sensor freezes (Q12)

PM2.5 LightGBM retrained under looser sample rules, test MAE scored on the primary samples (`report/SENSITIVITY_MASKING.csv`):

| Station | Model | Primary | No origin policy | All targets incl. imputed |
|---|---|---|---|---|
| Lumpyngngad | A0 | 9.84, 15.64, 16.82, 13.10 | 9.98, 16.46, 16.42, 13.11 | 10.27, 16.31, 16.17, 13.55 |
| | A2 | 9.11, 10.94, 12.29, 11.42 | 9.07, 11.01, 12.29, 11.38 | 9.19, 10.92, 12.49, 11.39 |
| | C3_sh | 15.68, 13.05, 15.62, 15.08 | 12.50, 12.19, 15.60, 14.20 | 10.28, 12.41, 14.65, 13.84 |
| JN Stadium | A0 | 23.77, 32.14, 30.56, 32.20 | 23.35, 30.83, 30.45, 34.05 | 22.41, 28.16, 28.89, 33.32 |
| | A3 | 23.28, 31.54, 26.93, 30.03 | 21.82, 29.03, 27.09, 31.46 | 21.99, 28.30, 26.73, 33.03 |

- **Lumpyngngad:** the sample rules barely matter for A0/A2 (training samples grow by 24% without the origin policy and 70% with all targets). The unstable shared C3_sh benefits most from more data.
- **JN Stadium:** training on every hour, imputed targets included, lowers A0 test MAE by 5–12% at h ≤ 336, consistent with a model starved of data. It does not change any architecture ranking.
- **Imputed inputs.** 71–78% of Lumpyngngad test origins (by horizon) have at least one imputed hour in their input window. Errors there are higher (A0 h = 168: 17.1 vs 11.6 µg/m³), and the multivariate gain is larger there (A2/A0 0.66 vs 0.84 on fully observed windows), but it is present on fully observed windows too (`report/TEST_MAE_BY_INPUT_IMPUTATION.csv`). At JN the split shows no consistent pattern.
- **Sensor freezes:** none of 24 h or more at either station (Section 3.1), so unlike CPCB they play no role.
- **Calibration changes** matter far more than masking here (Section 3.4).

## 13. Limitations

1. One split per station, one year of data. The Lumpyngngad test block is October–December, validation is monsoon; at JN Stadium training is late monsoon and test is winter. Validation and test disagree on many comparisons, and every test-level claim rests on one season.
2. JN Stadium: 591–1,153 training samples and a test regime outside the training range. Its results identify no architecture.
3. h = 744: about two non-overlapping test horizons per station; intervals understate the uncertainty.
4. Decomposed inputs see 55 h of history against 24 h for raw inputs.
5. PM2.5 imputation regresses on same-hour PM10 (M8), so "univariate" inputs carry some PM10 information at JN Stadium.
6. Station meteorology only; no forecast meteorology exists for these stations, and ERA5 is not available at the origin in real time.
7. Small LightGBM grid (4 configurations); Stage 2 families ran only on the shortlist (3–4 architectures per station); other targets ran LightGBM only.
8. Only J = 5 was modelled; MSTL and other decompositions in the registry were not run.
9. Sample blocks for the bootstrap are consecutive samples, not consecutive hours (Section 10).

## 14. Recommendations

- **Lumpyngngad:** use undecomposed multivariate lags (A2, or A3) of PM2.5, SO2 and CO, with a penalised linear model or LightGBM. Do not decompose. Monitor input sensors for regime changes (the O3 failure would recur with any input), for example with the monthly-median ratio now in the audit.
- **JN Stadium:** keep A0 or persistence until a full year of data exists, then rerun this study; the pipeline needs only a config change.
- **Before more architecture work:** rolling-origin evaluation (several validation/test folds through the year) at Lumpyngngad, because the single monsoon validation block mis-ranked architectures at h = 744 and could not see the covariate degradation.

## 15. Runtime

Wall clock on a 16-core Windows machine, every model single-threaded:

| Stage | Time | Notes |
|---|---|---|
| preprocess | 45 s | Phase 1a causal store, both stations |
| audit | 1 min | 28 checks, 34 tests |
| smoke | 3–6 min | every architecture, PM2.5, h = 24, both stations; 70 checks |
| full (LightGBM, 14 architectures × 4 h × 2 stations) | 40 min | 8 processes; C2_sep/C3_sep take 8–20 min each |
| families + targets + sensitivity | 45 min | 18 processes; CatBoost on C3 is the long pole |
| Lumpyngngad rerun after the O3 exclusion | 32 min | |
| report | 2 min | |

Total CPU time for the final model runs: 5.6 h (LightGBM 4.3 h, CatBoost 0.9 h, XGBoost 0.4 h, linear < 0.1 h).

## 16. Reproduction

From the project root with `C:\Program Files\R\R-4.5.2\bin` on PATH (bash). Use script files; `Rscript -e` crashes on this machine once arrow is loaded.

```bash
Rscript run_shillong_arch.R --stage=preprocess          # builds store/shillong/clean (skips if unchanged)
Rscript run_shillong_arch.R --stage=audit               # writes audit/, runs tests, gate AUDIT_PASSED
Rscript run_shillong_arch.R --stage=smoke               # every architecture once, gate SMOKE_PASSED
for st in Lumpyngngad JN_Stadium; do for h in 24 168 336 744; do
  Rscript run_shillong_arch.R --stage=full --station=$st --horizons=$h & done; done; wait
for st in Lumpyngngad JN_Stadium; do for h in 24 168 336 744; do
  Rscript run_shillong_arch.R --stage=families --station=$st --horizons=$h &
  Rscript run_shillong_arch.R --stage=targets --station=$st --horizons=$h & done
  Rscript run_shillong_arch.R --stage=sensitivity --station=$st & done; wait
Rscript run_shillong_arch.R --stage=report
Rscript tests/shillong/run_tests.R                       # tests alone
```

Stages skip runs whose `.rds` already exists (`--force` refits). Every stage writes `RUN_METADATA.json` with the git commit, package versions (R 4.5.2, lightgbm 4.7.0, xgboost 3.2.1.1, catboost 1.2.8, glmnet 5.2, arrow 26.0.0, data.table 1.18.0) and SHA-256 hashes of the config and code.

## 17. Output index (`results/shillong_arch/`)

| Path | Content |
|---|---|
| `audit/` | `RAW_15MIN.csv`, `HOURLY_VARIABLES.csv`, `FILL_METHODS.csv`, `MONTHLY_LEVELS.csv`, `ALIGNMENT.csv`, `AVAILABILITY.csv`, `COVARIATES.csv`, `OVERLAP.csv`, `DECOMP_AUDIT.csv`, `SPLITS.csv`, `SAMPLE_COUNTS.csv`, `CHECKS.csv`, `TEST_SUMMARY.csv` |
| `smoke/` | `SMOKE_METRICS.csv`, `SMOKE_CHECKS.csv`, `FEATURE_SCHEMAS.csv` |
| `runs/<family>/<station>/<target>/h<h>/<arch>.rds` | per-seed predictions (component and reconstructed level, every block), tuning table, selected configuration, importance, feature schema |
| `sensitivity/<variant>/…` | the same for the masking/policy variants |
| `report/` | `LEVEL_METRICS.csv`, `COMPONENT_METRICS.csv`, `PAIRED_COMPARISONS.csv`, `COMPONENT_PAIRED.csv`, `PAIRED_VS_CLIMATOLOGY.csv`, `BEST_BY_HORIZON.csv`, `FAMILY_METRICS.csv`, `FAMILY_SELECTED.csv`, `FAMILY_PAIRED.csv`, `TARGETS_PAIRED.csv`, `SENSITIVITY_MASKING.csv`, `TEST_MAE_BY_INPUT_IMPUTATION.csv`, `IMPORTANCE_BY_SOURCE.csv`, `IMPORTANCE_BY_INPUT_COMPONENT.csv`, `SEED_SUMMARY.csv`, `SELECTED_CONFIGS.csv`, `TUNING_ALL.csv.gz`, `MASE_SCALES.csv`, `RUNTIME_BY_RUN.csv` |
| `report/plots/` | `ratio_vs_A0_heatmap.png`, `level_mase_by_arch.png`, `paired_ratios.png`, `component_mase.png`, `best_by_horizon.png` |
| `archive_o3_included/` | the 132 runs and the report made before the Lumpyngngad O3 exclusion |
| `logs/`, `run_log.txt` | stage logs |
