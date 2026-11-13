# File guide

This guide covers every retained file in the current tracked project. Paths are relative to the repo root.

Start with README.md for commands. Read code/ for the implementation. Use data/ for inputs, results/ for saved evidence, and docs/ for the three final PDFs.

Model tests exercise data alignment, causality, feature construction, and model fitting. The experiment runners use these tests before training.

## Root files

| File | Use |
|---|---|
| [.gitignore](.gitignore) | Defines which paths are excluded from version control. |
| [README.md](README.md) | Explains this folder and how to use its contents. |
| [FILE_GUIDE.md](FILE_GUIDE.md) | Lists the role of every retained file. |

## Code and app

| File | Use |
|---|---|
| [code/R/README.md](code/R/README.md) | Explains this folder and how to use its contents. |
| [code/R/core/00_packages.R](code/R/core/00_packages.R) | Loads R packages. Installs missing packages when enabled. |
| [code/R/core/01_constants.R](code/R/core/01_constants.R) | Defines paths, pollutants, horizons, and model defaults. |
| [code/R/core/02_data.R](code/R/core/02_data.R) | Reads source data and prepares pollutant series. |
| [code/R/core/03_preprocess.R](code/R/core/03_preprocess.R) | Splits time periods and scales inputs using training data. |
| [code/R/core/04_modwt.R](code/R/core/04_modwt.R) | Builds wavelet components and reconstructs the original series. |
| [code/R/core/05_features.R](code/R/core/05_features.R) | Turns a series into rows of past values and later targets. |
| [code/R/core/06_models.R](code/R/core/06_models.R) | Fits baseline, boosting, and component models. Produces forecasts. |
| [code/R/core/07_conformal.R](code/R/core/07_conformal.R) | Calibrates prediction intervals and measures their coverage. |
| [code/R/core/08_metrics.R](code/R/core/08_metrics.R) | Computes forecast errors and model-rank summaries. |
| [code/R/core/09_hparams.R](code/R/core/09_hparams.R) | Selects model settings using validation data. |
| [code/R/core/10_eda_design.R](code/R/core/10_eda_design.R) | Summarizes time-series patterns used to choose model designs. |
| [code/R/decomposition/30_decomp_registry.R](code/R/decomposition/30_decomp_registry.R) | Defines the available decomposition methods and settings. |
| [code/R/decomposition/31_decomp_causal.R](code/R/decomposition/31_decomp_causal.R) | Builds causal additive Haar components. |
| [code/R/decomposition/32_decomp_trailing.R](code/R/decomposition/32_decomp_trailing.R) | Computes components using trailing windows. |
| [code/R/decomposition/33_decomp_diagnostics.R](code/R/decomposition/33_decomp_diagnostics.R) | Measures component quality and reconstruction errors. |
| [code/R/decomposition/34_decomp_screen.R](code/R/decomposition/34_decomp_screen.R) | Screens decomposition choices using allowed data periods. |
| [code/R/decomposition/35_decomp_io.R](code/R/decomposition/35_decomp_io.R) | Reads and writes stored components and checkpoints. |
| [code/R/load_all.R](code/R/load_all.R) | Loads shared R helpers in dependency order. |
| [code/R/multivariate/40_mv_data.R](code/R/multivariate/40_mv_data.R) | Loads aligned CPCB pollutants, time blocks, and sample counts. |
| [code/R/multivariate/41_mv_features.R](code/R/multivariate/41_mv_features.R) | Builds direct-horizon inputs and train-fitted transforms. |
| [code/R/multivariate/43_mv_models.R](code/R/multivariate/43_mv_models.R) | Defines the common learner interface and LightGBM wrapper. |
| [code/R/multivariate/44_mv_metrics.R](code/R/multivariate/44_mv_metrics.R) | Scores direct forecasts and computes paired uncertainty estimates. |
| [code/R/multivariate/45_mv_families.R](code/R/multivariate/45_mv_families.R) | Adds XGBoost, CatBoost, linear, and PLS learner wrappers. |
| [code/R/multivariate/46_mv_featsel.R](code/R/multivariate/46_mv_featsel.R) | Fits feature-selection and dimension-reduction transforms. |
| [code/R/multivariate/47_mv_eval.R](code/R/multivariate/47_mv_eval.R) | Builds comparable metric tables and paired model comparisons. |
| [code/R/multivariate/48_mv_runner.R](code/R/multivariate/48_mv_runner.R) | Tunes and refits multivariate models using the study settings. |
| [code/R/multivariate/49_mv_stages.R](code/R/multivariate/49_mv_stages.R) | Runs feature-selection, other-target, and result-summary stages. |
| [code/R/preprocessed_experiment/00_setup.R](code/R/preprocessed_experiment/00_setup.R) | Loads cleaned-CPCB settings and protects source inputs. |
| [code/R/preprocessed_experiment/10_audit.R](code/R/preprocessed_experiment/10_audit.R) | Summarizes faults, repeated fills, and usable targets. |
| [code/R/preprocessed_experiment/20_preprocess.R](code/R/preprocessed_experiment/20_preprocess.R) | Creates clean and unmasked experiment inputs. |
| [code/R/preprocessed_experiment/30_decomp.R](code/R/preprocessed_experiment/30_decomp.R) | Builds trailing components for the cleaned experiment. |
| [code/R/preprocessed_experiment/40_features.R](code/R/preprocessed_experiment/40_features.R) | Builds aligned 24-hour targets and input features. |
| [code/R/preprocessed_experiment/50_models.R](code/R/preprocessed_experiment/50_models.R) | Defines the five cleaned-CPCB model designs. |
| [code/R/preprocessed_experiment/60_eval.R](code/R/preprocessed_experiment/60_eval.R) | Scores matched targets and computes paired comparisons. |
| [code/R/preprocessed_experiment/70_pipeline.R](code/R/preprocessed_experiment/70_pipeline.R) | Runs tuning, final fits, and saved experiment outputs. |
| [code/R/preprocessing/20_ingest.R](code/R/preprocessing/20_ingest.R) | Reads each source and aligns readings to hourly timestamps. |
| [code/R/preprocessing/21_quality.R](code/R/preprocessing/21_quality.R) | Flags invalid readings and decides which targets may be scored. |
| [code/R/preprocessing/22_impute.R](code/R/preprocessing/22_impute.R) | Fills model inputs using past information. |
| [code/R/preprocessing/23_store_clean.R](code/R/preprocessing/23_store_clean.R) | Writes hourly data, masks, fill labels, and policy files. |
| [code/R/second_stage/60_ss_core.R](code/R/second_stage/60_ss_core.R) | Implements PCA and direct, recursive, and hybrid forecasts. |
| [code/R/second_stage/61_ss_stages.R](code/R/second_stage/61_ss_stages.R) | Runs second-stage fitting and stores each experiment output. |
| [code/R/second_stage/62_ss_report.R](code/R/second_stage/62_ss_report.R) | Summarizes second-stage scores, comparisons, and plots. |
| [code/R/shillong_architecture/50_sh_data.R](code/R/shillong_architecture/50_sh_data.R) | Builds separate Shillong station panels, weather inputs, and components. |
| [code/R/shillong_architecture/51_sh_features.R](code/R/shillong_architecture/51_sh_features.R) | Builds the separate and shared Shillong architecture inputs. |
| [code/R/shillong_architecture/52_sh_audit.R](code/R/shillong_architecture/52_sh_audit.R) | Summarizes station availability, fills, and component behavior. |
| [code/R/shillong_architecture/53_sh_experiments.R](code/R/shillong_architecture/53_sh_experiments.R) | Fits Shillong architectures and reconstructs pollutant forecasts. |
| [code/R/shillong_architecture/54_sh_stages.R](code/R/shillong_architecture/54_sh_stages.R) | Runs the Shillong audit, smoke fits, shortlist, and sensitivity stages. |
| [code/R/shillong_architecture/55_sh_report.R](code/R/shillong_architecture/55_sh_report.R) | Turns saved architecture fits into scores, comparisons, and plots. |
| [code/README.md](code/README.md) | Explains this folder and how to use its contents. |
| [code/app/.gitignore](code/app/.gitignore) | Excludes installed app dependencies and generated build output. |
| [code/app/README.md](code/app/README.md) | Explains this folder and how to use its contents. |
| [code/app/data_tools/export_app_assets.R](code/app/data_tools/export_app_assets.R) | Exports saved R experiment outputs as browser assets. |
| [code/app/data_tools/export_app_series.py](code/app/data_tools/export_app_series.py) | Exports the stored pollutant series for the browser. |
| [code/app/index.html](code/app/index.html) | Provides the browser entry page. |
| [code/app/package-lock.json](code/app/package-lock.json) | Locks the app dependency versions. |
| [code/app/package.json](code/app/package.json) | Lists app packages and development or build commands. |
| [code/app/public/data/conformal.json](code/app/public/data/conformal.json) | Saved prediction-interval values displayed by the app. |
| [code/app/public/data/eda/acf_pacf_cpcb_pm25.png](code/app/public/data/eda/acf_pacf_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda/boxes_cpcb_pm25.png](code/app/public/data/eda/boxes_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda/diag_2x2_cpcb_pm25.png](code/app/public/data/eda/diag_2x2_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda/eda_design_board_cpcb_pm25.png](code/app/public/data/eda/eda_design_board_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda/eda_energy_cpcb_pm25.png](code/app/public/data/eda/eda_energy_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda/eda_snaive_resid_acf_cpcb_pm25.png](code/app/public/data/eda/eda_snaive_resid_acf_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda/eda_to_pipeline_cpcb_pm25.png](code/app/public/data/eda/eda_to_pipeline_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda/mra_d1d4_s4_cpcb_pm25.png](code/app/public/data/eda/mra_d1d4_s4_cpcb_pm25.png) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/data/eda_decisions.json](code/app/public/data/eda_decisions.json) | Saved eda decisions values for the app. |
| [code/app/public/data/extension_scores.csv](code/app/public/data/extension_scores.csv) | Saved extension scores values for the app. |
| [code/app/public/data/extension_scores.json](code/app/public/data/extension_scores.json) | Saved extension scores values for the app. |
| [code/app/public/data/filter_scores.csv](code/app/public/data/filter_scores.csv) | Saved filter scores values for the app. |
| [code/app/public/data/filter_scores.json](code/app/public/data/filter_scores.json) | Saved filter scores values for the app. |
| [code/app/public/data/hparams.json](code/app/public/data/hparams.json) | Saved hparams values for the app. |
| [code/app/public/data/manifest.json](code/app/public/data/manifest.json) | Maps app station and pollutant choices to their data files. |
| [code/app/public/data/modwt_haar_fixture.json](code/app/public/data/modwt_haar_fixture.json) | Saved modwt haar fixture values for the app. |
| [code/app/public/data/scores.json](code/app/public/data/scores.json) | Saved scores values for the app. |
| [code/app/public/data/series_CPCB.json](code/app/public/data/series_CPCB.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_CPCB_CO.json](code/app/public/data/series_CPCB_CO.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_CPCB_NO2.json](code/app/public/data/series_CPCB_NO2.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_CPCB_O3.json](code/app/public/data/series_CPCB_O3.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_CPCB_PM10.json](code/app/public/data/series_CPCB_PM10.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_CPCB_PM2_5.json](code/app/public/data/series_CPCB_PM2_5.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_CPCB_SO2.json](code/app/public/data/series_CPCB_SO2.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_ID1.json](code/app/public/data/series_ID1.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_ID1_CO.json](code/app/public/data/series_ID1_CO.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_ID1_NO2.json](code/app/public/data/series_ID1_NO2.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_ID1_O3.json](code/app/public/data/series_ID1_O3.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_ID1_PM10.json](code/app/public/data/series_ID1_PM10.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_ID1_PM2_5.json](code/app/public/data/series_ID1_PM2_5.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_ID1_SO2.json](code/app/public/data/series_ID1_SO2.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_SHILLONG.json](code/app/public/data/series_SHILLONG.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_SHILLONG_CO.json](code/app/public/data/series_SHILLONG_CO.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_SHILLONG_NO2.json](code/app/public/data/series_SHILLONG_NO2.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_SHILLONG_O3.json](code/app/public/data/series_SHILLONG_O3.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_SHILLONG_PM10.json](code/app/public/data/series_SHILLONG_PM10.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_SHILLONG_PM2_5.json](code/app/public/data/series_SHILLONG_PM2_5.json) | Saved pollutant series used by the app. |
| [code/app/public/data/series_SHILLONG_SO2.json](code/app/public/data/series_SHILLONG_SO2.json) | Saved pollutant series used by the app. |
| [code/app/public/data/shillong_direct_scores.csv](code/app/public/data/shillong_direct_scores.csv) | Saved shillong direct scores values for the app. |
| [code/app/public/data/shillong_direct_scores.json](code/app/public/data/shillong_direct_scores.json) | Saved shillong direct scores values for the app. |
| [code/app/public/favicon.svg](code/app/public/favicon.svg) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/icons.svg](code/app/public/icons.svg) | Saved chart, icon, or illustration used by the app. |
| [code/app/public/logo.svg](code/app/public/logo.svg) | Saved chart, icon, or illustration used by the app. |
| [code/app/src/App.tsx](code/app/src/App.tsx) | Defines app routes and page layout. |
| [code/app/src/components/Detail.tsx](code/app/src/components/Detail.tsx) | Reusable detail display component. |
| [code/app/src/components/Katex.tsx](code/app/src/components/Katex.tsx) | Reusable katex display component. |
| [code/app/src/components/Layout.tsx](code/app/src/components/Layout.tsx) | Reusable layout display component. |
| [code/app/src/components/Logo.tsx](code/app/src/components/Logo.tsx) | Reusable logo display component. |
| [code/app/src/components/PageTransition.tsx](code/app/src/components/PageTransition.tsx) | Reusable pagetransition display component. |
| [code/app/src/components/Plot.tsx](code/app/src/components/Plot.tsx) | Reusable plot display component. |
| [code/app/src/components/Sparkline.tsx](code/app/src/components/Sparkline.tsx) | Reusable sparkline display component. |
| [code/app/src/lib/modwt.ts](code/app/src/lib/modwt.ts) | Implements the browser wavelet demonstration. |
| [code/app/src/lib/paths.ts](code/app/src/lib/paths.ts) | Resolves app data paths for local and hosted use. |
| [code/app/src/lib/plotlyTheme.ts](code/app/src/lib/plotlyTheme.ts) | Defines shared chart styling. |
| [code/app/src/lib/seriesView.ts](code/app/src/lib/seriesView.ts) | Chooses the displayed series and time range. |
| [code/app/src/lib/stats.ts](code/app/src/lib/stats.ts) | Computes browser summary statistics. |
| [code/app/src/lib/types.ts](code/app/src/lib/types.ts) | Defines TypeScript data shapes. |
| [code/app/src/main.tsx](code/app/src/main.tsx) | Starts the React app. |
| [code/app/src/pages/CatboostPage.tsx](code/app/src/pages/CatboostPage.tsx) | Displays the catboost page in the app. |
| [code/app/src/pages/ConformalPage.tsx](code/app/src/pages/ConformalPage.tsx) | Displays the conformal page in the app. |
| [code/app/src/pages/CreditsPage.tsx](code/app/src/pages/CreditsPage.tsx) | Displays the credits page in the app. |
| [code/app/src/pages/DataPage.tsx](code/app/src/pages/DataPage.tsx) | Displays the data page in the app. |
| [code/app/src/pages/EdaPage.tsx](code/app/src/pages/EdaPage.tsx) | Displays the eda page in the app. |
| [code/app/src/pages/ExtensionsPage.tsx](code/app/src/pages/ExtensionsPage.tsx) | Displays the extensions page in the app. |
| [code/app/src/pages/ModwtPage.tsx](code/app/src/pages/ModwtPage.tsx) | Displays the modwt page in the app. |
| [code/app/src/pages/PlaygroundPage.tsx](code/app/src/pages/PlaygroundPage.tsx) | Displays the playground page in the app. |
| [code/app/src/pages/ResultsPage.tsx](code/app/src/pages/ResultsPage.tsx) | Displays the results page in the app. |
| [code/app/src/pages/Start.tsx](code/app/src/pages/Start.tsx) | Displays the start page in the app. |
| [code/app/src/state/DataContext.tsx](code/app/src/state/DataContext.tsx) | Loads shared app data and exposes it to pages. |
| [code/app/src/styles/global.css](code/app/src/styles/global.css) | Styles the app layout and controls. |
| [code/app/src/vite-env.d.ts](code/app/src/vite-env.d.ts) | Declares Vite types for TypeScript. |
| [code/app/tsconfig.json](code/app/tsconfig.json) | Configures TypeScript compilation. |
| [code/app/tsconfig.node.json](code/app/tsconfig.node.json) | Configures TypeScript compilation. |
| [code/app/vite.config.ts](code/app/vite.config.ts) | Configures app builds and the hosting base path. |
| [code/config/README.md](code/config/README.md) | Explains this folder and how to use its contents. |
| [code/config/decomp.yaml](code/config/decomp.yaml) | Controls component methods, windows, levels, and screening. |
| [code/config/imputation_choice.yaml](code/config/imputation_choice.yaml) | Records the selected fill methods. |
| [code/config/multivariate.yaml](code/config/multivariate.yaml) | Controls the first raw-CPCB direct comparison. |
| [code/config/multivariate_experiments.yaml](code/config/multivariate_experiments.yaml) | Controls multivariate learners, feature selection, and other targets. |
| [code/config/preprocess.yaml](code/config/preprocess.yaml) | Controls source adapters, quality flags, gap filling, and target rules. |
| [code/config/preprocessed_experiment.yaml](code/config/preprocessed_experiment.yaml) | Controls cleaned-CPCB blocks, architectures, and tuning. |
| [code/config/second_stage.yaml](code/config/second_stage.yaml) | Controls PCA thresholds and direct, recursive, and hybrid strategies. |
| [code/config/shillong_arch.yaml](code/config/shillong_arch.yaml) | Controls station blocks, architectures, model grids, and output paths. |
| [code/experiments/run_conformal.R](code/experiments/run_conformal.R) | Runs the separate prediction-interval experiment. |
| [code/experiments/run_experiments.R](code/experiments/run_experiments.R) | Runs the original pollutant and model benchmark. |
| [code/experiments/run_extensions.R](code/experiments/run_extensions.R) | Runs alternative decomposition comparisons. |
| [code/experiments/run_filter_ablation_catboost.R](code/experiments/run_filter_ablation_catboost.R) | Compares Haar, D4, and LA8 wavelet filters. |
| [code/experiments/run_multivariate.R](code/experiments/run_multivariate.R) | Runs the first direct CPCB comparison with one or several pollutants. |
| [code/experiments/run_mv_experiments.R](code/experiments/run_mv_experiments.R) | Runs the full multivariate CPCB experiment stages. |
| [code/experiments/run_new_dataset.R](code/experiments/run_new_dataset.R) | Runs the additional Shillong benchmark. |
| [code/experiments/run_paper_protocol.R](code/experiments/run_paper_protocol.R) | Runs rolling forecasts under the separate paper protocol. |
| [code/experiments/run_preprocessed_experiment.R](code/experiments/run_preprocessed_experiment.R) | Runs the cleaned-CPCB audit, data, fitting, and evaluation phases. |
| [code/experiments/run_second_stage.R](code/experiments/run_second_stage.R) | Runs second-stage tests, smoke fits, full fits, and summaries. |
| [code/experiments/run_shillong_arch.R](code/experiments/run_shillong_arch.R) | Runs the larger two-station architecture study. |
| [code/experiments/run_shillong_direct.R](code/experiments/run_shillong_direct.R) | Runs direct 1, 6, and 24-hour Shillong forecasts. |
| [code/preprocessing/run_decomp.R](code/preprocessing/run_decomp.R) | Builds the configured shared decomposition store. |
| [code/preprocessing/run_preprocess.R](code/preprocessing/run_preprocess.R) | Builds the shared hourly input store from source data. |
| [code/project.R](code/project.R) | Finds the project root and reads UTF-8 settings. |
| [code/requirements-python.txt](code/requirements-python.txt) | Lists packages for Python app-data tools. |
| [code/tests/README.md](code/tests/README.md) | Explains this folder and how to use its contents. |
| [code/tests/decomposition/01_causality.R](code/tests/decomposition/01_causality.R) | Tests causality rules in this pipeline. |
| [code/tests/decomposition/02_additivity.R](code/tests/decomposition/02_additivity.R) | Tests additivity rules in this pipeline. |
| [code/tests/decomposition/03_validity.R](code/tests/decomposition/03_validity.R) | Tests validity rules in this pipeline. |
| [code/tests/decomposition/04_schema.R](code/tests/decomposition/04_schema.R) | Tests schema rules in this pipeline. |
| [code/tests/decomposition/05_resume.R](code/tests/decomposition/05_resume.R) | Tests resume rules in this pipeline. |
| [code/tests/decomposition/06_determinism.R](code/tests/decomposition/06_determinism.R) | Tests determinism rules in this pipeline. |
| [code/tests/decomposition/07_screen_embargo.R](code/tests/decomposition/07_screen_embargo.R) | Tests screen embargo rules in this pipeline. |
| [code/tests/decomposition/08_dummy_method.R](code/tests/decomposition/08_dummy_method.R) | Tests dummy method rules in this pipeline. |
| [code/tests/decomposition/_lib.R](code/tests/decomposition/_lib.R) | Shared setup and assertions for this model test suite. |
| [code/tests/decomposition/run_all.R](code/tests/decomposition/run_all.R) | Runs every test in this folder. |
| [code/tests/multivariate/expected_counts.R](code/tests/multivariate/expected_counts.R) | Computes expected sample counts independently of the model code. |
| [code/tests/multivariate/run_tests.R](code/tests/multivariate/run_tests.R) | Runs the model and data tests for this study. |
| [code/tests/multivariate/run_tests_phase2.R](code/tests/multivariate/run_tests_phase2.R) | Runs the model and data tests for this study. |
| [code/tests/preprocessed_experiment/test_data.R](code/tests/preprocessed_experiment/test_data.R) | Tests test data rules in this pipeline. |
| [code/tests/preprocessed_experiment/test_models.R](code/tests/preprocessed_experiment/test_models.R) | Tests test models rules in this pipeline. |
| [code/tests/preprocessing/01_causal_fill.R](code/tests/preprocessing/01_causal_fill.R) | Tests causal fill rules in this pipeline. |
| [code/tests/preprocessing/02_labelling.R](code/tests/preprocessing/02_labelling.R) | Tests labelling rules in this pipeline. |
| [code/tests/preprocessing/03_coverage.R](code/tests/preprocessing/03_coverage.R) | Tests coverage rules in this pipeline. |
| [code/tests/preprocessing/04_faults.R](code/tests/preprocessing/04_faults.R) | Tests faults rules in this pipeline. |
| [code/tests/preprocessing/05_scoring_guard.R](code/tests/preprocessing/05_scoring_guard.R) | Tests scoring guard rules in this pipeline. |
| [code/tests/preprocessing/06_selection_end.R](code/tests/preprocessing/06_selection_end.R) | Tests selection end rules in this pipeline. |
| [code/tests/preprocessing/07_grid.R](code/tests/preprocessing/07_grid.R) | Tests grid rules in this pipeline. |
| [code/tests/preprocessing/08_schema.R](code/tests/preprocessing/08_schema.R) | Tests schema rules in this pipeline. |
| [code/tests/preprocessing/09_e2e.R](code/tests/preprocessing/09_e2e.R) | Tests e2e rules in this pipeline. |
| [code/tests/preprocessing/_lib.R](code/tests/preprocessing/_lib.R) | Shared setup and assertions for this model test suite. |
| [code/tests/preprocessing/run_all.R](code/tests/preprocessing/run_all.R) | Runs every test in this folder. |
| [code/tests/second_stage/run_tests.R](code/tests/second_stage/run_tests.R) | Runs the model and data tests for this study. |
| [code/tests/shillong/run_tests.R](code/tests/shillong/run_tests.R) | Runs the model and data tests for this study. |

