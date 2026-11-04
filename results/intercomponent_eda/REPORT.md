# Cross-frequency EDA: Haar MODWT/MRA components (CPCB PM2.5)

## 1. Objective and context

Univariate component-wise forecasting (T1 / A1) already assigns each of D1–D5 and S5 its own model using only that component's history.
This EDA asks whether **other frequency bands contain incremental information** about a target band beyond that target's own lags.

**Scope:** exploratory and statistical only. No intercomponent forecasting models were trained.

## 2. Dataset and decomposition verification

- Sensor / variable: `CPCB` / `PM2.5`
- Stored decomposition: `mra_haar_J5__raw` (Haar MODWT/MRA, J=5, raw scale)
- Parquet: `C:\Users\chara\Desktop\atsa_project/store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet`
- Parquet md5: `3d1a72b96033c1ea33f1693307c5bf34`
- Components: D1, D2, D3, D4, D5, S5 (additive reconstruction)
- Split helper: `chrono_split_tvt` with nested test horizon h=24 hours, val_hours=336
- Train / validation / test lengths: 8521 / 336 / 24
- Complete six-component rows: 6833 (train complete: 6474)
- Train reconstruction check vs PM2.5: MAE=0.000000, max|err|=0.000000, cor=1.000000

Loading used `t1_load_stored_components()` / `get_decomp()` and `t1_align_components()`.
Warm-up / invalid MRA rows remain NA; they were **not** imputed for this analysis.
Discovery statistics use **train only**. Validation is confirmation. **Test was not used** to select relationships.

### Packages and parameters

- R packages: base/stats, readr, dplyr, tidyr, ggplot2, tibble, plus project `R/load_all.R` stack.
- Max lag k: 24 h; own-history AR order p: 24; MI bins: 10
- Block bootstrap: block=24 h, replicates=200, seed=7
- Rolling window: 336 h, step 24 h

Lag convention: **Corr(target(t), predictor(t−k))** with k≥1 = predictor in the past (forecast-usable).

## 3. Component-wise characteristics (Analysis A)

- **D1**: n_valid=6474, mean=0.755, sd=3.284, var=10.786, range=[-13.077,22.411], ACF(1)=0.858, ACF(24)=0.603, Σ|ACF1–24|=12.077
- **D2**: n_valid=6474, mean=0.378, sd=1.951, var=3.806, range=[-8.354,13.203], ACF(1)=0.838, ACF(24)=0.522, Σ|ACF1–24|=8.473
- **D3**: n_valid=6474, mean=0.190, sd=1.541, var=2.376, range=[-6.171,9.866], ACF(1)=0.886, ACF(24)=0.416, Σ|ACF1–24|=3.859
- **D4**: n_valid=6474, mean=0.096, sd=1.593, var=2.539, range=[-6.149,8.048], ACF(1)=0.950, ACF(24)=0.440, Σ|ACF1–24|=8.302
- **D5**: n_valid=6474, mean=0.050, sd=1.524, var=2.323, range=[-5.192,7.293], ACF(1)=0.977, ACF(24)=0.283, Σ|ACF1–24|=7.990
- **S5**: n_valid=6474, mean=12.525, sd=5.513, var=30.392, range=[2.161,31.692], ACF(1)=0.999, ACF(24)=0.858, Σ|ACF1–24|=22.229

Interpretation (descriptive, not predictive):
- **D1–D2** are high-frequency detail bands: lower persistence (smaller long-lag ACF mass).
- **D3–D4** are mid-frequency.
- **D5 / S5** are lower-frequency / smooth: stronger persistence.
- Visual similarity of low-frequency bands does **not** by itself imply cross-frequency forecast value.

Figures: `plots/components_timeseries.png`, `component_distributions.png`, `component_acf.png`.

## 4. Contemporaneous relationships (Analysis B)

Top absolute Pearson pairs (train), with block-bootstrap 95% CIs and BH-adjusted p-values:

- D1–D2: Pearson=0.893 [0.883,0.901], Spearman=0.880, MI=0.7890, n_eff≈1059.9, BH p(Pearson)=0.0000
- D2–D3: Pearson=0.753 [0.729,0.772], Spearman=0.716, MI=0.4414, n_eff≈956.8, BH p(Pearson)=0.0000
- D1–D3: Pearson=0.586 [0.548,0.623], Spearman=0.552, MI=0.2735, n_eff≈882.6, BH p(Pearson)=0.0000
- D4–D5: Pearson=0.543 [0.497,0.583], Spearman=0.485, MI=0.1998, n_eff≈242.6, BH p(Pearson)=0.0000
- D3–D4: Pearson=0.513 [0.468,0.557], Spearman=0.463, MI=0.2073, n_eff≈556.5, BH p(Pearson)=0.0000
- D1–D4: Pearson=0.243 [0.172,0.314], Spearman=0.201, MI=0.1160, n_eff≈661.2, BH p(Pearson)=0.0000
- D2–D4: Pearson=0.237 [0.169,0.290], Spearman=0.191, MI=0.1032, n_eff≈736.0, BH p(Pearson)=0.0000
- D5–S5: Pearson=0.111 [0.048,0.175], Spearman=0.067, MI=0.1054, n_eff≈80.0, BH p(Pearson)=0.4448

