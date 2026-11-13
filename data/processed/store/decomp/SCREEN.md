# Decomposition quick screen

Relative MAE vs F0 (lags only). Geometric mean across station × pollutant.
 Train: t+h < screen_start. Origins: daily 23:00 IST in the screen window.

## Ranking (pooled relative MAE)

### h = 1

| rank | method | scale | validity | rel_MAE | CI |
|---|---|---|---|---|---|
| 1 | coef_haar_J10 | log | basic | 0.639 | [0.505, 0.779] |
| 2 | coef_haar_J10 | log | strict | 0.639 | [0.505, 0.779] |
| 3 | coef_haar_J10 | raw | basic | 0.649 | [0.511, 0.789] |
| 4 | coef_haar_J10 | raw | strict | 0.649 | [0.511, 0.789] |
| 5 | mstl | log | basic | 0.667 | [0.568, 0.778] |
| 6 | mstl | log | strict | 0.667 | [0.568, 0.778] |
| 7 | mstl | raw | basic | 0.683 | [0.575, 0.803] |
| 8 | mstl | raw | strict | 0.683 | [0.575, 0.803] |
| 9 | mra_d4_J5 | log | basic | 0.684 | [0.563, 0.825] |
| 10 | mra_d4_J5 | log | strict | 0.684 | [0.563, 0.825] |
| 11 | mra_d4_J5 | raw | basic | 0.687 | [0.569, 0.823] |
| 12 | mra_d4_J5 | raw | strict | 0.687 | [0.569, 0.823] |
| 13 | mra_d4_J8 | log | basic | 0.689 | [0.563, 0.836] |
| 14 | mra_d4_J8 | log | strict | 0.689 | [0.563, 0.836] |
| 15 | mra_la8_J5 | log | basic | 0.690 | [0.568, 0.826] |
| 16 | mra_la8_J5 | log | strict | 0.690 | [0.568, 0.826] |
| 17 | mra_haar_J5 | log | basic | 0.693 | [0.570, 0.834] |
| 18 | mra_haar_J5 | log | strict | 0.693 | [0.570, 0.834] |
| 19 | mra_haar_J5 | raw | basic | 0.693 | [0.574, 0.833] |
| 20 | mra_haar_J5 | raw | strict | 0.693 | [0.574, 0.833] |
| 21 | mra_haar_J9 | log | basic | 0.694 | [0.564, 0.837] |
| 22 | mra_haar_J9 | log | strict | 0.694 | [0.564, 0.837] |
| 23 | mra_la8_J5 | raw | basic | 0.701 | [0.578, 0.841] |
| 24 | mra_la8_J5 | raw | strict | 0.701 | [0.578, 0.841] |
| 25 | mra_la8_J8 | log | basic | 0.713 | [0.579, 0.874] |
| 26 | mra_la8_J8 | log | strict | 0.713 | [0.579, 0.874] |
| 27 | mra_d4_J8 | raw | basic | 0.713 | [0.583, 0.867] |
| 28 | mra_d4_J8 | raw | strict | 0.713 | [0.583, 0.867] |
| 29 | mra_haar_J9 | raw | basic | 0.723 | [0.599, 0.863] |
| 30 | mra_haar_J9 | raw | strict | 0.723 | [0.599, 0.863] |
| 31 | mra_la8_J8 | raw | basic | 0.724 | [0.590, 0.876] |
| 32 | mra_la8_J8 | raw | strict | 0.724 | [0.590, 0.876] |

### h = 6

