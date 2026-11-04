# Limitations and Future Work

## Completed with caveats
- Full Shillong architecture comparison: completed with direct horizons, saved validation/test metrics, paired bootstrap and family comparisons.
- CPCB raw Phase 1/2 direct forecasting: completed, unmasked and leakage-tested for the S3 split.
- Legacy CPCB recursive bake-off: saved, but the repository audit documents circular-MRA, hyperparameter overlap, nested-origin and cache/protocol issues.
- Station-target baseline and robustness results: saved in Shillong result CSVs.

## Partially completed
- Legacy conformal prediction was executed, but calibration design and coverage are unreliable as described in `audit/AUDIT.md`.
- Feature selection, PCA and PLS are completed for CPCB Phase 2 and reported; some variants are unstable or hurt test performance.
- Second-stage PCA/direct/recursive/hybrid implementation passes 87 invariants/tests but has no saved run/report numerical artifacts.
- WaveCatBoost and paper-protocol outputs exist, but valid direct protocol reproduction is not complete.

## Proposed/not run
- PCA and direct/recursive/hybrid controlled Shillong comparison.
- A completed isolated preprocessed/clipped CPCB preprocessing track.
- Unified rolling-origin evaluation across datasets.
- Full multi-year and cross-station generalisation.

## Key limitations
- JN Stadium has short history and a season-changing train/test split.
- Lumpyngngad O3 and several gaps/sensor regimes complicate multivariate features.
- CPCB Phase 2 unmasked metrics mix real observations and constant-filled hours.
- Long-horizon performance is often close to climatology or constant forecasts.
- The legacy MRA and conformal paths have leakage or calibration defects.
- MCB/Nemenyi evidence should not be imported from stale legacy files without re-evaluation.
