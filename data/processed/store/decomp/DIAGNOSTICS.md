# Decomposition diagnostics

D1/D2 are hard fails. D3 uses data after t on purpose and is **not** stored as features.

## Runs

| method | scale | family | partial | runtime_s |
|---|---|---|---|---|
| coef_d4_J9 | log | causal_full | FALSE | 3.6 |
| coef_d4_J9 | raw | causal_full | FALSE | 4.64 |
| coef_haar_J10 | log | causal_full | FALSE | 1.25 |
| coef_haar_J10 | raw | causal_full | FALSE | 2.15 |
| coef_la8_J8 | log | causal_full | FALSE | 4.8 |
| coef_la8_J8 | raw | causal_full | FALSE | 6.32 |
| mra_d4_J5 | log | trailing | FALSE | 110.69 |
| mra_d4_J5 | raw | trailing | FALSE | 122.36 |
| mra_d4_J8 | log | trailing | FALSE | 300.59 |
| mra_d4_J8 | raw | trailing | FALSE | 260.05 |
| mra_haar_J5 | log | trailing | FALSE | 180.85 |
| mra_haar_J5 | raw | trailing | FALSE | 198 |
| mra_haar_J9 | log | trailing | FALSE | 606.98 |
| mra_haar_J9 | raw | trailing | FALSE | 599.88 |
| mra_la8_J5 | log | trailing | FALSE | 275.37 |
| mra_la8_J5 | raw | trailing | FALSE | 278.64 |
| mra_la8_J8 | log | trailing | FALSE | 796.76 |
| mra_la8_J8 | raw | trailing | FALSE | 893 |
| mstl | log | trailing | FALSE | 404.38 |
| mstl | raw | trailing | FALSE | 424.23 |

## D1 / D2 / D6

| method | scale | station | variable | D1 | max_delta | D2 | max_err | frac_basic_not_strict |
 |---|---|---|---|---|---|---|---|---|
