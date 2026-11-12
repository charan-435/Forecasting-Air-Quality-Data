# Data Preparation and Preprocessing: Repository Audit and Supplementary Slide Plan

Repository: <https://github.com/charan-435/Forecasting-Air-Quality-Data>

Scope: raw observations through forecasting-ready datasets. Model architecture, wavelet methodology, and forecast results are mentioned only when they determine preprocessing boundaries, leakage, or the definition of a prepared sample.

Evidence status used throughout:

- **Executed and evidenced**: code, stored output, and a successful log or test agree.
- **Implemented**: code/configuration exists, but successful execution is not established from the available repository.
- **Legacy/archived**: retained to reproduce earlier outputs; comments now mark it deprecated.
- **Paper statement**: stated in the four-page paper, but not necessarily reproducible from the checked-in data.
- **Not confirmed**: the available paper and repository do not establish the detail.

## Deliverable 1 - Repository audit

### 1.1 Reconstructed pipeline map

| Processing stage | Source file/function | Dataset affected | Evidence and status |
|---|---|---|---|
| Paper methodology | `A_Novel_Hybrid_Approach_For_Efficiently_Forecasting_Air_Quality_Data.pdf`, Section II-A | Original CPCB and ID1 sensor data | Paper states 15-minute raw data, missing-value imputation, hourly averages, min-max normalization, July 2022-July 2023, and 1/7/14/31-day scenarios. It gives no imputation algorithm, station names, missingness rates, or split dates. **Paper statement.** |
| Original CSV loading | `R/02_data.R`: `.read_paper_csv()`, `load_raw_datasets()` | `data/raw/CPCB.csv`, `data/raw/ID1.csv` | Reads CSV, removes index columns, renames `Ozone` to `O3` and `Temp` to `AT`, parses `Datetime` with `dmy_hm()`. **Executed by original experiment paths.** |
| Paper-store ingestion | `R/20_ingest.R`: `adapter_paper_cpcb_csv()`, `adapter_paper_id1_csv()`, `.drop_cloned_last_row()` | CPCB/ID1 clean-store representation | Parses configured `Asia/Kolkata` timestamps; CPCB's cloned final row is removed, giving 8,880 hours. Sources have `skip_preprocess: true`. **Executed and stored in `store/clean/series.parquet`.** |
| Legacy impossible-value screening | `R/03_preprocess.R`: `clip_impossible()` | Original CPCB/ID1 reproduction and legacy Shillong path | Negative values become NA; caps are PM2.5 1000, PM10 2000, NO2/O3/SO2 2000, CO 1e6. Checked-in CPCB/ID1 pollutant columns contain no negatives and do not reach these caps. **Executed but no values changed in current CPCB/ID1 files.** |
| Legacy missing-value treatment | `R/03_preprocess.R`: `impute_hourly()` and `prepare_series()` | Original CPCB/ID1 reproduction; legacy single-station Shillong cache | Full-series seasonal decomposition/interpolation (`na_seadec`, period 24), with linear interpolation fallback. It can use future observations. CPCB/ID1 checked-in CSVs have no NA, so the function changes nothing there. **Legacy/archived; executed for legacy Shillong.** |
| Original chronological splitting | `R/03_preprocess.R`: `chrono_split_tvt()`, `chrono_split()` | Original CPCB/ID1 and legacy Shillong bake-offs | Test is the last horizon `h`; validation is normally 336 hours; legacy `chrono_split()` returns train+validation as `y_train`. Four test windows are nested and share the final timestamp. **Executed; now marked deprecated.** |
| Original min-max scaling | `R/03_preprocess.R`: `minmax_fit()`, `minmax_apply()`, `minmax_invert()`; callers in run scripts | Original CPCB/ID1 and legacy Shillong model inputs | Formula is standard min-max. The legacy caller fits on the entire pre-test vector (training plus validation), not training alone. Test does not enter the fit. **Executed; partially leakage-safe, with validation leakage into scaler.** |
| General raw-source adapter | `R/20_ingest.R`: `adapter_vonter_parquet()` | Shillong and Delhi 15-minute CAAQMS sources | Filters by station ID, standardizes field names, preserves the published clock while attaching configured timezone. **Implemented; adapter is used by the general pipeline.** |
| Duplicate handling | `R/20_ingest.R`: `.dedup_timestamps()` | General 15-minute pipeline | Duplicate station-variable-timestamp rows are averaged and flagged. **Implemented. No executed Shillong clean-store output is present.** |
| Hour labeling and hourly regularization | `R/20_ingest.R`: `.hour_end()`, `regularize_hourly()` | General 15-minute pipeline | Defines hour `t` as readings ending in `(t-1h,t]`; start-labeled 15-minute readings are shifted forward before binning. Requires 75% sub-hour coverage (3 of 4 slots), fills a complete hourly grid, and stores counts/flags. **Implemented; no checked-in `store/shillong/clean` run.** |
| General quality masking | `R/21_quality.R`: `.flag_stuck()`, `.flag_spike()`, `quality_hourly()` | General Shillong/Delhi pipeline | Masks source NA, low coverage, bounds/negative values, stuck runs, and PM2.5/PM10 inconsistency. Spikes are flagged but not masked. **Implemented; configured for Shillong, execution not confirmed.** |
| General causal imputation | `R/22_impute.R`: `fill_one_step()`, `apply_fills()`, `impute_station()`, `benchmark_imputation()`, `choose_imputation()` | General Shillong/Delhi pipeline; CPCB cleaning experiment | Sequential past-only fills M1-M6 plus fitted M7/M8 options. Tracks gap length, hours since observation, long gaps, and trailing filled fractions. **Executed for the CPCB cleaning experiment; Shillong execution not confirmed.** |
| General clean-store generation | `R/23_store_clean.R`: `run_preprocess()`, `write_clean_store()` | Paper, Shillong, Delhi groups | Writes long series, wide station tables, daily summaries, policy, quality report, and imputation choice. Paper sources deliberately bypass cleaning/imputation. **Executed for paper group; Shillong store absent.** |
| CPCB fill-code audit | `R/preprocessed_experiment/10_audit.R`: `pe_fill_codes()`, `pe_audit()` | CPCB six-pollutant hourly store | Learns complete six-pollutant vectors repeated at least twice in training; audits repeats, bounds, stuck values, spikes, PM ratio, and split availability. **Executed 2026-11-03.** |
| CPCB cleaned experiment | `R/preprocessed_experiment/20_preprocess.R`: `pe_preprocess()` | CPCB clean vs unmasked experimental arms | Masks fill codes and invalid values, then uses M1-M6 causal fills chosen on artificial gaps from training only. Filled values are inputs only; masked targets are not scored. **Executed and verified.** |
| Shillong legacy paper-style preparation | `R/03_preprocess.R`: `paper_preprocess_15min()`; `run_new_dataset.R` | Lumpyngngad (`site_5131`) only | 35,040 15-minute rows to 8,760 hourly rows; mean of available samples; all missing hours then filled with full-series seasonal interpolation. **Executed; metadata stored in `SHILLONG_preprocess.rds`.** |
| Shillong extension notebook preparation | `WaveCatBoost_Shillong.ipynb`, Sections 1-5 | Lumpyngngad and JN Stadium | Uses UTC, explicit 2-of-4 slot minimum, leaves failed hours NA, retains feature NA for LightGBM, and drops rows only when target is missing. **Executed; cached hourly parquet and notebook outputs present.** |
| Shillong experiment split | `WaveCatBoost_Shillong.ipynb`, direct forecast protocol | Lumpyngngad target; JN Stadium/ERA5 features | Train origins through 2023-09-30 23:00 UTC; test origins after that through year end; target availability determines final samples. **Executed. No separate validation block or tuning procedure is shown.** |
| Leakage tests and audit | `audit/AUDIT.md`; `tests/preprocessed_experiment/test_data.R`, `test_models.R`; result CSVs | Original and cleaned CPCB experiments | Documents full-series imputation look-ahead, nested tests, scaler scope, cloned CPCB row, and later perturbation tests for causal features/scaling. **Executed; 18/18 data and 18/18 model tests passed for the cleaned experiment.** |

