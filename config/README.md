# Experiment settings

| File | What it controls |
|---|---|
| preprocess.yaml | Sources, timezone/interval labels, bounds, quality flags, gap handling, and eligibility. |
| imputation_choice.yaml | Saved method choices from the preprocessing benchmark; these are not new observations. |
| decomp.yaml | Component methods, trailing windows, levels, diagnostics, and screening. |
| preprocessed_experiment.yaml | Cleaned-CPCB split, 24-hour targets, model grid, architectures, and paired comparisons. |

Change settings before running the relevant pipeline and keep them alongside new outputs. A YAML edit does not invalidate every cache automatically. Original-benchmark defaults also live in R/core/01_constants.R, 06_models.R, and 09_hparams.R.
