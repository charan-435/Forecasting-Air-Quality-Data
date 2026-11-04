# B2 changelog

## 2026-11-02 — initial decomposed multivariate pipeline

- Built B2 from scratch under `R/b2/` and `run_b2.R`.
- Reuses stored `mra_haar_J5__raw` for all six CPCB pollutants (not recomputed).
- Feature space: 6×6×24 = 864 lagged components; direct fixed-horizon supervision.
- Setups: B2.0 univariate-direct LightGBM, B2.1 separate multivariate LightGBM, B2.2 shared LightGBM with component-id one-hot.
- Reconstruction: sum of six PM2.5 component forecasts.
- Safeguard tests: `tests/b2/` (20 PASS).
- Outputs only under `results/b2/`. T1, stored decomps, and B1 paths untouched.
- Modes: `smoke`, `stageA`, `full` (Stage B classical models + FS/DR on 1d).
