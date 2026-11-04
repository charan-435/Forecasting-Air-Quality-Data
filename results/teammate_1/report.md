# T1 Frequency-specific model selection

Independent per-component forecasts of stored Haar MODWT/MRA bands **D1–D5** and **S5**.
Cross-frequency features are out of scope (T2). Original WaveCatBoost is not modified.

## Frozen pipeline

- Decomposition: stored `mra_haar_J5__raw` via `get_decomp()` (never recomputed).
- Preprocess / imputation / MinMax helpers: original `R/03_preprocess.R`.
- Splits: `chrono_split_tvt` with nested last-h test windows and val_hours=336.
- Horizons (hours): 24, 168, 336, 744.
- Forecast origin: end of train (val stage) or end of train+val (test stage).
- Leakage control: recursive h-step; lags from the target component only.
- Tree hyperparameters source: Chosen p=24, depth=6, eta=0.05 from LGBM time-based CV (val MASE=1.848). WaveLGBM CV picked J=9; modelling uses K=J=5 (32 h cap).
- Component SARIMA: same `auto.arima(..., seasonal=FALSE, max.p=3, max.q=1, max.d=1)` call as `wave_fit_sarima()`.
- DLinear: causal moving-average + two OLS linear maps (Zeng et al. 2023 structure, no Torch). Kernel chosen on validation only.
- Reconstruction: `Y_hat = D1_hat + D2_hat + D3_hat + D4_hat + D5_hat + S5_hat`.
- Outputs written only under `results/teammate_1/`.

## Run configuration

- Mode: `smoke`
- Sensors: CPCB
- Pollutants: PM2.5
- Horizons: 1d
- Models: LightGBM, XGBoost, CatBoost, SARIMA, DLinear
- Random seed recorded: 7 (CatBoost/DLinear/SARIMA). XGBoost/LightGBM match original unseeded fitters.

## Heterogeneous selection (validation only)

Best model per component = lowest mean validation MASE across the horizons in this run.
Test metrics were stored for comparison but **were not read by `t1_select_best()`**.

- CPCB PM2.5 D1 -> **LightGBM** (mean val MASE=0.415)
- CPCB PM2.5 D2 -> **LightGBM** (mean val MASE=0.372)
- CPCB PM2.5 D3 -> **DLinear** (mean val MASE=0.513)
- CPCB PM2.5 D4 -> **CatBoost** (mean val MASE=0.422)
- CPCB PM2.5 D5 -> **SARIMA** (mean val MASE=0.184)
- CPCB PM2.5 S5 -> **DLinear** (mean val MASE=0.155)

## Reconstructed PM2.5 vs original bake-off

- `CPCB|PM2.5|1d`: T1 reconstructed MASE=0.789 MAE=3.344 RMSE=4.273 | WaveCatBoost MASE=0.712 | all six components=TRUE

## Metric files

- `component_metrics.csv`
- `component_predictions.rds`
- `best_models.csv`
- `heterogeneous_predictions.rds`
- `reconstructed_predictions.rds`
- `plots/`

- Validation rows: 30. Test rows: 30.

## Tests actually executed

See `tests_executed.md`. Safeguard suite: `Rscript tests/teammate_1/run_all.R`.
This report is filled from a real `run_teammate_1.R` run, not placeholder numbers.

## Smoke inspection notes

- This folder currently holds the **CPCB PM2.5 1d smoke run**, not the four-horizon CPCB+ID1 benchmark.
- Component test scores use `n_eval=23` of 24 hours: `series.rds` is one hour longer than the stored parquet at the tail. MASE/MAE/RMSE are computed on finite pairs only.
- Tree hyperparameters were **not** replaced with defaults: `p=24`, `max_depth=6`, `eta=0.05`, `nrounds=160` from `results/hparams.rds`.
- Reconstructed 1d MASE **0.789** vs original WaveCatBoost **0.712** and raw LightGBM **0.737** (from `results/scores.csv`). T1 is close but does not beat WaveCatBoost on this smoke cell.
- Full benchmark: `Rscript run_teammate_1.R full` (not executed here).

## What this run is not

- Not a recompute of MODWT.
- Not T2 cross-frequency modelling.
- Not a replacement of original `results/scores.csv` / WaveCatBoost.

