# Phase 1 dataset report: B0 and B1 (UNMASKED)

All results in this folder are **UNMASKED**. Following the selected experimental decision, no quality mask is applied. All 8,880 aligned hours are kept, including the 2,304 upstream constant-fill hours documented in `results/multivariate/phase0/DATA_AUDIT.md`. No target, origin or training row is excluded because it is flagged, and no origin threshold is applied. The Phase 0 quality analysis and mask file are kept unchanged in `results/multivariate/phase0/`. They are used here only for reporting, in this file and in `diagnostics/`.

## 1. Source and verification

| Item | Value |
|---|---|
| Source | `store/clean/series.parquet`, station `CPCB`, column `value_filled_causal` |
| File SHA-256 | `93c62ca44d3e0ebb79e3bea0a1852e048497ff41222740fcab14a807ad6d2e96` |
| Join | six pollutant series matched on the timestamp instant (seconds since epoch) |
| Hours | 8,880, from 2022-07-01 00:00 to 2023-07-05 23:00 IST, step 3,600 s |
| Duplicates | 0 in the panel and in each pollutant |
| Missing values | 0 |
| Timestamps across pollutants | identical instants for all six |
| Ordering | strictly ascending, hourly |
| Pollutant order | PM2.5, PM10, NO2, SO2, O3, CO |

Units were checked against `config/preprocess.yaml` canonical units and bounds, and match:

| Pollutant | Unit | Min | Median | Max |
|---|---|---|---|---|
| PM2.5 | µg/m³ | 0.280 | 11.884 | 66.80 |
| PM10 | µg/m³ | 0.320 | 19.944 | 392.74 |
| NO2 | µg/m³ | 1.766 | 2.176 | 25.89 |
| SO2 | µg/m³ | 2.921 | 4.966 | 9.83 |
| O3 | µg/m³ | 0.186 | 0.685 | 34.52 |
| CO | mg/m³ | 0.000 | 0.233 | 1.33 |

CO is in mg/m³ in the store because the ingest step divides the paper CSV's µg/m³ values by 1000. The raw CSV, the legacy preprocessing, `imputeTS` and the two-sided MRA helpers are not used or sourced (tests T17 and T13). Nothing was scaled.

## 2. Split (S3) and sample rules

| Block | Start (IST) | End (IST) | Hours | Store rows (1-based) | First origin |
|---|---|---|---|---|---|
| Train | 2022-09-24 07:00 | 2023-01-31 23:00 | 3,113 | 2,048 to 5,160 | 2022-09-25 06:00 |
| Validation | 2023-02-01 00:00 | 2023-04-03 23:00 | 1,488 | 5,161 to 6,648 | 2023-02-01 00:00 |
| Test | 2023-04-04 00:00 | 2023-07-05 23:00 | 2,232 | 6,649 to 8,880 | 2023-04-04 00:00 |

The rows before 2022-09-24 07:00 are not used, so B1 and later B2 share the same timestamps.

- Each sample has its origin t and its target t + h in the same block.
- The 24 lags (t, ..., t-23) may reach into the immediately preceding block: validation lags start at 2023-01-31 01:00 and test lags at 2023-04-03 01:00. Training lags start at the training block start.
- No target crosses a block boundary.
- The final refit uses the union of train and validation samples. Samples whose origin is in train and target in validation are not used, since their target would cross a boundary.

## 3. Sample counts (unmasked, recalculated)

Full table: `SAMPLE_COUNTS.csv`. "Eligible origins" are block hours with a full 24-hour lookback. "Samples" are those eligible origins whose target t + h also falls inside the block.

| h | Block | Eligible origins | Samples | First origin | Last origin | First target | Last target |
|---|---|---|---|---|---|---|---|
| 24 | train | 3,090 | 3,066 | 2022-09-25 06:00 | 2023-01-30 23:00 | 2022-09-26 06:00 | 2023-01-31 23:00 |
| 24 | validation | 1,488 | 1,464 | 2023-02-01 00:00 | 2023-04-02 23:00 | 2023-02-02 00:00 | 2023-04-03 23:00 |
| 24 | test | 2,232 | 2,208 | 2023-04-04 00:00 | 2023-07-04 23:00 | 2023-04-05 00:00 | 2023-07-05 23:00 |
| 168 | train | 3,090 | 2,922 | 2022-09-25 06:00 | 2023-01-24 23:00 | 2022-10-02 06:00 | 2023-01-31 23:00 |
| 168 | validation | 1,488 | 1,320 | 2023-02-01 00:00 | 2023-03-27 23:00 | 2023-02-08 00:00 | 2023-04-03 23:00 |
| 168 | test | 2,232 | 2,064 | 2023-04-04 00:00 | 2023-06-28 23:00 | 2023-04-11 00:00 | 2023-07-05 23:00 |
| 336 | train | 3,090 | 2,754 | 2022-09-25 06:00 | 2023-01-17 23:00 | 2022-10-09 06:00 | 2023-01-31 23:00 |
| 336 | validation | 1,488 | 1,152 | 2023-02-01 00:00 | 2023-03-20 23:00 | 2023-02-15 00:00 | 2023-04-03 23:00 |
| 336 | test | 2,232 | 1,896 | 2023-04-04 00:00 | 2023-06-21 23:00 | 2023-04-18 00:00 | 2023-07-05 23:00 |
| 744 | train | 3,090 | 2,346 | 2022-09-25 06:00 | 2022-12-31 23:00 | 2022-10-26 06:00 | 2023-01-31 23:00 |
| 744 | validation | 1,488 | 744 | 2023-02-01 00:00 | 2023-03-03 23:00 | 2023-03-04 00:00 | 2023-04-03 23:00 |
| 744 | test | 2,232 | 1,488 | 2023-04-04 00:00 | 2023-06-04 23:00 | 2023-05-05 00:00 | 2023-07-05 23:00 |

