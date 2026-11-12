# R code map

Load shared functions with `source("code/R/load_all.R")` from the repository root. Experiment scripts do this for you. The package setup can install missing dependencies on its first run.

| Folder | Responsibility | Read first |
|---|---|---|
| core/ | Original-data loading, lag features, MODWT, models, intervals, and metrics | 01_constants.R, 05_features.R, 06_models.R, 07_conformal.R |
| preprocessing/ | Hourly aggregation, quality masks, past-only fills, and clean-store writes | 20_ingest.R, 21_quality.R, 22_impute.R |
| decomposition/ | Method registry, causal/trailing components, diagnostics, and stored outputs | 30_decomp_registry.R, 31_decomp_causal.R, 32_decomp_trailing.R |
| preprocessed_experiment/ | Isolated cleaned-CPCB audit, features, architectures, and paired evaluation | 00_setup.R, 40_features.R, 70_pipeline.R |

Numeric prefixes show the order within a pipeline. The loader lists its order explicitly; the isolated experiment loads its own numbered files through run_preprocessed_experiment.R.

Two details are easy to miss:

- Repaired values are model inputs. The quality policy decides which observed targets may be scored.
- Original recursive features and cleaned direct features use different lag naming conventions. Read the feature-function comments before combining rows.

The original and cleaned pipelines stay separate so recorded results can still be interpreted against their own protocol.
