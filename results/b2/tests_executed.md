# B2 tests actually executed

Date: 2026-11-02

## Safeguards

```
Rscript tests/b2/run_all.R
```

Result: **20 PASS, 0 FAIL**.

Coverage: six-pollutant alignment, 864 features, lag ordering, no future leakage, train origin/target both in train, val/test targets in-block, component-id one-hot, reconstruction additivity, write sandbox, identical evaluation timestamps.

## Experiments executed

| Command | Result |
|---|---|
| `Rscript run_b2.R smoke` | exit 0 — D1@24h univ vs separate |
| `Rscript run_b2.R stageA` | exit 0 — all 6 components × 4 horizons; univ, separate, shared; reconstruction |
| `Rscript run_b2.R stageB` | classical models + FS/DR on 1d (started after Stage A) |

## Not claiming

- ID1 / Shillong / Delhi runs (code modular, not executed).
- Recursive / hybrid forecasting (explicitly out of scope for B2).
- Deep learning.
