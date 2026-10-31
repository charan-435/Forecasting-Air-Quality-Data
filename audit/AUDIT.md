# Methodological audit — WaveCatBoost R repo

Read-only audit of this implementation of Borah et al., IEEE Sensors Letters 2025. Tests live in `audit/tests/`; numeric dumps in `audit/impact/`. Run `Rscript audit/run_all.R` from the project root (32 PASS / 31 FAIL on 2026-10-30, R 4.5.1). FAIL here means “the invariant we would want after a fix does not hold today.”

---

## 1. Summary

Wave\* bake-off scores in `results/scores.csv` are **recursive multi-step forecasts from one nested origin per horizon**, not the letter’s rolling 1-hour-ahead evaluation. They cannot be compared to Table 1. All Wave\* models train CatBoost/LGB/XGB/SARIMA on **two-sided circular Haar (or D4/LA8) MRA components**: D5/S5 at time t move when Y[t+31] is bumped (D4/LA8: 63 h). The last 31 training rows — the entire lag window at the origin — are wrap-contaminated. Section 8 “letter notebook” paths are worse: **full-series MODWT (test in the circular filter) + teacher forcing + a 95% band fitted on test residuals**. CPCB 7-day conformal coverage is **30.4%** because Û_N ≈ 0.12 was taken from a **perfectly flat 168-hour calibration tail** (sd = 0) and then copied to every horizon hour around a collapsed forecast (yhat range 0.007). Train-only min-max vs the test set, CatBoost (not the XGBoost fallback), lag alignment, Haar/D4/LA8 reconstruction, and MASE vs paper Eq. (6) are **fine**. Trust **1-day recursive MASE as a relative ranking among our models on this split**, not as a reproduction of the letter, and do not trust conformal coverage, MCB as saved in `results/mcb.csv`, or Section 8 walk-forward MASE as a 7-day forecast.

---

## 2. Findings table

