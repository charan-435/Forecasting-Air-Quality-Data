# Methodology Reference

## Direct fixed-horizon forecasting
At origin \(t\), a separate model \(f_h\) predicts \(y_{t+h}\) from \(X_t\). The study uses horizons of 24, 168, 336 and 744 hours. Direct forecasting prevents one-step prediction errors from recursively feeding into later inputs.

## Causal missing-value treatment
For Shillong, invalid/stuck/low-coverage readings are masked and causal filling may be used as model input. Evaluation targets are observed, unmasked target hours only. CPCB paper files explicitly skip preprocessing in the Phase 1/2 studies.

## Haar MODWT/MRA
Shillong uses a causal J=5 Haar additive decomposition. MRA components represent approximately 2–4, 4–8, 8–16, 16–32, 32–64 and >64-hour bands. Component forecasts are summed exactly at reconstruction.

## Moving-block bootstrap
A paired moving-block bootstrap resamples data blocks to preserve temporal dependence. It estimates uncertainty for MAE ratios/differences. It is not a prediction interval. Shillong reports 999 replicates with block lengths selected from the data; sensitivity uses 24- and 168-hour blocks.

## MASE
\[
MASE = \frac{MAE(forecast)}{MAE(y_t-y_{t-24})_{train}}
\]
For horizons that are multiples of 24, persistence and seasonal-naive are identical.

## Validation/refit protocol
- Fit/tune on train using validation for selection or early stopping.
- Refit the selected configuration on train + validation.
- Freeze selected iteration/penalty/configuration.
- Predict test without fitting or tuning on test labels.

## Implemented model families
- LightGBM, XGBoost and CatBoost trees
- Ridge, Lasso and Elastic Net
- Legacy ARIMA/SARIMA and WaveSARIMA paths
- Legacy conformal implementation, which is audited but not part of the clean direct-study evidence