### 1.2 Dataset inventory

#### Paper and checked-in CPCB/ID1 data

The paper describes two sensor datasets in Meghalaya: CPCB, meaning the Central Pollution Control Board sensor network, and ID1, a low-cost sensor. It does not name the monitoring station or provide coordinates. Those details are **not confirmed from the available paper or repository metadata**.

Both checked-in files contain six pollutants: PM2.5, PM10, NO2, SO2, O3 (named `Ozone` in CPCB), and CO. AT and RH are also present but are not part of the six-pollutant forecasting table.

| Dataset representation | Coverage | Rows/hours | Frequency | Missing pollutant values | Notes |
|---|---:|---:|---|---:|---|
| Raw `CPCB.csv` | 2022-07-01 00:00 to 2023-07-06 00:00 | 8,881 | Exactly hourly | 0 in all six pollutants | Final row repeats the first row's pollutant vector and is inside every legacy test window. |
| CPCB paper clean store | 2022-07-01 00:00 to 2023-07-05 23:00 | 8,880 | Exactly hourly, Asia/Kolkata | 0 | New ingestion removes the cloned final row but otherwise stores values unchanged. |
| Raw/store `ID1.csv` | 2022-07-01 00:00 to 2023-08-01 00:00 | 9,505 | Exactly hourly | 0 in all six pollutants | No cloned last row was removed. |

Every pollutant therefore has the same nominal observation count within a dataset: 8,881 in the raw CPCB CSV (8,880 in the newer store) and 9,505 for ID1. This differs from the paper's description of missing 15-minute raw data. The defensible interpretation is that the public CSVs are already hourly, already imputed or otherwise completed derivatives of the original sensor streams.

#### Shillong source and cached representations

The Shillong 2023 parquet contains two CPCB stations:

| Station | ID | Role used in executed notebook | 15-minute rows | Period |
|---|---|---|---:|---|
| Lumpyngngad, Shillong - Meghalaya PCB | `site_5131` | Primary PM2.5 target | 35,040 | 2023-01-01 to 2023-12-31 |
| JN Stadium, Shillong - Meghalaya PCB | `site_5593` | Neighbor feature; mostly unavailable before July | 35,040 | 2023-01-01 to 2023-12-31 |

The combined source has 70,080 rows and 29 source columns. The executed extension notebook retained six principal pollutants plus other gases and meteorology. At the 15-minute level, PM2.5 availability was 78.3% at Lumpyngngad and 31.9% at JN Stadium. After the notebook's 2-of-4 hourly rule it was 80.2% and 32.1%, respectively. Lumpyngngad ambient temperature availability was 0%, motivating ERA5 temperature as an additional feature. These are notebook outputs, not values from the paper.

### 1.3 Files and outputs that establish successful execution