## Data and input stores

| File | Use |
|---|---|
| [data/README.md](data/README.md) | Explains this folder and how to use its contents. |
| [data/processed/SHILLONG.csv](data/processed/SHILLONG.csv) | Prepared shillong values. |
| [data/processed/SHILLONG_preprocess.rds](data/processed/SHILLONG_preprocess.rds) | Saved R inputs or preprocessing metadata for shillong preprocess. |
| [data/processed/era5_shillong_2023.parquet](data/processed/era5_shillong_2023.parquet) | Cached weather data used by the Shillong weather study. |
| [data/processed/series.rds](data/processed/series.rds) | Saved R inputs or preprocessing metadata for series. |
| [data/processed/shillong_hourly_2023.parquet](data/processed/shillong_hourly_2023.parquet) | Prepared shillong hourly 2023 data. |
| [data/processed/store/DATA_QUALITY.md](data/processed/store/DATA_QUALITY.md) | Input-store record for data quality. |
| [data/processed/store/README.md](data/processed/store/README.md) | Explains this folder and how to use its contents. |
| [data/processed/store/clean/README.md](data/processed/store/clean/README.md) | Explains this folder and how to use its contents. |
| [data/processed/store/clean/daily_CPCB.parquet](data/processed/store/clean/daily_CPCB.parquet) | Daily summaries of the prepared station readings. |
| [data/processed/store/clean/daily_ID1.parquet](data/processed/store/clean/daily_ID1.parquet) | Daily summaries of the prepared station readings. |
| [data/processed/store/clean/policy.yaml](data/processed/store/clean/policy.yaml) | Target and origin rules recorded with this input store. |
| [data/processed/store/clean/series.parquet](data/processed/store/clean/series.parquet) | Hourly input values, target masks, and fill labels. |
| [data/processed/store/clean/wide_CPCB.parquet](data/processed/store/clean/wide_CPCB.parquet) | Hourly station data with one column per variable. |
| [data/processed/store/clean/wide_ID1.parquet](data/processed/store/clean/wide_ID1.parquet) | Hourly station data with one column per variable. |
| [data/processed/store/decomp/DIAGNOSTICS.md](data/processed/store/decomp/DIAGNOSTICS.md) | Input-store record for diagnostics. |
| [data/processed/store/decomp/SCREEN.md](data/processed/store/decomp/SCREEN.md) | Input-store record for screen. |
| [data/processed/store/decomp/decomp_log.txt](data/processed/store/decomp/decomp_log.txt) | Input-store record for decomp log. |
| [data/processed/store/decomp/diagnostics.parquet](data/processed/store/decomp/diagnostics.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/diagnostics_d3.parquet](data/processed/store/decomp/diagnostics_d3.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/diagnostics_d4.parquet](data/processed/store/decomp/diagnostics_d4.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/manifests/mra_haar_J5__raw.json](data/processed/store/decomp/manifests/mra_haar_J5__raw.json) | Input-store record for mra haar j5 raw. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=CO.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=CO.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=NO2.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=NO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=O3.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=O3.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=PM10.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=PM10.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=SO2.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=SO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=CO.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=CO.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=NO2.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=NO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=O3.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=O3.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=PM10.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=PM10.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=PM2.5.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=PM2.5.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=SO2.parquet](data/processed/store/decomp/method=mra_haar_J5__raw/station=ID1/variable=SO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/decomp/screen_results.parquet](data/processed/store/decomp/screen_results.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocess_log.txt](data/processed/store/preprocess_log.txt) | Input-store record for preprocess log. |
| [data/processed/store/preprocessed_experiment/clean/fill_codes.csv](data/processed/store/preprocessed_experiment/clean/fill_codes.csv) | Prepared fill codes values. |
| [data/processed/store/preprocessed_experiment/clean/imputation_benchmark.csv](data/processed/store/preprocessed_experiment/clean/imputation_benchmark.csv) | Prepared imputation benchmark values. |
| [data/processed/store/preprocessed_experiment/clean/imputation_choice.yaml](data/processed/store/preprocessed_experiment/clean/imputation_choice.yaml) | Records the selected fill methods. |
| [data/processed/store/preprocessed_experiment/clean/manifest.json](data/processed/store/preprocessed_experiment/clean/manifest.json) | Records the source, settings, and schema of this input store. |
| [data/processed/store/preprocessed_experiment/clean/series.parquet](data/processed/store/preprocessed_experiment/clean/series.parquet) | Hourly input values, target masks, and fill labels. |
| [data/processed/store/preprocessed_experiment/decomp/clean/manifest.json](data/processed/store/preprocessed_experiment/decomp/clean/manifest.json) | Records the source, settings, and schema of this input store. |
| [data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=CO.parquet](data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=CO.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=NO2.parquet](data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=NO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=O3.parquet](data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=O3.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=PM10.parquet](data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=PM10.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet](data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=SO2.parquet](data/processed/store/preprocessed_experiment/decomp/clean/method=mra_haar_J5__raw/station=CPCB/variable=SO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/unmasked/manifest.json](data/processed/store/preprocessed_experiment/decomp/unmasked/manifest.json) | Records the source, settings, and schema of this input store. |
| [data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=CO.parquet](data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=CO.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=NO2.parquet](data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=NO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=O3.parquet](data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=O3.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=PM10.parquet](data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=PM10.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet](data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=SO2.parquet](data/processed/store/preprocessed_experiment/decomp/unmasked/method=mra_haar_J5__raw/station=CPCB/variable=SO2.parquet) | Stored wavelet components and their timestamps. |
| [data/processed/store/shillong/clean/imputation_choice.yaml](data/processed/store/shillong/clean/imputation_choice.yaml) | Records the selected fill methods. |
| [data/processed/store/shillong/clean/policy.yaml](data/processed/store/shillong/clean/policy.yaml) | Target and origin rules recorded with this input store. |
| [data/processed/store/shillong/clean/series.parquet](data/processed/store/shillong/clean/series.parquet) | Hourly input values, target masks, and fill labels. |
| [data/raw/CPCB.csv](data/raw/CPCB.csv) | Original source readings. Used to build model inputs. |
| [data/raw/ID1.csv](data/raw/ID1.csv) | Original source readings. Used to build model inputs. |
| [data/raw/shillong/shillong_15min_2023.parquet](data/raw/shillong/shillong_15min_2023.parquet) | Original source readings. Used to build model inputs. |

