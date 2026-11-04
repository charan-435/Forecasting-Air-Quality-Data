# Phase 2 test execution summary

Run: 2026-11-02 18:28:35 UTC. R 4.5.2.
Result: **18 / 18 passed**. Quality mask: none (UNMASKED).

| ID | Test | Result | Detail |
|---|---|---|---|
| P01 | Constant-fill flags reproduce the 2,304 Phase 0 hours | PASS | 2304 hours in 12 runs (144/168/600 h) |
| P02 | Target argument: y = target(t+h), inputs unchanged | PASS | six targets x two horizons |
| P03-xgboost | xgboost : no test-label use, reproducible, refit frozen | PASS | best_iter=5 refit=5 |
| P03-catboost | catboost : no test-label use, reproducible, refit frozen | PASS | best_iter=5 refit=5 |
| P03-ridge | ridge : no test-label use, reproducible, refit frozen | PASS | best_iter=1 refit=1 |
| P03-lasso | lasso : no test-label use, reproducible, refit frozen | PASS | best_iter=1 refit=1 |
| P03-elasticnet | elasticnet : no test-label use, reproducible, refit frozen | PASS | best_iter=1 refit=1 |
| P03-pls | pls : no test-label use, reproducible, refit frozen | PASS | best_iter=7 refit=7 |
| P04 | XGBoost predicts with exactly best_iter rounds | PASS | best_iter=5; truncated model == model trained for best_iter rounds |
| P05 | CatBoost refit uses exactly best_iter trees | PASS | best_iter=6 |
| P06 | Transforms are fitted on fitting rows only | PASS | corr_top24:24 mi_top24:24 enet_select:34 pca8:8 plsscores5:5 corr_top48+pca4:4 columns:48 |
| P07 | Pooled dataset: alignment, own slot, train-only scaling, no future inputs | PASS | h=168: 17532 train rows, 169 columns (pooled_B0: 25) |
| P08 | Pooled LightGBM: categorical target id, reproducible, no test-label use | PASS | best_iter=13 |
| P09 | Block length and DM test behave sensibly | PASS | PW white noise 1.7, AR(0.95) 75.0; chosen 76 (cap 400) |
| P10 | Seasonal naive equals the value at the origin for h = 24k | PASS | seasonal naive uses only the origin-hour observation |
| P11 | Tuning never reads test labels | PASS | best num_leaves=15 |
| P12 | Family registry: new families present, unknown names still fail | PASS | catboost,elasticnet,lasso,lightgbm,ols,pls,ridge,xgboost |
| P13 | RFE and transform tuning use train/validation only | PASS | RFE path 144>72>36>30 |