| Artifact | What it proves |
|---|---|
| `results/preprocessed_experiment/run_log.txt` | CPCB audit, masking, causal imputation, clean/unmasked stores, tests, and later experiment phases ran successfully on 2026-11-03/04. |
| `results/preprocessed_experiment/data_audit/*.csv` | Exact source schema, fill vectors, constant blocks, raw distributions, rules, and split availability. |
| `results/preprocessed_experiment/preprocessing/*.csv` | Counts after each invalid-value rule, selected imputation methods, gap lengths, and before/after summaries. |
| `results/preprocessed_experiment/tests/data_tests.csv` and `model_tests.csv` | Leakage and identity invariants passed for the cleaned experiment. |
| `store/preprocessed_experiment/clean/manifest.json` | Provenance and hash of the CPCB cleaned series. |
| `data/processed/SHILLONG_preprocess.rds` | Legacy Lumpyngngad 15-minute-to-hourly pipeline executed, including pre/post imputation counts. |
| `data/processed/shillong_hourly_2023.parquet` | Two-station hourly cache for the extension notebook, including per-hour slot counts and ERA5 fields. |
| `WaveCatBoost_Shillong.ipynb` saved outputs | 15-minute coverage, hourly coverage, split sizes, and common-row evaluation counts from the no-imputation notebook path. |

### 1.4 Contradictions and unresolved points

1. **Paper raw frequency versus repository files.** The paper says raw observations were 15-minute and missing. The public CPCB/ID1 CSVs are hourly and complete. The original imputation method cannot be recovered from those files.
2. **Timestamp timezone.** Legacy `.read_paper_csv()` does not supply a timezone. The newer store explicitly uses Asia/Kolkata. The source timestamps are treated as IST wall-clock time in the newer framework.
3. **CPCB endpoint.** The raw CSV has 8,881 rows through 2023-07-06 00:00, but that final pollutant vector equals the first row. The newer store removes it; archived original scores include it.
4. **Paper normalization scope.** The paper states min-max normalization to [0,1] but does not say which split supplies min/max. The legacy repository uses all pre-test observations, including its validation tail. The later cleaned experiment uses training-fitted standardization rather than min-max.
5. **Paper missing-value algorithm.** The paper uses the word “imputation” but gives no method or parameter. Any claim that the authors used linear or seasonal interpolation would be unsupported.
6. **Constant values.** The original pipeline treated repeated finite values as valid. The later CPCB experiment identified joint repeated vectors as synthetic fills and removed them. This is an extension, not established paper methodology.
7. **Shillong has two implemented preprocessing paths.** The legacy paper-style cache fills all hourly gaps and uses only Lumpyngngad. The extension notebook uses both stations, a 2-of-4 coverage rule, and no imputation. The general config defines a third, stronger causal pipeline using 3-of-4 coverage, Asia/Kolkata, quality masking, and causal fills, but a completed Shillong clean store is absent.
8. **Shillong notebook timezone.** The executed extension notebook uses UTC “as published.” The general preprocessing framework reinterprets the same source clock as Asia/Kolkata wall time. These are contradictory time semantics and must not be silently combined.
9. **Shillong validation/tuning.** The executed notebook has train and test only. A separate validation period and train-only hyperparameter selection are **not confirmed**.

## Deliverable 2 - Step-by-step technical explanation

## Part I - Original paper and CPCB/ID1 implementation

### 2.1 Acquisition and dataset identity

**Paper methodology.** The paper uses a CPCB dataset and an ID1 low-cost sensor dataset from Meghalaya. Raw measurements are described as 15-minute observations containing missing values. Six pollutants are forecast, and the time span is July 2022 to July 2023.

**Repository implementation.** The repository loads public CSV derivatives from the authors' GitHub dataset. They are already hourly and contain no missing pollutant cells. `CPCB.csv` covers 8,881 timestamps and `ID1.csv` covers 9,505. The newer store removes the cloned CPCB last row and stores 8,880 CPCB hours.

**Input.** Hourly wide CSV with `Datetime`, six pollutants, AT, and RH.

**Operation.** Remove index columns; normalize column names; parse the timestamp; attach sensor name.

**Output.** A wide hourly data frame, then one univariate series per sensor-pollutant pair.

**Assumption/limitation.** The checked-in files cannot show how the paper transformed raw 15-minute missing data into these complete hourly series. Consequently, the paper's missing-value percentages and imputation behavior are not reproducible from this repository.

### 2.2 Timestamp parsing and temporal alignment

**Paper methodology.** Hourly averages are calculated after missing-data treatment. No timezone or hour-label convention is stated.

**Legacy implementation.** Timestamps are parsed day-first with `dmy_hm()` without an explicit timezone. The series are sorted by time. The files already have a complete one-hour grid, so no resampling or cross-pollutant alignment is performed by the legacy path.

**Newer paper-store implementation.** Timestamps are parsed as Asia/Kolkata, and the CPCB cloned endpoint is removed. The resulting CPCB and ID1 time axes have one-hour spacing and zero duplicate hours.

**Why it matters.** A forecasting lag such as 24 hours assumes every adjacent row is exactly one hour apart. An irregular grid would turn “lag 24” into an inconsistent elapsed time and could misalign forecast targets.

**Alignment example.** At timestamp `2023-03-01 10:00`, all six pollutant fields in one row refer to the same nominal hour. The repository pivots such rows to pollutant-specific series while retaining that common timestamp. No nearest-neighbor join is needed for CPCB/ID1 because the wide CSV already supplies aligned fields.

**Limitation.** Archived outputs use the legacy timezone behavior and include the cloned CPCB endpoint. The newer store is the more defensible timestamp representation, but it is not identical to the archived original experiment input.

### 2.3 Missing-value identification and treatment

**Paper methodology.** The paper states that missing values were imputed to preserve continuity, then hourly averages were calculated. It does not name the imputer, say whether imputation happened before or after aggregation, or provide missingness by station/pollutant.

**Legacy implementation.** `prepare_series()` counts non-finite entries after loading. It converts negative/over-cap values to NA, then applies seasonal decomposition with interpolation at daily period 24; if that fails, it applies linear interpolation. This runs on the complete series before splitting.

