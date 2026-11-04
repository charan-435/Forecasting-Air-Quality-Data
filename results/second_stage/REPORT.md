# Second-stage experiments: PCA and direct / recursive / hybrid forecasting (Shillong, PM2.5)

This study adds two things to the Shillong architecture comparison (`results/shillong_arch/REPORT.md`, called *the original study* below):

- **PCA on the lag features**, with 90%, 95% and 99% variance thresholds.
- **Two multi-step strategies** alongside the original direct models:
  - **recursive** (a one-step model fed its own predictions);
  - **hybrid** (recursive up to a switch point s, then a direct model).

Everything else is held fixed from the original study: stations, splits, samples, target timestamps, imputation and masks, the origin policy, metrics, MASE scales, the LightGBM tuning grid, the 3 seeds and the tuning seed.

The original pipeline, data and results were not modified. All new code, configs and outputs are separate (see *Reproduction*). As a check, the direct runs with original features in this study reproduce the original study's predictions exactly: **176 of 176 (station, architecture, horizon, block) cells are identical** (`report/ORIGINAL_REPRODUCTION.csv`).

> **Status.** 88 cells are complete: the 24 primary cells (A2, A3 and C2_sep × 2 stations × 4 PCA settings) and 64 extension cells (A0, A1, B0, B1, B2, B3, C1_sep and C1_sh). C2_sh, C3_sep and C3_sh were not run (see §7).

---

## 1. Answers in brief

All comparisons are on the **test** block, paired on identical target hours. "Significant" means the 95% moving-block-bootstrap interval of the MAE ratio excludes 1 *and* the Diebold–Mariano p-value is below 0.05; "better / worse" counts below use that rule. The counts pool many overlapping cells (4 horizons × 4 PCA settings × architectures × stations), so read them as a description of consistency, not as independent tests.

| Question | Answer |
|---|---|
| Does PCA help? | **It depends on the strategy.** Direct models: it hurts (better/worse 22/116, median MAE ratio about 1.03). Hybrid models: neutral (61/42, median 1.00). Recursive models: it helps (135/46, median about 0.93). |
| Best threshold? | No threshold is consistently best. The verdict counts for 90, 95 and 99% are within a few cells of each other for every strategy (§3.2). |
| Does PCA help A2, A3 or C2_sep most? | None of the three gains with direct forecasting. With recursion, PCA helps C2_sep most: at Lumpyngngad it cuts recursive MAE by 44–63%, from 33.6–64.5 to 17.9–25.5 at h ≥ 168. That is because recursive C2_sep with original features degrades badly (§3.3). |
| Direct vs recursive? | **Direct is better.** Recursive is significantly worse in 172 comparisons and better in 34, and the gap grows with horizon: median ratio 1.04 at 24 h, 1.02 at 168 h, 1.15 at 336 h and 1.13 at 744 h. At Lumpyngngad recursive is worse in 133 comparisons and better in 2. |
| Does hybrid beat both? | **It beats recursive** almost everywhere: 149 better, 21 worse. **Against direct the result is mixed:** 86 better, 37 worse, 141 not clearly different, median ratio 0.99. |
| Does hybrid help more at longer horizons? | **No.** Against direct, the share of significant wins is similar at 168, 336 and 744 h (29/12, 32/14, 25/11). Against recursive the advantage is largest at 336 h. |
| Best combination per horizon? | See §5. On test, the best combination at Lumpyngngad is a direct or hybrid A2/A3 model at every horizon. At JN Stadium the winner changes at every horizon and is never far from persistence. The configuration chosen on validation is often not the best on test. |
| Consistent across stations? | Partly. "Recursive is worse than direct" and "PCA helps recursive" hold at both stations. Whether hybrid beats direct differs by station and architecture: all 11 architectures at JN Stadium: 63 better / 23 worse; at Lumpyngngad: 23 / 14. |
| Statistical strength? | Strong for recursive vs direct and hybrid vs recursive at Lumpyngngad (many DM p-values below 1e-6). Weak elsewhere: most PCA and hybrid-vs-direct effects are within ±5% and many intervals include 1. |
| Is validation a reliable guide? | **No.** Validation and test agree on the direction of an effect in only 64% of comparisons. At Lumpyngngad, validation picks recursive A2 with PCA 90% for h = 168, 336 and 744, and that choice is significantly worse on test than the original A2 direct model (MAE ratio 1.14, 1.33 and 1.22). |
| Computational cost | Direct is the cheapest. Recursive costs the one-step fits plus a step-by-step loop. Hybrid adds a 4-fold cross-fit of the one-step models and the stage-2 fits. For C2_sep (30 component models with 432–720 inputs), recursive plus hybrid took 2.5–5.4 h per cell, against 4–25 min for direct (§6). |

