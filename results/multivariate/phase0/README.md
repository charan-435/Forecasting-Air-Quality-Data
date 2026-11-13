# results/multivariate/phase0

This is an audit and planning folder only. No models were trained, and no existing preprocessing, decomposition or T1 output was changed.

Read in this order:

1. `DATA_AUDIT.md`: pollutant availability, the constant-fill blocks, the common intersection
2. `DECOMPOSITION_AUDIT.md`: `mra_haar_J5__raw` (not in the upload), causality and additivity checks
3. `LEAKAGE_AUDIT.md`: leakage findings and the rules for B1/B2
4. `SPLIT_PROPOSAL.md`: proposed split S3, with exact boundaries and sample counts
5. `FEATURE_DESIGN.md`: B0/B1/B2 matrices, dimensions, pooled layout
6. `IMPLEMENTATION_PLAN.md`: model-family support, next steps, recommendation

Machine-readable tables:

| File | Content |
|---|---|
| `pollutant_availability_cpcb_raw.csv` | per-variable audit of `data/raw/CPCB.csv` |
| `pollutant_availability_clean_store.csv` | same for `store/clean/series.parquet` (CPCB and ID1) |
| `pollutant_availability_other_cpcb_stations.csv` | Delhi and Shillong CAAQMS 15-min coverage |
| `alignment_summary_cpcb.csv` | common intersection and scorable hours per pollutant |
| `cpcb_frozen_blocks_ge24h.csv` | constant or repeated blocks of 24 h or more |
| `cpcb_monthly_pct_identical_to_previous_hour.csv`, `monthly_target_scorability_cpcb.csv` | monthly views |
| `proposed_quality_mask_cpcb.csv` | proposed row-level mask, one row per hour |
| `decomposition_availability.csv` | expected decomposition files and status |
| `decomposition_causality_check_mra_haar_J5.csv` | sampled bump tests and additivity |
| `decomposition_endpoint_dependence_profile_PM25.csv`, `decomposition_edge_fidelity_mra_haar_J5.csv` | endpoint behaviour of the trailing MRA |
| `leakage_risk_register.csv` | 16 risks with location, severity, mitigation |
| `split_options_sample_counts.csv`, `split_proposal_S3_boundaries_and_counts.csv` | split comparison and the proposed split |
| `feature_dimensions.csv`, `model_family_support.csv` | design and support tables |
| `data_audit_notes.json`, `split_notes.json` | scalar results used in the text |

Scripts:

- `check_decomp_store.R`: run from the project root to check a local decomposition store. It writes one new CSV here and nothing else.
- `scripts/`: the Phase 0 audit scripts. The Python ones need pandas and pyarrow; start with `export_wide.py <repo> <csv>`. The R check uses the repository's own decomposition functions.
