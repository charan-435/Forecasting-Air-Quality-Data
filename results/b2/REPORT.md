# B2 — Decomposed Multivariate Forecasting (CPCB UNMASKED)

## Objective

Does forecasting each PM2.5 Haar MRA component with 864 multivariate lags
(6 pollutants × 6 components × 24 hours) beat univariate own-history component forecasting?

- Mode: `stageA`
- Sensor: `CPCB`  Label: `UNMASKED`  Decomp: `mra_haar_J5__raw`
- Strategy: `direct_fixed_horizon` (no recursive / hybrid in this track)
- Feature count (full): **864**

## Decomposition audit

- PM2.5: complete6=6833 aligned=6833 md5=`3d1a72b96033c1ea33f1693307c5bf34`
- PM10: complete6=6833 aligned=6833 md5=`d9a7aac0fe2d393a4753c89a7b075807`
- NO2: complete6=6833 aligned=6833 md5=`86197137f042fd9227d03caa85758bf4`
- SO2: complete6=6833 aligned=6833 md5=`132ca409cac8fd90c29214e0ff94baa8`
- O3: complete6=6833 aligned=6833 md5=`cb5155e48fa3c38d26b9456e6ac53c0c`
- CO: complete6=6833 aligned=6833 md5=`32b7e591dd80f19808c334a883e10f4e`

Warmup / invalid basic rows stay NA; no future-looking imputation.

## Component test metrics

- B2.0_univariate_direct | D1 | h= 24: MASE=0.709 MAE=1.472
- B2.0_univariate_direct | D1 | h=168: MASE=1.090 MAE=2.289
- B2.0_univariate_direct | D1 | h=336: MASE=1.204 MAE=2.519
- B2.0_univariate_direct | D1 | h=744: MASE=1.202 MAE=2.431
- B2.0_univariate_direct | D2 | h= 24: MASE=0.686 MAE=0.916
- B2.0_univariate_direct | D2 | h=168: MASE=1.137 MAE=1.538
- B2.0_univariate_direct | D2 | h=336: MASE=1.079 MAE=1.462
- B2.0_univariate_direct | D2 | h=744: MASE=0.963 MAE=1.269
- B2.0_univariate_direct | D3 | h= 24: MASE=0.742 MAE=0.869
- B2.0_univariate_direct | D3 | h=168: MASE=1.204 MAE=1.425
- B2.0_univariate_direct | D3 | h=336: MASE=1.014 MAE=1.199
- B2.0_univariate_direct | D3 | h=744: MASE=0.850 MAE=0.986
- B2.0_univariate_direct | D4 | h= 24: MASE=1.068 MAE=1.299
- B2.0_univariate_direct | D4 | h=168: MASE=1.314 MAE=1.613
- B2.0_univariate_direct | D4 | h=336: MASE=1.158 MAE=1.418
- B2.0_univariate_direct | D4 | h=744: MASE=0.877 MAE=1.045
- B2.0_univariate_direct | D5 | h= 24: MASE=0.147 MAE=0.197
- B2.0_univariate_direct | D5 | h=168: MASE=0.945 MAE=1.285
- B2.0_univariate_direct | D5 | h=336: MASE=0.943 MAE=1.278
- B2.0_univariate_direct | D5 | h=744: MASE=0.966 MAE=1.241
- B2.0_univariate_direct | S5 | h= 24: MASE=0.495 MAE=1.060
- B2.0_univariate_direct | S5 | h=168: MASE=0.958 MAE=2.072
- B2.0_univariate_direct | S5 | h=336: MASE=1.077 MAE=2.304
- B2.0_univariate_direct | S5 | h=744: MASE=1.310 MAE=2.677
- B2.1_separate | D1 | h= 24: MASE=0.756 MAE=1.570
- B2.1_separate | D1 | h=168: MASE=1.075 MAE=2.257
- B2.1_separate | D1 | h=336: MASE=1.160 MAE=2.427
- B2.1_separate | D1 | h=744: MASE=1.128 MAE=2.280
- B2.1_separate | D2 | h= 24: MASE=0.953 MAE=1.272
- B2.1_separate | D2 | h=168: MASE=1.141 MAE=1.543
- B2.1_separate | D2 | h=336: MASE=1.023 MAE=1.385
- B2.1_separate | D2 | h=744: MASE=0.946 MAE=1.246
- B2.1_separate | D3 | h= 24: MASE=0.974 MAE=1.140
- B2.1_separate | D3 | h=168: MASE=1.221 MAE=1.445
- B2.1_separate | D3 | h=336: MASE=1.011 MAE=1.196
- B2.1_separate | D3 | h=744: MASE=0.897 MAE=1.041
- B2.1_separate | D4 | h= 24: MASE=0.702 MAE=0.853
- B2.1_separate | D4 | h=168: MASE=1.291 MAE=1.585
- B2.1_separate | D4 | h=336: MASE=1.159 MAE=1.418
- B2.1_separate | D4 | h=744: MASE=0.965 MAE=1.149
- B2.1_separate | D5 | h= 24: MASE=0.393 MAE=0.528
- B2.1_separate | D5 | h=168: MASE=0.948 MAE=1.289
- B2.1_separate | D5 | h=336: MASE=0.945 MAE=1.280
- B2.1_separate | D5 | h=744: MASE=0.975 MAE=1.252
- B2.1_separate | S5 | h= 24: MASE=0.257 MAE=0.550
- B2.1_separate | S5 | h=168: MASE=0.979 MAE=2.116
- B2.1_separate | S5 | h=336: MASE=1.128 MAE=2.413
- B2.1_separate | S5 | h=744: MASE=1.248 MAE=2.549
- B2.2_shared | D1 | h= 24: MASE=0.686 MAE=1.425
- B2.2_shared | D1 | h=168: MASE=1.104 MAE=2.317
- B2.2_shared | D1 | h=336: MASE=1.312 MAE=2.745
- B2.2_shared | D1 | h=744: MASE=1.200 MAE=2.427
- B2.2_shared | D2 | h= 24: MASE=0.633 MAE=0.846
- B2.2_shared | D2 | h=168: MASE=1.136 MAE=1.536
- B2.2_shared | D2 | h=336: MASE=1.046 MAE=1.417
- B2.2_shared | D2 | h=744: MASE=0.947 MAE=1.247
- B2.2_shared | D3 | h= 24: MASE=0.537 MAE=0.629
- B2.2_shared | D3 | h=168: MASE=1.186 MAE=1.404
- B2.2_shared | D3 | h=336: MASE=1.024 MAE=1.211
- B2.2_shared | D3 | h=744: MASE=0.878 MAE=1.019
- B2.2_shared | D4 | h= 24: MASE=0.755 MAE=0.917
- B2.2_shared | D4 | h=168: MASE=1.345 MAE=1.651
- B2.2_shared | D4 | h=336: MASE=1.205 MAE=1.475
- B2.2_shared | D4 | h=744: MASE=0.901 MAE=1.073
- B2.2_shared | D5 | h= 24: MASE=0.262 MAE=0.352
- B2.2_shared | D5 | h=168: MASE=0.954 MAE=1.298
- B2.2_shared | D5 | h=336: MASE=0.934 MAE=1.266
- B2.2_shared | D5 | h=744: MASE=0.873 MAE=1.121
- B2.2_shared | S5 | h= 24: MASE=0.246 MAE=0.527
- B2.2_shared | S5 | h=168: MASE=1.013 MAE=2.189
- B2.2_shared | S5 | h=336: MASE=1.084 MAE=2.319
- B2.2_shared | S5 | h=744: MASE=1.600 MAE=3.268