| ID | Cat | Sev | Location | What is wrong | Evidence | Affects | Proposed fix | Effort |
|---|---|---|---|---|---|---|---|---|
| F1 | A | **Critical** | `R/04_modwt.R:12-17,45-58,179-180`; `R/06_models.R:257-261` | Wave\* models are fit on two-sided circular MRA. Haar D5/S5 at t depend on Y[t+1…t+31]; D4/LA8 D5 on 63 future hours. Last 31 train rows (all p=24 origin lags of D5/S5) wrap to Y[1]. | `A1_mra_lookahead.R`; `impact/A1_lookahead_profiles.csv`; `impact/A1_wrap_rows_by_split.csv` | Every Wave\* row in `scores.csv`, filter ablation, extensions | Replace with causal / “à trous” MODWT (no future, no circular wrap), drop the last 2^J−1 rows from training | M |
| F2 | A | **Critical** | `R/06_models.R:209-238,183-194`; `run_paper_protocol.R` | Section 8 walk-forward: Haar MODWT on **full y** (test in the filter). Train-window V moves by 48 when test is +50. Teacher-forcing uses actual test coefficients as lags. | `A2_decomp_scope.R`; `X_paper_protocol_leak.R`; `impact/X_paper_protocol_scores.csv` | `results/paper_protocol.rds`, Section 8 “letter” plots and 7d MASE 0.59 / 0.20 | Delete or relabel as “leaky rolling 1-step, not a 7-day forecast”; do not mix with `scores.csv` | S |
| F3 | C | **Critical** | `R/03_preprocess.R:64-72`; `R/01_constants.R:21-26` | One origin per horizon; all four tests **end on the same last timestamp**. 4 nested windows, not 48 independent series. CPCB median MASE 7d=1.38 vs 14d=0.70 because 14d averages a hard week with an easier previous week. | `C15_splits.R`; `impact/C15_split_windows.csv` | Horizon comparisons, MCB over 48 “blocks”, “wave models at 31d” | Rolling origins or non-overlapping windows; report 4 nested tests as one series | L |
| F4 | C | **Critical** | `R/06_models.R:169-178` vs paper notebook `historical_forecasts` | `scores.csv` = recursive h-step from one origin. Paper Table 1 = Darts rolling 1-step. CPCB PM2.5 1d WaveCatBoost: paper 0.57 vs us 0.71; 7d: paper 5.07 vs us 1.50. | `C19_data_vs_paper.R`; `impact/C19_table1_vs_ours.csv` | Any “we reproduced Table 1” statement; cross-paper ranking | Keep both protocols, never average them; Table 1 column must say “rolling 1-step” | S (labelling) / L (re-eval) |
| F5 | A | **High** | `R/09_hparams.R:50-53`; `run_experiments.R:66-107` | Grid is `chrono_split(..., h=24)` on CPCB PM2.5, then frozen for all jobs. That prefix **contains 720 / 744 hours of the 31-day test** and 144 / 168 of the 7-day test. | `A5_hparams_overlap.R`; `impact/A5_hparam_test_overlap.csv` | All 7d/14d/31d tree and Wave\* scores (shared p, depth, η) | Grid on a prefix that ends before the 31d origin, or per-horizon grids | M |
| F6 | A | **High** | `R/07_conformal.R:25-27`; `run_conformal.R:21-43` | Û_N copied to every test hour. CPCB 7d: calibration tail is **exactly constant** (sd=0, 1 unique value), Û≈0.124, yhat range 0.007, **coverage 30.4%**. ID1 coverage 100% with width 48.5 µg/m³ (negative lower bound). Cal and test are both recursive 168-step, so 1-step CS is used as if it were h-step. | `A8_conformal.R`; `impact/A8_conformal_summary.csv` | `results/conformal.rds`, notebook “30% / 100%” | Calibrate on rolling 1-step residuals with varying Û_t; clip lower bound at 0; do not use a flat cal window | M |
| F7 | A | **High** | `run_paper_protocol.R` (quantile of \|Y_test−ŷ\|) | Section 8 ribbon is the 95% residual quantile **on the plotted window** → ~95% coverage by construction. | `A8_conformal.R` `A8_section8_band_not_from_test_residuals` | Section 8 walk-forward bands | Use a held-out calibration window that does not include the plotted test hours | S |
| F8 | C | **High** | `results/mcb.csv`; `R/08_metrics.R:55-73` | Saved MCB uses **n=10** (CD=3.799). Recompute on 48 blocks: CD=1.73, ranks change (WaveSARIMA 4.47, WaveCatBoost 4.90; saved file had 3.3 / 5.1). Blocks are nested, so even n=48 overstates independence. | `C17_mcb.R`; `impact/C17_mcb_recomputed.csv` | `results/mcb.csv` / any MCB plot from that file | Delete stale `mcb.csv`; recompute; treat nested horizons as one block | S |
| F9 | B | **High** | `run_experiments.R:125`; cache mtimes | Key is `sensor\|pollutant\|horizon\|method` only. `R/06_models.R` is **newer than** `forecast_cache.rds` (19:34 vs 17:13). Recursive bake-off still uses the old iterator, but nothing invalidates the cache after code change. | `X_cache_stale.R`; `impact/X_cache_mtimes.csv` | Trust that `scores.csv` matches current `R/` | Hash (J, p, nrounds, filter, git) into the key; rebuild after model-code edits | S |
| F10 | A | **Medium** | `R/03_preprocess.R:14-23,75-89` | `impute_hourly()` (na_seadec) runs on the **full series** before the split and uses Y after a gap (synthetic: t=100 changes when Y[120] is bumped). | `A3_imputation.R`; `impact/A3_imputed_counts.csv` | Would bias any series with NAs near the origin | Impute train only, then project test with a causal rule | S |
| F11 | A | **Medium** | `run_experiments.R:68`; `R/04_modwt.R:76-90` | `choose_J` on full CPCB PM2.5 including test. On this file J_elbow stays 5 if the 31d test is dropped (cap), so **no change to J used** — leak is latent. | `A6_datadriven_settings.R` | J only, currently capped at 5 | Call `choose_J` on the 31d training prefix | S |
| F12 | A | **Medium** | `run_experiments.R:141-146`; `analysis.Rmd:431` | Rmd: “val and test never enter the scaler.” Code: `minmax_fit(split$y_train)` and `chrono_split` sets `y_train = y_fit` (train+val). **Val is in the scaler.** Test is not. | `A4_scaling.R` (train vs test OK); code read of `chrono_split` | Small effect on [0,1] scale; contradicts the report | Fit scaler on `y_train` excluding val | S |
| F13 | C | **Medium** | `results/scores.csv` aggregation | Mean MASE winner = WaveCatBoost (1.103). Median winner = **CatBoost** (0.921). SO2 mean MASE 2.43 vs PM2.5 0.97. Drop SO2: WaveCatBoost still leads mean (0.841) but WaveLGB has the best **median** (0.810). | `C18_aggregation.R`; `impact/C18_mean_median_*.csv` | “best mean MASE” headlines | Report median and leave-one-pollutant ranks | S |
| F14 | C | **Medium** | `R/07_conformal.R:71-85`; `R/01_constants.R:31-32` | `mean(hourly lower PI)` vs WHO **24-hour** PM2.5=15 and NAAQS 24-hour=60. | `C20_alert_period.R` | Alert table in Section 8/10 | Compare 24h rolling means of ŷ / lower bound to 24h limits | S |
| F15 | B | **Medium** | `data/raw/CPCB.csv` last row; `R/02_data.R:14` | Last CPCB hour (06-07-2023 00:00) **equals the first row** (01-07-2022 00:00). It sits in every test window. `dmy_hm` with no tz → UTC, while the stamps are IST wall clock. | `C21_timestamps.R`; `A8_conformal_summary.csv` cal_tail_sd=0 | CPCB 1d/7d/14d/31d targets; conformal cal | Drop or flag the cloned last row; parse with `tz="Asia/Kolkata"` | S |
| F16 | B | **Low** | `R/06_models.R:63-76,92-108` | XGB/LGB `subsample=0.8` with **no seed**. CatBoost `random_seed=7`. | `B14_seeds_versions.R` | Reproducibility of tree rows | `set.seed` / XGB seed param | S |
| F17 | D | **Low** | `analysis.Rmd:632,640` | Dropdown “Test window (this horizon, no leakage)” oversells F1 wrap/two-sided labels. Test Y is held out of the bake-off transform (that part is true). | `X_paper_protocol_leak.R`; F1 | Report wording | Say “test Y held out of the transform; MRA is still two-sided on train” | S |
| F18 | C | **Low** | parsed rows vs GitHub line counts | Parsed CPCB=8881, ID1=9505. Same as the cloned paper GitHub CSVs (`PM2.5` identical). Citation “8882 / 9506 lines” counts a header/blank. | `C19_data_vs_paper.R` | Data-identity footnotes | Report parsed n=8881 / 9505 | S |

