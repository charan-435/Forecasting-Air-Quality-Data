# Intercomponent EDA — reproducibility

## Reproduce

From the project root:

```bash
Rscript run_intercomponent_eda.R
```

This sources:

- `R/load_all.R` — shared project constants and helpers
- `R/teammate_1/t1_pipeline.R` — stored-decomp loader, alignment, `chrono_split_tvt` wrappers
- `R/teammate_1/intercomponent_eda.R` — analyses A–E

Outputs are written only under `results/intercomponent_eda/`. Original T1 results are not modified. No forecasting models are trained.

## Data handling

- Series: `data/processed/series.rds` via `t1_load_prepared_series()`.
- Decomposition: stored `mra_haar_J5__raw` parquet via `get_decomp()` / `t1_load_stored_components()` (not recomputed).
- Alignment: timestamp hour-key matching in `t1_align_components()`.
- Missing values: warm-up / invalid MRA flags stay NA; rows used in pairwise stats require all six components finite (`complete.cases`). No imputation or interpolation.
- Splits: `chrono_split_tvt` with nested test horizon h=24 and `VAL_HOURS=336`. Discovery uses train; validation confirms; test is unused for decisions.

## Lag convention

`Corr(target(t), predictor(t − k))` for `k = 0..24`.
`k ≥ 1` means the predictor is in the past of the target (forecast-usable).

## Key parameters

| Parameter | Value |
|---|---|
| Components | D1, D2, D3, D4, D5, S5 |
| Own-history AR order | 24 |
| Max cross lag | 24 |
| MI bins | 10 quantiles |
| Block bootstrap | block 24 h, 200 reps, seed 7 |
| Rolling window / step | 336 h / 24 h |

## Packages

Base R `stats`, plus project stack: `readr`, `dplyr`, `tidyr`, `ggplot2`, `tibble`, `jsonlite`, and whatever `R/load_all.R` attaches for parquet IO.