## Final documents

| File | Use |
|---|---|
| [docs/presentation.pdf](docs/presentation.pdf) | Final presentation slides. |
| [docs/report.pdf](docs/report.pdf) | Final eight-page project report. |
| [docs/research_paper.pdf](docs/research_paper.pdf) | Assigned research paper. |

## Saved results

| File | Use |
|---|---|
| [results/README.md](results/README.md) | Explains this folder and how to use its contents. |
| [results/extensions/extension_cache.rds](results/extensions/extension_cache.rds) | Saved fits and predictions for decomposition extensions. |
| [results/extensions/extension_scores.csv](results/extensions/extension_scores.csv) | Recorded extension scores table for this study. |
| [results/extensions/extension_scores.rds](results/extensions/extension_scores.rds) | Saved R output for extension scores. |
| [results/extensions/filter_cache.rds](results/extensions/filter_cache.rds) | Saved fits and predictions for the filter comparison. |
| [results/extensions/filter_scores.csv](results/extensions/filter_scores.csv) | Recorded filter scores table for this study. |
| [results/extensions/filter_scores.rds](results/extensions/filter_scores.rds) | Saved R output for filter scores. |
| [results/figures/comparison/conformal_metrics.csv](results/figures/comparison/conformal_metrics.csv) | Recorded conformal metrics table for this study. |
| [results/figures/comparison/conformal_recorded.pdf](results/figures/comparison/conformal_recorded.pdf) | Saved conformal recorded plot. Used to inspect the recorded run. |
| [results/figures/comparison/filter_pm25_bars.pdf](results/figures/comparison/filter_pm25_bars.pdf) | Saved filter pm25 bars plot. Used to inspect the recorded run. |
| [results/figures/comparison/filter_pollutant_bars.pdf](results/figures/comparison/filter_pollutant_bars.pdf) | Saved filter pollutant bars plot. Used to inspect the recorded run. |
| [results/figures/comparison/filter_scores.csv](results/figures/comparison/filter_scores.csv) | Recorded filter scores table for this study. |
| [results/figures/comparison/validation_test.pdf](results/figures/comparison/validation_test.pdf) | Saved validation test plot. Used to inspect the recorded run. |
| [results/figures/comparison/validation_test.png](results/figures/comparison/validation_test.png) | Saved validation test plot. Used to inspect the recorded run. |
| [results/figures/eda/acf_cpcb_pm25.png](results/figures/eda/acf_cpcb_pm25.png) | Saved acf cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/acf_pacf_cpcb_pm25.png](results/figures/eda/acf_pacf_cpcb_pm25.png) | Saved acf pacf cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/boxes_cpcb_pm25.png](results/figures/eda/boxes_cpcb_pm25.png) | Saved boxes cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/diag_2x2_cpcb_pm25.png](results/figures/eda/diag_2x2_cpcb_pm25.png) | Saved diag 2x2 cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/eda_design_board_cpcb_pm25.png](results/figures/eda/eda_design_board_cpcb_pm25.png) | Saved eda design board cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/eda_design_decisions_cpcb_pm25.csv](results/figures/eda/eda_design_decisions_cpcb_pm25.csv) | Recorded eda design decisions cpcb pm25 table for this study. |
| [results/figures/eda/eda_design_summary_cpcb_pm25.csv](results/figures/eda/eda_design_summary_cpcb_pm25.csv) | Recorded eda design summary cpcb pm25 table for this study. |
| [results/figures/eda/eda_energy_cpcb_pm25.png](results/figures/eda/eda_energy_cpcb_pm25.png) | Saved eda energy cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/eda_snaive_resid_acf_cpcb_pm25.png](results/figures/eda/eda_snaive_resid_acf_cpcb_pm25.png) | Saved eda snaive resid acf cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/eda_to_pipeline_cpcb_pm25.png](results/figures/eda/eda_to_pipeline_cpcb_pm25.png) | Saved eda to pipeline cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/filter_taps.png](results/figures/eda/filter_taps.png) | Saved filter taps plot. Used to inspect the recorded run. |
| [results/figures/eda/lag1_scatter_cpcb_pm25.png](results/figures/eda/lag1_scatter_cpcb_pm25.png) | Saved lag1 scatter cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/lag24_scatter_cpcb_pm25.png](results/figures/eda/lag24_scatter_cpcb_pm25.png) | Saved lag24 scatter cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/mra_d1d4_s4_cpcb_pm25.png](results/figures/eda/mra_d1d4_s4_cpcb_pm25.png) | Saved mra d1d4 s4 cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/pacf_cpcb_pm25.png](results/figures/eda/pacf_cpcb_pm25.png) | Saved pacf cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/scatter_lags_cpcb_pm25.png](results/figures/eda/scatter_lags_cpcb_pm25.png) | Saved scatter lags cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/series_cpcb_pm25.png](results/figures/eda/series_cpcb_pm25.png) | Saved series cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/series_shillong_pm25.png](results/figures/eda/series_shillong_pm25.png) | Saved series shillong pm25 plot. Used to inspect the recorded run. |
| [results/figures/eda/snaive_resid_acf_cpcb_pm25.png](results/figures/eda/snaive_resid_acf_cpcb_pm25.png) | Saved snaive resid acf cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/forecast/conformal_cpcb_id1.png](results/figures/forecast/conformal_cpcb_id1.png) | Saved conformal cpcb id1 plot. Used to inspect the recorded run. |
| [results/figures/forecast/conformal_cpcb_pm25.png](results/figures/forecast/conformal_cpcb_pm25.png) | Saved conformal cpcb pm25 plot. Used to inspect the recorded run. |
| [results/figures/forecast/conformal_id1_pm25.png](results/figures/forecast/conformal_id1_pm25.png) | Saved conformal id1 pm25 plot. Used to inspect the recorded run. |
| [results/figures/forecast/conformal_shillong_pm25.png](results/figures/forecast/conformal_shillong_pm25.png) | Saved conformal shillong pm25 plot. Used to inspect the recorded run. |
| [results/figures/forecast/mase_pm25_model_comparison.pdf](results/figures/forecast/mase_pm25_model_comparison.pdf) | Saved mase pm25 model comparison plot. Used to inspect the recorded run. |
| [results/figures/modwt/haar_filters.pdf](results/figures/modwt/haar_filters.pdf) | Saved haar filters plot. Used to inspect the recorded run. |
| [results/figures/modwt/haar_gain.pdf](results/figures/modwt/haar_gain.pdf) | Saved haar gain plot. Used to inspect the recorded run. |
| [results/figures/modwt/modwt_math_slide.jpg](results/figures/modwt/modwt_math_slide.jpg) | Recorded output for modwt math slide. |
| [results/figures/modwt/modwt_math_slide.png](results/figures/modwt/modwt_math_slide.png) | Saved modwt math slide plot. Used to inspect the recorded run. |
| [results/figures/modwt/s6_scales.png](results/figures/modwt/s6_scales.png) | Saved s6 scales plot. Used to inspect the recorded run. |
| [results/figures/modwt/s7_modwt.png](results/figures/modwt/s7_modwt.png) | Saved s7 modwt plot. Used to inspect the recorded run. |
| [results/figures/modwt/synthetic_mra.pdf](results/figures/modwt/synthetic_mra.pdf) | Saved synthetic mra plot. Used to inspect the recorded run. |
| [results/figures/modwt/week_decomp.png](results/figures/modwt/week_decomp.png) | Saved week decomp plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/arch_family_map.png](results/figures/shillong_arch/arch_family_map.png) | Saved arch family map plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/best_by_horizon.png](results/figures/shillong_arch/best_by_horizon.png) | Saved best by horizon plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/component_mase.png](results/figures/shillong_arch/component_mase.png) | Saved component mase plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/level_mase_by_arch.png](results/figures/shillong_arch/level_mase_by_arch.png) | Saved level mase by arch plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/lump_a2_vs_a0_ratio.png](results/figures/shillong_arch/lump_a2_vs_a0_ratio.png) | Saved lump a2 vs a0 ratio plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/lump_test_mae_bars.png](results/figures/shillong_arch/lump_test_mae_bars.png) | Saved lump test mae bars plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/lump_test_mae_table.png](results/figures/shillong_arch/lump_test_mae_table.png) | Saved lump test mae table plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/paired_ratios.png](results/figures/shillong_arch/paired_ratios.png) | Saved paired ratios plot. Used to inspect the recorded run. |
| [results/figures/shillong_arch/ratio_vs_A0_heatmap.png](results/figures/shillong_arch/ratio_vs_A0_heatmap.png) | Saved ratio vs a0 heatmap plot. Used to inspect the recorded run. |
| [results/multivariate/phase0/README.md](results/multivariate/phase0/README.md) | Explains this folder and how to use its contents. |
| [results/multivariate/phase0/proposed_quality_mask_cpcb.csv](results/multivariate/phase0/proposed_quality_mask_cpcb.csv) | Recorded proposed quality mask cpcb table for this study. |
| [results/multivariate/phase1/SMOKE_RESULTS.csv](results/multivariate/phase1/SMOKE_RESULTS.csv) | Recorded smoke results table for this study. |
| [results/multivariate/phase2/REPORT.md](results/multivariate/phase2/REPORT.md) | Explains the study method, scores, and limitations. |
| [results/multivariate/phase2/report/HORIZON_COMPARISON_B0_B1.csv](results/multivariate/phase2/report/HORIZON_COMPARISON_B0_B1.csv) | Recorded horizon comparison b0 b1 table for this study. |
| [results/multivariate/phase2/report/RUN_METADATA.json](results/multivariate/phase2/report/RUN_METADATA.json) | Records run settings, source hashes, package versions, and time. |
| [results/multivariate/phase2/report/SELECTED_CONFIGS.csv](results/multivariate/phase2/report/SELECTED_CONFIGS.csv) | Recorded selected configs table for this study. |
| [results/paper/conformal.rds](results/paper/conformal.rds) | Saved calibration and test prediction intervals. |
| [results/paper/eda_summary.rds](results/paper/eda_summary.rds) | Saved R output for eda summary. |
| [results/paper/forecast_cache.rds](results/paper/forecast_cache.rds) | Saved forecast entries, scores, and available prediction arrays. |
| [results/paper/hparams.rds](results/paper/hparams.rds) | Saved model settings selected for the recorded fits. |
| [results/paper/mase_wide.csv](results/paper/mase_wide.csv) | Recorded mase wide table for this study. |
| [results/paper/mcb.csv](results/paper/mcb.csv) | Recorded mcb table for this study. |
| [results/paper/mcb.rds](results/paper/mcb.rds) | Saved R output for mcb. |
| [results/paper/paper_notebook_protocol_leaky_rolling_1step.rds](results/paper/paper_notebook_protocol_leaky_rolling_1step.rds) | Saved R output for paper notebook protocol leaky rolling 1step. |
| [results/paper/paper_protocol.rds](results/paper/paper_protocol.rds) | Saved rolling one-step forecasts under the paper protocol. |
| [results/paper/scores.csv](results/paper/scores.csv) | Recorded scores table for this study. |
| [results/paper/scores.rds](results/paper/scores.rds) | Saved R output for scores. |
| [results/preprocessed_experiment/A1/architecture.json](results/preprocessed_experiment/A1/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/A1/predictions_test.csv](results/preprocessed_experiment/A1/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/A1/predictions_val.csv](results/preprocessed_experiment/A1/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/A1/result.rds](results/preprocessed_experiment/A1/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/A1/selected.json](results/preprocessed_experiment/A1/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/A1/tuning.csv](results/preprocessed_experiment/A1/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/A1/unmasked_control/architecture.json](results/preprocessed_experiment/A1/unmasked_control/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/A1/unmasked_control/predictions_test.csv](results/preprocessed_experiment/A1/unmasked_control/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/A1/unmasked_control/predictions_val.csv](results/preprocessed_experiment/A1/unmasked_control/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/A1/unmasked_control/result.rds](results/preprocessed_experiment/A1/unmasked_control/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/A1/unmasked_control/selected.json](results/preprocessed_experiment/A1/unmasked_control/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/A1/unmasked_control/tuning.csv](results/preprocessed_experiment/A1/unmasked_control/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B0/architecture.json](results/preprocessed_experiment/B0/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B0/predictions_test.csv](results/preprocessed_experiment/B0/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B0/predictions_val.csv](results/preprocessed_experiment/B0/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B0/result.rds](results/preprocessed_experiment/B0/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B0/selected.json](results/preprocessed_experiment/B0/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B0/tuning.csv](results/preprocessed_experiment/B0/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B0/unmasked_control/architecture.json](results/preprocessed_experiment/B0/unmasked_control/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B0/unmasked_control/predictions_test.csv](results/preprocessed_experiment/B0/unmasked_control/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B0/unmasked_control/predictions_val.csv](results/preprocessed_experiment/B0/unmasked_control/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B0/unmasked_control/result.rds](results/preprocessed_experiment/B0/unmasked_control/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B0/unmasked_control/selected.json](results/preprocessed_experiment/B0/unmasked_control/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B0/unmasked_control/tuning.csv](results/preprocessed_experiment/B0/unmasked_control/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B1/architecture.json](results/preprocessed_experiment/B1/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B1/predictions_test.csv](results/preprocessed_experiment/B1/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B1/predictions_val.csv](results/preprocessed_experiment/B1/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B1/result.rds](results/preprocessed_experiment/B1/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B1/selected.json](results/preprocessed_experiment/B1/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B1/tuning.csv](results/preprocessed_experiment/B1/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B1/unmasked_control/architecture.json](results/preprocessed_experiment/B1/unmasked_control/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B1/unmasked_control/predictions_test.csv](results/preprocessed_experiment/B1/unmasked_control/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B1/unmasked_control/predictions_val.csv](results/preprocessed_experiment/B1/unmasked_control/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B1/unmasked_control/result.rds](results/preprocessed_experiment/B1/unmasked_control/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B1/unmasked_control/selected.json](results/preprocessed_experiment/B1/unmasked_control/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B1/unmasked_control/tuning.csv](results/preprocessed_experiment/B1/unmasked_control/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B2/architecture.json](results/preprocessed_experiment/B2/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B2/predictions_test.csv](results/preprocessed_experiment/B2/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B2/predictions_val.csv](results/preprocessed_experiment/B2/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B2/result.rds](results/preprocessed_experiment/B2/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B2/selected.json](results/preprocessed_experiment/B2/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B2/tuning.csv](results/preprocessed_experiment/B2/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B2/unmasked_control/architecture.json](results/preprocessed_experiment/B2/unmasked_control/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B2/unmasked_control/predictions_test.csv](results/preprocessed_experiment/B2/unmasked_control/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B2/unmasked_control/predictions_val.csv](results/preprocessed_experiment/B2/unmasked_control/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B2/unmasked_control/result.rds](results/preprocessed_experiment/B2/unmasked_control/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B2/unmasked_control/selected.json](results/preprocessed_experiment/B2/unmasked_control/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B2/unmasked_control/tuning.csv](results/preprocessed_experiment/B2/unmasked_control/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B3/architecture.json](results/preprocessed_experiment/B3/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B3/predictions_test.csv](results/preprocessed_experiment/B3/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B3/predictions_val.csv](results/preprocessed_experiment/B3/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B3/result.rds](results/preprocessed_experiment/B3/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B3/selected.json](results/preprocessed_experiment/B3/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B3/tuning.csv](results/preprocessed_experiment/B3/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/B3/unmasked_control/architecture.json](results/preprocessed_experiment/B3/unmasked_control/architecture.json) | Recorded settings or metadata for architecture. |
| [results/preprocessed_experiment/B3/unmasked_control/predictions_test.csv](results/preprocessed_experiment/B3/unmasked_control/predictions_test.csv) | Recorded predictions test table for this study. |
| [results/preprocessed_experiment/B3/unmasked_control/predictions_val.csv](results/preprocessed_experiment/B3/unmasked_control/predictions_val.csv) | Recorded predictions val table for this study. |
| [results/preprocessed_experiment/B3/unmasked_control/result.rds](results/preprocessed_experiment/B3/unmasked_control/result.rds) | Saved R output for result. |
| [results/preprocessed_experiment/B3/unmasked_control/selected.json](results/preprocessed_experiment/B3/unmasked_control/selected.json) | Recorded settings or metadata for selected. |
| [results/preprocessed_experiment/B3/unmasked_control/tuning.csv](results/preprocessed_experiment/B3/unmasked_control/tuning.csv) | Recorded tuning table for this study. |
| [results/preprocessed_experiment/REPORT.md](results/preprocessed_experiment/REPORT.md) | Explains the study method, scores, and limitations. |
| [results/preprocessed_experiment/comparisons/baseline_predictions_test.csv](results/preprocessed_experiment/comparisons/baseline_predictions_test.csv) | Recorded baseline predictions test table for this study. |
| [results/preprocessed_experiment/comparisons/kaisen_existing_scores_context.csv](results/preprocessed_experiment/comparisons/kaisen_existing_scores_context.csv) | Recorded kaisen existing scores context table for this study. |
| [results/preprocessed_experiment/comparisons/metrics_component_level.csv](results/preprocessed_experiment/comparisons/metrics_component_level.csv) | Recorded metrics component level table for this study. |
| [results/preprocessed_experiment/comparisons/metrics_pollutant_level.csv](results/preprocessed_experiment/comparisons/metrics_pollutant_level.csv) | Recorded metrics pollutant level table for this study. |
| [results/preprocessed_experiment/comparisons/paired_comparisons.csv](results/preprocessed_experiment/comparisons/paired_comparisons.csv) | Recorded paired comparisons table for this study. |
| [results/preprocessed_experiment/comparisons/selection_and_checks.json](results/preprocessed_experiment/comparisons/selection_and_checks.json) | Recorded settings or metadata for selection and checks. |
| [results/preprocessed_experiment/data_audit/AUDIT_REPORT.md](results/preprocessed_experiment/data_audit/AUDIT_REPORT.md) | Study notes about audit report. |
| [results/preprocessed_experiment/data_audit/exact_repeat_runs.csv](results/preprocessed_experiment/data_audit/exact_repeat_runs.csv) | Recorded exact repeat runs table for this study. |
| [results/preprocessed_experiment/data_audit/existing_rules_audit.csv](results/preprocessed_experiment/data_audit/existing_rules_audit.csv) | Recorded existing rules audit table for this study. |
| [results/preprocessed_experiment/data_audit/fill_code_blocks.csv](results/preprocessed_experiment/data_audit/fill_code_blocks.csv) | Recorded fill code blocks table for this study. |
| [results/preprocessed_experiment/data_audit/fill_code_hours_by_month.csv](results/preprocessed_experiment/data_audit/fill_code_hours_by_month.csv) | Recorded fill code hours by month table for this study. |
| [results/preprocessed_experiment/data_audit/fill_codes.csv](results/preprocessed_experiment/data_audit/fill_codes.csv) | Recorded fill codes table for this study. |
| [results/preprocessed_experiment/data_audit/provenance.json](results/preprocessed_experiment/data_audit/provenance.json) | Recorded settings or metadata for provenance. |
| [results/preprocessed_experiment/data_audit/schema.csv](results/preprocessed_experiment/data_audit/schema.csv) | Recorded schema table for this study. |
| [results/preprocessed_experiment/data_audit/split_availability.csv](results/preprocessed_experiment/data_audit/split_availability.csv) | Recorded split availability table for this study. |
| [results/preprocessed_experiment/data_audit/summary_raw.csv](results/preprocessed_experiment/data_audit/summary_raw.csv) | Recorded summary raw table for this study. |
| [results/preprocessed_experiment/decomposition/additivity_warmup.csv](results/preprocessed_experiment/decomposition/additivity_warmup.csv) | Recorded additivity warmup table for this study. |
| [results/preprocessed_experiment/decomposition/clean_vs_unmasked_pm25.csv](results/preprocessed_experiment/decomposition/clean_vs_unmasked_pm25.csv) | Recorded clean vs unmasked pm25 table for this study. |
| [results/preprocessed_experiment/decomposition/plots/additivity_resid_pm25.png](results/preprocessed_experiment/decomposition/plots/additivity_resid_pm25.png) | Saved additivity resid pm25 plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/decomposition/plots/components_clean_minus_unmasked_pm25.png](results/preprocessed_experiment/decomposition/plots/components_clean_minus_unmasked_pm25.png) | Saved components clean minus unmasked pm25 plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/decomposition/plots/components_clean_pm25.png](results/preprocessed_experiment/decomposition/plots/components_clean_pm25.png) | Saved components clean pm25 plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/plots/paired_differences_test.png](results/preprocessed_experiment/plots/paired_differences_test.png) | Saved paired differences test plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/plots/test_component_mae.png](results/preprocessed_experiment/plots/test_component_mae.png) | Saved test component mae plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/plots/test_forecasts_window.png](results/preprocessed_experiment/plots/test_forecasts_window.png) | Saved test forecasts window plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/plots/test_mae_by_architecture.png](results/preprocessed_experiment/plots/test_mae_by_architecture.png) | Saved test mae by architecture plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/plots/validation_vs_test.png](results/preprocessed_experiment/plots/validation_vs_test.png) | Saved validation vs test plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/preprocessing/imputation_benchmark_training_block.csv](results/preprocessed_experiment/preprocessing/imputation_benchmark_training_block.csv) | Recorded imputation benchmark training block table for this study. |
| [results/preprocessed_experiment/preprocessing/imputation_by_bucket_method.csv](results/preprocessed_experiment/preprocessing/imputation_by_bucket_method.csv) | Recorded imputation by bucket method table for this study. |
| [results/preprocessed_experiment/preprocessing/imputation_counts.csv](results/preprocessed_experiment/preprocessing/imputation_counts.csv) | Recorded imputation counts table for this study. |
| [results/preprocessed_experiment/preprocessing/plots/distribution_before_after.png](results/preprocessed_experiment/preprocessing/plots/distribution_before_after.png) | Saved distribution before after plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/preprocessing/plots/removed_counts.png](results/preprocessed_experiment/preprocessing/plots/removed_counts.png) | Saved removed counts plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/preprocessing/plots/timeseries_affected.png](results/preprocessed_experiment/preprocessing/plots/timeseries_affected.png) | Saved timeseries affected plot. Used to inspect the recorded run. |
| [results/preprocessed_experiment/preprocessing/pollutant_rules_counts.csv](results/preprocessed_experiment/preprocessing/pollutant_rules_counts.csv) | Recorded pollutant rules counts table for this study. |
| [results/preprocessed_experiment/preprocessing/rules.csv](results/preprocessed_experiment/preprocessing/rules.csv) | Recorded rules table for this study. |
| [results/preprocessed_experiment/preprocessing/summary_before_after.csv](results/preprocessed_experiment/preprocessing/summary_before_after.csv) | Recorded summary before after table for this study. |
| [results/preprocessed_experiment/provenance_models.json](results/preprocessed_experiment/provenance_models.json) | Recorded settings or metadata for provenance models. |
| [results/preprocessed_experiment/smoke/smoke_summary.csv](results/preprocessed_experiment/smoke/smoke_summary.csv) | Recorded smoke summary table for this study. |
| [results/preprocessed_experiment/tests/data_tests.csv](results/preprocessed_experiment/tests/data_tests.csv) | Recorded data tests table for this study. |
| [results/preprocessed_experiment/tests/model_tests.csv](results/preprocessed_experiment/tests/model_tests.csv) | Recorded model tests table for this study. |
| [results/shillong/architecture/BEST_BY_HORIZON.csv](results/shillong/architecture/BEST_BY_HORIZON.csv) | Recorded best by horizon table for this study. |
| [results/shillong/architecture/LEVEL_METRICS.csv](results/shillong/architecture/LEVEL_METRICS.csv) | Recorded level metrics table for this study. |
| [results/shillong/architecture/PAIRED_COMPARISONS.csv](results/shillong/architecture/PAIRED_COMPARISONS.csv) | Recorded paired comparisons table for this study. |
| [results/shillong/architecture/REPORT.md](results/shillong/architecture/REPORT.md) | Explains the study method, scores, and limitations. |
| [results/shillong/architecture/audit/ALIGNMENT.csv](results/shillong/architecture/audit/ALIGNMENT.csv) | Recorded alignment table for this study. |
| [results/shillong/architecture/audit/AUDIT_PASSED](results/shillong/architecture/audit/AUDIT_PASSED) | Marks a successful study stage. Later stages require this marker. |
| [results/shillong/architecture/audit/AVAILABILITY.csv](results/shillong/architecture/audit/AVAILABILITY.csv) | Recorded availability table for this study. |
| [results/shillong/architecture/audit/CHECKS.csv](results/shillong/architecture/audit/CHECKS.csv) | Recorded checks table for this study. |
| [results/shillong/architecture/audit/COVARIATES.csv](results/shillong/architecture/audit/COVARIATES.csv) | Recorded covariates table for this study. |
| [results/shillong/architecture/audit/DECOMP_AUDIT.csv](results/shillong/architecture/audit/DECOMP_AUDIT.csv) | Recorded decomp audit table for this study. |
| [results/shillong/architecture/audit/FILL_METHODS.csv](results/shillong/architecture/audit/FILL_METHODS.csv) | Recorded fill methods table for this study. |
| [results/shillong/architecture/audit/HOURLY_VARIABLES.csv](results/shillong/architecture/audit/HOURLY_VARIABLES.csv) | Recorded hourly variables table for this study. |
| [results/shillong/architecture/audit/MONTHLY_LEVELS.csv](results/shillong/architecture/audit/MONTHLY_LEVELS.csv) | Recorded monthly levels table for this study. |
| [results/shillong/architecture/audit/OVERLAP.csv](results/shillong/architecture/audit/OVERLAP.csv) | Recorded overlap table for this study. |
| [results/shillong/architecture/audit/RAW_15MIN.csv](results/shillong/architecture/audit/RAW_15MIN.csv) | Recorded raw 15min table for this study. |
| [results/shillong/architecture/audit/RUN_METADATA.json](results/shillong/architecture/audit/RUN_METADATA.json) | Records run settings, source hashes, package versions, and time. |
| [results/shillong/architecture/audit/SAMPLE_COUNTS.csv](results/shillong/architecture/audit/SAMPLE_COUNTS.csv) | Recorded sample counts table for this study. |
| [results/shillong/architecture/audit/SPLITS.csv](results/shillong/architecture/audit/SPLITS.csv) | Recorded splits table for this study. |
| [results/shillong/architecture/audit/TEST_SUMMARY.csv](results/shillong/architecture/audit/TEST_SUMMARY.csv) | Recorded test summary table for this study. |
| [results/shillong/direct_scores.csv](results/shillong/direct_scores.csv) | Recorded direct scores table for this study. |
| [results/shillong/forecast_h24.png](results/shillong/forecast_h24.png) | Saved forecast h24 plot. Used to inspect the recorded run. |
| [results/shillong/haar_mra_august.png](results/shillong/haar_mra_august.png) | Saved haar mra august plot. Used to inspect the recorded run. |
| [results/shillong/hourly_pm25_era5.png](results/shillong/hourly_pm25_era5.png) | Saved hourly pm25 era5 plot. Used to inspect the recorded run. |
| [results/shillong/mase_ablation.png](results/shillong/mase_ablation.png) | Saved mase ablation plot. Used to inspect the recorded run. |
| [results/shillong/pm25_15min_coverage.png](results/shillong/pm25_15min_coverage.png) | Saved pm25 15min coverage plot. Used to inspect the recorded run. |
| [results/shillong/pm25_slots_per_hour.png](results/shillong/pm25_slots_per_hour.png) | Saved pm25 slots per hour plot. Used to inspect the recorded run. |
| [results/shillong/second_stage/REPORT.md](results/shillong/second_stage/REPORT.md) | Explains the study method, scores, and limitations. |
| [results/shillong/second_stage/report/BEST_BY_HORIZON.csv](results/shillong/second_stage/report/BEST_BY_HORIZON.csv) | Recorded best by horizon table for this study. |
| [results/shillong/second_stage/report/COMPLETION.csv](results/shillong/second_stage/report/COMPLETION.csv) | Recorded completion table for this study. |
| [results/shillong/second_stage/report/RUN_METADATA.json](results/shillong/second_stage/report/RUN_METADATA.json) | Records run settings, source hashes, package versions, and time. |
