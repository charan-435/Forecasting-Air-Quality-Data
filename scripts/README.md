# Commands grouped by purpose

Run entry points from the repository root. Reusable functions belong under R/; scripts decide what work to run and where to save it.

| Folder | Purpose | Typical entry points |
|---|---|---|
| preprocessing/ | Prepare hourly stores and decompositions | run_preprocess.R, run_decomp.R |
| experiments/ | Fit or evaluate one experiment | run_experiments.R, run_preprocessed_experiment.R, run_conformal.R |
| figures/ | Draw saved results and export app data | make_report_figs.py, make_slide_figs.R, export_lab_assets.R |
| validation/ | Check consistency and smoke-test pipelines | check_report_scores.py, check_result_caches.R, smoke_test.R |

## Inputs and outputs

| Entry point under experiments/ | Reads | Writes |
|---|---|---|
| run_experiments.R | Paper CSVs, optional settings and fit caches | results/paper/, data/processed/series.rds |
| run_filter_ablation_catboost.R | Paper CSVs and settings | results/extensions/filter_* |
| run_extensions.R | Saved series, filter results, settings | results/extensions/extension_* |
| run_paper_protocol.R | Paper series and settings | results/paper/paper_protocol.rds |
| run_conformal.R | Prepared series and settings | results/paper/conformal.rds |
| run_preprocessed_experiment.R | Shared store and experiment config | Its separate store/preprocessed_experiment/ and results/preprocessed_experiment/ |
| run_shillong_direct.R | Shillong source and weather | results/shillong/direct_scores.csv and plots |

The root [README](../README.md) gives the run order and explains cache reuse.

make_report_figs.py reads the saved filter scores, cleaned metrics, and conformal arrays. Its base-R helper export_conformal_cache.R exports temporary CSVs without loading models or installing packages. Output PDFs go to report/figures/.

The current React Lab exports are export_lab_assets.R and export_lab_series.py. Retired Learn exporters and one-time migration scripts are removed.

Run source("scripts/publish_analysis.R") in RStudio to check and deploy the interactive report. See the root README for account configuration and bundle preview.
