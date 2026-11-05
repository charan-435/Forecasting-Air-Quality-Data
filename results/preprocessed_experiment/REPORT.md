# CPCB parallel preprocessed experiment — B0, A1, B1, B2, B3 at h = 24 h

**Question.** Does removing invalid pollutant observations change the relative performance of
component-specific, shared and covariate-augmented forecasting architectures?

**Short answer.** No architecture is reliably better than another on this data, with or without
cleaning. On validation, cleaning lowered the error of all five architectures and the covariate and
shared variants ranked ahead of B0; on the test block that ordering did not hold, every paired
architecture difference has a confidence interval that includes zero, and the one significant
cleaning effect goes the other way (A1). The clear benefit of cleaning is validity: the original
CPCB series contains 2,637 synthetic hours (29.7 %), 821 of them in the test block, which the
existing pipeline would have trained on and scored as real PM2.5.

Base: `kaisen` @ `38daa41`; experiment branch `utkarsh-kaisen`. Phases 1–2 (audit, cleaned data,
decomposition) are documented in [data_audit/AUDIT_REPORT.md](data_audit/AUDIT_REPORT.md).

---

## 1. Set-up

| Item | Setting |
|---|---|
| Data | CPCB hourly, 2022-07-01 → 2023-07-05 (8,880 h); target PM2.5; covariates PM10, NO2, SO2, O3, CO |
| Cleaning | invalid → NA (synthetic fill codes, kaisen stuck and PM-ratio rules); nothing clipped; kaisen causal fills restricted to past-only methods M1–M6 (model inputs only) |
| Decomposition | trailing `mra_haar_J5__raw` (window 2,048 h, Haar, J = 5): D1–D5, S5, separate store for the cleaned data |
| Split (PE-S3) | train targets ≤ 2023-02-28 23:00; validation 2023-03-01 → 04-30; test 2023-05-01 → 07-05 |
| Samples | training rows 2,496 (refit on train + validation 3,367); validation 757; test 658 — identical origins and targets for every architecture |
| Forecast | direct, ŷ(t + 24) = f(X_t); origin t = latest hour used; lag1 = value at t, lag24 = value at t − 23; covariates at t only |
| Model | LightGBM, L1 loss, single thread, seed 7, deterministic; grid num_leaves {15, 31, 63} × learning_rate {0.03, 0.1} × min_data_in_leaf {20, 50, 100}, starting from kaisen's screen config |
| Selection | early stopping (100 rounds) and grid choice on validation; B0/B2 per component by component MAE, B1/B3 by reconstructed PM2.5 MAE; B2/B3 also choose same-level (5) or all-level (30) covariates |
| Final model | refit on train + validation with frozen parameters and iteration count; test predicted once |
| Scaling | per series standardisation fitted on the training block (train + validation for the refit); reversed before reconstruction |
| Shared models | rows weighted by the component's training sd, so the loss equals the sum of original-unit component errors (the objective of B0's six models together) |
| Metrics | MAE, RMSE, MASE (denominator: lag-24 seasonal naive on valid training-block PM2.5 pairs, 4.356); only valid observations are scored |
| Control | **unmasked**: identical code, origins, targets and truth, but trained on the original series (fills included) — the comparison for research questions 1 and 10 |
| Uncertainty | moving-block bootstrap (block 24, 2,000 reps) of paired MAE/RMSE differences and ratios; Diebold–Mariano with Newey–West lag 23 and the Harvey correction |

Selected models (`*/selected.json`): B0 15–63 leaves, 16–356 rounds per component; A1 15 leaves,
19 rounds; B1 15 leaves, 55 rounds; B2 same-level covariates for D1, D4, S5 and all-level for D2, D3,
D5; B3 31 leaves, 238 rounds, same-level covariates.

## 2. Results — PM2.5 (reconstructed for B0–B3, direct for A1)

Validation numbers are selection results (early stopping and the grid used the same block); test
numbers are the single final evaluation.

**Cleaned data**