| rank | method | scale | validity | rel_MAE | CI |
|---|---|---|---|---|---|
| 1 | mstl | raw | basic | 1.033 | [0.962, 1.110] |
| 2 | mstl | raw | strict | 1.033 | [0.962, 1.110] |
| 3 | mstl | log | basic | 1.044 | [0.973, 1.125] |
| 4 | mstl | log | strict | 1.044 | [0.973, 1.125] |
| 5 | mra_la8_J5 | raw | basic | 1.073 | [0.998, 1.189] |
| 6 | mra_la8_J5 | raw | strict | 1.073 | [0.998, 1.189] |
| 7 | mra_haar_J5 | log | basic | 1.081 | [1.011, 1.187] |
| 8 | mra_haar_J5 | log | strict | 1.081 | [1.011, 1.187] |
| 9 | mra_d4_J5 | raw | basic | 1.093 | [1.003, 1.205] |
| 10 | mra_d4_J5 | raw | strict | 1.093 | [1.003, 1.205] |
| 11 | mra_d4_J5 | log | basic | 1.096 | [1.022, 1.208] |
| 12 | mra_d4_J5 | log | strict | 1.096 | [1.022, 1.208] |
| 13 | mra_haar_J5 | raw | basic | 1.097 | [1.016, 1.217] |
| 14 | mra_haar_J5 | raw | strict | 1.097 | [1.016, 1.217] |
| 15 | mra_la8_J5 | log | basic | 1.105 | [1.034, 1.217] |
| 16 | mra_la8_J5 | log | strict | 1.105 | [1.034, 1.217] |
| 17 | coef_haar_J10 | raw | basic | 1.109 | [1.008, 1.231] |
| 18 | coef_haar_J10 | raw | strict | 1.109 | [1.008, 1.231] |
| 19 | mra_d4_J8 | log | basic | 1.122 | [1.038, 1.257] |
| 20 | mra_d4_J8 | log | strict | 1.122 | [1.038, 1.257] |
| 21 | coef_haar_J10 | log | basic | 1.126 | [1.012, 1.275] |
| 22 | coef_haar_J10 | log | strict | 1.126 | [1.012, 1.275] |
| 23 | mra_d4_J8 | raw | basic | 1.131 | [1.032, 1.280] |
| 24 | mra_d4_J8 | raw | strict | 1.131 | [1.032, 1.280] |
| 25 | mra_la8_J8 | raw | basic | 1.140 | [1.051, 1.289] |
| 26 | mra_la8_J8 | raw | strict | 1.140 | [1.051, 1.289] |
| 27 | mra_la8_J8 | log | basic | 1.141 | [1.052, 1.297] |
| 28 | mra_la8_J8 | log | strict | 1.141 | [1.052, 1.297] |
| 29 | mra_haar_J9 | raw | basic | 1.153 | [1.048, 1.310] |
| 30 | mra_haar_J9 | raw | strict | 1.153 | [1.048, 1.310] |
| 31 | mra_haar_J9 | log | basic | 1.167 | [1.055, 1.329] |
| 32 | mra_haar_J9 | log | strict | 1.167 | [1.055, 1.329] |

### h = 24

| rank | method | scale | validity | rel_MAE | CI |
|---|---|---|---|---|---|
| 1 | mstl | log | basic | 0.970 | [0.865, 1.107] |
| 2 | mstl | log | strict | 0.970 | [0.865, 1.107] |
| 3 | mstl | raw | basic | 0.984 | [0.885, 1.121] |
| 4 | mstl | raw | strict | 0.984 | [0.885, 1.121] |
| 5 | mra_d4_J8 | log | basic | 1.080 | [0.972, 1.251] |
| 6 | mra_d4_J8 | log | strict | 1.080 | [0.972, 1.251] |
| 7 | mra_la8_J8 | log | basic | 1.086 | [0.979, 1.260] |
| 8 | mra_la8_J8 | log | strict | 1.086 | [0.979, 1.260] |
| 9 | mra_la8_J8 | raw | basic | 1.121 | [1.003, 1.322] |
| 10 | mra_la8_J8 | raw | strict | 1.121 | [1.003, 1.322] |
| 11 | mra_d4_J5 | log | basic | 1.134 | [1.040, 1.264] |
| 12 | mra_d4_J5 | log | strict | 1.134 | [1.040, 1.264] |
| 13 | mra_haar_J9 | raw | basic | 1.137 | [1.003, 1.358] |
| 14 | mra_haar_J9 | raw | strict | 1.137 | [1.003, 1.358] |
| 15 | mra_la8_J5 | log | basic | 1.137 | [1.047, 1.257] |
| 16 | mra_la8_J5 | log | strict | 1.137 | [1.047, 1.257] |
| 17 | mra_la8_J5 | raw | basic | 1.147 | [1.037, 1.309] |
| 18 | mra_la8_J5 | raw | strict | 1.147 | [1.037, 1.309] |
| 19 | mra_haar_J5 | log | basic | 1.147 | [1.053, 1.280] |
| 20 | mra_haar_J5 | log | strict | 1.147 | [1.053, 1.280] |
| 21 | mra_d4_J8 | raw | basic | 1.165 | [1.031, 1.388] |
| 22 | mra_d4_J8 | raw | strict | 1.165 | [1.031, 1.388] |
| 23 | mra_haar_J9 | log | basic | 1.169 | [1.019, 1.413] |
| 24 | mra_haar_J9 | log | strict | 1.169 | [1.019, 1.413] |
| 25 | mra_d4_J5 | raw | basic | 1.183 | [1.069, 1.339] |
| 26 | mra_d4_J5 | raw | strict | 1.183 | [1.069, 1.339] |
| 27 | mra_haar_J5 | raw | basic | 1.206 | [1.088, 1.385] |
| 28 | mra_haar_J5 | raw | strict | 1.206 | [1.088, 1.385] |
| 29 | coef_haar_J10 | log | basic | 1.242 | [1.070, 1.495] |
| 30 | coef_haar_J10 | log | strict | 1.242 | [1.070, 1.495] |
| 31 | coef_haar_J10 | raw | basic | 1.251 | [1.095, 1.491] |
| 32 | coef_haar_J10 | raw | strict | 1.251 | [1.095, 1.491] |

