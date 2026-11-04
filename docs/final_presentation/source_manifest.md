# Source Manifest

## Main source files
- `run_multivariate.R`, `run_mv_experiments.R`
- `R/40_mv_data.R` through `R/49_mv_stages.R`
- `run_shillong_arch.R`
- `R/50_sh_data.R` through `R/55_sh_report.R`
- `run_second_stage.R`
- `R/60_ss_core.R` through `R/62_ss_report.R`
- `R/20_ingest.R` through `R/23_store_clean.R`
- `R/31_decomp_causal.R`, `R/32_decomp_trailing.R`
- `config/multivariate.yaml`, `config/multivariate_experiments.yaml`
- `config/shillong_arch.yaml`, `config/second_stage.yaml`
- `config/preprocess.yaml`, `config/decomp.yaml`

## Main reports
- `results/shillong_arch/REPORT.md`
- `results/multivariate/phase2/REPORT.md`
- `results/multivariate/phase1/DATASET_REPORT.md`
- `results/multivariate/phase0/DATA_AUDIT.md`
- `results/multivariate/phase0/DECOMPOSITION_AUDIT.md`
- `audit/AUDIT.md`

## Numerical result directories
- `results/shillong_arch/report/`
- `results/shillong_arch/archive_o3_included/report/`
- `results/multivariate/phase2/report/`
- `results/multivariate/phase2/models/`
- `results/multivariate/phase2/featsel/`
- `results/multivariate/phase1/`
- `results/second_stage/tests/`

## Stores and data
- `store/clean/series.parquet`
- `store/shillong/clean/series.parquet`
- `data/raw/CPCB.csv`, `data/raw/ID1.csv`
- `data/raw/shillong/shillong_15min_2023.parquet`