**Actual effect on CPCB/ID1.** All six pollutant columns in both files have zero missing entries and zero negative entries. Therefore the imputation function returns each series unchanged. There is no repository evidence of an imputed CPCB/ID1 cell created during the R run.

**Leakage implication.** The algorithm itself is non-causal: if a gap existed near a forecast origin, later observations could affect the fill. The audit demonstrated this with a synthetic perturbation. This is a latent methodological flaw even though it did not alter the current complete CPCB/ID1 files.

### 2.4 Constant-filled and copied observations

The original CPCB file contains long periods where all six pollutant values repeat as a joint vector. The primary repeated vector occurs 2,304 times and is close to the column medians. A training-derived rule in the later CPCB experiment found five complete six-pollutant vectors that appeared at least twice in training; together they cover 2,637 of 8,880 hours (29.7%). The dominant blocks include repeated 168-hour periods and a 600-hour block from 2023-06-06 through 2023-06-30.

The detection rule is:

\[
F_t = \mathbf{1}\left[\mathbf{x}_t \text{ is complete and its exact six-pollutant vector occurs at least twice in training}\right].
\]

Here \(\mathbf{x}_t\) is the six-pollutant vector at hour \(t\). Exact equality is evaluated after formatting values to ten significant digits. The code learns eligible vectors using the training period only and applies the learned set to validation and test.

**Original treatment.** Retained as valid finite observations; the legacy clipping/imputation logic does not identify them.

**Later cleaning experiment.** Masked as synthetic fill codes, converted to NA, optionally filled causally for model inputs, and excluded from scored targets.

**Why these runs matter.** Long repeated blocks suppress variance and create artificially easy persistence patterns. If a test target is a copied constant rather than an independent measurement, a forecasting score measures agreement with the fill procedure as much as atmospheric prediction. The later experiment reports 768 fill-code hours in validation and 821 synthetic hours in its test block; 52% of the original test-block hours were synthetic fills for the PM2.5 study.

The rule should be presented as a repository-specific cleaning hypothesis, not a universal rule that every repeated air-quality value is invalid. Short repeats occur naturally; the evidence here is exact simultaneous repetition across six high-precision channels and very long blocks.

### 2.5 Invalid values, outliers, and physical consistency

**Legacy CPCB/ID1 rules.** Negative values become NA. Caps are pollutant-specific but coarse. The checked-in CPCB/ID1 data have no negative values and no values above those caps, so no cells were changed.

**General quality framework.** Configured bounds are PM2.5 0-1000, PM10 0-2000, NO2/SO2/O3 0-1000, CO 0-50 mg/m3, AT -10 to 50, and RH 0 to 100. A run is marked stuck from the sixth consecutive identical hour onward. PM2.5 and PM10 are both masked when PM2.5 exceeds 1.1 times PM10. A rolling 24-hour, six-MAD spike detector exists, but `spike.mask: false`, so spikes are diagnostic rather than automatically removed.

**Executed CPCB cleaning experiment.** No negatives or out-of-bound values were found. In addition to 2,637 fill-code hours per pollutant, 206 PM-ratio hours affected PM2.5 and PM10. After rule precedence, PM2.5 had 2,844 masked hours (32.03%), PM10 2,843 (32.02%), and each other pollutant 2,637 (29.7%). Nothing was clipped to a bound; invalid observations became NA.

This distinction is important: the later experiment removes physically or procedurally invalid values, while extreme but plausible measurements remain.

### 2.6 Scaling and normalization

The paper specifies min-max scaling:

\[
x'_t = \frac{x_t-x_{\min}}{x_{\max}-x_{\min}},
\]

where \(x_{\min}\) and \(x_{\max}\) are the fitted minimum and maximum. Inverse scaling is

\[
x_t = x'_t(x_{\max}-x_{\min})+x_{\min}.
\]

**Paper ambiguity.** It does not define whether min/max are estimated on the full series, training data, or each component.

**Legacy repository implementation.** Scaling is fitted separately for each sensor-pollutant series. The caller passes the entire pre-test vector produced by `chrono_split()`, which combines the training and validation portions. Test values do not enter min/max. Forecasts are inverse-transformed before metrics.

**Leakage assessment.** Test leakage is avoided, but validation information enters the scaler before validation is used for model selection/early stopping. Claims that “validation and test never enter the scaler” are therefore inaccurate for the legacy path.

**Later cleaned experiment.** It uses per-series standardization, fitted on training for selection and on training+validation for the final refit. This differs from the paper's min-max normalization and must be labeled as an extension.

### 2.7 Chronological train/validation/test preparation

For each horizon, the legacy split takes the final \(h\) hours as test and the preceding 336 hours as validation. Everything earlier is training. The wrapper used by the bake-off then combines training and validation as the pre-test fitting/scaling series in several paths.

#### CPCB legacy split

| Horizon | Training | Validation | Test |
|---|---|---|---|
| 1 day (24 h) | 8,521 h, through 2023-06-21 00:00 | 336 h, 2023-06-21 01:00 to 2023-07-05 00:00 | 24 h, 2023-07-05 01:00 to 2023-07-06 00:00 |
| 7 days (168 h) | 8,377 h, through 2023-06-15 00:00 | 336 h, through 2023-06-29 00:00 | 2023-06-29 01:00 to 2023-07-06 00:00 |
| 14 days (336 h) | 8,209 h, through 2023-06-08 00:00 | 336 h, through 2023-06-22 00:00 | 2023-06-22 01:00 to 2023-07-06 00:00 |
| 31 days (744 h) | 7,801 h, through 2023-05-22 00:00 | 336 h, through 2023-06-05 00:00 | 2023-06-05 01:00 to 2023-07-06 00:00 |