---

## 3. Detailed write-up

### F1 — Two-sided circular MRA (A1)

`haar_mra` reconstructs D_j by IMODWT of W_j with zeros elsewhere. The inverse step uses `roll_left` (a **forward** circular shift):

```12:17:R/04_modwt.R
roll_left <- function(x, s) {
  n <- length(x)
  if (s %% n == 0) return(x)
  s <- s %% n
  c(x[(s + 1):n], x[1:s])
}
```

`waveslim::mra(..., method="modwt", boundary="periodic")` is the same idea for D4/LA8.

**Test.** `audit/tests/A1_mra_lookahead.R` on an AR series, t0=200, J=5: bump Y[t0+k] by +10 and watch D_j[t0]. Haar D5 and S change for k=0…**31** (= 2^5−1). D4 and LA8 D5 change for k=0…**63**. Bump Y[n] changes D5/S at t=1 by 0.30 (circular wrap). At J=5, wrap length 31 ≥ p=24, so **every origin lag of D5 and S5 is wrap-contaminated** (`impact/A1_wrap_rows_by_split.csv`).

**Impact.** Not a cheap MASE re-run (WaveCatBoost 1d ~200 s). This is a **label leak inside train**: the target D_j,t is a two-sided filter of Y, so the model sees future-within-train information. Recursive forecasts from the origin then start from those contaminated lags. Bake-off Wave\* vs plain trees is therefore not a clean “value of MODWT” contrast.

**Fix.** Causal MODWT (backward filters only) or drop the last 2^J−1 samples when building the lag matrix. Trade-off: fewer effective training rows; plots of D_j will look different from the letter.

### F2 — Full-series MODWT + teacher forcing (A2 / Section 8)

Bake-off path **does** call `generic_mra(y_train)` (`R/06_models.R:257-261`). Perturbing only the test slice leaves train-only Haar MRA unchanged (`A2_train_only_mra_ignores_test_values` PASS).

`paper_wave_walkforward` does the letter-notebook thing:

```209:214:R/06_models.R
paper_wave_walkforward <- function(y, h, J, fitter, params) {
  y <- as.numeric(y)
  n <- length(y)
  ...
  wt <- haar_modwt(y, J)
```

