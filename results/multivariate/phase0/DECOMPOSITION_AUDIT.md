# Phase 0 decomposition audit: `mra_haar_J5__raw`

## 1. Availability

**The decomposition store is not in the uploaded archive.** There is no `store/decomp/` folder, no manifest and no decomposition log, for any pollutant or station. It is not in git history either, and `.RData` holds only v1 bake-off objects.

The existing code would write these files for B2 (`decomposition_availability.csv`):

| Pollutant | Expected file | In upload |
|---|---|---|
| PM2.5 | `store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=PM2.5.parquet` | No |
| PM10 | `store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=PM10.parquet` | No |
| NO2 | `store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=NO2.parquet` | No |
| SO2 | `store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=SO2.parquet` | No |
| O3 | `store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=O3.parquet` | No |
| CO | `store/decomp/method=mra_haar_J5__raw/station=CPCB/variable=CO.parquet` | No |
| manifest | `store/decomp/manifests/mra_haar_J5__raw.json` | No |

If these files exist on your machine (the T1 experiment presumably read them), nothing needs generating. Run the checker in this folder from the project root and keep its output here:

```
Rscript results/multivariate/phase0/check_decomp_store.R mra_haar_J5__raw CPCB
```

It writes `decomposition_store_check_mra_haar_J5__raw_CPCB.csv` and reads everything else without changing it. For each pollutant it checks that the file exists; that the components are D1 to D5 and S5; that timestamps match `store/clean` row for row and match the PM2.5 file; the warm-up NA count and first valid timestamp; that `valid_warmup` is consistent; the additivity error; and that stored values match a fresh trailing recomputation at 30 sampled hours. It also reads the manifest fields (`partial`, `family`, `J`, `filter`, `variables`, input hash). The last check matters because additivity alone cannot catch a two-sided store: a two-sided MRA is additive too. The checker was tested on a synthetic mock store containing one planted two-sided file and one missing file, and it flagged both (deviation 1.91 and `file_exists = FALSE`).

If the files do not exist locally, they need generating. Not done here, per the Phase 0 scope:

```
Rscript run_decomp.R mra_haar_J5 --skip-screen --skip-diag
```

This writes both the `raw` and `log` scales and both stations (CPCB and ID1) because `run_decomp()` loops over both scales and every station in the clean store. Only `__raw` / CPCB is needed. Afterwards, confirm in the manifest that `partial` is `false` and `variables` lists all six pollutants: the engine silently restricts a method to PM2.5/PM10 if its projected runtime exceeds `max_hours_per_method_scale` (6 h). That cap should not trigger here, since a 2,048-hour Haar window takes about 2 ms.

## 2. What the method is (from code and config)

| Item | Value | Source |
|---|---|---|
| Method id | `mra_haar_J5`, scale `raw` (file id `mra_haar_J5__raw`) | `config/decomp.yaml`, `method_full_id()` |
| Family | `trailing` | `config/decomp.yaml` |
| Function | `decomp_mra_haar()` calls `haar_mra(window, J = 5)` | `R/32_decomp_trailing.R`, `R/04_modwt.R` |
| Transform | Haar MODWT pyramid with circular boundary, then additive MRA | `R/04_modwt.R` |
| Level | J = 5 | config `params.J` |
| Components | D1, D2, D3, D4, D5, S5 | `decomp_mra_haar()` column names |
| Window | W = 2,048 hours, no padding (`pad: 0`) | config `window_h`, `params.pad` |
| Value stored at t | last row of the MRA of `x[t-2047 .. t]` | `run_trailing_series()` |
| Input | `value_filled_causal` from `store/clean`, raw scale | `compute_decomp_series()` |
| Warm-up | rows with t < W are NA; `valid_warmup = t >= W` | `run_trailing_series()`, `compute_decomp_series()` |
| Extra columns | `timestamp`, `valid_warmup`, `frac_filled_window`, `resid`, `valid_basic`, `valid_strict` | `compute_decomp_series()` |
| On-disk timestamps | written as UTC instants, converted back to IST by `get_decomp()` | `R/35_decomp_io.R` |
| Variables | the six pollutants (not AT/RH) | config `variables: pollutants` |

## 3. Verification by sampled recomputation

Since the stored files were not available, I ran the repository's own functions (`.decomp_at_t`, `decomp_mra_haar`, `haar_mra`) on the CPCB clean-store series at 40 randomly sampled hours per pollutant, rows 2,126 to 8,048. No decomposition series was written: only summary numbers. Full results: `decomposition_causality_check_mra_haar_J5.csv`.

| Pollutant | Components | Change at t after a +50 bump at t+1, t+24, t+168, t+336 or t+744 | Max additivity error at t | Change after a bump at t, t-1 | Change after a bump at t-2047 | Change after a bump at t-2048 |
|---|---|---|---|---|---|---|
| PM2.5 | D1 to D5, S5 | 0 | 3.6e-15 | 25, 12.5 | 12.5 | 0 |
| PM10 | D1 to D5, S5 | 0 | 7.1e-15 | 25, 12.5 | 12.5 | 0 |
| NO2 | D1 to D5, S5 | 0 | 4.4e-16 | 25, 12.5 | 12.5 | 0 |
| SO2 | D1 to D5, S5 | 0 | 8.9e-16 | 25, 12.5 | 12.5 | 0 |
| O3 | D1 to D5, S5 | 0 | 1.1e-15 | 25, 12.5 | 12.5 | 0 |
| CO | D1 to D5, S5 | 0 | 1.1e-16 | 25, 12.5 | 12.5 | 0 |