**Bottom line.**

- **Neither PCA nor a recursive or hybrid strategy gives a reliable, validation-selectable improvement over the original direct models.**
- The clearest positive results are both conditional:
  - PCA is the best of the three feature settings for *recursive* forecasting (90/95/99% vs original features), although recursive forecasting remains worse than direct.
  - Hybrid improves significantly on direct in about a third of comparisons (86 of 264). But the switch point and PCA setting chosen on validation do not carry over reliably to test.

---

## 2. Design

### 2.1 Experiment matrix

The matrix is {none, PCA 90%, PCA 95%, PCA 99%} × {direct, recursive, hybrid} × h ∈ {24, 168, 336, 744}, for each architecture and station, with PM2.5 as the target and LightGBM as the model. Each cell is (station, architecture, PCA setting) and produces:

- 4 direct runs;
- 1 recursive run (one one-step model, read off at every horizon);
- 9 hybrid runs: s ∈ {24, 48, 72} × h ∈ {168, 336, 744}.

**Skipped by design** (`report/SKIPPED.csv`):
- Hybrid at h = 24: with s = 24 the recursive block already reaches the horizon, so hybrid is identical to recursive, and s = 48 or 72 overshoots.
- Hybrid with s ≥ h in general.

### 2.2 PCA

- **What it's fitted on.** Standardisation and PCA are fitted on the **training block of each model only**. The fitted transform is then applied unchanged to validation and test. When the model is refitted on train + validation for the test forecasts, it still uses the training-block PCA; the PCA is never refitted on validation or test rows. Tests T01 and T04 check this.
- **What goes in.** Pollutant lag columns only. The target value at h is never an input.
- **What passes through untouched.** Meteorological covariates (A3, B2, B3, C3), calendar features and the component id of shared models. They are appended after the principal component scores. For A3, the PCA covers the pollutant lag block alone (T03).
- **Retained components.** k is the smallest number of components reaching the threshold (T02). For decomposed separate-model architectures (B0, B2, C1_sep, C2_sep), each component model has its own PCA fitted on its own training rows (T04).
- **Where to find k.** `report/PCA_RETAINED_BY_MODEL.csv` gives k for every model; `report/PCA_EXPLAINED_VARIANCE.csv` gives the cumulative curves.

Typical k (median across component models and horizons):

| Station | Arch | inputs | k 90% | k 95% | k 99% |
|---|---|---|---|---|---|
| Lumpyngngad | A2 | 72 | 8 | 16 | 39–40 |
| Lumpyngngad | A3 | 72 lags + 7 pass-through | 8 | 16 | 39–40 |
| Lumpyngngad | C2_sep | 432 | 43–46 | 58–60 | 80 |
| JN Stadium | A2 | 120 | 22–26 | 39–43 | 77–80 |
| JN Stadium | A3 | 120 lags + 10 pass-through | 22–26 | 39–43 | 77–80 |
| JN Stadium | C2_sep | 720 | 55 | 77–79 | 124–125 |

The hybrid stage-2 models need fewer components (for example, 4 instead of 8 for Lumpyngngad A2 at 90%). Their inputs are built partly from recursively predicted hours, which are smoother than observed hours.

### 2.3 Recursive strategy

A one-step (h = 1) model is trained per series that the architecture needs. It uses the architecture's own features, tuning grid and seeds.

| Architecture type | One-step models trained |
|---|---|
| Univariate level (A0, A1) | one, for PM2.5 |
| Multivariate level (A2, A3) | one per pollutant |
| Decomposed, separate models (B0, B2, C1_sep: the target only; C2_sep: every pollutant) | one per component |
| Shared (B1, B3, C1_sh) | one model for all components |

