# Phase 0 feature design for B1 and B2

Nothing here is built yet. This fixes the layout Phase 1 should produce. Dimensions are in `feature_dimensions.csv`.

## 1. Common conventions

- Pollutant set P = (PM2.5, PM10, NO2, SO2, O3, CO), in that fixed order. All six are usable (`DATA_AUDIT.md`), so k = 6.
- Origin t is the last hour whose values are known. Lags are k = 0, 1, ..., 23, meaning the values at t, t-1, ..., t-23. This is the repository's 24-hour lookback: `make_lags()` calls x(t-1) "lag1" when the target is t+1, which is the same information.
- Target hour t + h, for h in {24, 168, 336, 744}. The strategy (direct, recursive, hybrid) is decided later. The matrices below are what a direct model per horizon would use. A recursive model would use the same X but needs forecasts of every predictor series (see `LEAKAGE_AUDIT.md`, section 2).
- Rows: origins from 2022-09-25 06:00, filtered by the Phase 0 mask and the block rules in `SPLIT_PROPOSAL.md`. B0, B1 and B2 use exactly the same (origin, target) pairs.
- Sources: `store/clean/series.parquet` (`value_filled_causal`) for raw values, and `store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=<p>.parquet` for components. Join on the timestamp instant and assert the same 8,880 timestamps in every file.
- Column order: pollutant, then component (B2), then lag. Record it in the dataset manifest so PCA/PLS loadings and importance tables can be mapped back.

## 2. B0: univariate references (needed for the research question)

The question is whether other pollutants help. Each multivariate design needs a matching single-pollutant reference built on the same rows:

- B0-raw: the target pollutant's own 24 lags. 24 columns.
- B0-comp: the target pollutant's own six components × 24 lags. 144 columns.

B1 vs B0-raw and B2 vs B0-comp isolate the effect of the other pollutants. B2 vs B1 isolates the effect of decomposing.

## 3. B1: raw multivariate

For origin t:

X_B1(t) = [ x_p(t-k) : p in P, k = 0..23 ]

That is **6 × 24 = 144 columns**, named `<pollutant>__lag<kk>`, for example `PM2.5__lag00`, `CO__lag23`.

Target: y(t) = x_target(t + h) on the original scale. Initially target = PM2.5, later each of the six pollutants.

## 4. B2: decomposed multivariate

For origin t:

X_B2(t) = [ c_(p,j)(t-k) : p in P, j in (D1, D2, D3, D4, D5, S5), k = 0..23 ]

That is **6 × 6 × 24 = 864 columns**, named `<pollutant>__<component>__lag<kk>`, for example `NO2__D3__lag05`. Here c_(p,j)(s) is the stored trailing-window value at hour s, which depends only on x_p(s-2047 .. s).

Targets: six per target pollutant, y_j(t) = c_(target,j)(t + h), taken from the same store at row t + h. The forecast is ŷ(t + h) = sum over j of ĉ_j(t + h). Since the stored components add up to x exactly (error ≤ 1e-14), the realized targets reconstruct x_target(t + h) exactly, and the pollutant-level error equals the sum of the component errors.

## 5. Dimensions when fewer pollutants are usable

| Pollutants used (k) | B0-raw | B1 | B0-comp | B2 | B1 targets | B2 targets |
|---|---|---|---|---|---|---|
| 1 | 24 | 24 | 144 | 144 | 1 | 6 |
| 2 | 24 | 48 | 144 | 288 | 2 | 12 |
| 3 | 24 | 72 | 144 | 432 | 3 | 18 |
| 4 | 24 | 96 | 144 | 576 | 4 | 24 |
| 5 | 24 | 120 | 144 | 720 | 5 | 30 |
| **6 (this dataset)** | **24** | **144** | **144** | **864** | **6** | **36** |

In general, B1 = 24k and B2 = 144k.

## 6. Matrix sizes on the proposed split (h = 24, selection fits)

| Design | Rows | Columns | Columns / rows |
|---|---|---|---|
| B1, one target | 2,248 | 144 | 0.06 |
| B2, one component target | 2,248 | 864 | 0.38 |
| B2, one component target, h = 336 | 1,578 | 864 | 0.55 |
| B1 pooled over 6 targets | 13,488 | 150 (144 + 6 one-hot) | 0.01 |
| B2 pooled over 36 targets | 80,928 | 900 (864 + 36 one-hot) | 0.01 |
| B2 pooled, final refit | 119,592 | 900 | 0.01 |

The pooled B2 matrix holds about 73 million values (about 0.58 GB as R doubles), and the refit about 108 million (about 0.86 GB), per horizon. That is feasible, but build one horizon at a time and free it afterwards.

## 7. Pooled (shared) model layout

Stack one block of rows per target. Each block has the same X rows (the same origins), plus target identity and the target's own y:

- B1 pooled: 6 blocks. Identity is either one categorical column with 6 levels (CatBoost, LightGBM) or 6 one-hot columns (XGBoost, linear models).
- B2 pooled: 36 blocks, (pollutant, component). Identity is either two categorical columns (pollutant: 6 levels, component: 6 levels) or 36 one-hot columns.
- Targets differ greatly in scale (CO around 233 µg/m³ against O3 around 0.7, D1 against S5). Standardize y per target with mean and sd from the training rows, fit on the standardized y, and invert per target before scoring.
- Give each target equal total weight (blocks have equal row counts here, so weights are uniform).
- For linear models, additive identity dummies only shift the intercept, so all targets share one slope vector. That is a deliberate restriction and should be reported as such. Identity × feature interactions would reproduce separate models.

## 8. Notes for the linear and projection families

- B1 columns are exact linear combinations of B2 columns, since x_p(s) = sum over j of c_(p,j)(s). Never put B1 and B2 columns in the same linear model.
- Within B2, neighbouring lags of smooth components (S5, D5) are nearly collinear. Plain OLS on 864 columns will be poorly conditioned (columns/rows of 0.38 to 0.55). Run it with a QR rank check and report the condition number. Ridge, PCA and PLS are the remedies to compare.
- Standardize every column with training-row statistics before linear models, PCA, Sparse PCA and PLS. Trees need no scaling.

## 9. Left out of the core comparison

- Calendar features (hour of day, day of week) and AT/RH. These would change all designs at once and blur the B0/B1/B2 contrasts. AT and RH also have no `mra_haar_J5` components (`variables: pollutants`). Possible later ablation: B1 + AT/RH = 8 × 24 = 192 columns.
- A fill-indicator feature. At h = 24, 5.6% of retained training windows contain at least one flagged hour, against 78.7% of retained test windows. The test share comes mostly from the short 02:00 to 04:00 all-pollutant repeats that recur through spring 2023. They stay below the 25% origin threshold, so those origins are kept. Adding `frac_flagged_24h` as one extra column, identical for every design, is a sensible sensitivity check. It is not part of the core design.
