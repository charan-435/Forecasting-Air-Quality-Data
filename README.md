# WaveCatBoost in R

EDA-driven R implementation of Borah et al., *A Novel Hybrid Approach for Efficiently Forecasting Air Quality Data* (IEEE Sensors Letters, 2025), plus AR/SARIMA and other boosting models with and without MODWT.

Data: [jborah2/WaveCatBoost-Time-Series-Model](https://github.com/jborah2/WaveCatBoost-Time-Series-Model).

## Files

- `WaveCatBoost.ipynb` — code notebook (R kernel). Open in Cursor / Jupyter and run from the project root.
- `analysis.Rmd` — interactive report (`runtime: shiny`). Open in RStudio and click **Run Document**.
- `run_experiments.R` — bake-off (6 pollutants × 2 sensors × 4 horizons). Writes `results/`.
- `R/` — helpers (MODWT, models, conformal, metrics).
- `data/raw/` — `CPCB.csv`, `ID1.csv`.

## Run

```bat
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" run_experiments.R quick
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" run_experiments.R
```

Then open `WaveCatBoost.ipynb` (R kernel) or `analysis.Rmd` in RStudio.

CatBoost’s R package is not on CRAN. If it is missing, CatBoost slots fall back to XGBoost; WaveLGBM / WaveXGB still measure the MODWT effect.
