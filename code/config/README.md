# Experiment settings

| File | What it controls |
|---|---|
| preprocess.yaml | Sources, timezone/interval labels, bounds, quality flags, gap handling, and eligibility. |
| imputation_choice.yaml | Saved method choices from the preprocessing benchmark; these are not new observations. |
| decomp.yaml | Component methods, trailing windows, levels, diagnostics, and screening. |
| preprocessed_experiment.yaml | Cleaned-CPCB split, 24-hour targets, model grid, architectures, and paired comparisons. |
| multivariate.yaml | Raw CPCB input lags, time splits, and the first B0/B1 comparison. |
| multivariate_experiments.yaml | More learners, feature selection, and other CPCB targets. |
| shillong_arch.yaml | Two-station architecture study, data checks, splits, and model grids. |
| second_stage.yaml | PCA choices and direct, recursive, and hybrid Shillong forecasts. |

Change settings before running the relevant pipeline and keep them alongside new outputs. A YAML edit does not invalidate every cache automatically. Original-benchmark defaults also live in code/R/core/01_constants.R, 06_models.R, and 09_hparams.R.