At each step, the 3 seeds' predictions are averaged and pushed into a sliding state window for each origin.

- **Decomposed architectures.** The models predict the components. Their sum is the predicted level, and the components are then **recomputed from the extended level series** with the same causal Haar filter. The pushed components are therefore exactly the decomposition of the history that includes the predictions (T08). Level = sum of components holds at every step (T08, smoke checks).
- **Meteorological covariates (A3, B2, B3).** Future meteorology is not observed, so covariates are **held at their value at the true forecast origin**, a persistence assumption. The calendar features use the true target hour.
- **Causality.** Tests T06 and T07 check that:
  - changing any data after the origin changes neither recursive forecasts nor hybrid inputs (T06);
  - step 1 of the recursion reproduces the one-step model on the original features exactly (T07);
  - the state features at step 0 equal the original feature builder for all 14 architectures at both stations (T05).
- **Models used per block.** Validation forecasts use the train-only (selection) models; test forecasts use the train + validation refit, exactly as in the direct pipeline.

**Known limitation.** The one-step models are trained on observed lags but run on their own predictions, so errors compound (exposure bias). This study does not apply teacher-forcing corrections such as DAgger or noise injection to the recursive strategy. It is evaluated as the standard recursive baseline. The mismatch is what the hybrid design addresses below.

### 2.4 Hybrid strategy and the train / inference mismatch

The hybrid forecast for horizon h with switch point s works like this:

1. Run the recursive models from the true origin o for s steps.
2. Apply a stage-2 direct model for horizon h − s at the virtual origin o + s.

The stage-2 inputs are the architecture's normal features, with these differences:
- the most recent 24 hours of every series, including the decomposed components, come from the recursion (predicted hours o+1 … o+s);
- older lags are observed;
- covariates are held at the true origin;
- the calendar features use the target hour.

**Addressing the mismatch.** A stage-2 model trained on *observed* inputs but applied to *predicted* inputs would have exactly the problem the spec asks to avoid. So the stage-2 training inputs are also produced by recursion:

- **Training rows** come from **cross-fitted** one-step models. The training origins are split into 4 contiguous folds. For each fold, every one-step model is refitted on training rows whose whole window `[o − 55, o + 1]` does not touch `[fold start − 55, fold end + 72]`, using the same tuned parameters and best iteration count. The fold's origins are then forecast recursively with those models. No training row's recursive inputs come from a model that saw that row's future (T09).
- **Validation rows** use the selection (train-only) one-step models.
- **Test rows** use the train + validation refit models.

So at every stage the stage-2 model sees recursively predicted inputs produced by models that never saw the target period. Its inputs at test time come from the same distribution as during training. The switch point s is chosen per (station, architecture, PCA, h) by **validation MAE only** (`report/HYBRID_SWITCH_POINTS.csv`).

### 2.5 Statistics

For each comparison, both forecasts cover the same target hours (seed-mean forecasts). The report gives:
- the MAE ratio, with a 95% interval from a paired moving-block bootstrap (block length = max(h, the Politis–White estimate for the loss differential));
- a Diebold–Mariano test with HAC variance.

All results are in `report/PAIRED_COMPARISONS.csv`, for both validation and test.

---

## 3. Results

Test MAE in µg/m³. For hybrid, s is chosen on validation. Full table: `report/EXPERIMENTS.csv` (MAE, RMSE and MASE for validation and test, plus k, input count, n_train, n_test and runtime for every experiment). Heatmaps: `report/plots/mase_heatmap_test.png` and `mase_heatmap_validation.png`.

### 3.1 Primary architectures

**Lumpyngngad** (test persistence MAE: 10.0 / 13.3 / 15.7 / 14.7 at 24 / 168 / 336 / 744 h)