#### ID1 legacy split

| Horizon | Training | Validation | Test |
|---|---|---|---|
| 1 day | 9,145 h, through 2023-07-17 00:00 | 336 h, through 2023-07-31 00:00 | 2023-07-31 01:00 to 2023-08-01 00:00 |
| 7 days | 9,001 h, through 2023-07-11 00:00 | 336 h, through 2023-07-25 00:00 | 2023-07-25 01:00 to 2023-08-01 00:00 |
| 14 days | 8,833 h, through 2023-07-04 00:00 | 336 h, through 2023-07-18 00:00 | 2023-07-18 01:00 to 2023-08-01 00:00 |
| 31 days | 8,425 h, through 2023-06-17 00:00 | 336 h, through 2023-07-01 00:00 | 2023-07-01 01:00 to 2023-08-01 00:00 |

All four tests end at the same timestamp in each dataset, so they are nested suffixes, not independent forecast origins. Hyperparameters chosen using the CPCB 1-day pre-test prefix overlap 86%-97% of the longer-horizon test windows. This is model-selection leakage for the longer horizons.

### 2.8 Final CPCB/ID1 forecasting-ready dataset

For the archived original experiment, each forecasting-ready object is an hourly univariate pollutant series with no NA, a legacy pre-test/test split, and optional min-max scaling. The preparation does not remove constant-filled blocks, and archived CPCB test data include the cloned final row.

For the later clean-store framework, CPCB/ID1 are stored on explicit Asia/Kolkata hourly axes, but `skip_preprocess: true` means the standard paper store does not apply quality masking or causal filling. The separate CPCB cleaning experiment is the only executed path that removes fill codes and uses causal fills.

## Part II - Extensions to Data Preparation for the Shillong Dataset

### 2.9 Why Shillong needs a separate preprocessing discussion

Shillong is supplied as rawer 15-minute CAAQMS data for two stations, with substantial and station-dependent missingness. Unlike CPCB/ID1, the repository controls the hourly aggregation rule and retains observation counts. This makes missingness, time labeling, and cross-station availability part of the experimental design.

Lumpyngngad is suitable as a full-year PM2.5 target but lacks station temperature. JN Stadium is mainly a later-year neighbor series and is unsuitable as a complete full-year target. The two stations therefore cannot be cleaned and evaluated as if they had equal coverage.

### 2.10 Executed legacy Shillong path

`paper_preprocess_15min()` selects Lumpyngngad only, interprets the published clock as Asia/Kolkata wall time, clips impossible values, and takes the arithmetic mean of whatever finite 15-minute readings exist in each hour. It then creates a full 8,760-hour grid and fills every remaining pollutant gap using the same full-series seasonal interpolation used in the legacy CPCB/ID1 code.

Before hourly imputation, missing hours were:

| Pollutant | Missing 15-minute slots | Missing hourly values before fill | Missing after fill |
|---|---:|---:|---:|
| NO2 | 9,063 | 2,198 | 0 |
| O3 | 2,559 | 488 | 0 |
| CO | 2,069 | 415 | 0 |
| SO2 | 2,164 | 471 | 0 |
| PM2.5 | 7,603 | 1,529 | 0 |
| PM10 | 17,070 | 3,961 | 0 |

This path closely imitates the paper's short description, but it is not leakage-safe because imputation is performed across the full year before splitting. It also accepts an hourly mean from a single observed 15-minute slot.

### 2.11 Executed Shillong extension notebook path

The notebook uses both stations and applies an explicit rule:

\[
\bar{x}_{s,t} =
\begin{cases}
\frac{1}{n_{s,t}}\sum_{i=1}^{n_{s,t}}x_{s,t,i}, & n_{s,t}\ge 2,\\
\mathrm{NA}, & n_{s,t}<2,
\end{cases}
\]

where \(n_{s,t}\) is the number of observed 15-minute slots for station \(s\), hour \(t\). Rain is summed and wind direction uses a circular mean, with the same two-slot threshold.

**Input.** 70,080 station-slot rows for 2023.

**Operation.** Parse timestamps as UTC, group by station and floored hour, aggregate fields, retain per-variable slot counts, and left-join hourly ERA5 data.

**Output.** 17,520 station-hour rows (8,760 per station) with measurements, counts, and ERA5 fields.

**Missingness policy.** No forward fill, seasonal interpolation, or cross-station imputation. Hours failing the threshold stay NA. LightGBM receives feature NA directly; a row is excluded only when its forecast target is missing. Thus the final number of evaluated rows varies by horizon, but all compared models at a horizon use a common target mask.

**Time-zone limitation.** This notebook treats published times as UTC. The general pipeline treats the clock as IST. A presentation should show the notebook's actual UTC implementation and flag the unresolved semantic difference.

### 2.12 Configured general Shillong causal pipeline

The reusable pipeline defines Lumpyngngad and JN Stadium separately, both in Asia/Kolkata. It shifts start-labeled 15-minute readings to the hour they end in, requires 75% sub-hour coverage (three slots), averages duplicate observations, fills a complete hourly grid, and applies quality flags.

Its quality policy masks:

- source NA and low coverage;
- negative or out-of-bound values;
- exact stuck runs from hour six onward;
- PM2.5/PM10 ratio violations above 1.1;
- optionally spikes, although the current configuration flags rather than masks spikes.

Missing inputs can then be filled sequentially using past-only rules. The store records `value_hourly_raw`, `value_masked`, `value_filled_causal`, fill method, gap state, long-gap status, trailing fill fractions, and `is_scorable`. Filled values are explicitly prohibited as evaluation targets.