### h = 72

| rank | method | scale | validity | rel_MAE | CI |
|---|---|---|---|---|---|
| 1 | mstl | log | basic | 1.071 | [0.947, 1.235] |
| 2 | mstl | log | strict | 1.071 | [0.947, 1.235] |
| 3 | mstl | raw | basic | 1.084 | [0.967, 1.235] |
| 4 | mstl | raw | strict | 1.084 | [0.967, 1.235] |
| 5 | mra_la8_J8 | log | basic | 1.185 | [1.046, 1.398] |
| 6 | mra_la8_J8 | log | strict | 1.185 | [1.046, 1.398] |
| 7 | mra_d4_J8 | log | basic | 1.210 | [1.059, 1.422] |
| 8 | mra_d4_J8 | log | strict | 1.210 | [1.059, 1.422] |
| 9 | mra_la8_J5 | log | basic | 1.230 | [1.086, 1.425] |
| 10 | mra_la8_J5 | log | strict | 1.230 | [1.086, 1.425] |
| 11 | mra_haar_J9 | log | basic | 1.247 | [1.075, 1.479] |
| 12 | mra_haar_J9 | log | strict | 1.247 | [1.075, 1.479] |
| 13 | mra_la8_J8 | raw | basic | 1.255 | [1.091, 1.483] |
| 14 | mra_la8_J8 | raw | strict | 1.255 | [1.091, 1.483] |
| 15 | mra_d4_J5 | log | basic | 1.272 | [1.128, 1.475] |
| 16 | mra_d4_J5 | log | strict | 1.272 | [1.128, 1.475] |
| 17 | mra_haar_J5 | log | basic | 1.290 | [1.154, 1.497] |
| 18 | mra_haar_J5 | log | strict | 1.290 | [1.154, 1.497] |
| 19 | coef_haar_J10 | log | basic | 1.291 | [1.100, 1.604] |
| 20 | coef_haar_J10 | log | strict | 1.291 | [1.100, 1.604] |
| 21 | coef_haar_J10 | raw | basic | 1.296 | [1.110, 1.583] |
| 22 | coef_haar_J10 | raw | strict | 1.296 | [1.110, 1.583] |
| 23 | mra_d4_J5 | raw | basic | 1.314 | [1.168, 1.552] |
| 24 | mra_d4_J5 | raw | strict | 1.314 | [1.168, 1.552] |
| 25 | mra_d4_J8 | raw | basic | 1.323 | [1.152, 1.572] |
| 26 | mra_d4_J8 | raw | strict | 1.323 | [1.152, 1.572] |
| 27 | mra_la8_J5 | raw | basic | 1.323 | [1.168, 1.573] |
| 28 | mra_la8_J5 | raw | strict | 1.323 | [1.168, 1.573] |
| 29 | mra_haar_J9 | raw | basic | 1.329 | [1.154, 1.581] |
| 30 | mra_haar_J9 | raw | strict | 1.329 | [1.154, 1.581] |
| 31 | mra_haar_J5 | raw | basic | 1.358 | [1.195, 1.603] |
| 32 | mra_haar_J5 | raw | strict | 1.358 | [1.195, 1.603] |