| Model | Val MAE | Val RMSE | Val MASE | Test MAE | Test RMSE | Test MASE |
|---|---|---|---|---|---|---|
| B0 | 7.257 | 9.315 | 1.666 | **7.480** | 10.108 | 1.717 |
| A1 | 6.975 | 9.042 | 1.601 | 7.842 | 10.470 | 1.800 |
| B1 | 7.150 | 9.260 | 1.641 | 7.591 | 10.292 | 1.743 |
| B2 | 7.035 | 9.135 | 1.615 | 8.062 | **9.917** | 1.851 |
| B3 | **6.972** | **9.021** | **1.601** | 7.726 | 9.939 | 1.774 |
| persistence (= seasonal naive at h = 24) | 7.969 | 10.904 | 1.829 | 8.134 | 11.709 | 1.867 |
| hour-of-day climatology | 9.840 | 12.551 | 2.259 | 7.059 | 10.694 | 1.621 |
| train-mean climatology | 9.840 | 12.848 | 2.259 | 7.382 | 11.250 | 1.695 |

**Unmasked control** (same targets and truth)

| Model | Val MAE | Val RMSE | Test MAE | Test RMSE |
|---|---|---|---|---|
| B0 | 7.348 | 9.388 | 7.757 | 10.429 |
| A1 | 7.100 | 9.241 | 7.416 | 10.100 |
| B1 | 7.345 | 9.462 | 7.469 | 10.312 |
| B2 | 7.307 | 9.386 | 7.874 | 10.336 |
| B3 | 7.153 | 9.405 | 7.684 | 10.357 |

Full tables: `comparisons/metrics_pollutant_level.csv`; predictions: `<arch>/predictions_{val,test}.csv`
(and `<arch>/unmasked_control/`). Reconstruction check: Σ actual components = actual PM2.5 to 7e-15.

**Test MASE is above 1 for every model**, including the baselines: the denominator is the training
block's seasonal-naive error (4.36), and the test block is harder. It is dominated by May 2023
(467 of 658 targets), when PM2.5 was low and regular and the hour-of-day climatology is best
(MAE 5.29 vs B0 6.21); in June the models win (B0 11.98 vs climatology 13.28).

## 3. Component level (cleaned data, `comparisons/metrics_component_level.csv`)

| Component | Val B0 | Val B1 | Val B2 | Val B3 | Test B0 | Test B1 | Test B2 | Test B3 |
|---|---|---|---|---|---|---|---|---|
| D1 | 2.810 | 2.773 | 2.792 | 2.785 | 2.859 | 2.845 | 2.866 | 2.856 |
| D2 | 1.713 | 1.743 | 1.701 | 1.737 | 1.778 | 1.770 | 1.801 | 1.778 |
| D3 | 1.355 | 1.375 | 1.292 | 1.366 | 1.421 | 1.419 | 1.418 | 1.410 |
| D4 | 1.426 | 1.424 | 1.434 | 1.411 | 1.380 | 1.385 | 1.385 | 1.385 |
| D5 | 1.428 | 1.538 | 1.407 | 1.521 | 1.522 | 1.626 | 1.513 | 1.597 |
| S5 | 3.645 | 3.551 | 4.223 | 4.192 | 3.715 | 3.671 | 3.482 | 3.450 |

(MAE in PM2.5 units; MASE per component in the same file.)

## 4. Paired comparisons on identical targets (`comparisons/paired_comparisons.csv`)

MAE difference A − B (negative = A better), 95 % moving-block bootstrap CI, Diebold–Mariano p on
absolute errors.