Full matrices: `tables/pearson_matrix.csv`, `spearman_matrix.csv`, `mutual_information_matrix.csv`.
Heatmaps: `plots/heatmap_*.png`.

Notes:
- Adjacent scales can show moderate association; distant scales are often weaker.
- MI captures possibly nonlinear dependence; compare MI vs Pearson to spot nonlinear candidates.
- Contemporaneous dependence is **not** permission to use another component's future value in forecasting.

## 5. Lagged cross-correlation (Analysis C)

Strongest usable lagged relationships (k=1..24, train):

- D2 ← D1: max|r|=0.806 at lag 1 (r=0.806); lag0=0.893; #lags |r|≥0.10: 24
- D1 ← D2: max|r|=0.804 at lag 1 (r=0.804); lag0=0.893; #lags |r|≥0.10: 24
- D3 ← D2: max|r|=0.725 at lag 1 (r=0.725); lag0=0.753; #lags |r|≥0.10: 18
- D2 ← D3: max|r|=0.634 at lag 1 (r=0.634); lag0=0.753; #lags |r|≥0.10: 24
- D3 ← D1: max|r|=0.581 at lag 1 (r=0.581); lag0=0.586; #lags |r|≥0.10: 19
- D5 ← D4: max|r|=0.559 at lag 1 (r=0.559); lag0=0.543; #lags |r|≥0.10: 18
- D4 ← D3: max|r|=0.554 at lag 1 (r=0.554); lag0=0.513; #lags |r|≥0.10: 16
- D1 ← D3: max|r|=0.529 at lag 3 (r=0.529); lag0=0.586; #lags |r|≥0.10: 24

Figures: `plots/lagged_ccf_grid.png`, `plots/lagged_maxabs_heatmap.png`.

## 6. Incremental dependence after own history (Analysis D)

AR(24) OLS baseline fit on each target (train):

- D1 AR(24) train R²=0.758 (n=6450)
- D2 AR(24) train R²=0.812 (n=6450)
- D3 AR(24) train R²=0.921 (n=6450)
- D4 AR(24) train R²=0.980 (n=6450)
- D5 AR(24) train R²=0.994 (n=6450)
- S5 AR(24) train R²=1.000 (n=6450)

Residual correlations Corr(ε_i(t), C_j(t−k)) — top pairs:

- S5 ← D4: max|resid r|=0.167 at lag  1 (r=-0.167); #lags |r|≥0.05: 11; BH-sig lags: 18
- S5 ← D5: max|resid r|=0.160 at lag  1 (r=-0.160); #lags |r|≥0.05: 12; BH-sig lags: 18
- D1 ← D5: max|resid r|=0.154 at lag 13 (r=0.154); #lags |r|≥0.05: 16; BH-sig lags: 18
- D1 ← D3: max|resid r|=0.141 at lag  3 (r=0.141); #lags |r|≥0.05:  4; BH-sig lags: 12
- D2 ← D5: max|resid r|=0.130 at lag 13 (r=0.130); #lags |r|≥0.05: 14; BH-sig lags: 17
- S5 ← D2: max|resid r|=0.127 at lag  2 (r=0.127); #lags |r|≥0.05:  2; BH-sig lags:  8
- D1 ← D4: max|resid r|=0.124 at lag  7 (r=0.124); #lags |r|≥0.05: 16; BH-sig lags: 19
- S5 ← D3: max|resid r|=0.122 at lag  3 (r=0.122); #lags |r|≥0.05:  3; BH-sig lags: 11
- D4 ← D2: max|resid r|=0.116 at lag  2 (r=0.116); #lags |r|≥0.05:  1; BH-sig lags:  5
- D5 ← D4: max|resid r|=0.113 at lag  1 (r=-0.113); #lags |r|≥0.05:  4; BH-sig lags:  7

Also computed: partial correlations controlling for own lags (`tables/partial_correlations.csv`).
Figure: `plots/residual_maxabs_heatmap.png`.

**Key question:** after AR(24) own history, do other bands still correlate with the residual?

## 7. Temporal stability (Analysis E)

Rolling-window summary for shortlisted pairs (residual correlations at the train-selected lag):

