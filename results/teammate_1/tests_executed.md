# T1 tests actually executed

Date: 2026-11-02

## Safeguard suite (executed)

```
Rscript tests/teammate_1/run_all.R
```

Result: **41 PASS, 0 FAIL**, exit code 0. Re-run after scoring/alignment fixes: **41 PASS, 0 FAIL**.

| Script | What it checked |
|---|---|
| `01_stored_unchanged.R` | Stored Haar J=5 parquet md5/size/values unchanged after `get_decomp`; D1–D5 and S5 present |
| `02_independent_inputs.R` | Lag matrix is `lag1..lagp` of one series; no other bands as features |
| `03_splits_and_leakage.R` | `chrono_split_tvt` match; train < val < test; lag1 at origin is last train value |
| `04_selection_and_recon.R` | Selection uses validation only (test-winning model rejected); reconstruction needs all six components; writes outside `results/teammate_1/` refused |

## Smoke experiment (executed)

```
Rscript run_teammate_1.R smoke
```

Result: exit code 0. CPCB PM2.5, horizon 1d (24 h), models LightGBM / XGBoost / CatBoost / SARIMA / DLinear, components D1–D5 / S5.

Inspected files: `component_metrics.csv`, `best_models.csv`, `report.md`, `plots/*.png`.

## Not executed

- `Rscript run_teammate_1.R full` (CPCB+ID1 PM2.5, horizons 1d/7d/14d/31d). Code path exists; numbers for those cells are not in this folder.
)
