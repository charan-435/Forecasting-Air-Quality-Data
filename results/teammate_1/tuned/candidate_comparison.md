# Component-wise model comparison

Reporting only. The hyperparameter search is unchanged, and original T1 result files are not overwritten.

## Component-wise model comparison

Original validation and test MASE are read from `results/teammate_1/component_metrics.csv`.
That file is the T1 model-selection experiment. These columns are not retuned, and this table does not change the frozen component-to-model map.

Tuned validation and test MASE are filled only for the frozen assignment of that component, and only when T1-Tuned has already stored the validation-selected configuration and its later test evaluation.
Every other candidate was not tuned, so its tuned cells are N/A.
A frozen assignment with no stored test evaluation is also N/A.
Model selection stays on validation MASE. Test MASE is shown after the fact and is not a selection input.

Markdown scores are rounded to 3 decimals. `candidate_comparison.csv` keeps the stored values.

### CPCB | PM2.5 | 1d

| Component | Model | Original Validation MASE | Original Test MASE | Tuned Validation MASE | Tuned Test MASE |
|---|---|---:|---:|---:|---:|
| D1 | LightGBM | 0.415 | 0.541 | 0.405 | 0.781 |
| D1 | XGBoost | 0.606 | 0.575 | N/A | N/A |
| D1 | CatBoost | 0.449 | 0.642 | N/A | N/A |
| D1 | SARIMA | 0.503 | 0.893 | N/A | N/A |
| D1 | DLinear | 0.501 | 0.754 | N/A | N/A |
| D2 | LightGBM | 0.372 | 0.858 | 0.358 | 0.880 |
| D2 | XGBoost | 0.425 | 0.810 | N/A | N/A |
| D2 | CatBoost | 0.387 | 0.703 | N/A | N/A |
| D2 | SARIMA | 0.448 | 0.752 | N/A | N/A |
| D2 | DLinear | 0.391 | 0.749 | N/A | N/A |
| D3 | LightGBM | 0.602 | 0.781 | N/A | N/A |
| D3 | XGBoost | 0.592 | 0.655 | N/A | N/A |
| D3 | CatBoost | 0.621 | 0.543 | N/A | N/A |
| D3 | SARIMA | 0.576 | 1.050 | N/A | N/A |
| D3 | DLinear | 0.513 | 0.659 | 0.501 | 0.790 |
| D4 | LightGBM | 0.440 | 0.374 | N/A | N/A |
| D4 | XGBoost | 0.452 | 0.454 | N/A | N/A |
| D4 | CatBoost | 0.422 | 0.622 | N/A | N/A |
| D4 | SARIMA | 0.505 | 1.000 | N/A | N/A |
| D4 | DLinear | 0.442 | 0.512 | N/A | N/A |
| D5 | LightGBM | 0.300 | 1.179 | N/A | N/A |
| D5 | XGBoost | 0.372 | 0.452 | N/A | N/A |
| D5 | CatBoost | 0.262 | 0.180 | N/A | N/A |
| D5 | SARIMA | 0.184 | 0.643 | N/A | N/A |
| D5 | DLinear | 0.198 | 0.414 | N/A | N/A |
| S5 | LightGBM | 0.234 | 0.369 | N/A | N/A |
| S5 | XGBoost | 0.239 | 0.526 | N/A | N/A |
| S5 | CatBoost | 0.292 | 0.934 | N/A | N/A |
| S5 | SARIMA | 0.296 | 0.858 | N/A | N/A |
| S5 | DLinear | 0.155 | 0.320 | N/A | N/A |

The validation heatmap uses the original T1 scores only: components are rows and candidate models are columns.
File: `plots/original_val_mase_heatmap.png`. Tuned scores are not drawn on it.