This design is stronger than the notebook's missing-value handling, but its Shillong execution is **not confirmed from the available repository** because `store/shillong/clean/series.parquet`, a Shillong quality report, and a Shillong imputation-choice file are absent.

### 2.13 Alternative preprocessing and cleaning experiments

| Experiment | Motivation | Implementation | Dataset/status |
|---|---|---|---|
| Legacy filled Shillong | Reproduce the paper's stated continuous hourly series | Mean of available slots; full-series seasonal interpolation | Lumpyngngad; **executed**, but non-causal. |
| No-imputation Shillong notebook | Preserve observed missingness and avoid invented targets | At least 2/4 slots; failed hours stay NA; feature NA handled by model | Both stations; **executed**. |
| Configured causal Shillong store | Make aggregation, quality, filling, and scoring policy explicit | 3/4 slots; end-labeled IST hour; masks invalid values; past-only imputation; scorable flag | Both stations; **implemented, execution not confirmed**. |
| CPCB clean versus unmasked | Measure impact of synthetic fill removal separately from architecture | Training-derived joint fill codes, invalid-to-NA, causal fill for inputs, identical valid targets | CPCB; **executed and verified**. |
| Shillong neighbor and ERA5 representations | Address missing station meteorology and spatial context | Retain JN Stadium PM2.5 and ERA5 current-time fields as features; target-hour weather labeled oracle where tested | Notebook; **executed**. |

### 2.14 Leakage-safe safeguards and remaining risks

**Implemented in the executed Shillong notebook:**

- Direct targets are created as \(y_{t+h}\); features use information at origin \(t\).
- Circular full-series decomposition is excluded from model inputs; only causal Haar states are used.
- Test origins occur after 2023-09-30 23:00 UTC.
- Missing target rows are removed consistently across model comparisons.
- Target-hour ERA5 is explicitly labeled an oracle ablation rather than deployable input.

**Not established or still risky:**

- No validation block or train-only hyperparameter tuning is shown.
- The no-imputation notebook leaves missing lag features to LightGBM, but some derived causal Haar fields become NA after gaps; this is intentional but affects available information.
- Timestamp interpretation conflicts with the general IST pipeline.
- The legacy Shillong cache imputes before splitting and therefore uses future information.

**Implemented and tested in the later CPCB cleaned experiment:** transformations and imputation selection use the training block; scaling is fitted on training; test labels cannot change selection; perturbing future values does not change earlier features; filled targets are not scored.

## Deliverable 3 - Slide-by-slide content plan

### Section A - Original paper and CPCB/ID1

### Slide 1 - From Sensor Observations to Forecasting-Ready Series

**Objective.** Establish the chronological workflow and the evidence layers.

**Explain.** Paper: missing 15-minute data -> imputation -> hourly average -> min-max normalization -> forecast scenarios. Repository: checked-in CPCB/ID1 start at the hourly-complete stage. Later experiments add explicit cleaning.

**Suggested visual.** Three-lane flowchart: paper statement, legacy implementation, later verified extensions. Required data: none beyond the audit. Audience takeaway: these lanes overlap but are not identical.

**Implementation detail.** Label every box as paper-stated, executed, or unconfirmed.

**Likely question.** “Can we reproduce the authors' original 15-minute imputation?” Answer: no, not from the checked-in hourly-complete CPCB/ID1 files.

### Slide 2 - Dataset Sources, Pollutants, and Coverage

**Objective.** Define CPCB and ID1 and quantify the actual files.

**Explain.** Six pollutants; CPCB 8,881 raw hourly rows/8,880 corrected store hours; ID1 9,505 hours; no missing pollutant cells; station identity/location not confirmed.

**Suggested visual.** Coverage timeline with one bar per dataset and a small dataset table. Required data: raw timestamps and pollutant column counts. Takeaway: complete hourly derivatives, different endpoints.

**Likely question.** “Why does CPCB lose one row?” The final row duplicates the first pollutant vector and is removed only in the newer store.

### Slide 3 - Timestamp Parsing and Hourly Alignment

**Objective.** Show why the one-hour grid is reliable and where timezone uncertainty remains.

**Explain.** Day-first parsing; zero duplicate hours; exactly one-hour steps; legacy no explicit timezone versus newer Asia/Kolkata.

**Suggested visual.** A four-row raw table around one timestamp leading to aligned pollutant series, plus a note on the CPCB cloned endpoint. Required data: a short timestamp sample. Takeaway: alignment is already present in CPCB/ID1.

**Likely question.** “Were 15-minute observations averaged in our R code?” Not for CPCB/ID1; that happened upstream of the public CSVs.

### Slide 4 - Missing Values: Paper Claim Versus Repository Evidence

**Objective.** Prevent unsupported claims about imputation.

**Explain.** Paper says imputation but does not specify the algorithm. Legacy code offers seasonal/linear interpolation; current CPCB/ID1 have zero missing cells, so it performs no fills.

**Equation.** Missing proportion:
\[P_{missing}=100N_{missing}/N_{total}.\]
For each checked-in CPCB/ID1 pollutant, this is 0% at the hourly CSV stage.

**Suggested visual.** Paper-method box beside a zero-missingness matrix for repository files. Required data: per-column NA counts. Takeaway: upstream preprocessing is hidden.

**Likely question.** “Which imputation did the paper use?” Not confirmed.

### Slide 5 - Constant-Filled Observations Hidden Inside Complete Data

**Objective.** Explain why zero NA does not imply valid observations.

**Explain.** Exact six-pollutant vectors, training-derived threshold of two occurrences, 2,637 affected CPCB hours, long 168-hour and 600-hour blocks.

**Equation.** Present the joint-vector indicator \(F_t\).