### h = 168

| rank | method | scale | validity | rel_MAE | CI |
|---|---|---|---|---|---|
| 1 | mstl | log | basic | 1.056 | [0.981, 1.151] |
| 2 | mstl | log | strict | 1.056 | [0.981, 1.151] |
| 3 | mstl | raw | basic | 1.074 | [0.995, 1.175] |
| 4 | mstl | raw | strict | 1.074 | [0.995, 1.175] |
| 5 | mra_d4_J5 | log | basic | 1.176 | [1.046, 1.370] |
| 6 | mra_d4_J5 | log | strict | 1.176 | [1.046, 1.370] |
| 7 | mra_la8_J5 | log | basic | 1.186 | [1.053, 1.381] |
| 8 | mra_la8_J5 | log | strict | 1.186 | [1.053, 1.381] |
| 9 | mra_d4_J5 | raw | basic | 1.188 | [1.047, 1.398] |
| 10 | mra_d4_J5 | raw | strict | 1.188 | [1.047, 1.398] |
| 11 | mra_haar_J5 | log | basic | 1.190 | [1.051, 1.396] |
| 12 | mra_haar_J5 | log | strict | 1.190 | [1.051, 1.396] |
| 13 | mra_la8_J5 | raw | basic | 1.198 | [1.057, 1.420] |
| 14 | mra_la8_J5 | raw | strict | 1.198 | [1.057, 1.420] |
| 15 | mra_haar_J5 | raw | basic | 1.220 | [1.074, 1.451] |
| 16 | mra_haar_J5 | raw | strict | 1.220 | [1.074, 1.451] |
| 17 | mra_d4_J8 | log | basic | 1.260 | [1.071, 1.526] |
| 18 | mra_d4_J8 | log | strict | 1.260 | [1.071, 1.526] |
| 19 | mra_la8_J8 | log | basic | 1.262 | [1.074, 1.528] |
| 20 | mra_la8_J8 | log | strict | 1.262 | [1.074, 1.528] |
| 21 | mra_d4_J8 | raw | basic | 1.265 | [1.070, 1.545] |
| 22 | mra_d4_J8 | raw | strict | 1.265 | [1.070, 1.545] |
| 23 | mra_la8_J8 | raw | basic | 1.270 | [1.097, 1.545] |
| 24 | mra_la8_J8 | raw | strict | 1.270 | [1.097, 1.545] |
| 25 | coef_haar_J10 | log | basic | 1.271 | [1.126, 1.551] |
| 26 | coef_haar_J10 | log | strict | 1.271 | [1.126, 1.551] |
| 27 | mra_haar_J9 | raw | basic | 1.285 | [1.087, 1.588] |
| 28 | mra_haar_J9 | raw | strict | 1.285 | [1.087, 1.588] |
| 29 | mra_haar_J9 | log | basic | 1.293 | [1.106, 1.581] |
| 30 | mra_haar_J9 | log | strict | 1.293 | [1.106, 1.581] |
| 31 | coef_haar_J10 | raw | basic | 1.299 | [1.116, 1.624] |
| 32 | coef_haar_J10 | raw | strict | 1.299 | [1.116, 1.624] |

## CI entirely below 1 (beats F0)

