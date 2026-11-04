# T1-Tuned — component-wise hyperparameter optimization

Architecture map is **frozen** from the T1 CPCB PM2.5 1d validation selection.
Only hyperparameters are searched. Test metrics are stored after selection and are not used to pick trials.

## Frozen pipeline (reused, not duplicated)

- Series: `data/processed/series.rds` via `t1_load_prepared_series()`.
- Decomposition: stored `mra_haar_J5__raw` via `t1_load_stored_components()` / `get_decomp()`.
- Splits: `chrono_split_tvt` (`t1_split_y`), val_hours=336.
- Scaling: train-window `minmax_fit` / `minmax_apply` / `minmax_invert` for trees and DLinear; SARIMA native scale.
- Inputs: `t1_independent_lags` / `make_lags` on the target component only.
- Forecast: `recursive_tree_forecast` (trees), `t1_forecast_dlinear`, `forecast_arima_obj`.
- Reconstruction: `Y_hat = D1_hat + D2_hat + D3_hat + D4_hat + D5_hat + S5_hat` via `t1_build_reconstructed()`.
- Metrics: `score_forecast` (MASE/MAE/RMSE).
- Outputs only under `results/teammate_1/tuned/`. Original T1 files are not overwritten.

## Frozen architecture map

- D1 → **LightGBM** (architecture frozen from T1; not re-selected)
- D2 → **LightGBM** (architecture frozen from T1; not re-selected)
- D3 → **DLinear** (architecture frozen from T1; not re-selected)
- D4 → **CatBoost** (architecture frozen from T1; not re-selected)
- D5 → **SARIMA** (architecture frozen from T1; not re-selected)
- S5 → **DLinear** (architecture frozen from T1; not re-selected)

## Search protocol

- Objective: validation MASE of the component forecast (not reconstructed Y, not test).
- Frozen T1 hyperparameters are always trial 0 and win ties.
- LightGBM random trials (plus frozen): 24. Space: num_leaves, max_depth, eta, nrounds, min_child_samples, feature_fraction, lambda_l1/l2. `p` stays 24.
- CatBoost random trials (plus frozen): 10. Space: depth, eta, iterations, l2_leaf_reg, random_strength, bagging_temperature.
- DLinear: exhaustive `p` × `kernel` only (OLS implementation has no lr/epochs/batch/dropout).
- SARIMA: T1 frozen auto.arima (nonseasonal) + seasonal auto.arima + bounded (p,d,q) and a small seasonal subset at period 24.
- Early stopping uses the original inner `split_val` tail of the current history window.

## Run configuration

- Mode: `cpcb`
- Sensors: CPCB
- Horizons: 1d
- Validation trials recorded: 119

## Selected hyperparameters (validation only)

- CPCB PM2.5 D1 / LightGBM: trial  4 frozen=FALSE val MASE=0.405 hparams={"p":24,"nrounds":160,"max_depth":-1,"eta":0.03,"lgb_leaves":15,"min_child_samples":30,"feature_fraction":0.7,"lambda_l1":0.1,"lambda_l2":0,"early_stopping":30,"val_hours":336,"trial_id":4,"is_frozen":false}
- CPCB PM2.5 D2 / LightGBM: trial  7 frozen=FALSE val MASE=0.358 hparams={"p":24,"nrounds":200,"max_depth":7,"eta":0.05,"lgb_leaves":31,"min_child_samples":30,"feature_fraction":0.8,"lambda_l1":0,"lambda_l2":1,"early_stopping":30,"val_hours":336,"trial_id":7,"is_frozen":false}
- CPCB PM2.5 D3 / DLinear: trial  7 frozen=FALSE val MASE=0.501 hparams={"p":24,"kernel":49,"trend":"causal_moving_average","seasonal":"ols_linear","note":"OLS DLinear: no lr/epochs/batch/dropout","trial_id":7,"is_frozen":false}
- CPCB PM2.5 D4 / CatBoost: trial  5 frozen=FALSE val MASE=0.403 hparams={"p":24,"nrounds":600,"max_depth":10,"eta":0.08,"l2_leaf_reg":3,"random_strength":0,"bagging_temperature":0,"early_stopping":30,"val_hours":336,"trial_id":5,"is_frozen":false}
- CPCB PM2.5 D5 / SARIMA: trial 40 frozen=FALSE val MASE=0.182 hparams={"arimaorder":[3,0,1,0,0,1,24],"spec_id":"s_301_001","seasonal":true,"kind":"fixed","trial_id":40,"is_frozen":false}
- CPCB PM2.5 S5 / DLinear: trial 10 frozen=FALSE val MASE=0.130 hparams={"p":48,"kernel":25,"trend":"causal_moving_average","seasonal":"ols_linear","note":"OLS DLinear: no lr/epochs/batch/dropout","trial_id":10,"is_frozen":false}

## Reconstructed PM2.5

- `CPCB|PM2.5|1d`: T1-Tuned MASE=0.935 MAE=3.962 RMSE=4.903 | T1-untuned MASE=0.789 | WaveCatBoost MASE=0.712 | raw LightGBM MASE=0.737 | all six=TRUE

## Files

- `tuning_trials.csv`
- `selected_hparams.csv` / `best_models.csv`
- `component_metrics.csv`
- `component_predictions.rds`
- `heterogeneous_predictions.rds`
- `reconstructed_predictions.rds`
- `plots/`

This report is filled from a real `run_teammate_1_tuned.R` run, not placeholder numbers.
See `tests_executed.md` for tests that were actually run.