Refit (train plus validation) samples: 4,530 (h = 24), 4,242 (168), 3,906 (336), 3,090 (744).

All 48 count and timestamp cells match an independent calculation (`tests/multivariate/expected_counts.R`), which uses only the calendar strings in the config and clock arithmetic (test T14; column `matches_expected`). The masked Phase 0 counts were not reused. For example, the h = 24 test block has 2,208 samples here against 1,146 under the Phase 0 mask.

## 4. Constant-fill hours kept in each block (reference only)

Counted with the Phase 0 mask file for reporting. Nothing was excluded.

| h | Train fill targets | Validation fill targets | Test fill targets |
|---|---|---|---|
| 24 | 600 of 3,066 (19.6%) | 336 of 1,464 (23.0%) | **936 of 2,208 (42.4%)** |
| 168 | 570 of 2,922 (19.5%) | 288 of 1,320 (21.8%) | 816 of 2,064 (39.5%) |
| 336 | 456 of 2,754 (16.6%) | 168 of 1,152 (14.6%) | 768 of 1,896 (40.5%) |
| 744 | 456 of 2,346 (19.4%) | 168 of 744 (22.6%) | **768 of 1,488 (51.6%)** |

The test block includes the 600-hour fill period of 6 to 30 June 2023. Test metrics therefore mix real hours with constant-fill hours, and the constant-fill share rises with the horizon. Test T12 confirms that every fill target in each block's target range is present in the datasets.

## 5. Features

| Design | Inputs | Columns | Order | Manifest |
|---|---|---|---|---|
| B0 | PM2.5 only | 24 | `PM2.5__lag00` to `PM2.5__lag23` | `FEATURE_MANIFEST_B0.csv` |
| B1 | six pollutants | 144 | PM2.5, PM10, NO2, SO2, O3, CO; lags 00 to 23 within each | `FEATURE_MANIFEST_B1.csv` |

`<pollutant>__lagKK` is the value at origin t minus KK hours (KK = 00 to 23). Target: y(t, h) = PM2.5(t + h), on the original scale, with one dataset per horizon. B0's 24 columns are identical to the first 24 columns of B1, and the two designs share exactly the same samples (identical `y_sha256` and `origins_sha256` in `DATASET_HASHES.csv`).

Leakage checks on the features (all passed, see `TEST_SUMMARY.md`):
- Values were checked cell by cell against the store, using timestamp lookup (T06).
- X(t) did not change when every pollutant after t was overwritten, when only PM10, NO2, SO2, O3 and CO after t were overwritten, or when t-24 was changed. It did change when t or t-23 was changed (T07).
- Targets are exactly h hours after the origin (T08).
- Block membership holds for every horizon (T09 to T11).

## 6. MASE denominator (unmasked)

The seasonal-naive (lag 24) MAE of the PM2.5 series inside the training block (2022-09-24 07:00 to 2023-01-31 23:00): **4.1124 µg/m³**, from 3,089 pairs, constant-fill hours included. This is the primary denominator for every block, with the same formula as `R/08_metrics.R` (test T18). As an alternative, test rows also carry `MASE_refit_scale`, which uses the train plus validation series (4.9768, 4,577 pairs).

## 7. Reproducibility record

- `DATASET_MANIFEST.json`: source, hash, reader, pollutant order, units, timestamp boundaries, split dates and row indices, lookback, horizons, feature names in order, quality mask = none, seed, bootstrap settings, MASE scales, package versions, config and code hashes.
- `DATASET_HASHES.csv`: SHA-256 of X, y and origins for each design, horizon and block that was run.
- `RUN_METADATA.json`: run time, designs, horizons, seed, elapsed time, package versions, outputs.

This run used R 4.3.3, lightgbm 4.7.0 and **nanoparquet 0.5.2**. CRAN was not reachable from the build sandbox, so `arrow` could not be installed and lightgbm was built from CRAN's GitHub source mirror. The data layer prefers `arrow` when it is installed and records which reader was used. I checked that the nanoparquet values and instants are bit-identical to a pyarrow read of the same file, so dataset hashes should match on your machine. Model metrics may differ slightly if your lightgbm version is not 4.7.0.

## 8. Files

| File | Content |
|---|---|
| `DATASET_REPORT.md` | this report |
| `SAMPLE_COUNTS.csv` | per horizon and block counts, timestamps, independent expected counts, match flag |
| `FEATURE_MANIFEST_B0.csv`, `FEATURE_MANIFEST_B1.csv` | position, name, pollutant, lag, unit |
| `MODEL_CONFIG.yaml` | configured and effective LightGBM parameters, selection and refit rules, selected iterations |
| `SMOKE_RESULTS.csv`, `SMOKE_COMPARISON.csv`, `SMOKE_PREDICTIONS.csv` | smoke metrics, paired B1 vs B0 comparison, predictions |
| `SMOKE_REPORT.md` | smoke experiment report |
| `DATASET_MANIFEST.json`, `DATASET_HASHES.csv`, `RUN_METADATA.json` | hashes and run metadata |
| `TEST_SUMMARY.md`, `TEST_SUMMARY.csv` | test execution summary (22 of 22 passed) |
| `diagnostics/` | diagnostic-only split of errors by fill and non-fill target, plus a seasonal-naive reference |
