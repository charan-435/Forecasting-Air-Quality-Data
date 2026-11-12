# Air-quality forecasting with WaveCatBoost

Applied Time Series Analysis project based on Borah et al., *A Novel Hybrid Approach for Efficiently Forecasting Air Quality Data*. We compare raw-series forecasting with wavelet-component models, study data cleaning, and inspect recorded prediction intervals.

## Repository layout

| Directory | Contents |
|---|---|
| [code/](code/README.md) | R modelling functions, experiment runners, figure generators, checks, and the app. |
| [results/](results/README.md) | Recorded scores, predictions, experiment reports, plots, and historical audit evidence. |
| [docs/](docs/) | Exactly three final PDFs: [report](docs/report.pdf), [presentation](docs/presentation.pdf), and [research paper](docs/research_paper.pdf). |
| [data/](data/README.md) | Original data, processed hourly inputs, and reusable intermediate stores. |

The current React app lives in [code/app/](code/app/README.md). Document source, publishing helpers, the retired static viewer, and one-time migration scripts are removed.

## 1. Install dependencies

Use R; RStudio is optional. From the repository root, install the modelling dependencies:

```r
source("code/R/core/00_packages.R")
```

The package setup installs missing CRAN packages. It attempts CatBoost 1.2.8 for Windows; on other systems install the CatBoost R package separately. CatBoost must be available to reproduce its models. The existing XGBoost fallback is labelled in the results and produces a different experiment. Check `CATBOOST_AVAILABLE` before starting a CatBoost run.

Python figure scripts need the packages in [code/requirements-python.txt](code/requirements-python.txt):

```sh
python -m pip install -r code/requirements-python.txt
```

There is no complete R dependency lockfile for the historical fits. Record `sessionInfo()` with a fresh run; package or input changes can change numerical results. The app has a committed npm lockfile.

All commands below run from the repository root unless a `cd` command is shown. If PowerShell cannot find Rscript, use the installation path, for example:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/Rscript.exe" code/validation/check_result_caches.R
```

## 2. Inspect the saved results first

```sh
python code/validation/check_results.py
Rscript code/validation/check_result_caches.R
```

These commands verify recorded tables and cache consistency without fitting models. The first also checks the app's exported scores, cached series references, and the three document PDFs.

| Question | Recorded source | Evaluation |
|---|---|---|
| Original model comparison | results/paper/scores.csv | Recursive terminal-origin forecasts; filter CPCB/ID1 for the paper-data summary. |
| Rolling forecast panels | results/paper/paper_protocol.rds | Rolling one-step forecasts, separate from the recursive comparison. |
| Haar, D4 and LA8 | results/extensions/filter_scores.csv | One-day filter comparison. |
| Cleaning effect | results/preprocessed_experiment/comparisons/metrics_pollutant_level.csv | Direct 24-hour predictions on common valid targets. |
| Calibrated intervals | results/paper/conformal.rds | Recorded rolling one-step split-conformal experiment. |
| Imported Shillong study | results/shillong/architecture/REPORT.md | Retained results; complete original training code is unavailable. |

Do not combine different evaluation protocols into one ranking. Presentation residual bands are descriptive bands fitted on the displayed residuals; the recorded calibrated intervals are a separate experiment.

## 3. Reproduce the cleaned CPCB experiment

Inputs are `data/raw/CPCB.csv` and the settings in [code/config/preprocessed_experiment.yaml](code/config/preprocessed_experiment.yaml).

```sh
Rscript code/preprocessing/run_preprocess.R paper
Rscript code/experiments/run_preprocessed_experiment.R phase1
Rscript code/experiments/run_preprocessed_experiment.R phase2
Rscript code/experiments/run_preprocessed_experiment.R phase3
Rscript code/experiments/run_preprocessed_experiment.R phase4
```

| Stage | Work |
|---|---|
| Prepare | Build the shared hourly store at data/processed/store/clean/. |
| phase1 | Snapshot project integrity, audit values, mask invalid observations, and fill inputs from the past. |
| phase2 | Build trailing Haar components and check data/target alignment. |
| phase3 | Run a small fit and verify model interfaces. |
| phase4 | Tune, refit, evaluate B0/A1/B1/B2/B3, and write paired comparisons. |

The isolated intermediate store is `data/processed/store/preprocessed_experiment/`. Outputs go to `results/preprocessed_experiment/`. Filled values may be model inputs; invalid targets are not scored. Run phases in order. After source or layout changes, start again at phase1 so the integrity snapshot describes the current checkout.

The configuration uses seed 7, 24 input lags, direct 24-hour targets, training through February 2023, validation through April, and later valid test targets. The full runner applies the saved search grid.

## 4. Reproduce the original models and extensions

```sh
# Original recursive comparison; completed fits may be loaded from cache.
Rscript code/experiments/run_experiments.R

