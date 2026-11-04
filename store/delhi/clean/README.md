# Clean hourly store (Phase 1a)

Built by `Rscript run_preprocess.R` from `config/preprocess.yaml`.
No plots. Tables live in `store/DATA_QUALITY.md`.

## Time labelling

Hour **t** is the mean of readings whose interval ends in **(t − 1h, t]**.
A value stamped t is fully known at t. Start-labelled sources are shifted
forward by their native interval before binning. All timestamps are `Asia/Kolkata`.

Paper CSVs are already hourly and end-labelled; they are stored as-is
(`skip_preprocess: true`). Quality flags stay false except source NA,
and no causal fill is applied.

## `series.parquet`

- station
- variable
- timestamp
- value_hourly_raw
- n_sub_valid
- n_sub_expected
- value_masked
- value_filled_causal
- fill_method
- gap_id
- gap_len_sofar
- hours_since_observed
- in_long_gap
- frac_filled_24h
- frac_filled_168h
- is_na_source
- is_low_coverage
- is_duplicate_ts
- is_out_of_bounds
- is_negative
- is_stuck
- is_pm_ratio
- is_spike
- is_masked
- is_scorable

- `value_filled_causal` is a model input only. Never score it.
- `is_scorable = !is_masked`. Only scorable hours are evaluation targets.
- `fill_method` is NA on observed hours. A non-NA fill_method is never scorable.
- `gap_len_sofar` is causal (hours since the gap started). Total gap length is not stored.

## Other files

- `wide_<station>.parquet`: `value_filled_causal` plus `<var>_is_masked`.
- `daily_<station>.parquet`: IST calendar-day mean of scorable hours, days with ≥ min_daily_hours.
- `policy.yaml`: exclusion rules for later phases.
- `../quality/imputation_benchmark.parquet` (raw sources only; not written for paper).

## Dataset switch

- `active: paper` — CPCB.csv / ID1.csv, already hourly; quality and imputation are skipped.
- `active: delhi` — 15-min CPCB CAAQMS (ITO, R K Puram); full causal preprocess.
- `active: shillong` — 15-min CPCB CAAQMS (Lumpyngngad, JN Stadium); full causal preprocess.

Override: `Rscript run_preprocess.R paper`, `delhi`, or `shillong`.