| Arch | h | direct none | direct best PCA | recursive none | recursive best PCA | hybrid none | hybrid best PCA |
|---|---|---|---|---|---|---|---|
| A2 | 24 | **9.11** | 9.65 (99) | 11.64 | 9.84 (90) | – | – |
| A2 | 168 | 10.94 | **10.43** (99) | 13.33 | 12.44 (90) | 10.63 | 10.88 (99) |
| A2 | 336 | **12.29** | 12.91 (95) | 14.43 | 16.33 (90) | 13.12 | 12.38 (95) |
| A2 | 744 | 11.42 | 11.29 (90) | 12.78 | 13.88 (99) | 11.69 | **10.75** (90) |
| A3 | 24 | **9.04** | 9.73 | 10.86 | 10.48 (90) | – | – |
| A3 | 168 | 10.82 | **10.44** (90) | 19.43 | 13.19 (95) | 10.75 | 10.97 (90) |
| A3 | 336 | **12.51** | 13.57 | 22.99 | 14.96 (95) | 13.67 | 14.22 (99) |
| A3 | 744 | 12.31 | 12.91 (95) | 22.06 | 14.20 (95) | 12.69 | **11.60** (95) |
| C2_sep | 24 | **9.54** | 9.56 (99) | 18.88 | 10.61 (90) | – | – |
| C2_sep | 168 | **10.45** | 11.74 (99) | 33.57 | 17.95 (95) | 10.51 | 10.97 (95) |
| C2_sep | 336 | 13.90 | 17.08 (95) | 38.89 | 21.67 (99) | **12.31** | 13.48 (99) |
| C2_sep | 744 | 13.06 | 14.56 (90) | 64.52 | 24.10 (99) | 13.78 | **11.75** (99) |

**JN Stadium** (test persistence MAE: 21.6 / 28.9 / 33.4 / 29.9)

| Arch | h | direct none | direct best PCA | recursive none | recursive best PCA | hybrid none | hybrid best PCA |
|---|---|---|---|---|---|---|---|
| A2 | 24 | 23.88 | 25.88 (90) | 23.92 | **23.66** (90) | – | – |
| A2 | 168 | 33.19 | 32.74 (95) | 42.29 | **32.40** (90) | 33.39 | 33.22 (95) |
| A2 | 336 | **27.32** | 27.78 (99) | 52.29 | 36.89 (95) | 28.81 | 32.20 (90) |
| A2 | 744 | **30.56** | 33.05 (99) | 50.40 | 37.46 (99) | 30.86 | 32.08 (95) |
| A3 | 24 | **23.28** | 24.00 (90) | 23.58 | 23.44 (90) | – | – |
| A3 | 168 | 31.54 | 29.11 (90) | 38.84 | 28.83 (90) | **26.32** | 26.59 (95) |
| A3 | 336 | **26.93** | 27.88 (90) | 43.28 | 30.81 (90) | 27.50 | 27.43 (95) |
| A3 | 744 | **30.03** | 32.71 (90) | 45.04 | 32.36 (95) | 32.69 | 31.71 (95) |
| C2_sep | 24 | 23.28 | 23.24 (99) | 23.57 | **23.08** (90) | – | – |
| C2_sep | 168 | 31.22 | 31.03 (90) | **27.08** | 28.82 (90) | 32.59 | 30.66 (90) |
| C2_sep | 336 | **28.10** | 28.48 (99) | 30.28 | 31.41 (90) | 31.76 | 29.97 (99) |
| C2_sep | 744 | 32.68 | 32.45 (99) | 30.45 | 31.45 (90) | **28.90** | 32.72 (95) |

"Best PCA" is chosen in hindsight on test, for description only. Selection on validation is in §5 and `report/PCA_SELECTED.csv`.

### 3.2 PCA vs original features

Test, all completed architectures, counted over (arch, station, h, threshold):

| Strategy | Threshold | n | Median MAE ratio PCA / none | Significantly better | Significantly worse |
|---|---|---|---|---|---|
| direct | 90% | 88 | 1.037 | 7 | 41 |
| direct | 95% | 88 | 1.037 | 8 | 38 |
| direct | 99% | 88 | 1.028 | 7 | 37 |
| hybrid | 90% | 66 | 0.996 | 22 | 14 |
| hybrid | 95% | 66 | 0.996 | 19 | 14 |
| hybrid | 99% | 66 | 0.995 | 20 | 14 |
| recursive | 90% | 88 | 0.927 | 48 | 10 |
| recursive | 95% | 88 | 0.933 | 43 | 16 |
| recursive | 99% | 88 | 0.927 | 44 | 20 |

Primary architectures only (24 cells): direct 3 better / 37 worse (of 72); hybrid 12 / 18 (of 54); recursive 39 / 7 (of 72).

