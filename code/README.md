# Implementation map

Run commands from the repository root. Start with the root README for run order, inputs, cache handling and reproduction limits.

| Location | Responsibility |
|---|---|
| project.R | Locate the checkout without machine-specific paths. |
| R/core/ | Load data, create lags, decompose, fit models, and compute metrics/intervals. |
| R/preprocessing/ | Hourly aggregation, quality masks, past-only filling and store writes. |
| R/decomposition/ | Causal/trailing decomposition registry, diagnostics and checkpoints. |
| R/preprocessed_experiment/ | Isolated cleaned-CPCB experiment, from audit to paired evaluation. |
| R/multivariate/ | Direct CPCB models with one or several input pollutants. |
| R/shillong_architecture/ | Separate and shared component models for the two Shillong stations. |
| R/second_stage/ | Train-only PCA and direct, recursive, and hybrid Shillong forecasts. |
| config/ | Input paths, quality rules, decomposition settings, splits and tuning grid. |
| experiments/ | Runnable model/evaluation entrypoints. |
| preprocessing/ | Runnable hourly-store and decomposition entrypoints. |
| tests/ | Model and data tests used by the experiment runners. |
| app/ | React/TypeScript implementation and committed browser data. |
| app/data_tools/ | Refresh app assets from the recorded experiment outputs. |

`source("code/R/load_all.R")` loads modelling helpers in a fixed order. Numeric prefixes show the dependencies: settings and input helpers come before models and evaluation. The cleaned experiment loads its own numbered modules after the shared helpers.

Read data loading and preprocessing first. Then follow decomposition, lag creation, model fitting, and evaluation. Comments explain the main choices. Inputs may be filled, but targets must be valid. Calibration comes before testing. Cached summaries may come from a different run.

The multivariate and Shillong runners load their own module lists. Their YAML settings control the data splits, model grids, and output paths. Result-summary stages compute metrics and compare the fitted models.

See [the file guide](../FILE_GUIDE.md) for the role of every shared file. The root README gives the run order and explains how to compare scores with matching predictions.
