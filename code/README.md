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
| figures/ | Optional local plot tools. This folder is ignored by Git. |
| validation/ | Check recorded values, app assets, cache consistency and a small model fit. |
| tests/ | Preprocessing, decomposition and cleaned-experiment tests. |
| app/ | React/TypeScript implementation and committed browser data. |
| app/data_tools/ | Refresh app assets from the recorded experiment outputs. |

`source("code/R/load_all.R")` loads modelling helpers in a fixed order. Numeric prefixes show the dependencies: settings and input helpers come before models and evaluation. The cleaned experiment loads its own numbered modules after the shared helpers.

Read data loading and preprocessing first. Then follow decomposition, lag creation, model fitting, and evaluation. Comments explain the main choices. Inputs may be filled, but targets must be valid. Calibration comes before testing. Cached summaries may come from a different run.

Publishing utilities, document source and one-time migration scripts are intentionally excluded. Completed PDFs live in docs/; saved experiment evidence lives in results/.

The three added module folders were restored from the `lalit` branch at commit `a6dad69`. Their runners are in experiments/. Their YAML files are in config/. New runs record hashes for the updated paths and files. Result-summary stages remain with the experiments because they evaluate fitted models.
