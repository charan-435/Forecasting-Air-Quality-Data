# T1-Tuned changelog

## 2026-11-02 — component-wise hyperparameter optimization

- Added `R/teammate_1/t1_tuned.R` and `run_teammate_1_tuned.R`.
- Architecture map frozen from T1 CPCB PM2.5 1d: D1/D2 LightGBM, D3 DLinear, D4 CatBoost, D5 SARIMA, S5 DLinear.
- Hyperparameters selected on validation MASE only; test evaluated after selection.
- Reuses T1 loaders, `chrono_split_tvt`, MinMax, independent lags, reconstruction, and scoring. Does not recompute MODWT.
- Outputs under `results/teammate_1/tuned/` only (original T1 and bake-off results untouched).
- Safeguard tests added in `tests/teammate_1/05_tuned.R` (suite: 64 PASS / 0 FAIL).
- CPCB PM2.5 1d run executed successfully (~3.5 h wall time, 119 validation trials).
- Full CPCB+ID1 four-horizon mode is implemented (`Rscript run_teammate_1_tuned.R full`) but was **not** executed in this session.
