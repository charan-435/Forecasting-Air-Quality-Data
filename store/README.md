# Clean hourly store (Phase 1a)

Leak-free preprocessing ends here. Later phases (decomposition, origins, models)
read `store/clean/` and must follow `store/clean/policy.yaml`.

Build: `Rscript run_preprocess.R` from the project root.
Config: `config/preprocess.yaml`. Log: `store/preprocess_log.txt`.
No plots. Tables: `store/DATA_QUALITY.md`. Column dictionary: `store/clean/README.md`.

## Time labelling

Hour **t** is the mean of readings in **(t − 1h, t]** (end-labelled, `Asia/Kolkata`).
A value stamped t is fully known at t. Start-labelled sources are shifted forward
by their native interval before binning.

## Dataset switch

| `active` | Sources | Preprocess |
|---|---|---|
| `paper` | `data/raw/CPCB.csv`, `data/raw/ID1.csv` | **Skipped** — already hourly / paper-ready |
| `delhi` | ITO, R K Puram 15-min CPCB (`data/raw/delhi/`) | Full causal pipeline |
| `shillong` | Lumpyngngad, JN Stadium 15-min CPCB | Full causal pipeline |

## Policy (also in `store/clean/policy.yaml`)

- A training or evaluation **target** must be `is_scorable`.
- Exclude a training row if `frac_filled_24h` at its input time is > 0.5.
- Skip a forecast origin if `frac_filled_24h` at the origin is > 0.25, or if `in_long_gap` is true at the origin.

`value_filled_causal` is a model input only. Never score it.