# Smaller one-day check with seasonal naive, SARIMA and LightGBM variants.
Rscript code/experiments/run_experiments.R quick

# One-day WaveCatBoost filter comparison, then Fourier/EMD extensions.
Rscript code/experiments/run_filter_ablation_catboost.R
Rscript code/experiments/run_extensions.R

# Rolling one-step forecast panels and the separate conformal experiment.
Rscript code/experiments/run_paper_protocol.R
Rscript code/experiments/run_conformal.R

# Shillong benchmark and direct 1/6/24-hour models.
Rscript code/experiments/run_new_dataset.R
Rscript code/experiments/run_shillong_direct.R
```

Original inputs are `data/raw/CPCB.csv` and `data/raw/ID1.csv`. Shillong uses `data/raw/shillong/shillong_15min_2023.parquet`. The direct weather study uses `data/processed/era5_shillong_2023.parquet`; if absent, its runner attempts retrieval.

Optional shared decomposition:

```sh
Rscript code/preprocessing/run_preprocess.R shillong
Rscript code/preprocessing/run_decomp.R mra_haar_J5 --skip-screen --skip-diag
```

### Cached versus fresh results

Some runners skip completed fits. A quick successful run can mean cached results were loaded. Before retraining, copy the relevant result folder outside this checkout and inspect the runner's cache checks. The main caches are `forecast_cache.rds`, `hparams.rds`, `filter_cache.rds`, and `extension_cache.rds`. There is no universal force-refit flag. Preserve the original inputs, seed, split settings and dependency versions alongside each new run.

### Reproduction limit

The imported 14-design Shillong architecture study is missing its original training runner, configuration and part of the second-stage code. This repository can validate its retained tables and regenerate their plots, but cannot refit that study end to end. The supplied component/second-stage summaries also lack enough retained evidence for independent numerical verification. These limits are stated in the report and experiment notes. Historical audit files under `results/archive/` retain their original paths and dates.

## 5. Run the app

The app displays committed JSON and illustrates the implementation; it does not train models in the browser. With Node.js 22 or later:

```sh
# Optional: refresh app data from recorded experiment outputs.
Rscript code/app/data_tools/export_app_assets.R
python code/app/data_tools/export_app_series.py

cd code/app
npm ci
npm run dev
```

Run `npm run build` inside `code/app/` for a production build. The default asset base is relative; set `VITE_BASE_PATH` when hosting beneath a project subpath. See [the app README](code/app/README.md).

## 6. Reproduce figures

```sh
Rscript code/figures/make_eda_figures.R
Rscript code/figures/make_conformal_figures.R
Rscript code/figures/make_shillong_figures.R
python code/figures/make_comparison_figures.py --rscript "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
```

| Output | Contents |
|---|---|
| results/figures/eda/ | Raw series, ACF/PACF, lag plots, design decisions and Haar diagnostics. |
| results/figures/forecast/ | Recorded rolling forecasts with descriptive residual bands. |
| results/figures/shillong_arch/ | Architecture comparisons drawn from saved validation/test CSVs. |
| results/figures/comparison/ | Filter bar plots, cleaned metrics and recorded calibrated intervals. |

These commands generate individual figures and diagnostic tables. They do not generate reports or presentations. The three final PDFs are supplied in `docs/`; document source and publishing scripts are intentionally absent.

## 7. Check code and data assumptions

```sh
Rscript code/validation/smoke_test.R
Rscript code/tests/preprocessing/run_all.R
Rscript code/tests/decomposition/run_all.R
python code/validation/check_results.py
Rscript code/validation/check_result_caches.R
```

The cleaned experiment runs its data and model checks during phases 2 and 3. Tests can write temporary synthetic stores. Shared modelling helpers stay separate from the cleaned experiment so the evaluation protocols remain clear. Scratch work under `tmp/`, app builds, package caches and local deployment state are ignored and excluded from the online repository.
