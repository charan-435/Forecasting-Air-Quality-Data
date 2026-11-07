# WaveCatBoost demo (ATSA Group 8)

Open `index.html` in a browser. No build step.

To share: zip this folder and send it.

## CSV upload

```
Datetime,PM2.5,NO2
01-07-2022 00:00,12.4,18.1
```

Upload stays local. Only seasonal naive runs in the browser; WaveCatBoost is in the R project.

## Recorded results

The scores table uses `results/paper/scores.csv`. The film and forecast viewer use `results/paper/paper_protocol.rds`, matching report Sections 8.1–8.2 (rolling one-step, K = 9); the band animation is illustrative. These protocols have different scores and are labelled separately. Refresh exports from the repository root with `Rscript scripts/figures/sync_recorded_results.R`. No models are fitted.