**Why PCA hurts direct models.** LightGBM already selects features within its splits. Rotating 72–720 correlated lags into dense components removes the axis-aligned "last value of PM2.5" feature the trees rely on. This shows directly in the one-step accuracy, where PCA raises one-step test MAE from 5.2–5.3 to 6.6–8.3 at Lumpyngngad (`report/ONESTEP_ACCURACY.csv`).

**Why it helps recursive models.** A one-step model with original features fits the training data very closely: for example, one-step train MAE 0.55 vs validation 6.5 for JN Stadium A3. Fed its own predictions, it extrapolates badly. Forecast spread shows this: at h = 744 at Lumpyngngad, recursive C2_sep with original features averages 84 µg/m³ against an observed mean of 20 (`report/FORECAST_SPREAD.csv`). With PCA, the one-step model is fitted to a few smooth components and is less sensitive to drift in the fed-back inputs.

**Threshold.** No threshold is consistently best. In `report/PCA_SELECTED.csv`, validation picks each of 90, 95 and 99% for some cells and "none" for others, and the test ratio of the validation-selected setting against "none" is spread around 1.

### 3.3 Direct vs recursive vs hybrid

Test, all completed architectures:

| Comparison | h | n | Median MAE ratio | Better | Worse |
|---|---|---|---|---|---|
| recursive vs direct | 24 | 88 | 1.035 | 11 | 34 |
| | 168 | 88 | 1.022 | 12 | 35 |
| | 336 | 88 | 1.147 | 3 | 55 |
| | 744 | 88 | 1.126 | 8 | 48 |
| hybrid vs recursive | 168 | 88 | 0.933 | 42 | 14 |
| | 336 | 88 | 0.870 | 58 | 0 |
| | 744 | 88 | 0.910 | 49 | 7 |
| hybrid vs direct | 168 | 88 | 0.988 | 29 | 12 |
| | 336 | 88 | 0.980 | 32 | 14 |
| | 744 | 88 | 0.998 | 25 | 11 |

By station:

| Comparison | Station | Median ratio | Better | Worse |
|---|---|---|---|---|
| recursive vs direct | Lumpyngngad | 1.230 | 2 | 133 |
| | JN Stadium | 1.005 | 32 | 39 |
| hybrid vs recursive | Lumpyngngad | 0.751 | 103 | 2 |
| | JN Stadium | 0.965 | 46 | 19 |
| hybrid vs direct | Lumpyngngad | 1.003 | 23 | 14 |
| | JN Stadium | 0.976 | 63 | 23 |

Plots: `report/plots/strategy_comparison.png` (ratios with intervals), `horizon_performance.png` and `hybrid_switch_points.png`.

- **Recursive.** It is clearly worse at Lumpyngngad, where the direct models are strong (A2/A3/C2_sep direct MASE 0.54–0.82 with original features). At JN Stadium the direct models barely beat persistence, so recursion has less to lose. There, recursive forecasting with target-only decompositions gives the best test results at long horizons: C1_sep recursive PCA 90% at h = 168 (24.30, against 32.14 for the original A0) and B2 recursive PCA 99% at h = 744 (27.23, against 32.20). Neither is selectable on validation; at h = 744, for example, B2 recursive is the worst B2 strategy on validation.
- **Hybrid vs direct.** For the 3 primary architectures the hybrid gains are concentrated at Lumpyngngad: A2 at h = 744 with PCA 90% (10.75 vs 11.42 for direct, s = 72) and C2_sep at h = 336 (12.31 vs 13.90). For the extension architectures they are at JN Stadium (B0, B2, B3 at 168–336 h). The size is typically 3–10%. The chosen switch point varies with no clear pattern (`report/HYBRID_SWITCH_POINTS.csv`). The validation-selected s is also the test-best s in 122 of 264 cells (46%), only somewhat better than the 33% expected by chance with 3 options.
- **Horizon.** Recursion degrades with horizon, steeply between 168 and 336 h. Hybrid's advantage over recursive is largest at 336 h. Its advantage over direct does not grow with horizon.

### 3.4 Architectures under each strategy

Test, MAE ratio against A2 under the same strategy and PCA setting:

