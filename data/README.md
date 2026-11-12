# Source data and prepared inputs

| Location | Meaning |
|---|---|
| raw/CPCB.csv, raw/ID1.csv | Already-hourly files from the paper's public code. Preserve them as received. |
| raw/shillong/shillong_15min_2023.parquet | Separate Lumpyngngad and JN Stadium station records. |
| processed/ | Reusable hourly series, packed inputs, and cached weather. |

A prepared series is not automatically valid ground truth. CPCB contains repeated fill patterns and a cloned final row; the cleaned experiment handles these explicitly. Read units, especially CO, from the source metadata and audit.

Run code/preprocessing/run_preprocess.R with paper or shillong to build the relevant shared store. Quality masks, input-fill provenance, and target eligibility live in data/processed/store/. Predictions and scores live in results/.
