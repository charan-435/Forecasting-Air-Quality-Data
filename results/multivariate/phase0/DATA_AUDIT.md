# Phase 0 data audit: CPCB pollutant availability

Audit date: 2026-11-02. Repository snapshot: branch `lalit` at `38daa41` (same commit as `origin/kaisen`), with uncommitted edits to `WaveCatBoost.ipynb`, `results/mase_wide.csv` and `results/mcb.csv`. Read-only: nothing in the repository was changed.

## 1. What was inspected

| Source | Content | Used for B1/B2? |
|---|---|---|
| `data/raw/CPCB.csv` | Paper's CPCB station (Meghalaya). Hourly, 8 variables | Reference raw file |
| `store/clean/series.parquet` | Phase 1a long store, paper group (CPCB, ID1), `skip_preprocess: true` | **Yes, primary input** |
| `store/clean/wide_CPCB.parquet` | Wide view of the same values | Cross-check only |
| `data/raw/delhi/cpcb_delhi_2023.parquet` | CPCB CAAQMS, ITO (site_117) and R K Puram (site_124), 15 min, 2023 | Possible later replication |
| `data/raw/shillong/shillong_15min_2023.parquet` | CPCB CAAQMS, Lumpyngngad (site_5131) and JN Stadium (site_5593), 15 min, 2023 | Possible later replication |
| `data/raw/ID1.csv` | Low-cost sensor from the paper (not CPCB) | Out of scope |
| `data/processed/series.rds`, `.RData`, `data/processed/SHILLONG.csv` | v1 objects built with the deprecated full-series imputer | Must not be used |

Present in the code and docs but **not in the uploaded archive**: `store/decomp/` (no decomposition store at all), any T1 experiment output, `store/DATA_QUALITY.md`, `store/quality/`, `store/delhi/`, `store/shillong/`, and the `audit/tests/` and `audit/impact/` folders that `audit/AUDIT.md` refers to.

## 2. Availability per pollutant (CPCB)

Values from `store/clean/series.parquet` (`value_filled_causal`), checked against `data/raw/CPCB.csv`. Full tables: `pollutant_availability_cpcb_raw.csv`, `pollutant_availability_clean_store.csv`.

| Pollutant | Store unit | Start (IST) | End (IST) | Step | Rows | Missing timestamps | Duplicate timestamps | NA / non-finite | Negative | Out of bounds | Zeros | Constant-fill hours | Min / median / max (raw file) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PM2.5 | µg/m³ | 2022-07-01 00:00 | 2023-07-05 23:00 | 60 min | 8,880 | 0 | 0 | 0 | 0 | 0 | 0 | 2,304 | 0.28 / 11.88 / 66.80 |
| PM10 | µg/m³ | 2022-07-01 00:00 | 2023-07-05 23:00 | 60 min | 8,880 | 0 | 0 | 0 | 0 | 0 | 0 | 2,304 | 0.32 / 19.94 / 392.74 |
| NO2 | µg/m³ | 2022-07-01 00:00 | 2023-07-05 23:00 | 60 min | 8,880 | 0 | 0 | 0 | 0 | 0 | 0 | 2,304 | 1.77 / 2.18 / 25.89 |
| SO2 | µg/m³ | 2022-07-01 00:00 | 2023-07-05 23:00 | 60 min | 8,880 | 0 | 0 | 0 | 0 | 0 | 0 | 2,304 | 2.92 / 4.97 / 9.83 |
| O3 | µg/m³ | 2022-07-01 00:00 | 2023-07-05 23:00 | 60 min | 8,880 | 0 | 0 | 0 | 0 | 0 | 0 | 2,304 | 0.19 / 0.68 / 34.52 |
| CO | mg/m³ (raw file µg/m³, divided by 1000 in the store) | 2022-07-01 00:00 | 2023-07-05 23:00 | 60 min | 8,880 | 0 | 0 | 0 | 0 | 0 | 31 | 2,304 | 0 / 233.0 / 1,332 µg/m³ |

Bounds are those in `config/preprocess.yaml`. AT and RH have the same grid and are also complete.

Points behind the table:

1. **Grid.** The raw file has 8,881 rows. Its last row (2023-07-06 00:00) is an exact copy of row 1 (AUDIT F15). `adapter_paper_cpcb_csv` drops it, so the store has 8,880 rows on a regular hourly grid with no gaps and no duplicates. Store values equal the raw values exactly (CO divided by 1000).
2. **Constant-fill blocks (main finding).** 2,304 hours (25.9%) carry one fixed vector across all eight variables: PM2.5 11.884, PM10 19.944, NO2 2.176, SO2 4.966, O3 1.171, CO 233.04 µg/m³, AT 23.34, RH 72.36. These values are close to, but not equal to, the mean of the remaining hours (for example PM2.5 11.88 against 12.17, O3 1.171 against 1.174). This looks like a mean fill applied upstream before the CSV was published. The blocks fall on fixed calendar days (`cpcb_frozen_blocks_ge24h.csv`):

   | Period | Filled days each month | Hours per month |
   |---|---|---|
   | Jul to Dec 2022 | days 1 to 6 | 144 |
   | Jan to May 2023 | days 6 to 12 | 168 |
   | Jun 2023 | days 6 to 30 | 600 |

   The regular pattern suggests a processing artefact rather than random sensor outages. The cause cannot be determined from the file. The store marks all of these hours as observed (`is_masked = FALSE`, `is_scorable = TRUE`, `fill_method = NA`), because paper sources skip quality control.
