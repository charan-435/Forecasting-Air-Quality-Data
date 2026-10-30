# WaveCatBoost — extension ideas (beyond the paper)

**To:** ATSA team
**From:** WaveCatBoost implementation group
**Purpose:** pick 2–3 extensions that can actually move MASE, not more ablations of the same pipeline.

We already **implemented the paper** (Haar MODWT → one CatBoost per component → sum reconstruct → conformal intervals) and **already added** SARIMA / XGB / LightGBM with and without MODWT, seasonal naive, EDA for \(p\) / \(J\) / \(S=24\), a time-based hyperparameter grid, MCB ranks, and the WHO/NAAQS alert.

The letter’s own future work is **spatial dependence**. Everything below is *not* in the paper and *not* already in our repo.

---

## What the bake-off is telling us

48 cases (2 sensors × 6 pollutants × 4 horizons). No single model wins.

| Fact from `results/scores.csv` | What it implies |
|---|---|
| Seasonal naive is **best on 12 / 48** cases (most of any method) | Long-horizon CPCB forecasts are often just “yesterday at this hour” |
| WaveCatBoost is **best on only 3 / 48** cases, but has the **best mean MASE** (1.10) | Strong on some series, not a universal winner |
| WaveSARIMA wins ID1 PM2.5 and PM10 at 1d / 7d / 31d (MASE **0.17** vs our WaveCatBoost **0.42** on ID1 PM2.5 1-day) | Linear models on wavelet scales beat Ordered boosting on the low-cost sensor |
| CPCB PM2.5 **7-day**: every method is 1.496–1.502 | Recursive 1-step has **collapsed** — models are indistinguishable |
| One \((p, \text{depth}, \eta, J)\) frozen from CPCB PM2.5, 1-day | We never let the model adapt to sensor, pollutant, or horizon |
| AT and RH sit in the CSVs and are plotted, then dropped | We are still strictly univariate, like the letter |

So “train a bigger CatBoost” is the wrong next step. The gaps are **how we forecast multi-step**, **what features we give the trees**, and **whether every wavelet scale should use the same model**.

---

## Already done — do not re-propose

Paper: Haar MODWT, CatBoost per component, IMODWT/sum, conformal PIs, univariate, horizons 1 / 7 / 14 / 31 days.

Us: AR/SARIMA, XGB, LGBM ± wave, snaive, EDA-driven \(p\) and \(J\), train-only min-max, MCB, alert rule.

---

## Proposed extensions (ranked)

Effort: **S** = a few evenings, **M** = about a week, **L** = remaining project if we drop other items.

### 1. Direct (or DirRec) multi-step instead of recursive 1-step — **S–M**

**Why it should help.** Paper Algorithm 1, step 14, and our `recursive_tree_forecast` both feed \(\hat y_{t}\) back as a lag. After a few dozen hours the input is mostly our own errors. That is exactly the CPCB 7-day tie.

**What to build.** For horizon \(h\), train either:

- **Direct:** one model that predicts \(y_{t+h}\) from lags at \(t\) (or 24 direct models for a 1-day path), or
- **DirRec:** predict step 1, then a *new* model for step 2 that may use \(\hat y_{t+1}\), and so on in blocks of 24 hours.

Keep Haar MRA. Apply direct/DirRec **per component**, then sum — that is still WaveCatBoost, just not recursive.

**Success metric.** CPCB PM2.5 7-day MASE should **leave** the 1.496 cluster. If it does not, the problem is the split/features, not the iterator.

### 2. Scale-specific models (the real hybrid) — **M**

**Why it should help.** We currently fit the *same* CatBoost on \(D_1\) (hourly noise/spikes) and on \(S_5\) (smooth daily cycle). WaveSARIMA beating WaveCatBoost on ID1 PM is evidence that some scales are closer to linear.

**What to build.** After Haar MRA:

| Component | Typical content | Candidate model |
|---|---|---|
| \(D_1, D_2\) | noise, spikes | SARIMA / small AR, or a spike classifier + residual |
| \(D_3, D_4\) | intra-day | LightGBM / CatBoost |
| \(S_J\) | daily / slow | CatBoost or SARIMA with period 24 |

Call it **WaveHybrid**. Ablation vs all-CatBoost and all-SARIMA (we already have both).

**Success metric.** ID1 PM2.5 1-day should move from WaveCatBoost 0.42 toward WaveSARIMA 0.17 *without* giving up CPCB PM2.5 1-day (where WaveCatBoost already wins at 0.71).

### 3. Calendar + meteorology features (cheap exogenous) — **S**

**Why it should help.** Hour-of-day and day-of-week are visible in our own boxplots, but the trees only see raw lags. CPCB/ID1 already have **AT** and **RH**. Wavelet-NARX papers (e.g. roadside NO2 with weather + calendar) pick up several points of explained variance from exactly these inputs. The letter is univariate on purpose; this is a clean extension.