| coef_d4_J9 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | CPCB | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | CPCB | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | CPCB | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | CPCB | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | CPCB | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | ID1 | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | ID1 | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | ID1 | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | ID1 | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | log | ID1 | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | AT | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | CPCB | RH | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | AT | TRUE | 0 | TRUE | NA | 0.000 |
| coef_d4_J9 | raw | ID1 | RH | TRUE | 0 | TRUE | NA | 0.000 |
| coef_haar_J10 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| coef_haar_J10 | log | CPCB | PM10 | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| coef_haar_J10 | log | CPCB | NO2 | TRUE | 0 | TRUE | 6.66e-16 | 0.000 |
| coef_haar_J10 | log | CPCB | SO2 | TRUE | 0 | TRUE | 1.33e-15 | 0.000 |
| coef_haar_J10 | log | CPCB | O3 | TRUE | 0 | TRUE | 1.33e-15 | 0.000 |
| coef_haar_J10 | log | CPCB | CO | TRUE | 0 | TRUE | 1.67e-16 | 0.000 |
| coef_haar_J10 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 2.66e-15 | 0.000 |
| coef_haar_J10 | log | ID1 | PM10 | TRUE | 0 | TRUE | 2.66e-15 | 0.000 |
| coef_haar_J10 | log | ID1 | NO2 | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| coef_haar_J10 | log | ID1 | SO2 | TRUE | 0 | TRUE | 1.33e-15 | 0.000 |
| coef_haar_J10 | log | ID1 | O3 | TRUE | 0 | TRUE | 2.66e-15 | 0.000 |
| coef_haar_J10 | log | ID1 | CO | TRUE | 0 | TRUE | 2.66e-15 | 0.000 |
| coef_haar_J10 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| coef_haar_J10 | raw | CPCB | PM10 | TRUE | 0 | TRUE | 5.68e-14 | 0.000 |
| coef_haar_J10 | raw | CPCB | NO2 | TRUE | 0 | TRUE | 3.55e-15 | 0.000 |
| coef_haar_J10 | raw | CPCB | SO2 | TRUE | 0 | TRUE | 3.55e-15 | 0.000 |
| coef_haar_J10 | raw | CPCB | O3 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| coef_haar_J10 | raw | CPCB | CO | TRUE | 0 | TRUE | 2.22e-16 | 0.000 |
| coef_haar_J10 | raw | CPCB | AT | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| coef_haar_J10 | raw | CPCB | RH | TRUE | 0 | TRUE | 5.68e-14 | 0.000 |
| coef_haar_J10 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 4.26e-14 | 0.000 |
| coef_haar_J10 | raw | ID1 | PM10 | TRUE | 0 | TRUE | 5.68e-14 | 0.000 |
| coef_haar_J10 | raw | ID1 | NO2 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| coef_haar_J10 | raw | ID1 | SO2 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| coef_haar_J10 | raw | ID1 | O3 | TRUE | 0 | TRUE | 4.26e-14 | 0.000 |
| coef_haar_J10 | raw | ID1 | CO | TRUE | 0 | TRUE | 2.27e-13 | 0.000 |
| coef_haar_J10 | raw | ID1 | AT | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| coef_haar_J10 | raw | ID1 | RH | TRUE | 0 | TRUE | 5.68e-14 | 0.000 |
| coef_la8_J8 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | CPCB | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | CPCB | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | CPCB | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | CPCB | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | CPCB | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | ID1 | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | ID1 | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | ID1 | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | ID1 | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | log | ID1 | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | AT | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | CPCB | RH | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | PM10 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | NO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | SO2 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | O3 | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | CO | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | AT | TRUE | 0 | TRUE | NA | 0.000 |
| coef_la8_J8 | raw | ID1 | RH | TRUE | 0 | TRUE | NA | 0.000 |
| mra_d4_J5 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 8.44e-15 | 0.000 |
| mra_d4_J5 | log | CPCB | PM10 | TRUE | 0 | TRUE | 1.07e-14 | 0.000 |
| mra_d4_J5 | log | CPCB | NO2 | TRUE | 0 | TRUE | 5.33e-15 | 0.000 |
| mra_d4_J5 | log | CPCB | SO2 | TRUE | 0 | TRUE | 5.33e-15 | 0.000 |
| mra_d4_J5 | log | CPCB | O3 | TRUE | 0 | TRUE | 2.89e-15 | 0.000 |
| mra_d4_J5 | log | CPCB | CO | TRUE | 0 | TRUE | 1.22e-15 | 0.000 |
| mra_d4_J5 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 1.15e-14 | 0.000 |
| mra_d4_J5 | log | ID1 | PM10 | TRUE | 0 | TRUE | 1.15e-14 | 0.000 |
| mra_d4_J5 | log | ID1 | NO2 | TRUE | 0 | TRUE | 8.88e-15 | 0.000 |
| mra_d4_J5 | log | ID1 | SO2 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_d4_J5 | log | ID1 | O3 | TRUE | 0 | TRUE | 1.07e-14 | 0.000 |
| mra_d4_J5 | log | ID1 | CO | TRUE | 0 | TRUE | 1.6e-14 | 0.000 |
| mra_d4_J5 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 1.07e-13 | 0.000 |
| mra_d4_J5 | raw | CPCB | PM10 | TRUE | 0 | TRUE | 5.68e-13 | 0.000 |
| mra_d4_J5 | raw | CPCB | NO2 | TRUE | 0 | TRUE | 3.55e-14 | 0.000 |
| mra_d4_J5 | raw | CPCB | SO2 | TRUE | 0 | TRUE | 1.78e-14 | 0.000 |
| mra_d4_J5 | raw | CPCB | O3 | TRUE | 0 | TRUE | 1.87e-14 | 0.000 |
| mra_d4_J5 | raw | CPCB | CO | TRUE | 0 | TRUE | 2e-15 | 0.000 |
| mra_d4_J5 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 5.68e-13 | 0.000 |
| mra_d4_J5 | raw | ID1 | PM10 | TRUE | 0 | TRUE | 6.82e-13 | 0.000 |
| mra_d4_J5 | raw | ID1 | NO2 | TRUE | 0 | TRUE | 9.95e-14 | 0.000 |
| mra_d4_J5 | raw | ID1 | SO2 | TRUE | 0 | TRUE | 2.56e-13 | 0.000 |
| mra_d4_J5 | raw | ID1 | O3 | TRUE | 0 | TRUE | 1.99e-13 | 0.000 |
| mra_d4_J5 | raw | ID1 | CO | TRUE | 0 | TRUE | 5e-12 | 0.000 |
| mra_d4_J8 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 1.2e-14 | 0.000 |
| mra_d4_J8 | log | CPCB | PM10 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| mra_d4_J8 | log | CPCB | NO2 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_d4_J8 | log | CPCB | SO2 | TRUE | 0 | TRUE | 7.55e-15 | 0.000 |
| mra_d4_J8 | log | CPCB | O3 | TRUE | 0 | TRUE | 5.22e-15 | 0.000 |
| mra_d4_J8 | log | CPCB | CO | TRUE | 0 | TRUE | 1.55e-15 | 0.000 |
| mra_d4_J8 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 1.6e-14 | 0.000 |
| mra_d4_J8 | log | ID1 | PM10 | TRUE | 0 | TRUE | 1.69e-14 | 0.000 |
| mra_d4_J8 | log | ID1 | NO2 | TRUE | 0 | TRUE | 1.2e-14 | 0.000 |
| mra_d4_J8 | log | ID1 | SO2 | TRUE | 0 | TRUE | 9.77e-15 | 0.000 |
| mra_d4_J8 | log | ID1 | O3 | TRUE | 0 | TRUE | 1.51e-14 | 0.000 |
| mra_d4_J8 | log | ID1 | CO | TRUE | 0 | TRUE | 2.13e-14 | 0.000 |
| mra_d4_J8 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 1.28e-13 | 0.000 |
| mra_d4_J8 | raw | CPCB | PM10 | TRUE | 0 | TRUE | 6.25e-13 | 0.000 |
| mra_d4_J8 | raw | CPCB | NO2 | TRUE | 0 | TRUE | 3.91e-14 | 0.000 |
| mra_d4_J8 | raw | CPCB | SO2 | TRUE | 0 | TRUE | 2.49e-14 | 0.000 |
| mra_d4_J8 | raw | CPCB | O3 | TRUE | 0 | TRUE | 3.31e-14 | 0.000 |
| mra_d4_J8 | raw | CPCB | CO | TRUE | 0 | TRUE | 2.44e-15 | 0.000 |
| mra_d4_J8 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 6.82e-13 | 0.000 |
| mra_d4_J8 | raw | ID1 | PM10 | TRUE | 0 | TRUE | 7.39e-13 | 0.000 |
| mra_d4_J8 | raw | ID1 | NO2 | TRUE | 0 | TRUE | 1.28e-13 | 0.000 |
| mra_d4_J8 | raw | ID1 | SO2 | TRUE | 0 | TRUE | 2.84e-13 | 0.000 |
| mra_d4_J8 | raw | ID1 | O3 | TRUE | 0 | TRUE | 2.7e-13 | 0.000 |
| mra_d4_J8 | raw | ID1 | CO | TRUE | 0 | TRUE | 5.46e-12 | 0.000 |
| mra_haar_J5 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J5 | log | CPCB | PM10 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J5 | log | CPCB | NO2 | TRUE | 0 | TRUE | 4.44e-16 | 0.000 |
| mra_haar_J5 | log | CPCB | SO2 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J5 | log | CPCB | O3 | TRUE | 0 | TRUE | 4.44e-16 | 0.000 |
| mra_haar_J5 | log | CPCB | CO | TRUE | 0 | TRUE | 1.11e-16 | 0.000 |
| mra_haar_J5 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J5 | log | ID1 | PM10 | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| mra_haar_J5 | log | ID1 | NO2 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J5 | log | ID1 | SO2 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J5 | log | ID1 | O3 | TRUE | 0 | TRUE | 1.33e-15 | 0.000 |
| mra_haar_J5 | log | ID1 | CO | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| mra_haar_J5 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_haar_J5 | raw | CPCB | PM10 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| mra_haar_J5 | raw | CPCB | NO2 | TRUE | 0 | TRUE | 3.55e-15 | 0.000 |
| mra_haar_J5 | raw | CPCB | SO2 | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| mra_haar_J5 | raw | CPCB | O3 | TRUE | 0 | TRUE | 3.55e-15 | 0.000 |
| mra_haar_J5 | raw | CPCB | CO | TRUE | 0 | TRUE | 1.11e-16 | 0.000 |
| mra_haar_J5 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 2.84e-14 | 0.000 |
| mra_haar_J5 | raw | ID1 | PM10 | TRUE | 0 | TRUE | 5.68e-14 | 0.000 |
| mra_haar_J5 | raw | ID1 | NO2 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_haar_J5 | raw | ID1 | SO2 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_haar_J5 | raw | ID1 | O3 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| mra_haar_J5 | raw | ID1 | CO | TRUE | 0 | TRUE | 1.29e-13 | 0.000 |
| mra_haar_J9 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J9 | log | CPCB | PM10 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J9 | log | CPCB | NO2 | TRUE | 0 | TRUE | 4.44e-16 | 0.000 |
| mra_haar_J9 | log | CPCB | SO2 | TRUE | 0 | TRUE | 4.44e-16 | 0.000 |
| mra_haar_J9 | log | CPCB | O3 | TRUE | 0 | TRUE | 4.44e-16 | 0.000 |
| mra_haar_J9 | log | CPCB | CO | TRUE | 0 | TRUE | 1.11e-16 | 0.000 |
| mra_haar_J9 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J9 | log | ID1 | PM10 | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| mra_haar_J9 | log | ID1 | NO2 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J9 | log | ID1 | SO2 | TRUE | 0 | TRUE | 4.44e-16 | 0.000 |
| mra_haar_J9 | log | ID1 | O3 | TRUE | 0 | TRUE | 8.88e-16 | 0.000 |
| mra_haar_J9 | log | ID1 | CO | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| mra_haar_J9 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_haar_J9 | raw | CPCB | PM10 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| mra_haar_J9 | raw | CPCB | NO2 | TRUE | 0 | TRUE | 1.55e-15 | 0.000 |
| mra_haar_J9 | raw | CPCB | SO2 | TRUE | 0 | TRUE | 1.78e-15 | 0.000 |
| mra_haar_J9 | raw | CPCB | O3 | TRUE | 0 | TRUE | 2.44e-15 | 0.000 |
| mra_haar_J9 | raw | CPCB | CO | TRUE | 0 | TRUE | 1.39e-16 | 0.000 |
| mra_haar_J9 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 2.84e-14 | 0.000 |
| mra_haar_J9 | raw | ID1 | PM10 | TRUE | 0 | TRUE | 5.68e-14 | 0.000 |
| mra_haar_J9 | raw | ID1 | NO2 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_haar_J9 | raw | ID1 | SO2 | TRUE | 0 | TRUE | 7.11e-15 | 0.000 |
| mra_haar_J9 | raw | ID1 | O3 | TRUE | 0 | TRUE | 1.42e-14 | 0.000 |
| mra_haar_J9 | raw | ID1 | CO | TRUE | 0 | TRUE | 2.27e-13 | 0.000 |
| mra_la8_J5 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 2.58e-12 | 0.000 |
| mra_la8_J5 | log | CPCB | PM10 | TRUE | 0 | TRUE | 3.29e-12 | 0.000 |
| mra_la8_J5 | log | CPCB | NO2 | TRUE | 0 | TRUE | 2.3e-12 | 0.000 |
| mra_la8_J5 | log | CPCB | SO2 | TRUE | 0 | TRUE | 5.72e-13 | 0.000 |
| mra_la8_J5 | log | CPCB | O3 | TRUE | 0 | TRUE | 1.49e-12 | 0.000 |
| mra_la8_J5 | log | CPCB | CO | TRUE | 0 | TRUE | 6.51e-13 | 0.000 |
| mra_la8_J5 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 3.92e-12 | 0.000 |
| mra_la8_J5 | log | ID1 | PM10 | TRUE | 0 | TRUE | 4.01e-12 | 0.000 |
| mra_la8_J5 | log | ID1 | NO2 | TRUE | 0 | TRUE | 2.15e-12 | 0.000 |
| mra_la8_J5 | log | ID1 | SO2 | TRUE | 0 | TRUE | 5.23e-12 | 0.000 |
| mra_la8_J5 | log | ID1 | O3 | TRUE | 0 | TRUE | 1.29e-12 | 0.000 |
| mra_la8_J5 | log | ID1 | CO | TRUE | 0 | TRUE | 6.03e-12 | 0.000 |
| mra_la8_J5 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 5.76e-11 | 0.000 |
| mra_la8_J5 | raw | CPCB | PM10 | TRUE | 0 | TRUE | 3.92e-10 | 0.000 |
| mra_la8_J5 | raw | CPCB | NO2 | TRUE | 0 | TRUE | 2.31e-11 | 0.000 |
| mra_la8_J5 | raw | CPCB | SO2 | TRUE | 0 | TRUE | 4.58e-12 | 0.000 |
| mra_la8_J5 | raw | CPCB | O3 | TRUE | 0 | TRUE | 1.21e-11 | 0.000 |
| mra_la8_J5 | raw | CPCB | CO | TRUE | 0 | TRUE | 1.07e-12 | 0.000 |
| mra_la8_J5 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 4e-10 | 0.000 |
| mra_la8_J5 | raw | ID1 | PM10 | TRUE | 0 | TRUE | 4.45e-10 | 0.000 |
| mra_la8_J5 | raw | ID1 | NO2 | TRUE | 0 | TRUE | 3.65e-11 | 0.000 |
| mra_la8_J5 | raw | ID1 | SO2 | TRUE | 0 | TRUE | 2.13e-10 | 0.000 |
| mra_la8_J5 | raw | ID1 | O3 | TRUE | 0 | TRUE | 8.44e-11 | 0.000 |
| mra_la8_J5 | raw | ID1 | CO | TRUE | 0 | TRUE | 3.62e-09 | 0.000 |
| mra_la8_J8 | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 2.42e-12 | 0.000 |
| mra_la8_J8 | log | CPCB | PM10 | TRUE | 0 | TRUE | 3.55e-12 | 0.000 |
| mra_la8_J8 | log | CPCB | NO2 | TRUE | 0 | TRUE | 2.42e-12 | 0.000 |
| mra_la8_J8 | log | CPCB | SO2 | TRUE | 0 | TRUE | 7.62e-13 | 0.000 |
| mra_la8_J8 | log | CPCB | O3 | TRUE | 0 | TRUE | 1.39e-12 | 0.000 |
| mra_la8_J8 | log | CPCB | CO | TRUE | 0 | TRUE | 6.39e-13 | 0.000 |
| mra_la8_J8 | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 4.33e-12 | 0.000 |
| mra_la8_J8 | log | ID1 | PM10 | TRUE | 0 | TRUE | 4.45e-12 | 0.000 |
| mra_la8_J8 | log | ID1 | NO2 | TRUE | 0 | TRUE | 2.22e-12 | 0.000 |
| mra_la8_J8 | log | ID1 | SO2 | TRUE | 0 | TRUE | 5.47e-12 | 0.000 |
| mra_la8_J8 | log | ID1 | O3 | TRUE | 0 | TRUE | 1.41e-12 | 0.000 |
| mra_la8_J8 | log | ID1 | CO | TRUE | 0 | TRUE | 6.75e-12 | 0.000 |
| mra_la8_J8 | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 5.66e-11 | 0.000 |
| mra_la8_J8 | raw | CPCB | PM10 | TRUE | 0 | TRUE | 4.11e-10 | 0.000 |
| mra_la8_J8 | raw | CPCB | NO2 | TRUE | 0 | TRUE | 2.43e-11 | 0.000 |
| mra_la8_J8 | raw | CPCB | SO2 | TRUE | 0 | TRUE | 5.79e-12 | 0.000 |
| mra_la8_J8 | raw | CPCB | O3 | TRUE | 0 | TRUE | 9.14e-12 | 0.000 |
| mra_la8_J8 | raw | CPCB | CO | TRUE | 0 | TRUE | 1.06e-12 | 0.000 |
| mra_la8_J8 | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 4.25e-10 | 0.000 |
| mra_la8_J8 | raw | ID1 | PM10 | TRUE | 0 | TRUE | 4.74e-10 | 0.000 |
| mra_la8_J8 | raw | ID1 | NO2 | TRUE | 0 | TRUE | 3.75e-11 | 0.000 |
| mra_la8_J8 | raw | ID1 | SO2 | TRUE | 0 | TRUE | 2.21e-10 | 0.000 |
| mra_la8_J8 | raw | ID1 | O3 | TRUE | 0 | TRUE | 8.71e-11 | 0.000 |
| mra_la8_J8 | raw | ID1 | CO | TRUE | 0 | TRUE | 3.81e-09 | 0.000 |
| mstl | log | CPCB | PM2.5 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | CPCB | PM10 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | CPCB | NO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | CPCB | SO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | CPCB | O3 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | CPCB | CO | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | ID1 | PM2.5 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | ID1 | PM10 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | ID1 | NO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | ID1 | SO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | ID1 | O3 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | log | ID1 | CO | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | CPCB | PM2.5 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | CPCB | PM10 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | CPCB | NO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | CPCB | SO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | CPCB | O3 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | CPCB | CO | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | ID1 | PM2.5 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | ID1 | PM10 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | ID1 | NO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | ID1 | SO2 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | ID1 | O3 | TRUE | 0 | TRUE | 0 | 0.000 |
| mstl | raw | ID1 | CO | TRUE | 0 | TRUE | 0 | 0.000 |