I also checked that `run_trailing_series()` returns exactly `.decomp_at_t()` at a given row (difference 0) and leaves rows 1 to W-1 as NA.

Conclusions per item the task asked about:

- **Method, level, component names:** Haar MRA, J = 5, D1 to D5 and S5 for every pollutant, as configured.
- **Causality:** a value at t uses only `x[t-2047 .. t]`. Future values have no effect.
- **Additivity / reconstruction:** D1 + ... + D5 + S5 = x at every row, up to about 1e-14.
- **Warm-up:** the first 2,047 rows are NA, from 2022-07-01 00:00 to 2022-09-24 06:00 IST. The first valid component is at **2022-09-24 07:00** (row 2,048). This is 23.1% of the series, and it is the same for every pollutant because all six share one grid.
- **Timestamp alignment:** by construction each file has one row per `store/clean` row in timestamp order (`df$timestamp <- sv$timestamp`). Raw and component series align row for row, and the six pollutants align with each other because they share the 8,880-hour grid. The checker confirms this on the real files.
- **`valid_strict`:** equals `valid_basic` for CPCB, because `frac_filled_24h` is 0 everywhere (fill rows are not flagged). It offers no protection against the constant-fill blocks.

## 4. Is the trailing-window MRA suitable for forecasting?

It is **leakage-safe** and **additive**, so it can be used for B2 as both feature and target. Two properties limit how informative it is.

**Circular wrap at the window end.** At the last row of the window, the inverse transform wraps around to the start of the window. The endpoint value depends on the last 32 hours and on the first 31 hours of the window, roughly 85 days earlier (`decomposition_endpoint_dependence_profile_PM25.csv`):

| Component | Recent hours used | Old hours used (k hours before t) |
|---|---|---|
| D1 | t, t-1 | t-2047 |
| D2 | t to t-3 | t-2045 to t-2047 |
| D3 | t to t-7 | t-2041 to t-2047 |
| D4 | t to t-15 | t-2033 to t-2047 |
| D5 | t to t-31 | t-2017 to t-2047 |
| S5 | t to t-31 | t-2017 to t-2047 |

For example, the real-time D1 is 0.5·x[t] − 0.25·x[t−1] − 0.25·x[t−2047]. A quarter of it is the reading from 85 days earlier.

**Real-time values differ from settled values.** I compared each endpoint value with the value the same hour gets once 32 later hours are available (D3-style diagnostic, which uses future data on purpose; diagnostic only, never a feature). Median over pollutants (`decomposition_edge_fidelity_mra_haar_J5.csv`):

| Component | Correlation | nRMSE | Sign agreement |
|---|---|---|---|
| D1 | 0.59 | 2.31 | 0.44 |
| D2 | 0.62 | 1.27 | 0.53 |
| D3 | 0.79 | 0.79 | 0.58 |
| D4 | 0.74 | 0.71 | 0.66 |
| D5 | 0.50 | 1.12 | 0.60 |
| S5 | 0.70 | 0.74 | 1.00 |

So the real-time components are noisy stand-ins for the frequency bands, not the clean bands seen in the paper's two-sided plots. Because B2 targets are also real-time components (each at its own t+h), training and evaluation stay consistent and reconstruction by summation is exact. The noise may still reduce what B2 can gain over B1. This is a property of the agreed protocol, not a defect to fix in Phase 1.

**Interaction with the fill blocks.** The decomposition runs over the constant-fill hours as if they were real. Inside long blocks D1 to D5 are near 0 and S5 is near the fill constant, with transients at block edges. Through the wrap, a fill block 85 days earlier also enters the endpoint value. None of this is leakage. The Phase 0 mask removes these hours as targets and as origins (see `SPLIT_PROPOSAL.md`).

## 5. Alternatives (recorded, not adopted)

The protocol stays `mra_haar_J5__raw`. One option worth a later sensitivity run: the causal Haar pyramid already in the repository (`decomp_coef_haar`, family `causal_full`) gives W1 to W5 plus V5. I checked it on the CPCB series. It is additive (W1 + ... + W5 + V5 = x, error ≤ 1.4e-14), strictly causal (a bump at row 5,000 changes nothing before it), and valid from row 32, so its warm-up is 31 hours instead of 2,047, with no wrap. The config only lists it as `coef_haar_J10`, whose first five levels plus V5 are exactly the J = 5 version. Switching would be a protocol change and is not proposed for B2.

## 6. What needs to be generated

- If the local store exists: nothing. Run `check_decomp_store.R` first.
- If not: `mra_haar_J5__raw` for CPCB, all six pollutants (PM2.5, PM10, NO2, SO2, O3, CO), using the command in section 1, then run the checker.
- No other decomposition is needed for B1 or B2.