| Comparison | Validation MAE diff [CI] | Test MAE diff [CI] | Test MAE ratio | Test RMSE diff [CI] | Test DM p |
|---|---|---|---|---|---|
| A1 vs B0 | −0.28 [−0.81, 0.17] | +0.36 [−0.37, 0.98] | 1.048 | +0.36 [−0.51, 0.98] | 0.30 |
| B1 vs B0 | −0.11 [−0.35, 0.15] | +0.11 [−0.21, 0.30] | 1.015 | +0.18 [−0.15, 0.34] | 0.45 |
| B2 vs B0 | −0.22 [−0.73, 0.24] | +0.58 [−0.19, 1.36] | 1.078 | −0.19 [−1.03, 0.71] | 0.16 |
| B3 vs B1 | −0.18 [−0.49, 0.08] | +0.14 [−0.34, 0.65] | 1.018 | −0.35 [−0.84, 0.19] | 0.60 |
| B3 vs B2 | −0.06 [−0.35, 0.27] | −0.34 [−0.85, 0.07] | 0.958 | +0.02 [−0.57, 0.45] | 0.18 |
| B3 (best decomposed on validation) vs A1 | −0.00 [−0.34, 0.39] | −0.12 [−0.76, 0.49] | 0.985 | −0.53 [−1.38, 0.36] | 0.73 |
| B0 clean vs unmasked | −0.09 [−0.34, 0.14] | −0.28 [−0.70, 0.18] | 0.964 | −0.32 [−0.92, 0.37] | 0.23 |
| A1 clean vs unmasked | −0.13 [−0.42, 0.09] | **+0.43 [0.17, 0.66]** | 1.057 | +0.37 [0.07, 0.69] | 0.001 |
| B1 clean vs unmasked | **−0.20 [−0.40, −0.01]** | +0.12 [−0.25, 0.47] | 1.016 | −0.02 [−0.63, 0.59] | 0.53 |
| B2 clean vs unmasked | −0.27 [−0.79, 0.17] | +0.19 [−0.60, 0.90] | 1.024 | −0.42 [−1.46, 0.57] | 0.63 |
| B3 clean vs unmasked | −0.18 [−0.50, 0.11] | +0.04 [−0.67, 0.65] | 1.005 | −0.42 [−1.46, 0.50] | 0.90 |

Against persistence, every architecture has a lower RMSE on test (DM p on squared errors 0.007–0.06)
and a lower MAE whose CI includes zero; on validation A1, B1 and B3 beat persistence clearly.
Plot: `plots/paired_differences_test.png`.

## 5. Answers to the research questions

1. **Does invalid-value removal improve performance compared with the unmasked results?**
   Not reliably. On validation, cleaning lowered MAE for all five architectures (by 0.09–0.27) and
   RMSE for all five, significant only for B1. On test, MAE improved for B0 (−0.28, CI includes 0),
   was essentially unchanged for B3, slightly worse for B1 and B2 (CIs include 0) and **worse for A1
   (+0.43, CI 0.17–0.66)**. RMSE on test improved for B0, B2 and B3 (−0.3 to −0.4, CIs include 0) and
   worsened for A1. The existing kaisen CPCB scores (`results/paper/scores.csv`, e.g. WaveCatBoost 1-day
   MAE 3.02) are **not comparable**: they are recursive forecasts from one origin over the last 24 h,
   scored on the store values including synthetic fills, with an imputed-data MASE scale; they are
   copied to `comparisons/kaisen_existing_scores_context.csv` as context only.
2. **Does decomposed forecasting beat direct raw forecasting with covariates?** No clear difference.
   B0 is lower than A1 on test (7.48 vs 7.84) but higher on validation (7.26 vs 6.98); both CIs
   include zero. The validation-selected best decomposed model (B3) vs A1: −0.12 on test, CI −0.76 to 0.49.
3. **Does one shared model beat independent component models?** No. B1 vs B0: −0.11 on validation,
   +0.11 on test, both CIs include zero. The shared model is as good with one model instead of six.
4. **Do contemporaneous covariates improve component-specific models?** No consistent gain. B2 vs B0:
   −0.22 MAE on validation, +0.58 MAE but −0.19 RMSE on test; all CIs include zero.
5. **Do covariates improve shared models?** No consistent gain. B3 vs B1: −0.18 on validation,
   +0.14 MAE and −0.35 RMSE on test; CIs include zero.
6. **Is B3 better than B2 and B1?** B3 had the lowest validation error of all five architectures, but
   on test it is not better than B1 (+0.14) and only possibly better than B2 (−0.34, CI −0.85 to 0.07).
   Not established.
7. **Which components benefit most from covariates?** On test, the smooth component **S5** (B2 3.48
   vs B0 3.72; B3 3.45 vs B1 3.67, about −6 %); D5 marginally for B2; D1/D2 not at all. On validation
   the gains were in D2, D3 and D5 while S5 got worse (B2 4.22 vs 3.65), so no component benefits
   consistently across both blocks.
