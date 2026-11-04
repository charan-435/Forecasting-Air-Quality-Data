# Phase 0 split proposal

## 1. Constraints

- One chronological split, shared by every B1 and B2 run and every target. No shuffling.
- B2 components are NA until 2022-09-24 07:00 (2,047-hour MRA warm-up), and a 24-hour lag window needs 23 more hours. The **first usable origin is 2022-09-25 06:00** for B1 and B2 alike. B1 could start earlier, but then the two would not share timestamps.
- Every horizon up to 744 h needs origins **and** targets inside the validation and test blocks. A block shorter than 744 h has no h = 744 samples at all.
- Targets must be scorable under the Phase 0 mask (`proposed_quality_mask_cpcb.csv`). Origins follow `store/clean/policy.yaml` applied to that mask: an evaluation origin is skipped if more than 25% of its lag window is flagged or if it sits more than 72 h into a flagged run; a training row is dropped if more than 50% is flagged.
- Project conventions are kept: test at the end of the series, validation directly before it, train before that. Hourly IST timestamps, 24-hour lookback, MASE with season 24.

Sample membership rule, for horizon h and origin t:

- train: first usable origin ≤ t and t + h ≤ train end
- validation: validation start ≤ t and t + h ≤ validation end
- test: test start ≤ t and t + h ≤ test end

So no label crosses into a later block, and no origin uses a model trained on labels after that origin.

## 2. Options compared

Scorable samples per horizon after the mask and origin rules (`split_options_sample_counts.csv`):

| Option | Train block | Validation block | Test block | Train (h = 24 / 168 / 336 / 744) | Validation | Test |
|---|---|---|---|---|---|---|
| T1-like (val 336 h, test 744 h) | to 2023-05-21 23:00 | 2023-05-22 to 2023-06-04 | 2023-06-05 to 2023-07-05 | 4,065 / 2,898 / 2,999 / 3,506 | 312 / 168 / **0 / 0** | 79 / **0 / 0 / 0** |
| S1 (1,488 / 1,488) | to 2023-03-03 23:00 | 2023-03-04 to 2023-05-04 | 2023-05-05 to 2023-07-05 | 2,781 / 2,010 / 1,979 / 2,245 | 1,044 / 744 / 624 / 559 | 613 / 396 / 252 / **144** |
| S2 (1,104 / 1,488) | to 2023-03-19 23:00 | 2023-03-20 to 2023-05-04 | 2023-05-05 to 2023-07-05 | 2,962 / 2,070 / 2,195 / 2,378 | 869 / 587 / 419 / 360 | 613 / 396 / 252 / **144** |
| **S3 (1,488 / 2,232), proposed** | to 2023-01-31 23:00 | 2023-02-01 to 2023-04-03 | 2023-04-04 to 2023-07-05 | 2,248 / 1,609 / 1,578 / 1,688 | 1,019 / 666 / 599 / 468 | **1,146 / 767 / 647 / 677** |

All train blocks start at 2022-09-24 07:00. Their first origin is 2022-09-25 06:00.

- **T1-like** windows at the series end do not work once fill hours are masked: there are no test samples at all for h ≥ 168, because June 2023 is 83% fill. Without the mask the 744-hour test window would be 600/744 fill.
- **S1 and S2** keep more training data. But their h = 744 test is 144 samples whose targets fall on only six calendar days (5 Jun and 1 to 5 Jul 2023).
- **S3** is the only option with several hundred scorable test samples at every horizon, including 677 at h = 744 with targets spread over May, June and July. Its validation block has 468 samples at h = 744.

## 3. Proposed split (S3)

| Block | Start (IST) | End (IST) | Hours | Rows (1-based, store order) | Role |
|---|---|---|---|---|---|
| Warm-up | 2022-07-01 00:00 | 2022-09-24 06:00 | 2,047 | 1 to 2,047 | Decomposition history only. No samples |
| Train | 2022-09-24 07:00 | 2023-01-31 23:00 | 3,113 | 2,048 to 5,160 | Fitting during model selection |
| Validation | 2023-02-01 00:00 | 2023-04-03 23:00 | 1,488 | 5,161 to 6,648 | Early stopping and all selection |
| Test | 2023-04-04 00:00 | 2023-07-05 23:00 | 2,232 | 6,649 to 8,880 | Read once at the end |

Samples (origin, target) per horizon (`split_proposal_S3_boundaries_and_counts.csv`, which also lists the first and last origin and target for each cell):

| Horizon | Train: origins kept / scorable samples | Validation | Test | Train + validation refit |
|---|---|---|---|---|
| 24 h | 2,398 / 2,248 | 1,087 / 1,019 | 1,236 / 1,146 | 3,322 |
| 168 h | 2,254 / 1,609 | 943 / 666 | 1,157 / 767 | 2,419 |
| 336 h | 2,086 / 1,578 | 775 / 599 | 1,157 / 647 | 2,388 |
| 744 h | 1,845 / 1,688 | 546 / 468 | 1,127 / 677 | 2,738 |

The counts are identical for all six target pollutants and for B1 and B2, because the mask is row-level.

Test targets by month: h = 24 gives 413 (Apr), 534 (May), 120 (Jun), 79 (Jul); h = 744 gives 437 (May), 120 (Jun), 120 (Jul).

## 4. Procedure

1. **Selection.** Fit on train samples. Pick hyperparameters, early-stopping rounds, λ/α, PCA/PLS component counts and feature subsets on validation samples. Fit every transform (scalers, PCA, PLS, MI binning) on train rows only.
2. **Final fit.** Refit on train plus validation samples (labels up to 2023-04-03 23:00) with the selected settings frozen. Use the best iteration from step 1 for boosting.
3. **Test.** Score the test samples once. Report validation and test results separately and never pick anything on test.
4. **Scoring.** Score on the original scale, on scorable targets only. MASE uses the seasonal-naive (lag 24) MAE on scorable training pairs of the fit being scored: 2,336 pairs in the train block. Report MAE and RMSE as well. For B2, sum the six component forecasts before scoring.
5. **Origin sets.** The primary analysis uses per-horizon origin sets as above. For cross-horizon comparisons, add a common-origin view: the test origins valid at h = 744, scored at every horizon.

## 5. Caveats

- With about one year of data, the blocks cover different seasons: train is autumn and winter, validation is February to early April, test is April to July (pre-monsoon and monsoon). Some loss from train to test reflects seasonal shift, not just model quality. The refit on train plus validation reduces this, without removing it.
- Neighbouring origins overlap heavily, especially at h = 744, so the effective number of independent test cases is much smaller than the sample counts. Use block-bootstrap intervals (the repository already has `.block_boot_ci`) rather than treating samples as independent.
- A rolling-origin design (for example monthly refits through the test block) would make better use of the data. It is a reasonable later robustness check, but it multiplies the model count, so it is not the primary proposal.
- If the mask is rejected and the fill hours are kept as targets (paper-comparable), S3 can still be used. Report those scores as a secondary, clearly labelled result.