Full-series V on the train window **moves by 48.4** when test Y is +50. Walk-forward then feeds **actual** test coefficients as lags (`walkforward_tree_forecast`). Reported walk-forward MASE (CPCB 0.59, ID1 0.20) is rolling 1-step with leaked coefficients, not a 7-day forecast.

### F3 — Nested single-origin tests (C15)

`chrono_split` always takes the last h hours. CPCB test windows:

| Horizon | Test start | Test end | Origin |
|---|---|---|---|
| 1d | 2023-07-05 01:00 | 2023-07-06 | 2023-07-05 |
| 7d | 2023-06-29 01:00 | 2023-07-06 | 2023-06-29 |
| 14d | 2023-06-22 01:00 | 2023-07-06 | 2023-06-22 |
| 31d | 2023-06-05 01:00 | 2023-07-06 | 2023-06-05 |

**True independent evaluation units:** 2 sensors × 6 pollutants × **1 terminal origin** = 12 series, with 4 nested suffixes. MCB’s n=48 treats nested suffixes as independent.

**14d vs 7d.** CPCB median MASE 7d=1.383, 14d=0.705. The 7d week is a hard recursive-collapse week (all methods ≈ 1.50 on PM2.5). 14d includes the previous week, which is easier, so the average looks “better at longer horizon.” That is a window artefact, not skill at 14 days.

### F4 — Not the same task as the letter (C19)

Data: this `CPCB.csv` PM2.5 is **identical** to `_orig_wavecatboost/Dataset/CPCB.csv`. Parsed n=8881 / 9505.

Paper Table 1 vs `scores.csv` (overlapping models) is in `impact/C19_table1_vs_ours.csv`. Example, CPCB PM2.5:

| h | Paper LGB / XGB / Cat / Wave | Ours (recursive) LGB / XGB / Cat / Wave |
|---|---|---|
| 1d | 3.81 / 2.85 / 5.32 / **0.57** | 0.74 / 1.37 / 0.82 / **0.71** |
| 7d | 6.86 / 5.92 / 6.57 / **5.07** | 1.50 / 1.50 / 1.50 / **1.50** |

Paper column = rolling 1-step (Darts `historical_forecasts`). Ours = one recursive path of length h. `analysis.Rmd` §10 already says Table 1 will not match; Section 8 walk-forward still presents “letter notebook” MASE next to recursive scores.

### F5 — Hparam prefix overlaps longer tests (A5)

`choose_hparams` uses the 1-day split (train ends at index 8857). Frozen `(p=24, depth=6, η=0.05)` for every job (`hparams.rds`: val MASE 1.848; J=9 from WaveLGB then **capped at 5** in `run_experiments.R:98-103`).

| Horizon | Overlap with hparam train | Fraction of that test |
|---|---|---|
| 1d | 0 | 0 |
| 7d | 144 h | 86% |
| 14d | 312 h | 93% |
| 31d | 720 h | 97% |

Early stopping for each **job** still sits before that job’s test (`A7` PASS). The leak is **model selection**, not the per-job val tail.

### F6 — Conformal 30.4% / 100% (A8)

```25:26:R/07_conformal.R
  # Deployed form: no test actuals. Last calibration U scales the test band.
  u_test <- rep(u_cal[n], length(yhat_test))
```

`run_conformal.R` does a true recursive forecast on the last 168 train hours (not in-sample) — that part is honest. On CPCB those 168 hours are **flat** (`cal_tail_sd=0`, `cal_tail_nunique=1`), so Û_N≈0.124. Test ŷ is also collapsed (`yhat_sd=0.002`, range 0.007). Coverage 30.4%, width 0.38. ID1: coverage 1.00, width 48.5, min lower bound negative (notebook already flags this).

### F7 — Section 8 band from test residuals

`run_paper_protocol.R` sets `half = quantile(|y_test - yhat|, 0.95)`. Same construction as the authors’ `Conformal Prediction.R`. Coverage is tautological; it is not the letter’s CS_t / CQ_t deployed without test actuals.

### F8 — Stale MCB file (C17)

`mcb_from_table(scores)` on 48 complete cases: CD = 3.102 × √(9×10/(6×48)) = **1.734**. `results/mcb.csv` has CD **3.799**, which is the same formula with **n=10**. Rank order disagrees with a fresh compute. Do not cite `mcb.csv`.

### F9 — Cache key / staleness (X)

`06_models.R` mtime after `forecast_cache.rds`. Recursive functions used by the bake-off were not replaced, but walk-forward / paper protocol was added in the same file. Key ignores J (capped 5), p, nrounds. Rebuild after any model change.

