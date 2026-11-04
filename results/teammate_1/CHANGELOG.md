# T1 changelog

## 2026-11-02 — frequency-specific model selection

- Added isolated runner `run_teammate_1.R` and `R/teammate_1/t1_pipeline.R`.
- Loads stored `mra_haar_J5__raw` via `get_decomp()`; does not recompute MODWT.
- Independent LightGBM / XGBoost / CatBoost / SARIMA / DLinear models per D1–D5 / S5.
- Tree hyperparameters taken from `results/hparams.rds` (p=24, depth=6, eta=0.05, nrounds=160). DLinear kernel is validation-only.
- Validation-only heterogeneous selection, additive reconstruction, outputs only under `results/teammate_1/`.
- Safeguard tests in `tests/teammate_1/` (41/41 passed).
- Smoke run executed: CPCB PM2.5, 24-hour horizon, all five models, six components.
- Full 4-horizon CPCB+ID1 benchmark is implemented (`Rscript run_teammate_1.R full`) but was **not** executed in this session.
- Original WaveCatBoost, preprocess, stored decomposition, and T2 paths are not modified.
)