**Suggested visual.** Time series highlighting fill-code blocks and a monthly affected-hours bar chart. Required data: `fill_code_blocks.csv`, `fill_code_hours_by_month.csv`. Takeaway: completeness was partly produced by synthetic constants.

**Likely question.** “Could genuine values repeat?” Yes; the evidence is joint exact repetition across all six channels and long blocks, not a ban on ordinary repeats.

### Slide 6 - Invalid-Value and Outlier Policy

**Objective.** Separate invalid measurements from statistical extremes.

**Explain.** Bounds, negatives, six-hour stuck rule, PM ratio >1.1, spikes flagged but retained. Current CPCB had no bound violations; the main removals were fill codes and PM-ratio violations.

**Suggested visual.** Rule-to-action table and removed-hours stacked bars by pollutant. Required data: `pollutant_rules_counts.csv`. Takeaway: the extension masks invalid values; it does not broadly trim extremes.

**Likely question.** “Were high pollution episodes clipped?” No evidence of clipping in the executed cleaned experiment.

### Slide 7 - Causal Filling for Inputs, Never for Targets

**Objective.** Explain the later clean experiment's separation of model continuity and evaluation truth.

**Explain.** Invalid -> NA; past-only method selected by pollutant/gap bucket; filled series used as inputs; `is_scorable` excludes fills from targets. Mention longest 600-hour gap and 144 initial hours without history.

**Suggested visual.** Before/masked/causally-filled three-line example with target eligibility markers. Required data: clean series and fill method. Takeaway: models receive continuous inputs where possible without scoring invented observations.

**Likely question.** “Does forward fill make long gaps trustworthy?” No; long-gap and filled-fraction policies restrict eligibility.

### Slide 8 - Scaling: Formula, Fit Scope, and Discrepancy

**Objective.** State exactly which observations determine scaling.

**Explain.** Paper min-max [0,1], legacy implementation per series on pre-test train+validation, inverse transform before metrics; later clean experiment uses training-fitted standardization.

**Equation.** Min-max and inverse formulas.

**Suggested visual.** Distribution before/after scaling with vertical markers for train-derived min/max. Required data: one pollutant and its split. Takeaway: test is excluded, validation is not excluded in the legacy scaler.

**Likely question.** “Is scaling fully leakage-safe?” Not in the strict training-only sense for the legacy path.

### Slide 9 - Chronological Splits and Nested Forecast Windows

**Objective.** Show the exact temporal partitions and leakage risk.

**Explain.** 336-hour validation, final `h` hours as test, four horizons sharing one endpoint, CPCB and ID1 dates, longer test windows overlapping the 1-day hyperparameter prefix.

**Suggested visual.** Horizontal timeline with four nested test suffixes. Required data: split date table. Takeaway: horizons are not independent test cases.

**Likely question.** “Was test data used to fit scaling?” No. “Was it used indirectly for longer-horizon model selection?” The shared 1-day hyperparameter prefix overlaps longer tests.

### Slide 10 - What “Prepared CPCB/ID1 Data” Actually Means

**Objective.** Close the first narrative before Shillong.

**Explain.** Archived path: complete hourly series, constant fills retained, legacy scaling/splits. New store: corrected timezone and cloned row, but paper sources skip cleaning. Separate clean experiment: masked synthetic values and causal input fills.

**Suggested visual.** A comparison table with three output datasets. Required data: audit inventory. Takeaway: select the dataset version explicitly for every downstream experiment.

**Likely question.** “Which version should supplementary results cite?” Cite the exact experiment; never call all three simply “preprocessed CPCB.”

### Section B - Shillong extensions

### Slide 11 - Why Shillong Requires New Preprocessing

**Objective.** Introduce data-quality differences without repeating Section A.

**Explain.** Two stations, 15-minute source, unequal coverage, Lumpyngngad target, JN Stadium neighbor, missing station temperature.

**Suggested visual.** Station map plus 15-minute availability bars. Required data: station coordinates from notebook and availability table. Takeaway: station-specific coverage determines role.

**Likely question.** “Why not forecast JN Stadium for the full year?” It is largely unavailable before July.

### Slide 12 - Hourly Aggregation With an Explicit Coverage Rule

**Objective.** Explain the executed 2-of-4 rule.

**Explain.** Mean for concentrations/met fields, sum for rain, circular mean for wind direction, NA below two slots, UTC in notebook.

**Equation.** Piecewise hourly mean formula from Section 2.11.

**Suggested visual.** Four 15-minute cells feeding one hourly cell, with examples for 4/4, 2/4, and 1/4 observed. Required data: illustrative observed slots. Takeaway: low-coverage hours remain missing.

**Likely question.** “Why two slots rather than three?” It is the notebook's chosen rule; the general configured pipeline uses the stricter 75%/three-slot rule.

### Slide 13 - Shillong Missingness and Alternative Treatments

**Objective.** Compare the two executed paths and the configured causal path.

**Explain.** Legacy single-station full interpolation; notebook no imputation; general pipeline causal fills with quality flags but no confirmed Shillong run.

**Suggested visual.** Three-column decision table and missingness heatmap for both stations. Required data: hourly counts and legacy metadata. Takeaway: these are alternative experiments, not successive steps in one pipeline.

**Likely question.** “Which Shillong results use interpolated targets?” The legacy `run_new_dataset.R` path can; the extension notebook does not.

### Slide 14 - Leakage-Safe Shillong Feature Preparation

**Objective.** Show what information is allowed at forecast origin.

**Explain.** Lags, calendar, current ERA5/station data, current neighbor PM2.5, causal Haar state; no future values; target-hour ERA5 only as labeled oracle; common target rows.

