# Air-quality forecasting with WaveCatBoost

This is our Applied Time Series Analysis project. It is based on Borah et al., *A Novel Hybrid Approach for Efficiently Forecasting Air Quality Data*.

WaveCatBoost splits a pollutant series into wavelet components. It fits one model to each component. It then combines their forecasts. We compare this method with simpler models. We also study data cleaning, other inputs, and prediction intervals.

## Start here

1. Read [docs/report.pdf](docs/report.pdf) for the method and findings.
2. Follow the pipeline map below to find the code.
3. Inspect the saved CSVs before fitting models.
4. Use the reproduction commands for a new run.

The repo explains the main CPCB pipeline. It also includes the app and the Shillong studies. The multivariate, Shillong architecture, and second-stage code was restored from the `lalit` branch at commit `a6dad69`. These modules now use the current folders.

## Folder guide

| Folder | What it contains |
|---|---|
| [code/](code/README.md) | Model code, experiment runners, checks, and the app. |
| [results/](results/README.md) | Saved scores, predictions, plots, and study notes. |
| [docs/](docs/) | Three PDFs: report, presentation, and research paper. |
| [data/](data/README.md) | Raw readings, prepared hourly data, and stored components. |

The app is in code/app/. Scratch files, local package folders, and app builds are ignored. Report and presentation generators are not needed to run the project.

## How the pipeline works

| Step | What happens | Where to read the code |
|---|---|---|
| 1. Read settings | Find the project root. Choose sources, splits, and model settings. | code/project.R and code/config/ |
| 2. Load data | Read each source. Put the readings on a common hourly grid. | code/R/core/02_data.R and code/R/preprocessing/20_ingest.R |
| 3. Check readings | Flag bad values. Fill gaps using past data. Keep a mask for valid targets. | code/R/preprocessing/21_quality.R and 22_impute.R |
| 4. Split the series | Keep training, validation, and test periods in time order. | code/R/core/03_preprocess.R and code/R/preprocessed_experiment/40_features.R |
| 5. Build components | Split the series into fast and slow parts. | code/R/core/04_modwt.R and code/R/decomposition/ |
| 6. Make inputs | Build lag rows. For direct models, pair each row with a later target. | code/R/core/05_features.R and code/R/preprocessed_experiment/40_features.R |
| 7. Fit models | Choose settings on validation data. Fit the final model before testing. | code/R/core/06_models.R and code/R/preprocessed_experiment/50_models.R |
| 8. Combine forecasts | Add the predicted components to get the pollutant forecast. | code/R/core/06_models.R and code/R/preprocessed_experiment/70_pipeline.R |
| 9. Score forecasts | Check MAE, RMSE, and MASE on the same valid targets. | code/R/core/08_metrics.R and code/R/preprocessed_experiment/60_eval.R |
| 10. Check intervals | Use past errors to set the prediction band. Measure its test coverage. | code/R/core/07_conformal.R |

There are two main paths. The original benchmark keeps the earlier method for comparison. The cleaned CPCB path adds stricter data checks and trailing components. Do not treat them as the same experiment.

For a quick code tour, read project.R, load_all.R, 05_features.R, 04_modwt.R, 06_models.R, 07_conformal.R, and 08_metrics.R. Then read the cleaned experiment modules in their numbered order.

## 1. Install dependencies

Use R. RStudio is optional. Run this at the repository root:

~~~r
source("code/R/core/00_packages.R")
~~~

The setup installs missing CRAN packages. It also tries the Windows CatBoost package. On other systems, install CatBoost for R separately.

CatBoost must be available for its recorded model. The code can fall back to XGBoost. That fallback is a different experiment. Check CATBOOST_AVAILABLE before fitting.

Python checks use the packages listed here:

~~~sh
python -m pip install -r code/requirements-python.txt
~~~

The app has an npm lockfile. The historical R fits do not have a full package lockfile. Save sessionInfo() with a new run.

All commands below start at the repo root. If Rscript is not on PATH, use its full path. For example:

~~~powershell
& "C:/Program Files/R/R-4.6.1/bin/Rscript.exe" code/validation/check_result_caches.R
~~~

Run this in PowerShell, not at the R prompt. Change the version in the path to match your installation.

## 2. Inspect saved results

These checks do not fit models:

~~~sh
python code/validation/check_results.py
Rscript code/validation/check_result_caches.R
~~~

