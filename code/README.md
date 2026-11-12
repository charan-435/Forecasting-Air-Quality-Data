# Implementation map

Run commands from the repository root. Start with the root README for run order, inputs, cache handling and reproduction limits.

| Location | Responsibility |
|---|---|
| project.R | Locate the checkout without machine-specific paths. |
| R/core/ | Load data, create lags, decompose, fit models, and compute metrics/intervals. |
| R/preprocessing/ | Hourly aggregation, quality masks, past-only filling and store writes. |
| R/decomposition/ | Causal/trailing decomposition registry, diagnostics and checkpoints. |
| R/preprocessed_experiment/ | Isolated cleaned-CPCB experiment, from audit to paired evaluation. |
| config/ | Input paths, quality rules, decomposition settings, splits and tuning grid. |
| experiments/ | Runnable model/evaluation entrypoints. |
| preprocessing/ | Runnable hourly-store and decomposition entrypoints. |
| figures/ | Plot recorded results and design diagnostics; no PDF document generation. |
| validation/ | Check recorded values, app assets, cache consistency and a small model fit. |
| tests/ | Preprocessing, decomposition and cleaned-experiment tests. |
| app/ | React/TypeScript implementation and committed browser data. |
| app/data_tools/ | Refresh app assets from the recorded experiment outputs. |

`source("code/R/load_all.R")` loads modelling helpers in a fixed order. Numeric prefixes show the dependencies: settings and input helpers come before models and evaluation. The cleaned experiment loads its own numbered modules after the shared helpers.

When reading the pipeline, follow data loading, preprocessing, lag creation, decomposition, model fitting, then evaluation. Comments call out assumptions that affect interpretation: inputs may be filled, targets must be valid, calibration precedes testing, and cached summaries can come from a different prediction run.

Publishing utilities, document source and one-time migration scripts are intentionally excluded. Completed PDFs live in docs/; saved experiment evidence lives in results/.