8. **Does any improvement persist on the test set?** No. The validation ranking (B3 ≈ A1 < B2 < B1 < B0)
   reverses on test (B0 < B1 < B3 < A1 < B2) and none of the paired test differences between
   architectures excludes zero.
9. **Does reconstructed PM2.5 forecasting improve?** Against persistence, yes in RMSE for all models
   (test DM p ≤ 0.06) and in MAE on validation. Against the hour-of-day climatology, the models are
   much better on validation (MAE ~7.0 vs 9.8) and better in test RMSE (9.9–10.5 vs 10.7), but **worse
   in test MAE** (7.48 at best vs 7.06), because May 2023 was a calm, regular month.
10. **How much comes from removing invalid observations vs changing the architecture?** On test MAE,
    the spread between architectures (7.48–8.06, 0.58) is about as large as the cleaning effects
    (−0.28 to +0.43), and almost none of either is distinguishable from noise. On validation both
    point the same way: cleaning −0.09 to −0.27 per architecture, architecture spread 0.29.
    Sample/protocol differences between the two arms: none for evaluation (same origins, targets,
    truth, code, grid); the arms differ only in training data — the unmasked arm trains on more rows
    from the original series (3,761 vs 2,496; 5,225 vs 3,367 in the refit), including synthetic
    fill hours as targets, and its decomposition warms up six days earlier.

**Interpretation.** With 658 test targets from one season and h = 24 h, the differences between
architectures (≈ 1–8 %) are smaller than the sampling uncertainty. Removing invalid values does not
change the relative performance of the architectures in a reliable way. Its main value is that
models are no longer trained on, and evaluated against, constant fills that make up 52 % of the
test block's hours in the original series.

## 6. Limitations

- One split (PE-S3, a documented substitute: kaisen @ 38daa41 has no S3 split), one station, one
  target, one horizon. The test block is mostly May 2023; June (validity-limited by a 600-h fill
  block) contributes 115 targets.
- Validation errors are optimistic (the same block chose parameters and early stopping); only test
  numbers are final.
- Errors of overlapping 24-h forecasts are dependent; the block bootstrap and DM lag 23 account for
  this, but evaluation targets are not contiguous (skipped origins), so CIs are approximate.
- Existing convention kept: each trailing decomposition window is circular, so the last row of every
  component (used as lag 1) carries wrap-around effects (AUDIT F1).
- Source units are inconsistent with the config (CO looks like mg/m³, NO2 sits near 2.2); left as-is.
- Covariates are contemporaneous at the origin only, as specified; no lagged covariates were tried.

## 7. Integrity and tests

- 229 existing files hashed before the run and verified unchanged after every phase
  (`guard/verify_*.csv`); every output is under `store/preprocessed_experiment/` or
  `results/preprocessed_experiment/`.
- Data tests 18/18 (`tests/data_tests.csv`); model tests 18/18 (`tests/model_tests.csv`): lag order,
  no covariate lags, own-component lags only, component identity, **perturbation after the origin
  leaves features unchanged**, scaling on training data only, targets inside their blocks, test
  labels cannot change selection, identical targets across architectures, reconstruction, no NA.
- Evaluation is deterministic: re-running it reproduced byte-identical comparison tables.

## 8. Reproduce

```
Rscript scripts/experiments/run_preprocessed_experiment.R phase1   # guard snapshot, audit, cleaned dataset   (~1 min)
Rscript scripts/experiments/run_preprocessed_experiment.R phase2   # decompositions + data tests                (~5 min)
Rscript scripts/experiments/run_preprocessed_experiment.R phase3   # smoke run + model tests                    (~1 min)
Rscript scripts/experiments/run_preprocessed_experiment.R phase4   # full run, both datasets + evaluation       (~14 min)
```

R 4.5.3, lightgbm 4.7.0, arrow 26.0.0; exact package versions, code and data hashes, seed and
commands in `provenance_models.json`, `data_audit/provenance.json`, `store/preprocessed_experiment/*/manifest.json`.
Configuration: `config/preprocessed_experiment.yaml`.
