# Architecture Reference

## Shillong definitions

| ID | Formulation |
|---|---|
| A0 | \(y_{t+h}=f_h(PM2.5_{t},...,PM2.5_{t-23})\) |
| A1 | A0 plus contemporaneous origin meteorological covariates |
| A2 | Fixed-horizon model on the last 24 values of every available used pollutant |
| A3 | A2 plus contemporaneous meteorological covariates |
| B0 | Forecast each D1-D5/S5 component from its own 24 lags, then sum components |
| B1 | Shared one-row-per-component model with component id and standardised own-component lag slot |
| B2 | B0 components plus origin meteorological covariates |
| B3 | B1 shared components plus origin meteorological covariates |
| C1_sep/C1_sh | Target-pollutant component lag history, separate/shared level reconstruction |
| C2_sep/C2_sh | All available pollutants' component lag histories, separate/shared component models |
| C3_sep/C3_sh | C2 components plus origin meteorological covariates |

Meteorological covariates are origin features and are not pollutant measurements. The study does not evaluate future meteorological forecasts.

## CPCB Phase 2 raw definitions
- **B0:** raw PM2.5 history only; 24 features.
- **B1:** six-pollutant raw history; 144 features.

Here B0/B1 are raw and univariate/multivariate raw designs, not decomposition architectures. This label set must not be mixed with Shillong B0/B1.

## Shared representation
Shared models stack rows for origin and component. Each row contains the model's own component 24-lag slot, component ID, and any covariates. The own slot is standardised by the component training distribution and reconstructed components are summed to level.
