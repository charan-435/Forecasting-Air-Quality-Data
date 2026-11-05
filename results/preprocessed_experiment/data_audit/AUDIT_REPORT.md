# CPCB preprocessed experiment — Phases 1–2: audit, cleaned dataset, decomposition

Base: branch `kaisen` @ `38daa41` (no other work used). Run with
`Rscript scripts/experiments/run_preprocessed_experiment.R phase1` then `phase2`. Config:
`config/preprocessed_experiment.yaml`. Every output is under `store/preprocessed_experiment/`
or `results/preprocessed_experiment/`.

## Isolation

- 229 existing files (everything outside `.git` and the experiment's own paths: data, `store/clean`,
  configs, `R/`, runners, results, other datasets) were hashed before the run
  (`guard/hashes_before.json`) and re-checked after each phase: **0 changed, 0 removed, 0 added**
  (`guard/verify_phase1.csv`, `guard/verify_phase2.csv`).
- Shared code is sourced unchanged. Three wrappers avoid shared side effects:
  - `kaisen` `pp_log()` / `decomp_log()` append to `store/` logs → redirected to the experiment log in this R session.
  - `run_preprocess()` writes `config/imputation_choice.yaml` → its steps are called individually instead.
  - `compute_decomp_series()` checkpoints into `store/decomp/` → the same engine (`run_trailing_series()` + `decomp_mra_haar()`) is called with an experiment checkpoint path.

## 1. Audit of the source data (`data_audit/`)

| Item | Finding |
|---|---|
| Source | `store/clean/series.parquet`, station CPCB, stored as-is (`skip_preprocess: true`) |
| Hours | 8,880, 2022-07-01 00:00 → 2023-07-05 23:00 IST, every step 1 h, no duplicates |
| Pollutants | PM2.5, PM10, NO2, SO2, O3, CO — all present, no NA, no negatives |
| Existing quality flags | none set (all quality columns FALSE, every hour "scorable") |
| Raw CSV | 8,881 rows; its last row (06-07-2023 00:00) is a clone of the first (AUDIT F15); the store already excludes it |
| Units | config says µg/m³ for all six, but CO spans 0–1.33 (mg/m³-like) and NO2 sits near 2.2; reported as-is, not converted |

**Synthetic fills.** Five complete six-pollutant vectors repeat at 2–2,304 distinct hours
(`fill_codes.csv`). Independent sensors reporting to 6+ decimals cannot repeat a joint vector, so
these are fills, not measurements:

| Code | Hours (train / val / test) | Pattern |
|---|---|---|
| F2 | 2,304 (1,200 / 336 / 768) | each value ≈ the column mean; first 6–7 days of every month + 6–30 June 2023 (600 h) |
| F3 | 296 (176 / 67 / 53) | a second near-mean constant set |
| F4 | 31 (31 / 0 / 0) | constant set with CO = 0 (all 31 CO zeros), Jul–Aug 2022 |
| F1 | 4 (train) | an identical vector at 4 different dates |
| F5 | 2 (train) | an identical vector at 2 different dates |

Together 2,637 hours (29.7 %). Codes are learned on the training block only and applied everywhere.

**Existing repository rules** (`config/preprocess.yaml`, audited on the raw values, `existing_rules_audit.csv`):
bounds and negativity flag nothing; the causal stuck rule (≥ 6 h) flags 2,379–2,380 hours per
pollutant, all inside the fill blocks except one genuine 6-h PM2.5 freeze; PM2.5 > 1.1 × PM10 in
206 hours (ratio median 1.48, max 16.9); the MAD spike flag marks 295–785 hours per pollutant but is
not a mask in kaisen (`spike.mask: false`) and is kept as information only.

## 2. Validity rules applied (`preprocessing/rules.csv`, `pollutant_rules_counts.csv`)

All rules are **invalid-value removal**, not statistical outlier treatment: no percentile clipping,
no winsorisation, no value replaced by a bound. Every invalid value becomes NA.

| Rule (precedence) | Source | Definition | Why |
|---|---|---|---|
| fill_code | this experiment | six-pollutant vector seen at ≥ 2 training hours | synthetic fill, not a measurement |
| negative | kaisen | value < 0 | impossible concentration |
| out_of_bounds | kaisen bounds | outside [lower, upper] | physically implausible |
| stuck | kaisen `stuck_hours` | identical value ≥ 6 h, causal (start of a run not rewritten) | frozen sensor |
| pm_ratio | kaisen `pm_ratio_max` | PM2.5 > 1.1 × PM10, both PM values | PM2.5 is part of PM10 |

| Pollutant | Lower / upper bound | Set to NA | % | fill code | stuck | PM ratio | Clipped |
|---|---|---|---|---|---|---|---|
| PM2.5 | 0 / 1000 µg/m³ | 2,844 | 32.0 | 2,637 | 1 | 206 | 0 |
| PM10 | 0 / 2000 µg/m³ | 2,843 | 32.0 | 2,637 | 0 | 206 | 0 |
| NO2 | 0 / 1000 | 2,637 | 29.7 | 2,637 | 0 | 0 | 0 |
| SO2 | 0 / 1000 | 2,637 | 29.7 | 2,637 | 0 | 0 | 0 |
| O3 | 0 / 1000 | 2,637 | 29.7 | 2,637 | 0 | 0 | 0 |
| CO | 0 / 50 (mg/m³) | 2,637 | 29.7 | 2,637 | 0 | 0 | 0 |