### F10 — Imputation before split (A3)

`prepare_series` clips then `impute_hourly` then returns `y`; `chrono_split` comes later. On **these** CSVs there are **zero** NAs in any test or 744 h pre-origin window (`A3_imputed_counts.csv`), so reported MASE is not scoring imputed test targets. The imputer still looks ahead when NAs exist (synthetic test).

### F11–F18

See table. F12: scaler uses pre-test window including 14-day val. F13: mean vs median. F14: 24 h limits vs hourly PI. F15: cloned last CPCB row is inside every test set and matches the all-constant July 2022 start — likely why CPCB conformal cal is flat if that pattern repeats. F16: unseeded XGB/LGB. F17: “no leakage” wording. F18: n=8881 vs “8882 lines.”

---

## 4. Verified OK

| Check | Evidence |
|---|---|
| Bake-off MRA is computed on the train slice; test Y does not enter those coefficients | `A2_train_only_mra_ignores_test_values` PASS; `wave_fit_components(y_train, ...)` |
| Min-max min/max vs **test**: train-only; invert before MASE/MAE/RMSE | `A4_scaling.R`; CPCB PM2.5 1d train min/max = 0.28 / 66.8 = full-series (test not more extreme) |
| CatBoost binary used; 0/96 cache rows `fallback=TRUE`; median elapsed catboost 15 s vs xgb 1.5 s vs wavecatboost 96 s | `B10_catboost_fallback.R` |
| Lag1 = y_{t−1}; `last_lag_row` lag1 = most recent; recursive AR(1) matches φ^k y_n to 1e-16 | `B11_recursive_lags.R` |
| Haar recon max abs err 4e-16; D4 5e-15; LA8 4e-12 | `B12_reconstruction.R` |
| MASE ≡ paper Eq. (6) (mean form); S=24; denom on `y_train` only | `C16_mase.R` |
| scores: 432 rows, 9 methods × 48 cases, 0 NA MASE | `B13_sarima.R` |
| `nemenyi_q(9)=3.102`; 48 distinct (sensor, pollutant, horizon) | `C17_mcb.R` |
| Early stopping val is before **that job’s** test start | `A7_early_stopping.R` |
| EMD not in `scores.csv` / `extension_scores`; plot uses first 500 h of `y_train` | `A9_emd_scope.R` |
| SARIMA `frequency=24`, `seasonal=TRUE`; WaveSARIMA `seasonal=FALSE` on components | `B13_sarima.R` |
| Hourly grid regular, no duplicate timestamps, no gaps >1 h | `C21_timestamps.R` |
| `pacf_cutoff` not used in the bake-off; clip caps hardcoded | `A6_datadriven_settings.R` |
| J_elbow remains 5 if the 31d test is stripped (cap) | `A6_J_elbow_stable_if_test_dropped` |
| Same CPCB PM2.5 vector as the paper GitHub dump | `C19_data_vs_paper.R` |

---

## 5. Unconfirmed

| Item | Why open | What would settle it |
|---|---|---|
| MASE delta if Wave\* used causal MRA | No retrain in this audit (WaveCatBoost 1d ~200 s) | One CPCB PM2.5 1d WaveLGB job: current Haar MRA vs causal pyramid vs drop-last-31-rows |
| Whether `results/mcb.csv` was from a 10-case subset (e.g. PM2.5 only + extra) | CD matches n=10, k=9 exactly | Re-run `R/eval_dump.R` on the current `scores.rds` and replace the file |
| Paper Table 1 units | Treated as MASE; some cells (SO2 23.93) look like MASE with a tiny seasonal-naive scale | Confirm against the letter’s caption / supplement |
| Darts `historical_forecasts` defaults in the public notebook | User notes `forecast_horizon=1`; notebook also sets `output_chunk_length=4` | Print Darts version + `historical_forecasts` signature used by the authors |
| How often CPCB is exactly constant in train (beyond the 168 h cal tail) | We only measured the conformal cal window | Scan run-lengths of identical hours in CPCB PM2.5 |
| IST vs UTC shift on “hour of day” EDA | `dmy_hm` → UTC; stamps are IST wall time; no DST in Asia/Kolkata | Re-parse with `tz="Asia/Kolkata"` and compare hour-of-day boxplots |

---

## 6. Claims audit