| method | scale | validity | h | rel_MAE |
|---|---|---|---|---|
| coef_haar_J10 | log | basic | 1 | 0.639 |
| coef_haar_J10 | log | strict | 1 | 0.639 |
| coef_haar_J10 | raw | basic | 1 | 0.649 |
| coef_haar_J10 | raw | strict | 1 | 0.649 |
| mra_d4_J5 | log | basic | 1 | 0.684 |
| mra_d4_J5 | log | strict | 1 | 0.684 |
| mra_d4_J5 | raw | basic | 1 | 0.687 |
| mra_d4_J5 | raw | strict | 1 | 0.687 |
| mra_d4_J8 | log | basic | 1 | 0.689 |
| mra_d4_J8 | log | strict | 1 | 0.689 |
| mra_d4_J8 | raw | basic | 1 | 0.713 |
| mra_d4_J8 | raw | strict | 1 | 0.713 |
| mra_haar_J5 | log | basic | 1 | 0.693 |
| mra_haar_J5 | log | strict | 1 | 0.693 |
| mra_haar_J5 | raw | basic | 1 | 0.693 |
| mra_haar_J5 | raw | strict | 1 | 0.693 |
| mra_haar_J9 | log | basic | 1 | 0.694 |
| mra_haar_J9 | log | strict | 1 | 0.694 |
| mra_haar_J9 | raw | basic | 1 | 0.723 |
| mra_haar_J9 | raw | strict | 1 | 0.723 |
| mra_la8_J5 | log | basic | 1 | 0.690 |
| mra_la8_J5 | log | strict | 1 | 0.690 |
| mra_la8_J5 | raw | basic | 1 | 0.701 |
| mra_la8_J5 | raw | strict | 1 | 0.701 |
| mra_la8_J8 | log | basic | 1 | 0.713 |
| mra_la8_J8 | log | strict | 1 | 0.713 |
| mra_la8_J8 | raw | basic | 1 | 0.724 |
| mra_la8_J8 | raw | strict | 1 | 0.724 |
| mstl | log | basic | 1 | 0.667 |
| mstl | log | strict | 1 | 0.667 |
| mstl | raw | basic | 1 | 0.683 |
| mstl | raw | strict | 1 | 0.683 |

## Basic vs strict (median rel_MAE)

- basic: 1.053
- strict: 1.053

## Raw vs log (median rel_MAE)

- log: 1.047
- raw: 1.055

## Shortlist

Configs that beat F0 at one or more horizons, plus the best of each family.

| method | scale | validity | family | why |
|---|---|---|---|---|
| coef_haar_J10 | log | basic | wavelet_coef | beats F0 |
| coef_haar_J10 | log | strict | wavelet_coef | beats F0 |
| coef_haar_J10 | raw | basic | wavelet_coef | beats F0 |
| coef_haar_J10 | raw | strict | wavelet_coef | beats F0 |
| mra_d4_J5 | log | basic | MRA | beats F0 |
| mra_d4_J5 | log | strict | MRA | beats F0 |
| mra_d4_J5 | raw | basic | MRA | beats F0 |
| mra_d4_J5 | raw | strict | MRA | beats F0 |
| mra_d4_J8 | log | basic | MRA | beats F0 |
| mra_d4_J8 | log | strict | MRA | beats F0 |
| mra_d4_J8 | raw | basic | MRA | beats F0 |
| mra_d4_J8 | raw | strict | MRA | beats F0 |
| mra_haar_J5 | log | basic | MRA | beats F0 |
| mra_haar_J5 | log | strict | MRA | beats F0 |
| mra_haar_J5 | raw | basic | MRA | beats F0 |
| mra_haar_J5 | raw | strict | MRA | beats F0 |
| mra_haar_J9 | log | basic | MRA | beats F0 |
| mra_haar_J9 | log | strict | MRA | beats F0 |
| mra_haar_J9 | raw | basic | MRA | beats F0 |
| mra_haar_J9 | raw | strict | MRA | beats F0 |
| mra_la8_J5 | log | basic | MRA | beats F0 |
| mra_la8_J5 | log | strict | MRA | beats F0 |
| mra_la8_J5 | raw | basic | MRA | beats F0 |
| mra_la8_J5 | raw | strict | MRA | beats F0 |
| mra_la8_J8 | log | basic | MRA | beats F0 |
| mra_la8_J8 | log | strict | MRA | beats F0 |
| mra_la8_J8 | raw | basic | MRA | beats F0 |
| mra_la8_J8 | raw | strict | MRA | beats F0 |
| mstl | log | basic | MSTL | beats F0 |
| mstl | log | strict | MSTL | beats F0 |
| mstl | raw | basic | MSTL | beats F0 |
| mstl | raw | strict | MSTL | beats F0 |
| mra_d4_J5 | log | basic | MRA | best of family |
| mstl | log | basic | MSTL | best of family |
| coef_haar_J10 | log | basic | wavelet_coef | best of family |