## D3 edge fidelity (real-time vs revised at t+512)

| method | scale | station | variable | component | n | cor | nrmse | sign_agree |
 |---|---|---|---|---|---|---|---|---|
| coef_d4_J9 | log | CPCB | PM2.5 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM2.5 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM2.5 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | PM10 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | PM10 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | NO2 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | NO2 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | SO2 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | SO2 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | O3 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | O3 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | CPCB | CO | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | CPCB | CO | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM2.5 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM2.5 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | PM10 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | PM10 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | NO2 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | NO2 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | SO2 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | SO2 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | O3 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | O3 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | log | ID1 | CO | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | log | ID1 | CO | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM2.5 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM2.5 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | PM10 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | PM10 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | NO2 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | NO2 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | SO2 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | SO2 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | O3 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | O3 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | CO | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | CO | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | AT | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | AT | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | CPCB | RH | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | CPCB | RH | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM2.5 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM2.5 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W4 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W5 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W6 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W7 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W8 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | W9 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | PM10 | V1 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V2 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V3 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V4 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V5 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V6 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V7 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V8 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | PM10 | V9 | 300 | 1.000 | 0.000 | 1.000 |
| coef_d4_J9 | raw | ID1 | NO2 | W1 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | NO2 | W2 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | NO2 | W3 | 0 | NA | NA | NA |
| coef_d4_J9 | raw | ID1 | NO2 | W4 | 0 | NA | NA | NA |