## Reconstructed PM2.5

- B2.0_univariate_direct h= 24: MASE=0.861 MAE=3.647 RMSE=4.315 n= 23
- B2.1_separate h= 24: MASE=0.894 MAE=3.791 RMSE=4.395 n= 23
- B2.2_shared h= 24: MASE=0.724 MAE=3.068 RMSE=4.011 n= 23
- B2.0_univariate_direct h=168: MASE=1.595 MAE=6.666 RMSE=9.912 n=167
- B2.1_separate h=168: MASE=1.538 MAE=6.429 RMSE=9.894 n=167
- B2.2_shared h=168: MASE=1.661 MAE=6.939 RMSE=9.682 n=167
- B2.0_univariate_direct h=336: MASE=1.229 MAE=5.239 RMSE=7.457 n=335
- B2.1_separate h=336: MASE=0.904 MAE=3.852 RMSE=7.557 n=335
- B2.2_shared h=336: MASE=1.239 MAE=5.281 RMSE=7.462 n=335
- B2.0_univariate_direct h=744: MASE=0.706 MAE=3.124 RMSE=5.120 n=743
- B2.1_separate h=744: MASE=0.718 MAE=3.178 RMSE=5.133 n=743
- B2.2_shared h=744: MASE=1.074 MAE=4.751 RMSE=6.149 n=743

## Research answers

1. Multivariate vs univariate (1d, LightGBM): separate wins on {D4,S5}; univ wins on {D1,D2,D3,D5}.
   Per-component ΔMASE (sep−univ): D1= 0.047; D2= 0.266; D3= 0.232; D4=-0.367; D5= 0.246; S5=-0.238
4. Shared vs separate mean test MASE @1d: separate=0.672 shared=0.520
7. Reconstructed PM2.5 (see reconstructed_metrics.csv).
2–3. See feature_importance_top.csv for predictive (not causal) pollutant-component contributors.
5–6. Horizon persistence and FS/DR answered after stageA/full runs.
Note: B2 uses direct fixed-horizon supervision; original T1 used recursive h-step. Fair protocol comparison is B2.0 univariate-direct vs B2.1/B2.2 on identical timestamps.

## Reproduction

```bash
Rscript run_b2.R smoke    # D1 @ 24h + univ vs separate
Rscript run_b2.R stageA   # all components, 4 horizons, separate+shared+univ
Rscript run_b2.R full     # + Stage B models + feature selection on 1d
Rscript tests/b2/run_all.R
```

Outputs only under `results/b2/`. T1 / stored decomps / B1 untouched.

