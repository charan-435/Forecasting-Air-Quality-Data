# Air-quality forecasting with WaveCatBoost

R implementation of Borah et al., *A Novel Hybrid Approach for Efficiently Forecasting Air Quality Data*, with experiments on the paper's CPCB/ID1 data and Shillong air-quality data.

Open `analysis.Rmd` in RStudio and select **Run Document** to view the interactive report. Its default test horizon is seven days. The current deck is `presentation/main.pdf`, with Beamer source in `presentation/main.tex` and `presentation/segments/`.

## Directory guide

```text
analysis.Rmd                    Interactive report
R/
  core/                         Data loading, models, wavelets and metrics
  preprocessing/                Hourly aggregation, quality checks and imputation
  decomposition/                Causal decomposition and stored components
  preprocessed_experiment/       Cleaned CPCB experiment
  reporting/                    Saved-result plots and table formatting
  load_all.R                    Shared R loader
scripts/
  experiments/                  Forecasting experiment entry points
  preprocessing/                Build hourly and decomposition stores
  figures/                      Regenerate presentation figures and tables
  validation/                   Smoke check
config/                         Preprocessing and experiment settings
data/
  raw/                          CPCB.csv, ID1.csv and Shillong station extract
  processed/                    Hourly data and cached ERA5 reanalysis
store/                          Prepared inputs and causal component stores
results/
  paper/                        Saved forecasts, scores and tuning results
  extensions/                   Filter, Fourier and EMD experiment results
  shillong/                     Direct forecasts and imported architecture evidence
  preprocessed_experiment/      Cleaned CPCB predictions and comparisons
presentation/                   Current PDF, LaTeX, bibliography and figures
docs/                           Reference paper and historical audit
tests/                          Preprocessing, decomposition and cleaned-CPCB checks
```

Run the commands below from the repository root. `Rscript` must be on PATH, or use the full path to your R installation. The main runners also resolve the repository root when launched by absolute path.

## Environment and data

`R/core/00_packages.R` lists the analysis packages loaded by `R/load_all.R`. The report also needs `rmarkdown`, `knitr`, and RStudio or Pandoc. The shared loader can install missing analysis packages.

CatBoost is required to reproduce CatBoost scores. The existing implementation falls back to XGBoost when CatBoost is unavailable, which changes the fitted models and results. Keep the cached scores when viewing the recorded experiment.

The paper CSVs originated from [jborah2/WaveCatBoost-Time-Series-Model](https://github.com/jborah2/WaveCatBoost-Time-Series-Model). The Shillong extract contains Lumpyngngad and JN Stadium separately. JN Stadium supplies neighbour inputs in the direct-forecast experiment. Delhi is outside the final report's scope.

## Reproduce the available experiments

| Result | Command |
|---|---|
| Paper CPCB/ID1 comparison | `Rscript scripts/experiments/run_experiments.R` |
| Shillong hourly benchmark | `Rscript scripts/experiments/run_new_dataset.R` |
| Paper-protocol forecast panels and residual intervals | `Rscript scripts/experiments/run_paper_protocol.R` |
| Haar, D4 and LA8 comparison | `Rscript scripts/experiments/run_filter_ablation_catboost.R` |
| Fourier and EMD comparison | `Rscript scripts/experiments/run_extensions.R` |
| Shillong direct forecasts at 1, 6 and 24 hours | `Rscript scripts/experiments/run_shillong_direct.R` |
| Separate conformal calibration experiment | `Rscript scripts/experiments/run_conformal.R` |

The main runners reuse saved caches. A cached invocation can finish without refitting models. Preserve copies of the recorded caches before forcing a new experiment. The paper-protocol cache retains the evaluation protocol and limitations discussed in the report and audit.

For the cleaned CPCB comparison, prepare the shared inputs and run the four phases in order.

```sh
Rscript scripts/preprocessing/run_preprocess.R paper
Rscript scripts/experiments/run_preprocessed_experiment.R phase1
Rscript scripts/experiments/run_preprocessed_experiment.R phase2
Rscript scripts/experiments/run_preprocessed_experiment.R phase3
Rscript scripts/experiments/run_preprocessed_experiment.R phase4
```

Phase 1 creates a fresh integrity snapshot. Historical snapshots referred to the old repository layout and were removed during cleanup.

For the optional Shillong store, run `Rscript scripts/preprocessing/run_preprocess.R shillong`. To rebuild the shared Haar component store, run `Rscript scripts/preprocessing/run_decomp.R mra_haar_J5 --skip-screen --skip-diag`.

### Imported study results

`results/shillong/architecture/` contains the imported 14-design report and CSVs used in the presentation and Q&A. The original architecture-training runner, configuration and second-stage training code were absent before cleanup. Those experiments cannot be refitted end to end from this checkout. Their supplied evidence is retained. The short-horizon notebook experiment is preserved in `run_shillong_direct.R`.

The Q&A's supplied second-stage summaries are recorded explanations and are not generated dynamically by `analysis.Rmd`.

### Score sources

Sections 8.3 and 9 use measured recursive scores from `results/paper/scores.csv` (also mirrored in `scores.rds`). Sections 8.1–8.2 use the separate rolling one-step `paper_protocol.rds` cache; their scores are not interchangeable with recursive scores.

The root `ATSA_Presentation.pptx` retains the older paper-overview layout, but its results table now uses the same recorded project scores. Its explicitly labelled published-paper figures remain reference material. Refresh its native table with `python scripts/figures/sync_pptx_scores.py`. The current project deck is `presentation/main.pdf`, built from `presentation/main.tex`.

Run `Rscript scripts/figures/sync_recorded_results.R` to refresh the web demo from saved results, without fitting models. This also synchronizes forecast-cache score summaries to the CSV. Predictions from incompatible or unavailable runs are not attached to those summaries; the original cache is retained in `docs/audit/legacy_forecast_cache_2026-11-07.rds`. The demo film/viewer uses the separate paper-protocol cache, matching report Sections 8.1–8.2. Run `Rscript scripts/validation/check_result_caches.R` and `python scripts/validation/check_report_scores.py` to check the report, slide tables and web data against their saved sources. The supplied component and second-stage study summaries cannot be independently verified from the retained results.

## Presentation

```sh
Rscript scripts/figures/make_slide_figs.R
Rscript scripts/figures/make_conformal_figs.R
Rscript scripts/figures/make_shillong_arch_figs.R
```

Compile `presentation/main.tex` from the `presentation/` directory with a Beamer-capable LaTeX installation, for example `latexmk -pdf main.tex` or `tectonic main.tex`. The current PDF was rebuilt from this source with uniform Latin Modern fonts and automatic page numbering.

## Checks

```sh
Rscript scripts/validation/smoke_test.R
Rscript tests/phase1a/run_all.R
Rscript tests/phase1b/run_all.R
```

The historical audit and diagnostics are in `docs/audit/`. Its report documents the earlier implementation and includes line numbers from that version.