| Claim | Where | Verdict |
|---|---|---|
| Circular MODWT on **train only** so test never leaks into coefficients | `R/04_modwt.R:3`; `analysis.Rmd:432` | **Supported** for `scores.csv` Wave\* (F1 is wrap/two-sided **within train**). **Contradicted** for `paper_wave_walkforward` (F2). |
| “Test window (this horizon, no leakage)” | `analysis.Rmd:632` | **Unsupported** as written (F1 + F17). Test Y is held out of the bake-off transform. |
| Haar, scaler, early stopping never see **test** hours | `analysis.Rmd:640` | **Supported** for the cache path. |
| Val never enters the scaler | `analysis.Rmd:431` | **Contradicted** (`y_train = y_fit` includes 14 d val). |
| Hparam grid on CPCB PM2.5 train only, no peek at the test window | `R/09_hparams.R:1-2`; `analysis.Rmd:600` | **Contradicted** for 7/14/31 d (F5). True only vs the **1-day** test. |
| MASE will not match the letter’s Table 1 | `analysis.Rmd:1154` | **Supported** (F4). |
| Recursive multi-step accumulates error at 14- and 31-day | `analysis.Rmd:1154` | **Unsupported** as a monotone: CPCB 14d is *easier* than 7d (F3). 31d mixed. |
| Haar as good as / slightly better than D4/LA8 | `analysis.Rmd:1076` | **Supported** on the WaveLGB 1d filter table (`results/filter_scores.csv`). |
| ID1 7-day coverage 100%, width ~48, negative lower bound; CPCB ~30%, width 0.38 | `WaveCatBoost.ipynb` cell-040 | **Supported** as numbers (`A8`). **Contradicted** if read as “calibrated 95% PIs.” |
| Conformal layer not well calibrated on this split | same notebook cell | **Supported**. |
| CatBoost falls back to XGBoost if missing, labelled in the fit | README; `R/06_models.R:119-126` | **Supported** as code. **Did not fire** on the cached scores (`B10`). |
| WaveLGB identical/superior accuracy, 6× faster | not in `analysis.Rmd` / README (asked as an example) | **Contradicted** by `scores.csv`: mean MASE WaveLGB **1.241** vs WaveCatBoost **1.103**; median 0.970 vs 0.948. Speed: WaveLGB much faster (filter 1d ~6 s vs WaveCatBoost ~96 s median). |
| Wave models dominate at 31 days | not stated as a heading; CPCB PM2.5 31d WaveLGB 0.57 vs snaive 2.87 | **Unsupported** as a global claim: ID1 PM2.5 31d WaveXGB 1.23 **worse** than snaive 0.55. |
| “Zero lookahead” | not a literal string; implied by “train only” | **Contradicted** (F1). |
| Reconstruction Y = Σ D_k + S_K for Haar/D4/LA8 | `analysis.Rmd:1022` | **Supported** (F12 tests, err < 1e-11). |
| Data are the authors’ public hourly files | README; `analysis.Rmd` | **Supported** (PM2.5 identical to cloned GitHub CPCB). |

---

## 7. Suggested fix order

1. **Label and quarantine (S).** Relabel Section 8 walk-forward as rolling 1-step with full-series MODWT. Stop placing it next to recursive MASE. Rebuild `mcb.csv` from 48 cases or drop it. Hash the cache key.
2. **Data hygiene (S).** Drop or flag CPCB’s cloned last row; parse times as IST. Fit min-max on train excluding val.
3. **Hparams (S–M).** Grid on a prefix that ends before 2023-06-05 (31d origin), freeze, then re-run trees.
4. **Causal MRA (M).** Implement backward-only Haar; drop last 2^J−1 rows; re-run WaveLGB CPCB PM2.5 1d as the canary, then the full Wave\* bake-off.
5. **Evaluation design (L).** Either rolling 1-step (to match the letter) **or** recursive multi-step with several origins; do not MCB nested suffixes as 48 blocks.
6. **Conformal (M).** After forecasts are non-collapsed: rolling 1-step residuals, time-varying Û_t, no test-set residual quantile, no flat cal window.
7. **Imputation (S).** Train-only fill — no score impact on these CSVs, needed before any NA-heavy dataset (Shillong).

Do not mix a causal-MRA recursive bake-off with leaked walk-forward numbers in the same table.

---

## How to re-run

```bat
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" audit\run_all.R
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" audit\impact\A1_wrap_rows.R
```

Outputs: `audit/impact/*.csv`, `audit/impact/run_all_summary.txt`.