| Arch vs A2 | Better | Worse | Not clear |
|---|---|---|---|
| A0 | 6 | 13 | 3 |
| A1 | 6 | 11 | 5 |
| A3 | 5 | 5 | 12 |
| B0 | 4 | 12 | 6 |
| B1 | 5 | 13 | 4 |
| B2 | 6 | 10 | 6 |
| B3 | 5 | 12 | 5 |
| C1_sep | 5 | 12 | 5 |
| C1_sh | 5 | 12 | 5 |
| C2_sep | 6 | 8 | 8 |

- **Direct.** The original study's ranking holds: at Lumpyngngad, multivariate raw lags (A2, A3) beat the univariate and decomposed architectures. A3 and A2 are statistically indistinguishable in most cells.
- **Recursive.** The ranking reverses at JN Stadium. With original features, C2_sep recursive beats A2 recursive by 36–42% at 168–744 h, because A2/A3 recursion diverges there, while at Lumpyngngad C2_sep recursive is 1.6–5× *worse* than A2. Which architecture recurses best is station-specific.

### 3.5 Against the original results

Clearly labelled comparisons against the **original study's** direct models (A0 = univariate raw lags, and A2):

- **Direct with original features.** Identical to the original study (176/176).
- **Best new configurations vs the original models.** At Lumpyngngad, A2/A3/C2_sep hybrid with original features beat the original A0 at 168 and 336 h (ratio 0.67–0.81, significant). The original study's A2/A3 direct models already had a gain of the same size (ratio 0.69–0.74), so the gain comes from the multivariate inputs, not from the hybrid strategy.
- **Validation-selected vs the original.** Against the original A0: 3 better, 1 worse, 4 not clear. Against the original A2: 1 better (JN Stadium h = 168, C2_sep recursive PCA 95%, ratio 0.90), 5 worse, 2 not clear.

---

## 4. PCA diagnostics

- **Explained-variance curves** (training block, direct h = 24 models with PCA 99%): `report/plots/pca_explained_variance.png`. They differ sharply by station. At Lumpyngngad, the 72 lags of 3 pollutants reach 90% with 8 components. At JN Stadium, the 120 lags of 5 pollutants need 23–27, because of the weaker correlation between pollutants and the shorter training block.
- **Retained k by model:** `report/plots/pca_retained_components.png` and `report/PCA_RETAINED_BY_MODEL.csv`.
- **C2_sep.** Each component model gets its own PCA. The coarse components (D5, S5) compress to very few dimensions; the fine components (D1, D2) need many.

---

## 5. Best combination per horizon (`report/BEST_BY_HORIZON.csv`)

| Station | h | Chosen on validation | its test MAE | Best on test (hindsight) | test MAE | original A0 | original A2 | persistence |
|---|---|---|---|---|---|---|---|---|
| Lumpyngngad | 24 | A1 direct none | 9.72 | A3 direct none | 9.04 | 9.84 | 9.11 | 10.03 |
| Lumpyngngad | 168 | A2 recursive PCA 90 | 12.44 | A2 direct PCA 99 | 10.43 | 15.64 | 10.94 | 13.28 |
| Lumpyngngad | 336 | A2 recursive PCA 90 | 16.33 | A2 direct none | 12.29 | 16.82 | 12.29 | 15.70 |
| Lumpyngngad | 744 | A2 recursive PCA 90 | 13.91 | A2 hybrid PCA 90, s = 72 | 10.75 | 13.10 | 11.42 | 14.65 |
| JN Stadium | 24 | A3 recursive none | 23.58 | C1_sh direct none | 21.02 | 23.77 | 23.88 | 21.57 |
| JN Stadium | 168 | C2_sep recursive PCA 95 | 29.72 | C1_sep recursive PCA 90 | 24.30 | 32.14 | 33.19 | 28.92 |
| JN Stadium | 336 | A3 direct none | 26.93 | A3 direct none | 26.93 | 30.56 | 27.32 | 33.37 |
| JN Stadium | 744 | C1_sh direct none | 34.84 | B2 recursive PCA 99 | 27.23 | 32.20 | 30.56 | 29.92 |

