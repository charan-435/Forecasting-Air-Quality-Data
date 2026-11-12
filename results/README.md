# Read the experiment before comparing scores

| Folder | Retained evidence | Interpretation |
|---|---|---|
| paper/ | Original forecasts, settings, scores, rolling panels, conformal arrays | Recursive and rolling one-step predictions are different tasks. |
| extensions/ | Filter, Fourier, and EMD comparisons | Coverage varies by learner, sensor, and pollutant. |
| preprocessed_experiment/ | Audit, clean/unmasked fits, predictions, and paired comparisons | Direct 24-hour forecasts on common valid targets; start with REPORT.md. |
| shillong/ | Short-horizon direct scores and imported architecture evidence | The imported study lacks its original training code; start with architecture/REPORT.md. |

CSV files are easiest to inspect. RDS files preserve richer objects such as forecasts and fitting settings. A CSV summary and an arbitrary cached prediction array need not come from the same run.

Filter paper/scores.csv to CPCB and ID1 for the report's original-data summary. Do not include its additional SHILLONG group in that average. The old audit's conformal diagnostic is historical; the later one-step interval arrays are in paper/conformal.rds.

Copy recorded outputs before refitting. Some runners update results and others skip completed fits. Reproduction commands are in the root [README](../README.md).