- D1 ← D3 (k= 3): mean r=0.133, sd=0.110, frac(|r|≥0.05)=0.770, same-sign frac=0.910
- D1 ← D4 (k= 7): mean r=0.118, sd=0.099, frac(|r|≥0.05)=0.770, same-sign frac=0.902
- D1 ← D5 (k=13): mean r=0.144, sd=0.064, frac(|r|≥0.05)=0.941, same-sign frac=0.996
- D2 ← D5 (k=13): mean r=0.118, sd=0.060, frac(|r|≥0.05)=0.898, same-sign frac=0.969
- S5 ← D2 (k= 2): mean r=0.131, sd=0.093, frac(|r|≥0.05)=0.789, same-sign frac=0.957
- S5 ← D3 (k= 3): mean r=0.118, sd=0.101, frac(|r|≥0.05)=0.707, same-sign frac=0.922
- S5 ← D4 (k= 1): mean r=-0.158, sd=0.095, frac(|r|≥0.05)=0.902, same-sign frac=0.980
- S5 ← D5 (k= 1): mean r=-0.141, sd=0.101, frac(|r|≥0.05)=0.840, same-sign frac=0.922

Validation confirmation of train residual relationships:

- S5 ← D4 (k= 1): train resid r=-0.167 → validation resid r=-0.177 (n=312)
- S5 ← D5 (k= 1): train resid r=-0.160 → validation resid r=-0.207 (n=312)
- D1 ← D5 (k=13): train resid r=0.154 → validation resid r=0.111 (n=312)
- D1 ← D3 (k= 3): train resid r=0.141 → validation resid r=0.193 (n=312)
- D2 ← D5 (k=13): train resid r=0.130 → validation resid r=0.087 (n=312)
- S5 ← D2 (k= 2): train resid r=0.127 → validation resid r=0.177 (n=312)
- D1 ← D4 (k= 7): train resid r=0.124 → validation resid r=0.168 (n=312)
- S5 ← D3 (k= 3): train resid r=0.122 → validation resid r=0.138 (n=312)

Figure: `plots/rolling_stability.png`.

## 8. Limitations

- Haar MRA components are linearly related to Y; some cross-band structure can reflect filter leakage / shared driving shocks rather than transferable forecast features.
- Thousands of hourly points are highly autocorrelated; n_eff and block bootstrap CIs are approximate.
- MI uses quantile binning (10 bins); absolute MI scale depends on discretization.
- AR(24) residual diagnostic is linear/OLS; nonlinear incremental dependence could be missed.
- Smooth bands (especially S5) have near-perfect AR(24) R²; residual correlations are then correlations with a tiny leftover signal and may overstate practical forecast gains.
- Nested split uses h=24 for discovery train size; longer paper horizons shrink train further.
- Warm-up NAs reduce usable sample at the start of the series.
- Adjacent-band contemporaneous correlations are partly expected from wavelet filter leakage; lagged residual evidence is the more relevant gate for forecasting.

## 9. Final recommendation

### Verdict: **Promising**

- Residual pairs with max|r|≥0.10 (train): **11**
- Residual pairs with 0.05≤max|r|<0.10 (train): **16**
- Shortlisted pairs with validation residual confirmation (|r|≥0.05, same sign): **8**

### Per-target shortlist (train residual evidence)

- **D1**: D5 (lag 13, resid r=0.154); D3 (lag  3, resid r=0.141); D4 (lag  7, resid r=0.124)
- **D2**: D5 (lag 13, resid r=0.130); D4 (lag  6, resid r=0.085); S5 (lag  1, resid r=-0.080)
- **D3**: S5 (lag  1, resid r=-0.072); D5 (lag 11, resid r=0.069); D4 (lag  2, resid r=0.067)
- **D4**: D2 (lag 2, resid r=0.116); D3 (lag 3, resid r=0.088); D1 (lag 1, resid r=0.082)
- **D5**: D4 (lag 1, resid r=-0.113); D2 (lag 2, resid r=0.110); D3 (lag 3, resid r=0.089)
- **S5**: D4 (lag 1, resid r=-0.167); D5 (lag 1, resid r=-0.160); D2 (lag 2, resid r=0.127)

### Decision rule applied

- **Promising:** ≥3 pairs with residual |r|≥0.10 and ≥2 validation-confirmed.
- **Partially promising:** ≥1 strong residual pair or ≥3 weak residual pairs.
- **Not promising:** otherwise.

This recommendation uses train discovery + validation confirmation only. Test metrics were not consulted.

### Next step (gated)

Do **not** train intercomponent LightGBM/XGBoost/CatBoost models until this recommendation is reviewed.
If the verdict is Partially promising, prefer a **selective** experiment using only the shortlisted predictors/lags above.