| Question | Read this file | What it measures |
|---|---|---|
| Original model comparison | results/paper/scores.csv | Saved recursive forecasts. Use only CPCB and ID1 for the original-data summary. |
| Rolling forecasts | results/paper/paper_protocol.rds | A separate rolling one-step run. |
| Filter comparison | results/extensions/filter_scores.csv | Saved Haar, D4, and LA8 scores. |
| Cleaning effect | results/preprocessed_experiment/comparisons/metrics_pollutant_level.csv | Direct 24-hour forecasts on common valid targets. |
| Prediction intervals | results/paper/conformal.rds | The later rolling one-step calibration run. |
| Larger Shillong study | results/shillong/architecture/REPORT.md | Saved architecture comparisons. Its training code is now restored. |
| Multivariate CPCB | results/multivariate/phase2/REPORT.md | Raw target lags versus lags from several pollutants. |
| Second-stage Shillong | results/shillong/second_stage/REPORT.md | PCA and direct, recursive, and hybrid forecasts. |

A recursive forecast uses its own predictions as later inputs. A rolling one-step forecast gets a new observed value at each step. Their scores answer different questions.

The original score CSV is a saved historical result. The current main runner passes observed values into its main evaluation loop. It can therefore run a rolling protocol. A fresh run should not be assumed to reproduce the old recursive table exactly.

The presentation's residual bands use errors from the plotted period. They are descriptive plots. They are not the separate calibration experiment. The older audit also records a different interval run.

## 3. Reproduce the cleaned CPCB experiment

This is the clearest end-to-end study in the repo.

Inputs:
- data/raw/CPCB.csv
- code/config/preprocess.yaml
- code/config/decomp.yaml
- code/config/preprocessed_experiment.yaml

Run the steps in order:

~~~sh
Rscript code/preprocessing/run_preprocess.R paper
Rscript code/experiments/run_preprocessed_experiment.R phase1
Rscript code/experiments/run_preprocessed_experiment.R phase2
Rscript code/experiments/run_preprocessed_experiment.R phase3
Rscript code/experiments/run_preprocessed_experiment.R phase4
~~~

| Stage | What it does |
|---|---|
| Prepare | Build the shared store in data/processed/store/clean/. |
| phase1 | Save an integrity snapshot. Audit the data. Mask bad readings and fill model inputs. |
| phase2 | Build trailing Haar components. Check the rows and targets. |
| phase3 | Fit a small example. Check the model interface. |
| phase4 | Tune and refit the five designs. Score them and write paired comparisons. |

The separate input store is data/processed/store/preprocessed_experiment/. The results are in results/preprocessed_experiment/.

The setup uses seed 7 and 24 input lags. The target is 24 hours ahead. Training ends in February 2023. Validation ends in April. Later valid hours form the test period.

Filled values can be inputs. They are not valid target measurements. Read [the experiment report](results/preprocessed_experiment/REPORT.md) for scores and uncertainty intervals.

After source changes, start at phase1 again. Its integrity snapshot must match the current files.

## 4. Run the other experiments

~~~sh
# Original-model runner. Existing fits may be reused.
Rscript code/experiments/run_experiments.R

# Smaller one-day run.
Rscript code/experiments/run_experiments.R quick

# Filter and other decomposition comparisons.
Rscript code/experiments/run_filter_ablation_catboost.R
Rscript code/experiments/run_extensions.R

# Rolling forecasts and the separate interval experiment.
Rscript code/experiments/run_paper_protocol.R
Rscript code/experiments/run_conformal.R

# Shillong benchmark and direct 1, 6, and 24-hour forecasts.
Rscript code/experiments/run_new_dataset.R
Rscript code/experiments/run_shillong_direct.R
~~~

The original inputs are CPCB.csv and ID1.csv under data/raw/. Shillong uses data/raw/shillong/shillong_15min_2023.parquet. The weather study reads cached ERA5 data. It tries to retrieve the data if the cache is missing.

Optional store preparation:

~~~sh
Rscript code/preprocessing/run_preprocess.R shillong
Rscript code/preprocessing/run_decomp.R mra_haar_J5 --skip-screen --skip-diag
~~~

The decomposition command reads the shared paper store. It is separate from the cleaned CPCB store.

### Restored studies from Lalit's branch

The restored code keeps the study's model settings. Paths now follow this repo. Install the extra R packages before running these studies:

~~~r
install.packages(c("data.table", "glmnet", "pls"))
~~~

These model families fail clearly if a package is missing. They do not silently switch learners.

| Study | Modules | Settings | Outputs |
|---|---|---|---|
| Multivariate CPCB | code/R/multivariate/ | code/config/multivariate.yaml and multivariate_experiments.yaml | results/multivariate/ |
| Shillong architecture | code/R/shillong_architecture/ | code/config/shillong_arch.yaml | results/shillong/architecture/ |
| Shillong second stage | code/R/second_stage/ | code/config/second_stage.yaml | results/shillong/second_stage/ |

