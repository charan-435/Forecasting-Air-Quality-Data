# Read the experiment before comparing scores

| Folder | Retained evidence | Interpretation |
|---|---|---|
| paper/ | Original forecasts, settings, scores, rolling panels, conformal arrays | Recursive and rolling one-step predictions are different tasks. |
| extensions/ | Filter, Fourier, and EMD comparisons | Coverage varies by learner, sensor, and pollutant. |
| preprocessed_experiment/ | Audit, clean/unmasked fits, predictions, and paired comparisons | Direct 24-hour forecasts on common valid targets; start with REPORT.md. |
| shillong/ | Short-horizon scores, architecture evidence, and second-stage summaries | Start with architecture/REPORT.md and second_stage/REPORT.md. The study code is restored under code/R/. |
| multivariate/ | Selected raw-CPCB study summaries and the quality-mask audit | This is an older unmasked study. It differs from preprocessed_experiment/. |

CSV files are easiest to inspect. RDS files preserve richer objects such as forecasts and fitting settings. A CSV summary and an arbitrary cached prediction array need not come from the same run.

Filter paper/scores.csv to CPCB and ID1 for the report's original-data summary. Do not include its additional SHILLONG group in that average. The old audit's conformal diagnostic is historical; the later one-step interval arrays are in paper/conformal.rds.

Copy recorded outputs before refitting. Some runners update results and others skip completed fits. Reproduction commands are in the root [README](../README.md).

figures/comparison/ contains the report figures and comparison tables.

To inspect results, start with the CSVs listed in the root README. Check the station, pollutant, horizon, split, and model before comparing rows. Use matching observations and predictions to recompute errors. The README includes a short R example. See [FILE_GUIDE.md](../FILE_GUIDE.md) for the role of each saved file.

The study folders contain selected summaries, not every cached fit. New runs write their own audit, smoke, and model outputs. Back up saved evidence before refitting. The experiment report stages create result summaries, not the final report PDF.
