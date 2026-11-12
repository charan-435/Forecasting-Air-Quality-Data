# Air-quality forecasting with WaveCatBoost

This is our Applied Time Series Analysis course project on Borah et al., *A Novel Hybrid Approach for Efficiently Forecasting Air Quality Data* (IEEE Sensors Letters, 2025).

The method splits an hourly pollutant series into wavelet components, forecasts each component, and combines the forecasts. We compare it with simpler models, try other filters and inputs, and check how data cleaning affects the results.

Start with [the interactive R report](analysis.Rmd), [the presentation](presentation/main.pdf), or [WaveCatBoost Lab](https://charanponaganti.github.io/wavecatboost-learn/). Run the commands below from the repository root.

## Find your way around

| Location | What belongs here |
|---|---|
| [analysis.Rmd](analysis.Rmd) | Interactive R report and project discussion. Open it in RStudio and choose **Run Document**. |
| [R/](R/README.md) | Shared data preparation, models, metrics, and reporting functions. |
| [scripts/](scripts/README.md) | Commands that prepare inputs, run experiments, draw figures, or check results. |
| [config/](config/README.md) | Source paths, quality rules, decomposition settings, and cleaned-CPCB experiment settings. |
| [data/](data/README.md) | Original sensor files and reusable hourly inputs. |
| [store/](store/README.md) | Quality masks, causal fills, eligibility policies, and stored components. |
| [results/](results/README.md) | Recorded predictions, scores, tuning choices, and experiment reports. |
| [tests/](tests/README.md) | Checks grouped by preprocessing, decomposition, and the cleaned experiment. |
| [presentation/](presentation/README.md) | Current Beamer slides, figures, and the older PowerPoint overview. |
| [lab/](lab/README.md) | React/TypeScript educational app displaying committed result exports. It does not train models. |
| report/ | Final report and figure PDFs. Only PDFs are versioned here; editable sources are in the accompanying Overleaf ZIP. |
| docs/ | Assigned paper, supplementary cover, and historical implementation audit. |

Numbered R filenames indicate loading order. Normally you call a script under scripts/, which loads the helpers; you do not run each numbered file by hand.

## 1. Set up the tools

Use R with RStudio for the interactive report. The package list and setup are in [R/core/00_packages.R](R/core/00_packages.R).

~~~sh
Rscript -e "source('R/core/00_packages.R')"
~~~

The shared loader installs missing CRAN dependencies and attempts a Windows CatBoost binary installation. Its first run needs internet access. The R report also needs rmarkdown, knitr, and Pandoc; RStudio supplies the usual Pandoc integration.

~~~r
install.packages(c("rmarkdown", "knitr"))
~~~

CatBoost must be available to reproduce its scores. Otherwise the code uses a labelled XGBoost fallback, which is a different experiment. On systems other than Windows, install the CatBoost R package separately.

If PowerShell cannot find Rscript, use the full path to your installation. For example, with R 4.6.1:

~~~powershell
& "C:/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/validation/smoke_test.R
~~~

Run that in PowerShell, not at the R console. In the commands below, replace Rscript with the same full-path invocation when needed.

Python's standard library is sufficient for the recorded-score validator. Report figures also need numpy, pandas, and matplotlib; checking a compiled PDF's page count needs pypdf. The project does not currently have a complete dependency lockfile, so record package versions with any new fit.

## 2. Check the inputs

| Experiment | Input |
|---|---|
| Original CPCB/ID1 comparison | data/raw/CPCB.csv and data/raw/ID1.csv |
| Cleaned CPCB comparison | The CPCB file and the shared hourly store prepared in step 4 |
| Shillong studies | data/raw/shillong/shillong_15min_2023.parquet |
| Shillong weather extension | Cached data/processed/era5_shillong_2023.parquet, or internet access for the direct runner to retrieve it |

The original hourly files came from the [paper's companion repository](https://github.com/jborah2/WaveCatBoost-Time-Series-Model). The Shillong extract contains Lumpyngngad and JN Stadium separately. The original benchmark's SHILLONG group is a different evaluation from the later two-station architecture study.

## 3. Inspect recorded results

The CSVs and experiment reports can be read without fitting anything.

~~~sh
python scripts/validation/check_report_scores.py
Rscript scripts/validation/check_result_caches.R
~~~

The Python command checks displayed values against saved sources without changing them. The R command checks saved cache consistency.

| Question | Saved result | Protocol |
|---|---|---|
| Nine original methods | results/paper/scores.csv | Recursive terminal-origin forecasts. Filter to CPCB/ID1 for the paper-data summary. |
| Rolling forecast panels | results/paper/paper_protocol.rds | Rolling one-step forecasts, separate from recursive scores. |
| Haar, D4, and LA8 | results/extensions/filter_scores.csv | One-day filter ablation. |
| Effect of cleaning | results/preprocessed_experiment/comparisons/metrics_pollutant_level.csv | Direct 24-hour predictions on common valid targets. |
| Current calibrated intervals | results/paper/conformal.rds | Recorded rolling one-step split-conformal intervals. |
| Larger Shillong study | results/shillong/architecture/REPORT.md | Imported direct-horizon study with incomplete training code. |

Do not pool these protocols in one ranking. The older audit's conformal results differ from the later one-step cache. Presentation residual bands use a quantile fitted on displayed residuals: roughly 95% plotted coverage is descriptive, not independent calibration evidence.

## 4. Reproduce the cleaned CPCB experiment

~~~sh
Rscript scripts/preprocessing/run_preprocess.R paper
Rscript scripts/experiments/run_preprocessed_experiment.R phase1
Rscript scripts/experiments/run_preprocessed_experiment.R phase2
Rscript scripts/experiments/run_preprocessed_experiment.R phase3
Rscript scripts/experiments/run_preprocessed_experiment.R phase4
~~~

| Step | Work | Main output |
|---|---|---|
| Prepare | Build shared hourly inputs | store/clean/ |
| phase1 | Fresh integrity snapshot, audit, invalid-value masks, past-only input fills | results/preprocessed_experiment/data_audit/ and its separate clean store |
| phase2 | Trailing Haar components and data/target checks | store/preprocessed_experiment/ and tests/data_tests.csv |
| phase3 | Small smoke fit and model-interface checks | results/preprocessed_experiment/smoke/ |
| phase4 | Tune, refit, and evaluate B0/A1/B1/B2/B3 on clean and unmasked inputs | Architecture predictions and comparisons/ tables |

[config/preprocessed_experiment.yaml](config/preprocessed_experiment.yaml) records the settings: direct 24-hour targets, 24 input lags, training through 28 February 2023, validation through 30 April, and later valid test targets. LightGBM uses seed 7 and an 18-setting grid. Filled values are inputs; invalid targets are not scored.

Read [the experiment report](results/preprocessed_experiment/REPORT.md) for measured outcomes and paired intervals. Run phases in order after project edits: the integrity snapshot belongs to the files present at phase1.

## 5. Reproduce other available experiments

~~~sh
# Original recursive comparison; completed fits may be loaded from cache.
Rscript scripts/experiments/run_experiments.R

# Smaller one-day run: seasonal naive, SARIMA, and LightGBM variants.
Rscript scripts/experiments/run_experiments.R quick

# One-day WaveCatBoost filter comparison and the narrower extensions.
Rscript scripts/experiments/run_filter_ablation_catboost.R
Rscript scripts/experiments/run_extensions.R

# Rolling panels/descriptive bands, then the separate calibrated experiment.
Rscript scripts/experiments/run_paper_protocol.R
Rscript scripts/experiments/run_conformal.R

# Shillong hourly benchmark and direct 1 / 6 / 24-hour forecasts.
Rscript scripts/experiments/run_new_dataset.R
Rscript scripts/experiments/run_shillong_direct.R
~~~

Optional shared stores:

~~~sh
Rscript scripts/preprocessing/run_preprocess.R shillong
Rscript scripts/preprocessing/run_decomp.R mra_haar_J5 --skip-screen --skip-diag
~~~

The decomposition command uses the shared paper store and config/decomp.yaml. It does not replace the isolated cleaned-CPCB decomposition.

### Cached versus fresh runs

Some runners skip completed fits. A fast successful run can simply mean a cache was loaded. Before refitting, copy the relevant result folder outside the repository and record the commit and package versions. Main reusable files include forecast_cache.rds, hparams.rds, filter_cache.rds, and extension_cache.rds in their respective folders. Inspect the runner before renaming a cache; there is no universal force-refit flag.

Keep recorded outputs separate from new runs. Data changes, settings, package versions, and CatBoost fallback can change the numbers.

### Results that cannot be refitted here

The imported 14-design Shillong study retains its report and aggregate CSVs under results/shillong/architecture/. Its original runner, configuration, and some second-stage code were already missing. Those results can be inspected but cannot be reproduced end to end. The historical audit also documents periodic-wavelet and overlapping-window limitations of the original benchmark.

## 6. Refresh plots, report assets, and apps

~~~sh
Rscript scripts/figures/make_slide_figs.R
Rscript scripts/figures/make_conformal_figs.R
Rscript scripts/figures/make_shillong_arch_figs.R
python scripts/figures/make_report_figs.py
~~~

These read saved results. The R conformal figure script draws the presentation's descriptive bands. The Python report script draws the separate recorded calibrated intervals, filter bar plots, and cleaned-CPCB metric plot. Its RDS reader uses base R only and does not load modelling packages.

When R is not on PATH:

~~~powershell
python scripts/figures/make_report_figs.py --rscript "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
~~~

Report PDFs go under report/figures/; diagnostic CSVs go under report/. Compile ATS_Final_Report.tex from the accompanying Overleaf ZIP to build the report. Git intentionally ignores all non-PDF files under report/.

Compile the current Beamer presentation from presentation/, for example with latexmk -pdf main.tex.

To run the current Lab:

~~~sh
Rscript scripts/figures/export_lab_assets.R
cd lab
npm ci
npm run dev
~~~

Use npm run build inside lab/ to write lab/dist/. The earlier static viewer is in presentation/webapp/. It keeps its recorded exports; use the current Lab exporters for new app data.

## 7. Run checks

~~~sh
Rscript scripts/validation/smoke_test.R
Rscript tests/preprocessing/run_all.R
Rscript tests/decomposition/run_all.R
python scripts/validation/check_report_scores.py
Rscript scripts/validation/check_result_caches.R
~~~

Cleaned-experiment checks run in phases 2 and 3. Test folders formerly named phase1a and phase1b now describe their purpose. Historical audit documents retain old paths and line numbers because they describe that earlier implementation.

## Publish the interactive R report

Run from the project root in the RStudio console:

~~~r
install.packages("rsconnect")  # Once, if needed.
source("scripts/publish_analysis.R")
~~~

The publishing script checks helper syntax and resource discovery before uploading. It bundles the report helpers and saved results, rather than training modules and their optional dependencies. The report uses `R/reporting/load_report.R`; experiment runners use `R/load_all.R`.

The default destination is the existing `charan-435` Connect Cloud report. Sign into that account through RStudio first. To publish to another existing report, set `options(ats.publish.account = "your-account", ats.publish.app_id = "your-content-id")`. Local `rsconnect/` records are ignored. To inspect the bundle without publishing, set `options(ats.publish.dry_run = TRUE)`; reset it to `FALSE` before deploying.

Retired Learn exporters and one-time cache/PowerPoint migration scripts have been removed. The scripts retained here prepare inputs, reproduce experiments, generate current figures/app data, validate results, or publish the report. Saved results and processed inputs stay versioned because the interactive report uses them.