3. **Other repeated hours.** A further 256 hours repeat the previous hour exactly on all six pollutants. 175 of them sit in runs of 6 h or more, for example 2022-07-13 00:00 to 2022-07-14 10:00 (35 h) and the whole of 7 Oct, 7 Nov and 7 Dec 2022 (24 h each). Most of the rest are 3-hour repeats from 02:00 to 04:00 on many days in 2023. Single-pollutant repeats also occur (CO 277, NO2 53, PM2.5 37, O3 37, SO2 28, PM10 14); the CO ones look like value quantisation and are not treated as faults.
4. **The end of the series is mostly fill.** Of the last 744 hours, 600 are fill. Of the last 336, 216. Of the last 168, 48. The last 24 are clean. This is why the conformal calibration tail in AUDIT F6 was flat.
5. **Impossible values.** None. No negatives, nothing outside the configured bounds, no non-finite values. CO has 31 exact zeros, which are plausible readings near the detection limit.

## 3. Common timestamp intersection

All six pollutants are recorded on the same 8,880-hour grid with no missing values. Machine-readable: `alignment_summary_cpcb.csv`, `monthly_target_scorability_cpcb.csv`.

| Quantity | Value |
|---|---|
| Union grid | 8,880 hours, 2022-07-01 00:00 to 2023-07-05 23:00 IST |
| Common hours with all six pollutants finite | 8,880 (100% retained) |
| Missingness per pollutant after alignment | 0 for every pollutant |
| Hours not usable as targets (constant fill plus all-six runs of 6 h or more) | 2,479 (27.9%) |
| Scorable target hours | 6,401 (72.1%) |
| Hours left after the 2,047-hour MRA warm-up needed by B2 | 6,833 |
| Scorable target hours after warm-up | 4,878 (71.4%) |

Scorable share by month: 73.5% to 78.4% from Jul 2022 to May 2023, **16.7% in Jun 2023**, 100% for 1 to 5 Jul 2023.

Mask definition, as used in the split counts:

- Not scorable as a target: constant-fill hours (2,304) plus hours inside all-six repeat runs of 6 h or more (175). 2,479 hours in total.
- Flagged as input, for the origin and training-row rules: constant-fill hours plus every hour that repeats the previous hour on all six pollutants (256). 2,560 hours in total.

The mask is row-level: every flagged hour is flagged for all six pollutants at once. Sample sets are therefore identical for every target pollutant and for B1 and B2. The proposed mask is in `proposed_quality_mask_cpcb.csv` (one row per hour).

## 4. Is the common dataset suitable for multivariate forecasting?

Yes, with conditions.

- All six pollutants are usable. None has to be dropped, and no imputation is needed because nothing is missing.
- The constant-fill hours must be masked as targets. Scoring forecasts against them would measure how well a model reproduces a constant, and the fill state is shared by all six pollutants, so a multivariate model can detect it and score artificially well inside the blocks.
- Nothing has been discarded or imputed in this audit. The mask is an overlay on `store/clean` and leaves the store unchanged.
- June 2023 is 83% fill. The final weeks cannot carry a long-horizon test on their own, which shapes the split (see `SPLIT_PROPOSAL.md`).
- Some pollutants have very little dynamic range (SO2 2.9 to 9.8, NO2 median 2.18). MASE, rather than MAE, is needed to compare across targets.

## 5. Other CPCB stations in the repository

The 15-min CAAQMS extracts cover calendar 2023. The share of hours with at least 3 of 4 valid 15-min readings (the `min_subhour_coverage: 0.75` rule) is in `pollutant_availability_other_cpcb_stations.csv`:

| Station | PM2.5 | PM10 | NO2 | SO2 | O3 | CO |
|---|---|---|---|---|---|---|
| ITO, Delhi | 91.6% | 91.8% | 89.9% | 91.2% | 92.4% | 91.8% |
| R K Puram, Delhi | 93.6% | 91.5% | 86.4% | 74.8% | 86.3% | 73.1% |
| Lumpyngngad, Shillong | 77.7% | 51.0% | 73.9% | 93.6% | 93.0% | 93.8% |
| JN Stadium, Shillong | 31.9% | 33.6% | 36.5% | 36.5% | 20.2% | 36.9% |

These would need the Phase 1a causal preprocessing (`Rscript run_preprocess.R delhi`, `... shillong`) before use; those stores are not in the upload. ITO is the best candidate for a later replication. JN Stadium is unsuitable. The primary study stays on CPCB, as the protocol specifies.

## 6. Side notes

- ID1 (not CPCB): CO is labelled mg/m³ in `config/preprocess.yaml`, but 5,504 of 9,505 hours exceed the 50 mg/m³ bound (median 78). The unit label is probably wrong. Not relevant to this study.
- `data/processed/series.rds`, `.RData` and `data/processed/SHILLONG.csv` come from the v1 path that uses `impute_hourly()` on the full series (AUDIT F10). Do not use them as inputs.
