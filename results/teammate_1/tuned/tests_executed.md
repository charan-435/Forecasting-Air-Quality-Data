# T1-Tuned tests actually executed

Date: 2026-11-02

## Safeguard suite (executed)

```
Rscript tests/teammate_1/run_all.R
```

Result: **64 PASS, 0 FAIL**, exit code 0.

Includes original T1 tests (01–04) plus `05_tuned.R`:

| Check | Result |
|---|---|
| Frozen architecture map matches T1 winners | PASS |
| Selection uses validation MASE only | PASS |
| Frozen T1 config wins validation ties | PASS |
| Refuses test-only selection | PASS |
| DLinear search uses only `p` and `kernel` | PASS |
| Splits match `chrono_split_tvt` | PASS |
| Writes sandboxed under `results/teammate_1/` | PASS |
| No MODWT recompute | PASS |

## Experiment (executed)

```
Rscript run_teammate_1_tuned.R cpcb
```

Result: exit code 0 (~3.5 h). CPCB PM2.5, horizon 1d, 119 validation trials, then one test forecast per component with selected hyperparameters.

## Not executed

- `Rscript run_teammate_1_tuned.R full` (CPCB+ID1, four horizons).
