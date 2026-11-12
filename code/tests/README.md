# Checks grouped by what can go wrong

| Folder | Checks | Command from the repository root |
|---|---|---|
| preprocessing/ | Causal fills, hourly labels, coverage, faults, eligibility, and scoring guards | Rscript code/tests/preprocessing/run_all.R |
| decomposition/ | Causality, additivity, validity, schema, checkpoints, determinism, and embargoes | Rscript code/tests/decomposition/run_all.R |
| preprocessed_experiment/ | Cleaned target alignment and model interfaces | Run experiment phases 2 and 3; they call these checks. |

The first two folders were previously named phase1a and phase1b. Internal assertion IDs retain that history. Each runner resolves the project root when launched by its absolute path. Tests need the dependencies used by the shared R loader.

For recorded-table checks rather than model/data tests, use code/validation/.