**Suggested visual.** Forecast-origin diagram with allowed inputs at/before `t` and target at `t+h`. Required data: feature list. Takeaway: feature construction respects temporal direction.

**Likely question.** “Is reanalysis current weather deployable?” It represents observed/current conditions; target-hour reanalysis is not deployable and is labeled oracle.

### Slide 15 - Final Shillong Dataset and Open Decisions

**Objective.** State the executed output and unresolved choices before modeling.

**Explain.** 17,520 station-hour rows; PM2.5 hourly coverage 80.2%/32.1%; train through September and test October-December; no separate validation block; UTC-versus-IST conflict; general clean-store run still needed.

**Suggested visual.** Final coverage timeline with train/test shading and missing-hour marks. Required data: hourly parquet. Takeaway: the notebook dataset is usable but not the final unified preprocessing standard.

**Likely question.** “What should be done before a definitive Shillong comparison?” Resolve timezone semantics, choose and justify the slot threshold, run the general causal pipeline, freeze a validation block, and publish its quality report/manifest.

## Traceability table

| Step | Paper methodology | Our implementation | Source file/function | Status or discrepancy |
|---|---|---|---|---|
| Raw frequency | 15-minute | CPCB/ID1 files are already hourly; Shillong raw is 15-minute | Paper II-A; loaders/adapters | CPCB/ID1 raw stage unavailable. |
| Missing values | Imputed | CPCB/ID1 contain none; legacy imputer is seasonal/linear; Shillong has filled and unfilled variants | `impute_hourly()`, notebook aggregation | Paper algorithm not confirmed; legacy imputer looks ahead. |
| Hourly averaging | Performed after missing-data handling | Not performed for CPCB/ID1; performed for Shillong | `paper_preprocess_15min()`, notebook, `regularize_hourly()` | Shillong variants use different slot thresholds and time labeling. |
| Time zone | Not stated | Legacy unspecified; newer paper store IST; Shillong notebook UTC; general pipeline IST | loaders and config | Contradictory; must be resolved. |
| Duplicate timestamps | Not stated | CPCB/ID1 zero; general pipeline averages duplicates and flags them | `.dedup_timestamps()` | General Shillong execution not confirmed. |
| Constant fills | Not discussed | Retained originally; later CPCB experiment masks training-derived joint vectors | `pe_fill_codes()`, `pe_preprocess()` | Extension, not paper method. |
| Invalid values | Not discussed | Negatives/caps legacy; later bounds, stuck, PM ratio; spikes informational | preprocessing/quality functions | Executed CPCB cleaning found no bounds violations. |
| Normalization | Min-max [0,1] | Legacy min-max on pre-test train+val; cleaned experiment standardizes on training | min-max helpers; cleaned feature pipeline | Paper fit scope unknown; implementations differ. |
| Split | Four train-test scenarios | Legacy adds a 336-hour validation tail and nested final test windows | `chrono_split_tvt()` | Longer-horizon selection leakage exists. |
| Test isolation | Not detailed | Test excluded from scaler; legacy full-series imputer could leak if gaps existed; longer tests overlap shared tuning prefix | audit and split code | Partly safe, partly discrepant. |
| Shillong station treatment | Not in paper comparison | Lumpyngngad target; JN Stadium neighbor; station-specific coverage | notebook/config | Executed notebook only. |
| Causal imputation | Not stated | General M1-M6 framework; executed for CPCB cleaning | `R/22_impute.R`, `pe_preprocess()` | Shillong execution not confirmed. |
| Dataset storage | Not stated | CSV, parquet clean stores, manifests, quality tables | store writers/manifests | Provenance strongest for later CPCB experiment. |

## Recommended figures for later R Markdown production

| Figure | What it should show | Required intermediate data | Audience conclusion | Slide |
|---|---|---|---|---|
| Overall pipeline flow | Paper, legacy CPCB/ID1, cleaned extension, Shillong branch | Audit map | Preprocessing versions are distinct | 1 |
| Coverage timeline | CPCB/ID1 date spans and Shillong station availability | Raw/hourly timestamps | Datasets differ in span and completeness | 2, 11 |
| Raw sample table | Timestamp plus six pollutant columns | Raw CSV sample | CPCB/ID1 arrive already aligned hourly | 3 |
| Missingness heatmap | Pollutant x time/station NA mask | Raw and hourly Shillong data | Shillong missingness is structured and station-specific | 4, 13 |
| Missingness bars | Percent missing by station/pollutant | Counts before/after hourly aggregation | Aggregation policy changes usable coverage | 11-13 |
| Gap-length distribution | Number of gaps by duration bucket | Masked long series/gap IDs | Long gaps require different policy from isolated gaps | 7, 13 |
| Constant-run view | Highlight repeated six-pollutant fill-code blocks | Fill-code flags/blocks | Complete data can still be synthetic | 5 |
| Before/after cleaning series | Raw, masked, causally filled, scorable markers | Clean CPCB experiment series | Filling inputs is separate from evaluation truth | 6-7 |
| Invalid-rule counts | Removed hours by pollutant/reason | Pollutant rule counts | Most CPCB removals come from fill codes | 6 |
| Scaling comparison | Original and [0,1] series, train min/max | One split and scaler values | Test is transformed using fixed pre-test parameters | 8 |
| Nested split timeline | Four horizon windows | Exact split dates | Horizon tests share an endpoint and overlap | 9 |
| Slot-to-hour diagram | Four slots and 2-of-4/3-of-4 outcomes | Illustrative slots | Hourly missingness is a chosen rule | 12 |
| Forecast-origin diagram | Allowed features through `t`, target at `t+h` | Feature specification | No future information should enter predictors | 14 |

No numerical plot should be generated from the general Shillong causal pipeline until its store and quality outputs are actually produced.