Lower bound: concentrations cannot be negative. Upper bounds: the repository's physical limits; no
CPCB value reaches them. High genuine values are kept (e.g. PM10 peaks of 320–393 µg/m³).

## 3. Missing values (`preprocessing/imputation_counts.csv`, `store/.../imputation_choice.yaml`)

- kaisen's causal fills (`R/preprocessing/22_impute.R`), one method per pollutant and gap-length bucket, chosen by
  kaisen's artificial-gap benchmark run on the **training block only** (`selection_end` = end of training).
- **Only parameter-free, past-only methods** (M1 last value, M2/M3 same hour 24/168 h earlier, M4,
  M5/M6 trailing 28-day hour-of-day climatology). A first run with kaisen's full set showed that M7/M8
  fill early hours using parameters fitted on later training data (CO/O3 had fills three days before
  their first observation) and that M7 produced 97 negative CO values; both are excluded.
- Chosen for PM2.5: 1–3 h M1, 4–24 h M5, 25–72 h M5, > 72 h M2. Long gaps (> 72 h; 12 per pollutant,
  longest 600 h in June 2023) are filled the same way but flagged (`in_long_gap`), and forecast origins
  inside them are skipped (kaisen `policy.yaml`).
- Imputed: PM2.5 2,700, PM10 2,699, others 2,493. The first 144 hours (to 2022-07-06 23:00) precede
  any valid observation and stay NA (no past to fill from).
- Fills are model inputs only; a filled hour is never a scored target.

PM2.5 summary (`summary_before_after.csv`): before 8,880 h, mean 12.09, median 11.88 (the fill
constant); valid observations 6,036 h, mean 12.03, median 8.77.

## 4. Split (`data_audit/split_availability.csv`)

No "S3" split exists at `kaisen` `38daa41` (no split config, no `get_origins()`; `chrono_split()` is
deprecated by AUDIT F3). **PE-S3** is a documented substitute, keyed by the target time:

| Block | Targets | Valid targets after warm-up | Eligible origins |
|---|---|---|---|
| train | ≤ 2023-02-28 23:00 | 2,670 | 2,496 |
| val | 2023-03-01 → 2023-04-30 | 973 | 757 |
| test | 2023-05-01 → 2023-07-05 | 750 | 658 |

Eligible = origin after decomposition warm-up, target observed and valid, PM2.5 fill share in the
24 h before the origin ≤ 0.5 (training) / ≤ 0.25 and not in a long gap (val/test), per
`store/clean/policy.yaml`. The same origins serve every architecture.

## 5. Decomposition (`results/.../decomposition/`, `store/.../decomp/`)

- `mra_haar_J5__raw`: trailing window 2,048 h, Haar, J = 5, pad 0 (from `config/decomp.yaml`),
  components D1–D5 and S5, for all six cleaned pollutants (B2/B3 covariates need them).
- The existing `mra_haar_J5__raw` store has **not been generated** at `kaisen` `38daa41`
  (`store/decomp/` does not exist). An unmasked decomposition was computed under the experiment
  store as a control: cleaned and unmasked PM2.5 components differ in 56–84 % of hours (mean
  |difference| 0.41–1.73, max 12.9), so components of the original series are **not valid** for
  the cleaned data.
- Additivity: max |input − Σ components| ≤ 2.1e-14 after warm-up.
- Warm-up: the first full 2,048-h window of model inputs ends 2022-09-30 07:00 (2,191 warm-up rows,
  because the cleaned series starts 2022-07-07); unmasked: 2022-09-24 07:00.
- Existing convention kept: each trailing window is decomposed circularly and its last row stored, so
  values at t use only data ≤ t, but the last row of each component is affected by the window's
  wrap-around (AUDIT F1).

## 6. Tests (`results/.../tests/data_tests.csv`) — 18 / 18 pass

Grid identical to source; raw values unchanged; invalid → NA; valid unchanged; fills only on masked
hours; NA only before the first observation; no negative inputs; only M1–M6 used; nothing clipped;
fill codes unchanged when non-training values are perturbed; **imputation causal** (perturbing
hours after a cut leaves earlier fills identical); stored fill reproducible; components D1–D5, S5;
additivity < 1e-8; warm-up correct; **decomposition causal** (perturbing hours after t leaves
components at ≤ t identical); stored components equal a fresh computation.

## Deviations from the task text

| Task says | At kaisen 38daa41 | Done instead |
|---|---|---|
| use the existing S3 split | none exists | PE-S3, documented above |
| use existing `mra_haar_J5__raw` as reference | store never generated | same method, cleaned + unmasked control in the experiment store |
| compare with existing T1 / unmasked results | no T1 results; `results/paper/scores.csv` is the deprecated recursive single-origin protocol | planned: the same five architectures on the unmasked control, same origins and code |
| leave `results/multivariate/`, Phase 1/2 multivariate untouched | do not exist | nothing to protect beyond the guard |