Validation chooses the test-best configuration in 1 of 8 cases. The hindsight-best column is not an achievable forecast; it shows the spread of outcomes. As documented in the original study, the Lumpyngngad validation block is August–September (monsoon, low concentrations) and its test block is October–December. JN Stadium's training data cover only the end of the monsoon and its test block is winter. The seasonal shift between validation and test probably explains why rankings don't carry over.

---

## 6. Computational cost

Wall-clock seconds per cell; up to 10 cells ran concurrently, one thread per model, so absolute times include contention. Full table: `report/RUNTIME_BY_RUN.csv`; plot: `report/plots/runtime.png`.

| Station | Arch | PCA | Direct, 4 horizons | One-step fits | Recursion (val + test) | Cross-fit | Hybrid stage 2, 9 fits |
|---|---|---|---|---|---|---|---|
| Lumpyngngad | A2 | none | 26 | 95 | 91 | 81 | 54 |
| Lumpyngngad | A2 | 95% | 55 | 193 | 370 | 128 | 58 |
| Lumpyngngad | C2_sep | none | 849 | 8 179 | 1 548 | 1 909 | 629 |
| Lumpyngngad | C2_sep | 95% | 254 | 1 864 | 6 039 | 2 164 | 404 |
| JN Stadium | A2 | none | 240 | 92 | 53 | 52 | 52 |
| JN Stadium | C2_sep | none | 1 496 | 5 530 | 1 123 | 5 161 | 985 |
| JN Stadium | C2_sep | 95% | 332 | 3 343 | 6 902 | 738 | 388 |

- PCA makes direct fits faster (fewer columns) but makes the recursion *slower*, probably because the PCA projection is applied at every step for every origin.
- C2_sep with original features at JN Stadium needed 5.4 h for one cell and up to 27 GB of committed memory during the cross-fit. Its first attempt ran out of memory and was resumed (`ERRORS.csv`, `logs/`).

---

## 7. Completeness

`report/COMPLETION.csv` lists every (station, architecture, PCA) cell.

| Architectures | Status |
|---|---|
| A2, A3, C2_sep (primary) | complete: 24 cells × 14 runs |
| A0, A1, B0, B1, B2, B3, C1_sep, C1_sh | complete: 64 cells |
| C2_sh, C3_sep, C3_sh | **not run**: like C2_sep they use the components of all 5 pollutants (C3 adds covariates), giving 432–785 inputs. C2_sep needed 2.5–5.4 h and up to 27 GB per cell; on this 16 GB machine these 24 cells were not feasible. |

**Errors.** Three primary cells ran out of memory once: Lumpyngngad A2 PCA 95% and both JN Stadium C2_sep cells. All three were resumed from their saved files and completed. JN Stadium C2_sep with original features also crashed once with a segfault in the cross-fit stage and completed on the second attempt (`ERRORS.csv`, `logs/cell_*_attempt*.log`).

---

## 8. Reproduction

Code and configuration:
- runner: `run_second_stage.R`;
- module: `R/60_ss_core.R`, `R/61_ss_stages.R`, `R/62_ss_report.R`;
- config: `config/second_stage.yaml`, layered on `config/shillong_arch.yaml`;
- tests: `tests/second_stage/run_tests.R`, 87 checks, all passing.

```sh
Rscript run_second_stage.R --stage=tests            # writes tests/TESTS_PASSED
Rscript run_second_stage.R --stage=smoke            # light models; writes smoke/SMOKE_PASSED
Rscript run_second_stage.R --stage=run --station=Lumpyngngad --archs=A2 --pca=0.95   # one cell; resumable
bash results/second_stage/logs/run_cells.sh results/second_stage/logs/cells_primary.txt 10   # all primary cells
Rscript run_second_stage.R --stage=report           # tables and plots in report/
```

Outputs:
- `runs/<station>/<arch>/<pca>/`: `direct_h*.rds`, `recursive.rds` and `hybrid_s*_h*.rds`, holding predictions, models' info, tuning, PCA info and runtimes;
- `report/`:
  - experiment and metric tables: `EXPERIMENTS`, `METRICS_ALL` (CSV and Parquet), `COMPONENT_METRICS`;
  - `PREDICTIONS_SEED_MEAN.parquet`;
  - PCA tables;
  - `PAIRED_COMPARISONS.csv`;
  - `plots/`;
  - `RUN_METADATA.json`, with code and config hashes.