For multivariate CPCB, start with the existing paper store. Its constant-fill hours are part of this older, unmasked study. They are not the cleaned-CPCB protocol.

~~~sh
Rscript code/experiments/run_multivariate.R
Rscript code/experiments/run_mv_experiments.R --stage=check
Rscript code/experiments/run_mv_experiments.R --stage=smoke
Rscript code/experiments/run_mv_experiments.R --stage=model --family=lightgbm
~~~

Repeat the model stage for xgboost, catboost, ridge, lasso, and elasticnet. Then run the featsel, targets, and report stages. The report stage reads completed fits and writes result summaries. It does not build the final PDF.

For the larger Shillong study, run these steps in order:

~~~sh
Rscript code/experiments/run_shillong_arch.R --stage=preprocess
Rscript code/experiments/run_shillong_arch.R --stage=audit
Rscript code/experiments/run_shillong_arch.R --stage=smoke
Rscript code/experiments/run_shillong_arch.R --stage=full
Rscript code/experiments/run_shillong_arch.R --stage=families
Rscript code/experiments/run_shillong_arch.R --stage=targets
Rscript code/experiments/run_shillong_arch.R --stage=sensitivity
Rscript code/experiments/run_shillong_arch.R --stage=report
~~~

The hourly store is data/processed/store/shillong/clean/. It is kept separate from CPCB. The saved store is included for inspection. The preprocess stage rebuilds it from the raw 15-minute readings. The audit and smoke stages must pass before the full fits.

The second stage uses the same Shillong data and splits. Run it after the architecture audit and full study:

~~~sh
Rscript code/experiments/run_second_stage.R --stage=tests
Rscript code/experiments/run_second_stage.R --stage=smoke
Rscript code/experiments/run_second_stage.R --stage=run
Rscript code/experiments/run_second_stage.R --stage=report
~~~

These are long runs. Start with one cell, for example `--station=Lumpyngngad --horizons=24 --archs=A2`. The second-stage runner also accepts `--pca=none,0.9`. Check the runner header for each option.

The repo includes selected saved summaries from these studies. It does not copy all fitted model caches from Lalit's branch. A new full run must create its own fits and pass its own checks. Old metadata keeps the paths and hashes from the original run.

### Saved runs and fresh runs

Some runners skip completed fits. A fast run may only load a cache.

Before fitting again:
1. Copy the old result folder outside the repo.
2. Record the current commit.
3. Save the settings, seeds, and R package versions.
4. Check the runner's cache logic.
5. Keep the new predictions with their new scores.

The main caches include forecast_cache.rds, hparams.rds, filter_cache.rds, and extension_cache.rds. There is no single force-refit flag for all runners.

## 5. Run the app

The app reads saved JSON. It does not train models in the browser.

~~~sh
cd code/app
npm ci
npm run dev
~~~

Run npm run build in code/app/ to make a production build. The default asset base is relative. Use VITE_BASE_PATH for hosting under a subpath. See [the app README](code/app/README.md).

If you need to refresh the saved app data, run these from the repo root:

~~~sh
Rscript code/app/data_tools/export_app_assets.R
python code/app/data_tools/export_app_series.py
~~~

## 6. Read the plots and documents

The final report is docs/report.pdf. The talk is docs/presentation.pdf. The assigned paper is docs/research_paper.pdf.

Saved plots are under results/figures/. They cover data checks, forecasts, model comparisons, and intervals. Check each caption before comparing plots. A one-day test window does not always mean a direct 24-hour forecast.

The repo keeps the final documents. It does not need document-generation or publishing tools to explain the method.

## 7. Run checks

~~~sh
Rscript code/validation/smoke_test.R
Rscript code/tests/preprocessing/run_all.R
Rscript code/tests/decomposition/run_all.R
python code/validation/check_results.py
Rscript code/validation/check_result_caches.R
~~~

The cleaned experiment runs data and model checks in phases 2 and 3. Some tests write temporary synthetic stores.

During this integration, all 22 multivariate Phase 1 tests passed. The Shillong audit passed 28 checks and 34 tests. The Phase 2 suite passed 13 of 18 tests. The other five need the missing glmnet or pls packages. Install both before running that full suite. All 99 R files parsed successfully. The full studies and the second-stage fits were not rerun.

## What is complete?

The repo is enough to follow the main method and the cleaned CPCB pipeline. The inputs, settings, model functions, runners, and saved outputs are present.

The restored code now shows the larger Shillong and second-stage pipelines too. Restoring source files does not prove that every old score can be matched. The old fits lack a complete R package lockfile. Some archived scores have no matching prediction arrays. The restored full studies have not been refitted during this update.

Keep code/config/ in the repo. The runners read its YAML files. The historical audit under results/archive/ keeps old paths because it describes earlier runs.