Causal coefficients should have cor = 1 and nrmse = 0 by construction.

## D4 band stability (dominant period of revised window)

Wide IQR means the column mixes frequencies across time.

| method | scale | component | period_median | period_IQR | n |
 |---|---|---|---|---|---|
| coef_haar_J10 | log | V1 | 24.0 | 100.0 | 3600 |
| coef_haar_J10 | log | V10 | 3280.5 | 3753.0 | 3390 |
| coef_haar_J10 | log | V2 | 24.0 | 96.6 | 3600 |
| coef_haar_J10 | log | V3 | 135.0 | 128.2 | 3600 |
| coef_haar_J10 | log | V4 | 720.0 | 1818.5 | 3600 |
| coef_haar_J10 | log | V5 | 811.4 | 3060.4 | 3600 |
| coef_haar_J10 | log | V6 | 838.5 | 2967.5 | 3600 |
| coef_haar_J10 | log | V7 | 858.9 | 2926.0 | 3600 |
| coef_haar_J10 | log | V8 | 912.0 | 3305.6 | 3600 |
| coef_haar_J10 | log | V9 | 3037.5 | 4179.8 | 3600 |
| coef_haar_J10 | log | W1 | 24.0 | 0.6 | 3600 |
| coef_haar_J10 | log | W10 | 1062.5 | 697.0 | 3390 |
| coef_haar_J10 | log | W2 | 24.0 | 0.8 | 3600 |
| coef_haar_J10 | log | W3 | 24.0 | 0.0 | 3600 |
| coef_haar_J10 | log | W4 | 24.0 | 0.0 | 3600 |
| coef_haar_J10 | log | W5 | 24.0 | 0.0 | 3600 |
| coef_haar_J10 | log | W6 | 122.8 | 6.1 | 3600 |
| coef_haar_J10 | log | W7 | 239.3 | 19.5 | 3600 |
| coef_haar_J10 | log | W8 | 376.6 | 136.8 | 3600 |
| coef_haar_J10 | log | W9 | 711.1 | 94.2 | 3600 |
| coef_haar_J10 | raw | V1 | 24.0 | 0.1 | 4800 |
| coef_haar_J10 | raw | V10 | 3327.8 | 3731.2 | 4520 |
| coef_haar_J10 | raw | V2 | 24.0 | 0.1 | 4800 |
| coef_haar_J10 | raw | V3 | 24.0 | 112.6 | 4800 |
| coef_haar_J10 | raw | V4 | 793.8 | 4168.8 | 4800 |
| coef_haar_J10 | raw | V5 | 862.3 | 4031.5 | 4800 |
| coef_haar_J10 | raw | V6 | 1069.7 | 4400.8 | 4800 |
| coef_haar_J10 | raw | V7 | 1952.0 | 4553.2 | 4800 |
| coef_haar_J10 | raw | V8 | 2887.5 | 4866.4 | 4800 |
| coef_haar_J10 | raw | V9 | 3287.5 | 4262.5 | 4800 |
| coef_haar_J10 | raw | W1 | 24.0 | 1.1 | 4800 |
| coef_haar_J10 | raw | W10 | 1314.7 | 1497.1 | 4520 |
| coef_haar_J10 | raw | W2 | 24.0 | 0.6 | 4800 |
| coef_haar_J10 | raw | W3 | 24.0 | 0.0 | 4800 |
| coef_haar_J10 | raw | W4 | 24.0 | 0.0 | 4800 |
| coef_haar_J10 | raw | W5 | 24.0 | 0.0 | 4800 |
| coef_haar_J10 | raw | W6 | 82.2 | 6.2 | 4800 |
| coef_haar_J10 | raw | W7 | 237.8 | 28.2 | 4800 |
| coef_haar_J10 | raw | W8 | 417.9 | 215.0 | 4800 |
| coef_haar_J10 | raw | W9 | 712.7 | 114.6 | 4800 |
| mra_d4_J5 | log | D1 | 3.0 | 0.7 | 480 |
| mra_d4_J5 | log | D2 | 6.0 | 1.9 | 480 |
| mra_d4_J5 | log | D3 | 12.0 | 0.0 | 480 |
| mra_d4_J5 | log | D4 | 24.1 | 0.0 | 480 |
| mra_d4_J5 | log | D5 | 48.9 | 12.1 | 480 |
| mra_d4_J5 | log | S5 | 554.7 | 273.1 | 480 |
| mra_d4_J5 | raw | D1 | 2.7 | 0.7 | 480 |
| mra_d4_J5 | raw | D2 | 6.0 | 1.3 | 480 |
| mra_d4_J5 | raw | D3 | 12.0 | 0.0 | 480 |
| mra_d4_J5 | raw | D4 | 24.1 | 0.0 | 480 |
| mra_d4_J5 | raw | D5 | 50.6 | 14.4 | 480 |
| mra_d4_J5 | raw | S5 | 682.7 | 365.7 | 480 |
| mra_d4_J8 | log | D1 | 3.0 | 0.7 | 480 |
| mra_d4_J8 | log | D2 | 6.0 | 1.9 | 480 |
| mra_d4_J8 | log | D3 | 12.0 | 0.0 | 480 |
| mra_d4_J8 | log | D4 | 24.1 | 0.0 | 480 |
| mra_d4_J8 | log | D5 | 48.9 | 12.1 | 480 |
| mra_d4_J8 | log | D6 | 93.1 | 25.8 | 480 |
| mra_d4_J8 | log | D7 | 186.2 | 56.9 | 480 |
| mra_d4_J8 | log | D8 | 341.3 | 68.3 | 480 |
| mra_d4_J8 | log | S8 | 1024.0 | 426.7 | 480 |
| mra_d4_J8 | raw | D1 | 2.7 | 0.7 | 480 |
| mra_d4_J8 | raw | D2 | 6.0 | 1.3 | 480 |
| mra_d4_J8 | raw | D3 | 12.0 | 0.0 | 480 |
| mra_d4_J8 | raw | D4 | 24.1 | 0.0 | 480 |
| mra_d4_J8 | raw | D5 | 50.6 | 14.4 | 480 |
| mra_d4_J8 | raw | D6 | 95.3 | 18.8 | 480 |
| mra_d4_J8 | raw | D7 | 186.2 | 34.1 | 480 |
| mra_d4_J8 | raw | D8 | 341.3 | 68.3 | 480 |
| mra_d4_J8 | raw | S8 | 1024.0 | 341.3 | 480 |
| mra_haar_J5 | log | D1 | 2.9 | 1.2 | 480 |
| mra_haar_J5 | log | D2 | 8.0 | 4.0 | 480 |
| mra_haar_J5 | log | D3 | 12.0 | 6.7 | 480 |
| mra_haar_J5 | log | D4 | 24.1 | 0.0 | 480 |
| mra_haar_J5 | log | D5 | 47.9 | 21.8 | 480 |
| mra_haar_J5 | log | S5 | 597.3 | 221.9 | 480 |
| mra_haar_J5 | raw | D1 | 2.7 | 1.2 | 480 |
| mra_haar_J5 | raw | D2 | 10.0 | 3.4 | 480 |
| mra_haar_J5 | raw | D3 | 12.0 | 7.6 | 480 |
| mra_haar_J5 | raw | D4 | 24.1 | 0.0 | 480 |
| mra_haar_J5 | raw | D5 | 47.2 | 14.0 | 480 |
| mra_haar_J5 | raw | S5 | 682.7 | 307.2 | 480 |
| mra_haar_J9 | log | D1 | 2.9 | 1.2 | 480 |
| mra_haar_J9 | log | D2 | 8.0 | 4.0 | 480 |
| mra_haar_J9 | log | D3 | 12.0 | 6.7 | 480 |
| mra_haar_J9 | log | D4 | 24.1 | 0.0 | 480 |
| mra_haar_J9 | log | D5 | 47.9 | 21.8 | 480 |
| mra_haar_J9 | log | D6 | 97.7 | 40.5 | 480 |
| mra_haar_J9 | log | D7 | 227.6 | 66.9 | 480 |
| mra_haar_J9 | log | D8 | 341.3 | 68.3 | 480 |
| mra_haar_J9 | log | D9 | 682.7 | 341.3 | 480 |
| mra_haar_J9 | log | S9 | 2048.0 | 1024.0 | 480 |
| mra_haar_J9 | raw | D1 | 2.7 | 1.2 | 480 |
| mra_haar_J9 | raw | D2 | 10.0 | 3.4 | 480 |
| mra_haar_J9 | raw | D3 | 12.0 | 7.6 | 480 |
| mra_haar_J9 | raw | D4 | 24.1 | 0.0 | 480 |
| mra_haar_J9 | raw | D5 | 47.2 | 14.0 | 480 |
| mra_haar_J9 | raw | D6 | 102.4 | 24.0 | 480 |
| mra_haar_J9 | raw | D7 | 217.2 | 70.6 | 480 |
| mra_haar_J9 | raw | D8 | 341.3 | 68.3 | 480 |
| mra_haar_J9 | raw | D9 | 682.7 | 85.3 | 480 |
| mra_haar_J9 | raw | S9 | 2048.0 | 1024.0 | 480 |
| mra_la8_J5 | log | D1 | 3.0 | 0.6 | 480 |
| mra_la8_J5 | log | D2 | 6.0 | 0.8 | 480 |
| mra_la8_J5 | log | D3 | 12.0 | 0.0 | 480 |
| mra_la8_J5 | log | D4 | 24.1 | 0.0 | 480 |
| mra_la8_J5 | log | D5 | 46.5 | 8.6 | 480 |
| mra_la8_J5 | log | S5 | 554.7 | 273.1 | 480 |
| mra_la8_J5 | raw | D1 | 3.0 | 0.5 | 480 |
| mra_la8_J5 | raw | D2 | 6.0 | 0.5 | 480 |
| mra_la8_J5 | raw | D3 | 12.0 | 0.0 | 480 |
| mra_la8_J5 | raw | D4 | 24.1 | 0.0 | 480 |
| mra_la8_J5 | raw | D5 | 48.8 | 11.6 | 480 |
| mra_la8_J5 | raw | S5 | 682.7 | 365.7 | 480 |
| mra_la8_J8 | log | D1 | 3.0 | 0.6 | 480 |
| mra_la8_J8 | log | D2 | 6.0 | 0.8 | 480 |
| mra_la8_J8 | log | D3 | 12.0 | 0.0 | 480 |
| mra_la8_J8 | log | D4 | 24.1 | 0.0 | 480 |
| mra_la8_J8 | log | D5 | 46.5 | 8.6 | 480 |
| mra_la8_J8 | log | D6 | 95.3 | 22.4 | 480 |
| mra_la8_J8 | log | D7 | 186.2 | 40.6 | 480 |
| mra_la8_J8 | log | D8 | 341.3 | 68.3 | 480 |
| mra_la8_J8 | log | S8 | 1024.0 | 426.7 | 480 |
| mra_la8_J8 | raw | D1 | 3.0 | 0.5 | 480 |
| mra_la8_J8 | raw | D2 | 6.0 | 0.5 | 480 |
| mra_la8_J8 | raw | D3 | 12.0 | 0.0 | 480 |
| mra_la8_J8 | raw | D4 | 24.1 | 0.0 | 480 |
| mra_la8_J8 | raw | D5 | 48.8 | 11.6 | 480 |
| mra_la8_J8 | raw | D6 | 97.5 | 13.7 | 480 |
| mra_la8_J8 | raw | D7 | 170.7 | 34.1 | 480 |
| mra_la8_J8 | raw | D8 | 341.3 | 68.3 | 480 |
| mra_la8_J8 | raw | S8 | 682.7 | 341.3 | 480 |
| mstl | log | REM | 128.0 | 69.0 | 480 |
| mstl | log | SEAS168 | 170.7 | 29.5 | 480 |
| mstl | log | SEAS24 | 24.1 | 0.0 | 480 |
| mstl | log | TREND | 682.7 | 426.7 | 480 |
| mstl | raw | REM | 128.5 | 80.8 | 480 |
| mstl | raw | SEAS168 | 170.7 | 49.9 | 480 |
| mstl | raw | SEAS24 | 24.1 | 0.0 | 480 |
| mstl | raw | TREND | 682.7 | 341.3 | 480 |