**What to build.** Add to the lag matrix: `hour`, `dow`, `is_weekend`, maybe Fourier terms \(\sin(2\pi t/24)\), \(\cos(2\pi t/24)\), plus lagged AT/RH (train-only scaling). No future weather — use last observed AT/RH or a persistence forecast of weather.

**Success metric.** 1-day MASE on PM2.5 / O3 / NO2. O3 especially: SARIMA already crushes trees on CPCB O3 1-day (0.27 vs CatBoost 0.73) because of the strong daily cycle — calendar features should close that gap.

### 4. Unfreeze hyperparameters per series and per horizon — **S**

**Why it should help.** \(p=24\), depth, \(\eta\), \(J\le 5\) were chosen **once** on CPCB PM2.5, 1-day, then copied everywhere. ID1 is a different sensor; 31-day is a different problem.

**What to build.** Small validation grid **inside train** (we already have `choose_hparams`): at least per sensor, and \(J\) / \(p\) per horizon band (1d vs 7d+). Do not peek at test.

**Success metric.** ID1 Wave\* trees should stop losing badly to WaveSARIMA at short horizon; 31-day CPCB WaveLGBM (already 0.57) should not get worse.

### 5. Spatial + cross-pollutant lags (paper’s own future work) — **M**

**Why it should help.** Two sensors, same region. CPCB and ID1 are not independent. PM2.5 and PM10 share sources; O3 chemistry depends on NO2.

**What to build.** For target \(Y\) at sensor A, add lagged \(Y\) from sensor B and lagged sibling pollutants at A (never contemporaneous test values). This is still a tree on a wider lag matrix, optionally still on MODWT components of the *target* only.

**Success metric.** ID1 (noisier) should gain more than CPCB if CPCB is the cleaner neighbour.

### 6. Fix the evaluation, not only the model — **S**

**Why it should help.** One last-\(h\) split means 7-day and 14-day CPCB windows can be a quiet or weird week, which is why snaive “wins” so often. The letter uses the same protocol, so our table is comparable — but it is a weak claim about *skill*.

**What to build.** Rolling origin: e.g. 4 folds, origin stepped by 7 days, report mean ± sd MASE. Optional: pin conformal lower bounds at 0 (the letter’s own plots go negative).

**Success metric.** Rankings that survive more than one test week. Honest intervals with no negative µg/m³.

### 7. Better reconstruction and less boundary leakage — **M**

**Why it should help.** Circular MODWT wraps the start of the series onto the forecast origin. We already decompose **train only**; the last coefficients can still see time 1. Equal-weight sum \(D_1+\cdots+D_J+S_J\) also treats a useless noisy level as equal to the smooth.

**What to build.**

- Reflection (or periodic-on-a-recent-window) extension instead of full-series circular wrap.
- Drop levels whose validation energy / MASE does not help (we already have an energy elbow; make it *forecast*-based).
- Optional: non-negative least squares weights on component forecasts, fit on a train tail.

**Success metric.** Reconstruction error stays ~0 on train; 1-day MASE improves without changing the tree family.

### 8. Conformal → conformalized quantiles (better bands, not just points) — **M**

**Why it should help.** Our \(\hat U_t\) is rolling MAE. The letter is vague on the uncertainty model. Split conformal / CQR (quantile CatBoost at 5% and 95%, then conformal calibration) usually gives tighter 95% bands with the same coverage.

**What to build.** LightGBM/CatBoost `quantile` objective on the **summed** forecast (or per component, then combine). Calibrate on a hold-out tail of train, as in `run_conformal.R`. Keep the WHO/NAAQS rule on the **calibrated** lower bound.

**Success metric.** Test coverage near 95% **and** narrower mean width than `results/conformal.rds`.

---

## What we should *not* spend remaining time on

- Another boosting library (we already have XGB / LGBM / CatBoost ± wave).
- Deep nets (N-BEATS, TFT, transformers) unless a teammate already has a working stack — the letter already claims to beat them; reproducing that is a comparison, not a better WaveCatBoost.
- Re-scraping 15-minute CPCB. Breaks comparability with the public hourly files.
- Graph neural nets on two sensors. Spatial *lags* (idea 5) get 80% of that story.

---

## Suggested team plan

If we only do three things, do them in this order:

1. **Direct/DirRec multi-step** (kills the 7-day collapse).
2. **Calendar + AT/RH lags** (uses data we already load).
3. **Scale-specific WaveHybrid** (turns “Wave + one model” into an actual hybrid).

Optional fourth if someone has a spare day: **unfreeze hparams per sensor**.

Split: one person on the iterator (1), one on features (3 + 4), one on per-scale models (2). Same score table, same MASE, same chronological split — so new rows drop straight into `run_experiments.R` and the notebook.

We should judge a win as: **CPCB 7-day methods no longer tied at ~1.50**, and **ID1 PM short-horizon trees closer to WaveSARIMA**, without breaking CPCB PM2.5 1-day where WaveCatBoost already leads.
