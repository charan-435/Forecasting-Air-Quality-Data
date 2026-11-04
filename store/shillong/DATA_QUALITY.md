# Data quality (tables only, no plots)

Hour **t** is the mean of readings in **(t − 1h, t]** (end-labelled, IST).
Paper sources skip quality/imputation (`skip_preprocess: true`).

Duplicate raw timestamps averaged: 0

## Period and missing share

| station | variable | start | end | n | pct_masked |
|---|---|---|---|---|---|
| JN_Stadium | AT | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 66.96 |
| JN_Stadium | CO | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 63.07 |
| JN_Stadium | NO2 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 63.49 |
| JN_Stadium | O3 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 79.82 |
| JN_Stadium | PM10 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 66.37 |
| JN_Stadium | PM2.5 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 68.06 |
| JN_Stadium | RH | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 66.96 |
| JN_Stadium | SO2 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 63.47 |
| Lumpyngngad | AT | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 100.00 |
| Lumpyngngad | CO | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 6.19 |
| Lumpyngngad | NO2 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 26.07 |
| Lumpyngngad | O3 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 6.95 |
| Lumpyngngad | PM10 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 49.04 |
| Lumpyngngad | PM2.5 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 22.32 |
| Lumpyngngad | RH | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 6.37 |
| Lumpyngngad | SO2 | 2023-01-01 01:00 | 2024-01-01 00:00 | 8760 | 6.37 |

## Missingness by month (%)

| station | variable | month | n | pct_masked |
|---|---|---|---|---|
| JN_Stadium | AT | 2023-01 | 743 | 100.0 |
| JN_Stadium | AT | 2023-02 | 672 | 100.0 |
| JN_Stadium | AT | 2023-03 | 744 | 100.0 |
| JN_Stadium | AT | 2023-04 | 720 | 100.0 |
| JN_Stadium | AT | 2023-05 | 744 | 100.0 |
| JN_Stadium | AT | 2023-06 | 720 | 100.0 |
| JN_Stadium | AT | 2023-07 | 744 | 82.7 |
| JN_Stadium | AT | 2023-08 | 744 | 30.9 |
| JN_Stadium | AT | 2023-09 | 720 | 14.0 |
| JN_Stadium | AT | 2023-10 | 744 | 25.9 |
| JN_Stadium | AT | 2023-11 | 720 | 30.4 |
| JN_Stadium | AT | 2023-12 | 744 | 22.0 |
| JN_Stadium | AT | 2024-01 | 1 | 100.0 |
| JN_Stadium | CO | 2023-01 | 743 | 100.0 |
| JN_Stadium | CO | 2023-02 | 672 | 100.0 |
| JN_Stadium | CO | 2023-03 | 744 | 100.0 |
| JN_Stadium | CO | 2023-04 | 720 | 100.0 |
| JN_Stadium | CO | 2023-05 | 744 | 100.0 |
| JN_Stadium | CO | 2023-06 | 720 | 100.0 |
| JN_Stadium | CO | 2023-07 | 744 | 82.7 |
| JN_Stadium | CO | 2023-08 | 744 | 9.0 |
| JN_Stadium | CO | 2023-09 | 720 | 14.0 |
| JN_Stadium | CO | 2023-10 | 744 | 25.9 |
| JN_Stadium | CO | 2023-11 | 720 | 10.6 |
| JN_Stadium | CO | 2023-12 | 744 | 17.5 |
| JN_Stadium | CO | 2024-01 | 1 | 0.0 |
| JN_Stadium | NO2 | 2023-01 | 743 | 100.0 |
| JN_Stadium | NO2 | 2023-02 | 672 | 100.0 |
| JN_Stadium | NO2 | 2023-03 | 744 | 100.0 |
| JN_Stadium | NO2 | 2023-04 | 720 | 100.0 |
| JN_Stadium | NO2 | 2023-05 | 744 | 100.0 |
| JN_Stadium | NO2 | 2023-06 | 720 | 100.0 |
| JN_Stadium | NO2 | 2023-07 | 744 | 82.7 |
| JN_Stadium | NO2 | 2023-08 | 744 | 9.0 |
| JN_Stadium | NO2 | 2023-09 | 720 | 14.0 |
| JN_Stadium | NO2 | 2023-10 | 744 | 25.9 |
| JN_Stadium | NO2 | 2023-11 | 720 | 10.6 |
| JN_Stadium | NO2 | 2023-12 | 744 | 22.3 |
| JN_Stadium | NO2 | 2024-01 | 1 | 100.0 |
| JN_Stadium | O3 | 2023-01 | 743 | 100.0 |
| JN_Stadium | O3 | 2023-02 | 672 | 100.0 |
| JN_Stadium | O3 | 2023-03 | 744 | 100.0 |
| JN_Stadium | O3 | 2023-04 | 720 | 100.0 |
| JN_Stadium | O3 | 2023-05 | 744 | 100.0 |
| JN_Stadium | O3 | 2023-06 | 720 | 100.0 |
| JN_Stadium | O3 | 2023-07 | 744 | 82.9 |
| JN_Stadium | O3 | 2023-08 | 744 | 60.8 |
| JN_Stadium | O3 | 2023-09 | 720 | 49.0 |
| JN_Stadium | O3 | 2023-10 | 744 | 56.5 |
| JN_Stadium | O3 | 2023-11 | 720 | 59.0 |
| JN_Stadium | O3 | 2023-12 | 744 | 51.2 |
| JN_Stadium | O3 | 2024-01 | 1 | 100.0 |
| JN_Stadium | PM10 | 2023-01 | 743 | 100.0 |
| JN_Stadium | PM10 | 2023-02 | 672 | 100.0 |
| JN_Stadium | PM10 | 2023-03 | 744 | 100.0 |
| JN_Stadium | PM10 | 2023-04 | 720 | 100.0 |
| JN_Stadium | PM10 | 2023-05 | 744 | 100.0 |
| JN_Stadium | PM10 | 2023-06 | 720 | 100.0 |
| JN_Stadium | PM10 | 2023-07 | 744 | 90.3 |
| JN_Stadium | PM10 | 2023-08 | 744 | 16.0 |
| JN_Stadium | PM10 | 2023-09 | 720 | 14.6 |
| JN_Stadium | PM10 | 2023-10 | 744 | 28.0 |
| JN_Stadium | PM10 | 2023-11 | 720 | 11.5 |
| JN_Stadium | PM10 | 2023-12 | 744 | 38.0 |
| JN_Stadium | PM10 | 2024-01 | 1 | 100.0 |
| JN_Stadium | PM2.5 | 2023-01 | 743 | 100.0 |
| JN_Stadium | PM2.5 | 2023-02 | 672 | 100.0 |
| JN_Stadium | PM2.5 | 2023-03 | 744 | 100.0 |
| JN_Stadium | PM2.5 | 2023-04 | 720 | 100.0 |
| JN_Stadium | PM2.5 | 2023-05 | 744 | 100.0 |
| JN_Stadium | PM2.5 | 2023-06 | 720 | 100.0 |
| JN_Stadium | PM2.5 | 2023-07 | 744 | 85.6 |
| JN_Stadium | PM2.5 | 2023-08 | 744 | 15.2 |
| JN_Stadium | PM2.5 | 2023-09 | 720 | 14.7 |
| JN_Stadium | PM2.5 | 2023-10 | 744 | 29.4 |
| JN_Stadium | PM2.5 | 2023-11 | 720 | 15.0 |
| JN_Stadium | PM2.5 | 2023-12 | 744 | 58.5 |
| JN_Stadium | PM2.5 | 2024-01 | 1 | 100.0 |
| JN_Stadium | RH | 2023-01 | 743 | 100.0 |
| JN_Stadium | RH | 2023-02 | 672 | 100.0 |
| JN_Stadium | RH | 2023-03 | 744 | 100.0 |
| JN_Stadium | RH | 2023-04 | 720 | 100.0 |
| JN_Stadium | RH | 2023-05 | 744 | 100.0 |
| JN_Stadium | RH | 2023-06 | 720 | 100.0 |
| JN_Stadium | RH | 2023-07 | 744 | 82.7 |
| JN_Stadium | RH | 2023-08 | 744 | 30.9 |
| JN_Stadium | RH | 2023-09 | 720 | 14.0 |
| JN_Stadium | RH | 2023-10 | 744 | 25.9 |
| JN_Stadium | RH | 2023-11 | 720 | 30.4 |
| JN_Stadium | RH | 2023-12 | 744 | 22.0 |
| JN_Stadium | RH | 2024-01 | 1 | 100.0 |
| JN_Stadium | SO2 | 2023-01 | 743 | 100.0 |
| JN_Stadium | SO2 | 2023-02 | 672 | 100.0 |
| JN_Stadium | SO2 | 2023-03 | 744 | 100.0 |
| JN_Stadium | SO2 | 2023-04 | 720 | 100.0 |
| JN_Stadium | SO2 | 2023-05 | 744 | 100.0 |
| JN_Stadium | SO2 | 2023-06 | 720 | 100.0 |
| JN_Stadium | SO2 | 2023-07 | 744 | 82.7 |
| JN_Stadium | SO2 | 2023-08 | 744 | 9.0 |
| JN_Stadium | SO2 | 2023-09 | 720 | 14.0 |
| JN_Stadium | SO2 | 2023-10 | 744 | 25.9 |
| JN_Stadium | SO2 | 2023-11 | 720 | 10.6 |
| JN_Stadium | SO2 | 2023-12 | 744 | 22.0 |
| JN_Stadium | SO2 | 2024-01 | 1 | 100.0 |
| Lumpyngngad | AT | 2023-01 | 743 | 100.0 |
| Lumpyngngad | AT | 2023-02 | 672 | 100.0 |
| Lumpyngngad | AT | 2023-03 | 744 | 100.0 |
| Lumpyngngad | AT | 2023-04 | 720 | 100.0 |
| Lumpyngngad | AT | 2023-05 | 744 | 100.0 |
| Lumpyngngad | AT | 2023-06 | 720 | 100.0 |
| Lumpyngngad | AT | 2023-07 | 744 | 100.0 |
| Lumpyngngad | AT | 2023-08 | 744 | 100.0 |
| Lumpyngngad | AT | 2023-09 | 720 | 100.0 |
| Lumpyngngad | AT | 2023-10 | 744 | 100.0 |
| Lumpyngngad | AT | 2023-11 | 720 | 100.0 |
| Lumpyngngad | AT | 2023-12 | 744 | 100.0 |
| Lumpyngngad | AT | 2024-01 | 1 | 100.0 |
| Lumpyngngad | CO | 2023-01 | 743 | 2.4 |
| Lumpyngngad | CO | 2023-02 | 672 | 1.5 |
| Lumpyngngad | CO | 2023-03 | 744 | 3.2 |
| Lumpyngngad | CO | 2023-04 | 720 | 14.4 |
| Lumpyngngad | CO | 2023-05 | 744 | 9.8 |
| Lumpyngngad | CO | 2023-06 | 720 | 13.1 |
| Lumpyngngad | CO | 2023-07 | 744 | 10.3 |
| Lumpyngngad | CO | 2023-08 | 744 | 2.0 |
| Lumpyngngad | CO | 2023-09 | 720 | 0.4 |
| Lumpyngngad | CO | 2023-10 | 744 | 15.9 |
| Lumpyngngad | CO | 2023-11 | 720 | 0.8 |
| Lumpyngngad | CO | 2023-12 | 744 | 0.0 |
| Lumpyngngad | CO | 2024-01 | 1 | 0.0 |
| Lumpyngngad | NO2 | 2023-01 | 743 | 100.0 |
| Lumpyngngad | NO2 | 2023-02 | 672 | 100.0 |
| Lumpyngngad | NO2 | 2023-03 | 744 | 46.8 |
| Lumpyngngad | NO2 | 2023-04 | 720 | 16.5 |
| Lumpyngngad | NO2 | 2023-05 | 744 | 9.9 |
| Lumpyngngad | NO2 | 2023-06 | 720 | 14.3 |
| Lumpyngngad | NO2 | 2023-07 | 744 | 10.9 |
| Lumpyngngad | NO2 | 2023-08 | 744 | 2.0 |
| Lumpyngngad | NO2 | 2023-09 | 720 | 0.7 |
| Lumpyngngad | NO2 | 2023-10 | 744 | 15.9 |
| Lumpyngngad | NO2 | 2023-11 | 720 | 0.8 |
| Lumpyngngad | NO2 | 2023-12 | 744 | 0.0 |
| Lumpyngngad | NO2 | 2024-01 | 1 | 0.0 |
| Lumpyngngad | O3 | 2023-01 | 743 | 2.4 |
| Lumpyngngad | O3 | 2023-02 | 672 | 4.6 |
| Lumpyngngad | O3 | 2023-03 | 744 | 3.2 |
| Lumpyngngad | O3 | 2023-04 | 720 | 16.5 |
| Lumpyngngad | O3 | 2023-05 | 744 | 9.9 |
| Lumpyngngad | O3 | 2023-06 | 720 | 14.4 |
| Lumpyngngad | O3 | 2023-07 | 744 | 11.0 |
| Lumpyngngad | O3 | 2023-08 | 744 | 2.7 |
| Lumpyngngad | O3 | 2023-09 | 720 | 1.7 |
| Lumpyngngad | O3 | 2023-10 | 744 | 16.0 |
| Lumpyngngad | O3 | 2023-11 | 720 | 0.8 |
| Lumpyngngad | O3 | 2023-12 | 744 | 0.0 |
| Lumpyngngad | O3 | 2024-01 | 1 | 0.0 |
| Lumpyngngad | PM10 | 2023-01 | 743 | 5.2 |
| Lumpyngngad | PM10 | 2023-02 | 672 | 22.9 |
| Lumpyngngad | PM10 | 2023-03 | 744 | 37.0 |
| Lumpyngngad | PM10 | 2023-04 | 720 | 28.2 |
| Lumpyngngad | PM10 | 2023-05 | 744 | 21.0 |
| Lumpyngngad | PM10 | 2023-06 | 720 | 48.3 |
| Lumpyngngad | PM10 | 2023-07 | 744 | 100.0 |
| Lumpyngngad | PM10 | 2023-08 | 744 | 100.0 |
| Lumpyngngad | PM10 | 2023-09 | 720 | 90.3 |
| Lumpyngngad | PM10 | 2023-10 | 744 | 91.0 |
| Lumpyngngad | PM10 | 2023-11 | 720 | 16.9 |
| Lumpyngngad | PM10 | 2023-12 | 744 | 24.6 |
| Lumpyngngad | PM10 | 2024-01 | 1 | 100.0 |
| Lumpyngngad | PM2.5 | 2023-01 | 743 | 5.5 |
| Lumpyngngad | PM2.5 | 2023-02 | 672 | 4.8 |
| Lumpyngngad | PM2.5 | 2023-03 | 744 | 26.2 |
| Lumpyngngad | PM2.5 | 2023-04 | 720 | 50.7 |
| Lumpyngngad | PM2.5 | 2023-05 | 744 | 53.4 |
| Lumpyngngad | PM2.5 | 2023-06 | 720 | 29.4 |
| Lumpyngngad | PM2.5 | 2023-07 | 744 | 17.5 |
| Lumpyngngad | PM2.5 | 2023-08 | 744 | 8.1 |
| Lumpyngngad | PM2.5 | 2023-09 | 720 | 14.6 |
| Lumpyngngad | PM2.5 | 2023-10 | 744 | 21.4 |
| Lumpyngngad | PM2.5 | 2023-11 | 720 | 25.8 |
| Lumpyngngad | PM2.5 | 2023-12 | 744 | 9.8 |
| Lumpyngngad | PM2.5 | 2024-01 | 1 | 0.0 |
| Lumpyngngad | RH | 2023-01 | 743 | 2.4 |
| Lumpyngngad | RH | 2023-02 | 672 | 1.5 |
| Lumpyngngad | RH | 2023-03 | 744 | 3.2 |
| Lumpyngngad | RH | 2023-04 | 720 | 14.6 |
| Lumpyngngad | RH | 2023-05 | 744 | 9.9 |
| Lumpyngngad | RH | 2023-06 | 720 | 14.3 |
| Lumpyngngad | RH | 2023-07 | 744 | 10.9 |
| Lumpyngngad | RH | 2023-08 | 744 | 2.0 |
| Lumpyngngad | RH | 2023-09 | 720 | 0.6 |
| Lumpyngngad | RH | 2023-10 | 744 | 15.9 |
| Lumpyngngad | RH | 2023-11 | 720 | 0.8 |
| Lumpyngngad | RH | 2023-12 | 744 | 0.0 |
| Lumpyngngad | RH | 2024-01 | 1 | 0.0 |
| Lumpyngngad | SO2 | 2023-01 | 743 | 2.4 |
| Lumpyngngad | SO2 | 2023-02 | 672 | 1.5 |
| Lumpyngngad | SO2 | 2023-03 | 744 | 3.2 |
| Lumpyngngad | SO2 | 2023-04 | 720 | 14.6 |
| Lumpyngngad | SO2 | 2023-05 | 744 | 9.9 |
| Lumpyngngad | SO2 | 2023-06 | 720 | 14.3 |
| Lumpyngngad | SO2 | 2023-07 | 744 | 10.9 |
| Lumpyngngad | SO2 | 2023-08 | 744 | 2.0 |
| Lumpyngngad | SO2 | 2023-09 | 720 | 0.6 |
| Lumpyngngad | SO2 | 2023-10 | 744 | 15.9 |
| Lumpyngngad | SO2 | 2023-11 | 720 | 0.8 |
| Lumpyngngad | SO2 | 2023-12 | 744 | 0.0 |
| Lumpyngngad | SO2 | 2024-01 | 1 | 0.0 |

## Missingness by hour-of-day (%)

| station | variable | h0 | h1 | h2 | h3 | h4 | h5 | h6 | h7 | h8 | h9 | h10 | h11 | h12 | h13 | h14 | h15 | h16 | h17 | h18 | h19 | h20 | h21 | h22 | h23 |
|---|---| ---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|--- |
| JN_Stadium | AT | 66.8 | 67.7 | 66.8 | 67.1 | 66.8 | 67.1 | 66.8 | 67.1 | 67.4 | 67.7 | 67.7 | 67.9 | 67.7 | 67.4 | 67.1 | 66.3 | 66.3 | 66.3 | 66.6 | 66.3 | 66.6 | 66.6 | 66.0 | 66.8 |
| JN_Stadium | CO | 62.5 | 64.1 | 63.0 | 63.6 | 63.0 | 63.3 | 63.3 | 63.6 | 63.6 | 63.8 | 63.3 | 63.8 | 63.6 | 63.6 | 63.6 | 62.7 | 62.5 | 62.5 | 62.2 | 62.2 | 62.5 | 62.2 | 62.5 | 63.0 |
| JN_Stadium | NO2 | 63.3 | 64.1 | 63.3 | 63.6 | 63.3 | 63.8 | 63.3 | 63.6 | 63.8 | 64.1 | 64.1 | 64.7 | 64.4 | 64.1 | 63.8 | 63.0 | 63.0 | 62.7 | 63.3 | 62.7 | 63.0 | 63.0 | 62.5 | 63.3 |
| JN_Stadium | O3 | 86.6 | 86.6 | 86.3 | 84.7 | 84.7 | 82.5 | 83.8 | 85.5 | 81.9 | 74.5 | 71.5 | 71.0 | 70.7 | 70.1 | 69.9 | 69.6 | 71.2 | 73.7 | 79.5 | 83.8 | 86.6 | 86.6 | 87.4 | 87.1 |
| JN_Stadium | PM10 | 66.0 | 65.8 | 66.3 | 66.0 | 67.9 | 67.1 | 67.1 | 66.6 | 66.8 | 67.1 | 67.1 | 67.4 | 66.8 | 66.3 | 66.8 | 66.8 | 66.0 | 66.0 | 65.5 | 65.5 | 65.5 | 65.5 | 65.5 | 65.2 |
| JN_Stadium | PM2.5 | 67.1 | 67.4 | 68.8 | 68.5 | 70.1 | 67.7 | 68.5 | 69.0 | 68.2 | 67.7 | 67.9 | 69.0 | 68.2 | 68.8 | 68.5 | 68.8 | 68.8 | 67.7 | 67.7 | 67.7 | 67.1 | 66.8 | 67.1 | 66.3 |
| JN_Stadium | RH | 66.8 | 67.7 | 66.8 | 67.1 | 66.8 | 67.1 | 66.8 | 67.1 | 67.4 | 67.7 | 67.7 | 67.9 | 67.7 | 67.4 | 67.1 | 66.3 | 66.3 | 66.3 | 66.6 | 66.3 | 66.6 | 66.6 | 66.0 | 66.8 |
| JN_Stadium | SO2 | 63.3 | 64.1 | 63.3 | 63.6 | 63.3 | 63.6 | 63.3 | 63.6 | 63.8 | 64.1 | 64.1 | 64.7 | 64.4 | 64.1 | 63.8 | 63.0 | 63.0 | 62.7 | 63.0 | 62.7 | 63.0 | 63.0 | 62.5 | 63.3 |
| Lumpyngngad | AT | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 |
| Lumpyngngad | CO | 2.2 | 2.5 | 6.6 | 26.6 | 29.0 | 27.1 | 4.7 | 4.4 | 4.1 | 3.8 | 3.8 | 4.1 | 3.3 | 3.3 | 3.0 | 3.0 | 2.2 | 2.2 | 2.2 | 1.9 | 1.9 | 2.2 | 2.2 | 2.2 |
| Lumpyngngad | NO2 | 22.2 | 22.7 | 26.3 | 46.3 | 49.3 | 47.1 | 25.5 | 24.1 | 23.6 | 23.6 | 23.3 | 23.6 | 22.7 | 22.7 | 23.0 | 23.3 | 21.9 | 21.9 | 22.2 | 21.9 | 21.9 | 22.2 | 22.2 | 22.2 |
| Lumpyngngad | O3 | 2.5 | 3.0 | 6.6 | 27.1 | 29.9 | 28.8 | 6.6 | 4.9 | 4.9 | 4.7 | 4.7 | 4.4 | 3.8 | 4.1 | 4.4 | 4.1 | 3.0 | 3.3 | 2.5 | 2.7 | 2.7 | 2.7 | 2.7 | 2.7 |
| Lumpyngngad | PM10 | 46.3 | 45.2 | 51.2 | 63.3 | 64.7 | 64.1 | 48.5 | 62.2 | 49.3 | 47.4 | 47.1 | 47.1 | 46.0 | 44.9 | 44.9 | 44.1 | 44.4 | 45.2 | 44.1 | 45.5 | 45.8 | 46.0 | 44.4 | 45.2 |
| Lumpyngngad | PM2.5 | 17.3 | 16.4 | 23.8 | 38.4 | 40.8 | 41.4 | 40.3 | 25.8 | 24.9 | 21.4 | 20.5 | 21.6 | 20.0 | 18.9 | 18.4 | 17.5 | 16.7 | 14.8 | 15.3 | 16.2 | 16.4 | 17.0 | 15.6 | 16.2 |
| Lumpyngngad | RH | 2.2 | 2.5 | 6.6 | 26.8 | 29.9 | 27.7 | 6.0 | 4.7 | 4.1 | 4.1 | 3.8 | 4.1 | 3.3 | 3.3 | 3.3 | 3.6 | 2.2 | 2.2 | 2.2 | 1.9 | 1.9 | 2.2 | 2.2 | 2.2 |
| Lumpyngngad | SO2 | 2.2 | 2.5 | 6.6 | 26.8 | 29.9 | 27.7 | 6.0 | 4.7 | 4.1 | 4.1 | 3.8 | 4.1 | 3.3 | 3.3 | 3.3 | 3.6 | 2.2 | 2.2 | 2.2 | 1.9 | 1.9 | 2.2 | 2.2 | 2.2 |

## Gap-length counts (report only; total length is not in the store)

| station | variable | bucket | n_gaps |
|---|---|---|---|
| JN_Stadium | AT | 1-3 | 16 |
| JN_Stadium | AT | 25-72 | 1 |
| JN_Stadium | AT | 4-24 | 5 |
| JN_Stadium | AT | >72 | 6 |
| JN_Stadium | CO | 1-3 | 15 |
| JN_Stadium | CO | 25-72 | 3 |
| JN_Stadium | CO | 4-24 | 2 |
| JN_Stadium | CO | >72 | 4 |
| JN_Stadium | NO2 | 1-3 | 16 |
| JN_Stadium | NO2 | 25-72 | 3 |
| JN_Stadium | NO2 | 4-24 | 7 |
| JN_Stadium | NO2 | >72 | 4 |
| JN_Stadium | O3 | 1-3 | 77 |
| JN_Stadium | O3 | 25-72 | 7 |
| JN_Stadium | O3 | 4-24 | 78 |
| JN_Stadium | O3 | >72 | 6 |
| JN_Stadium | PM10 | 1-3 | 49 |
| JN_Stadium | PM10 | 25-72 | 3 |
| JN_Stadium | PM10 | 4-24 | 2 |
| JN_Stadium | PM10 | >72 | 6 |
| JN_Stadium | PM2.5 | 1-3 | 54 |
| JN_Stadium | PM2.5 | 25-72 | 3 |
| JN_Stadium | PM2.5 | 4-24 | 27 |
| JN_Stadium | PM2.5 | >72 | 5 |
| JN_Stadium | RH | 1-3 | 16 |
| JN_Stadium | RH | 25-72 | 1 |
| JN_Stadium | RH | 4-24 | 5 |
| JN_Stadium | RH | >72 | 6 |
| JN_Stadium | SO2 | 1-3 | 16 |
| JN_Stadium | SO2 | 25-72 | 3 |
| JN_Stadium | SO2 | 4-24 | 6 |
| JN_Stadium | SO2 | >72 | 4 |
| Lumpyngngad | AT | >72 | 1 |
| Lumpyngngad | CO | 1-3 | 88 |
| Lumpyngngad | CO | 25-72 | 2 |
| Lumpyngngad | CO | 4-24 | 23 |
| Lumpyngngad | CO | >72 | 1 |
| Lumpyngngad | NO2 | 1-3 | 91 |
| Lumpyngngad | NO2 | 25-72 | 2 |
| Lumpyngngad | NO2 | 4-24 | 24 |
| Lumpyngngad | NO2 | >72 | 2 |
| Lumpyngngad | O3 | 1-3 | 121 |
| Lumpyngngad | O3 | 25-72 | 2 |
| Lumpyngngad | O3 | 4-24 | 28 |
| Lumpyngngad | O3 | >72 | 1 |
| Lumpyngngad | PM10 | 1-3 | 313 |
| Lumpyngngad | PM10 | 25-72 | 5 |
| Lumpyngngad | PM10 | 4-24 | 39 |
| Lumpyngngad | PM10 | >72 | 5 |
| Lumpyngngad | PM2.5 | 1-3 | 298 |
| Lumpyngngad | PM2.5 | 25-72 | 6 |
| Lumpyngngad | PM2.5 | 4-24 | 85 |
| Lumpyngngad | PM2.5 | >72 | 4 |
| Lumpyngngad | RH | 1-3 | 90 |
| Lumpyngngad | RH | 25-72 | 2 |
| Lumpyngngad | RH | 4-24 | 27 |
| Lumpyngngad | RH | >72 | 1 |
| Lumpyngngad | SO2 | 1-3 | 90 |
| Lumpyngngad | SO2 | 25-72 | 2 |
| Lumpyngngad | SO2 | 4-24 | 27 |
| Lumpyngngad | SO2 | >72 | 1 |

Station-wide missing hours: 6067 ; single-variable missing hours: 10240

## Flag counts

| station | variable | is_na_source | is_low_coverage | is_duplicate_ts | is_out_of_bounds | is_negative | is_stuck | is_pm_ratio | is_spike | is_masked |
|---|---| ---|---|---|---|---|---|---|---|--- |
| JN_Stadium | AT | 0 | 5866 | 0 | 0 | 0 | 0 | 0 | 10 | 5866 |
| JN_Stadium | CO | 0 | 5525 | 0 | 0 | 0 | 0 | 0 | 117 | 5525 |
| JN_Stadium | NO2 | 0 | 5562 | 0 | 0 | 0 | 0 | 0 | 13 | 5562 |
| JN_Stadium | O3 | 0 | 6992 | 0 | 0 | 0 | 0 | 0 | 43 | 6992 |
| JN_Stadium | PM10 | 0 | 5814 | 0 | 0 | 0 | 0 | 0 | 53 | 5814 |
| JN_Stadium | PM2.5 | 0 | 5962 | 0 | 0 | 0 | 0 | 0 | 38 | 5962 |
| JN_Stadium | RH | 0 | 5866 | 0 | 0 | 0 | 0 | 0 | 174 | 5866 |
| JN_Stadium | SO2 | 0 | 5560 | 0 | 0 | 0 | 0 | 0 | 52 | 5560 |
| Lumpyngngad | AT | 0 | 8760 | 0 | 0 | 0 | 0 | 0 | 0 | 8760 |
| Lumpyngngad | CO | 0 | 542 | 0 | 0 | 0 | 0 | 0 | 88 | 542 |
| Lumpyngngad | NO2 | 0 | 2284 | 0 | 0 | 0 | 0 | 0 | 3 | 2284 |
| Lumpyngngad | O3 | 0 | 609 | 0 | 0 | 0 | 0 | 0 | 27 | 609 |
| Lumpyngngad | PM10 | 0 | 4294 | 0 | 0 | 0 | 2 | 0 | 55 | 4296 |
| Lumpyngngad | PM2.5 | 0 | 1952 | 0 | 0 | 0 | 3 | 0 | 93 | 1955 |
| Lumpyngngad | RH | 0 | 558 | 0 | 0 | 0 | 0 | 0 | 170 | 558 |
| Lumpyngngad | SO2 | 0 | 558 | 0 | 0 | 0 | 0 | 0 | 128 | 558 |

## Spike flags by date

| station | variable | day | n_spike |
|---|---|---|---|
| JN_Stadium | AT | 2023-09-22 | 4 |
| JN_Stadium | AT | 2023-09-23 | 1 |
| JN_Stadium | AT | 2023-11-18 | 3 |
| JN_Stadium | AT | 2023-12-08 | 1 |
| JN_Stadium | AT | 2023-12-19 | 1 |
| JN_Stadium | CO | 2023-07-26 | 2 |
| JN_Stadium | CO | 2023-07-29 | 2 |
| JN_Stadium | CO | 2023-07-30 | 3 |
| JN_Stadium | CO | 2023-08-09 | 3 |
| JN_Stadium | CO | 2023-08-10 | 2 |
| JN_Stadium | CO | 2023-08-14 | 3 |
| JN_Stadium | CO | 2023-08-15 | 1 |
| JN_Stadium | CO | 2023-08-17 | 3 |
| JN_Stadium | CO | 2023-08-30 | 2 |
| JN_Stadium | CO | 2023-08-31 | 1 |
| JN_Stadium | CO | 2023-09-12 | 5 |
| JN_Stadium | CO | 2023-09-13 | 1 |
| JN_Stadium | CO | 2023-09-15 | 3 |
| JN_Stadium | CO | 2023-09-16 | 4 |
| JN_Stadium | CO | 2023-09-17 | 5 |
| JN_Stadium | CO | 2023-09-18 | 5 |
| JN_Stadium | CO | 2023-09-24 | 2 |
| JN_Stadium | CO | 2023-09-25 | 3 |
| JN_Stadium | CO | 2023-09-26 | 4 |
| JN_Stadium | CO | 2023-09-28 | 3 |
| JN_Stadium | CO | 2023-10-01 | 5 |
| JN_Stadium | CO | 2023-10-02 | 2 |
| JN_Stadium | CO | 2023-10-03 | 2 |
| JN_Stadium | CO | 2023-10-08 | 2 |
| JN_Stadium | CO | 2023-10-09 | 5 |
| JN_Stadium | CO | 2023-10-10 | 1 |
| JN_Stadium | CO | 2023-10-11 | 3 |
| JN_Stadium | CO | 2023-10-13 | 4 |
| JN_Stadium | CO | 2023-10-16 | 1 |
| JN_Stadium | CO | 2023-10-29 | 2 |
| JN_Stadium | CO | 2023-10-30 | 1 |
| JN_Stadium | CO | 2023-11-03 | 4 |
| JN_Stadium | CO | 2023-11-10 | 3 |
| JN_Stadium | CO | 2023-11-13 | 2 |
| JN_Stadium | CO | 2023-11-18 | 3 |
| JN_Stadium | CO | 2023-11-19 | 4 |
| JN_Stadium | CO | 2023-11-21 | 1 |
| JN_Stadium | CO | 2023-11-26 | 1 |
| JN_Stadium | CO | 2023-12-12 | 1 |
| JN_Stadium | CO | 2023-12-13 | 2 |
| JN_Stadium | CO | 2023-12-14 | 1 |
| JN_Stadium | CO | 2023-12-19 | 3 |
| JN_Stadium | CO | 2023-12-24 | 4 |
| JN_Stadium | CO | 2023-12-30 | 1 |
| JN_Stadium | CO | 2023-12-31 | 2 |
| JN_Stadium | NO2 | 2023-08-16 | 2 |
| JN_Stadium | NO2 | 2023-09-12 | 3 |
| JN_Stadium | NO2 | 2023-09-29 | 1 |
| JN_Stadium | NO2 | 2023-10-08 | 2 |
| JN_Stadium | NO2 | 2023-10-09 | 3 |
| JN_Stadium | NO2 | 2023-12-30 | 2 |
| JN_Stadium | O3 | 2023-07-28 | 3 |
| JN_Stadium | O3 | 2023-07-29 | 1 |
| JN_Stadium | O3 | 2023-08-02 | 5 |
| JN_Stadium | O3 | 2023-08-10 | 1 |
| JN_Stadium | O3 | 2023-09-30 | 3 |
| JN_Stadium | O3 | 2023-10-14 | 2 |
| JN_Stadium | O3 | 2023-10-28 | 2 |
| JN_Stadium | O3 | 2023-11-08 | 3 |
| JN_Stadium | O3 | 2023-11-09 | 2 |
| JN_Stadium | O3 | 2023-11-10 | 3 |
| JN_Stadium | O3 | 2023-12-05 | 1 |
| JN_Stadium | O3 | 2023-12-07 | 1 |
| JN_Stadium | O3 | 2023-12-11 | 7 |
| JN_Stadium | O3 | 2023-12-24 | 7 |
| JN_Stadium | O3 | 2023-12-30 | 2 |
| JN_Stadium | PM10 | 2023-07-29 | 2 |
| JN_Stadium | PM10 | 2023-07-30 | 1 |
| JN_Stadium | PM10 | 2023-08-03 | 2 |
| JN_Stadium | PM10 | 2023-08-09 | 2 |
| JN_Stadium | PM10 | 2023-08-10 | 1 |
| JN_Stadium | PM10 | 2023-08-11 | 1 |
| JN_Stadium | PM10 | 2023-08-14 | 1 |
| JN_Stadium | PM10 | 2023-08-15 | 3 |
| JN_Stadium | PM10 | 2023-08-16 | 3 |
| JN_Stadium | PM10 | 2023-08-22 | 1 |
| JN_Stadium | PM10 | 2023-09-12 | 1 |
| JN_Stadium | PM10 | 2023-09-18 | 5 |
| JN_Stadium | PM10 | 2023-09-30 | 1 |
| JN_Stadium | PM10 | 2023-10-01 | 2 |
| JN_Stadium | PM10 | 2023-10-03 | 1 |
| JN_Stadium | PM10 | 2023-10-05 | 3 |
| JN_Stadium | PM10 | 2023-10-06 | 1 |
| JN_Stadium | PM10 | 2023-10-09 | 1 |
| JN_Stadium | PM10 | 2023-10-10 | 1 |
| JN_Stadium | PM10 | 2023-10-26 | 1 |
| JN_Stadium | PM10 | 2023-10-27 | 1 |
| JN_Stadium | PM10 | 2023-10-28 | 1 |
| JN_Stadium | PM10 | 2023-10-29 | 2 |
| JN_Stadium | PM10 | 2023-11-12 | 1 |
| JN_Stadium | PM10 | 2023-11-13 | 1 |
| JN_Stadium | PM10 | 2023-11-18 | 8 |
| JN_Stadium | PM10 | 2023-12-09 | 4 |
| JN_Stadium | PM10 | 2023-12-21 | 1 |
| JN_Stadium | PM2.5 | 2023-07-29 | 1 |
| JN_Stadium | PM2.5 | 2023-07-30 | 1 |
| JN_Stadium | PM2.5 | 2023-08-05 | 1 |
| JN_Stadium | PM2.5 | 2023-08-14 | 1 |
| JN_Stadium | PM2.5 | 2023-09-04 | 3 |
| JN_Stadium | PM2.5 | 2023-09-06 | 3 |
| JN_Stadium | PM2.5 | 2023-09-12 | 2 |
| JN_Stadium | PM2.5 | 2023-09-18 | 1 |
| JN_Stadium | PM2.5 | 2023-09-21 | 1 |
| JN_Stadium | PM2.5 | 2023-09-24 | 1 |
| JN_Stadium | PM2.5 | 2023-09-30 | 1 |
| JN_Stadium | PM2.5 | 2023-10-27 | 1 |
| JN_Stadium | PM2.5 | 2023-10-28 | 1 |
| JN_Stadium | PM2.5 | 2023-10-29 | 2 |
| JN_Stadium | PM2.5 | 2023-11-10 | 1 |
| JN_Stadium | PM2.5 | 2023-11-12 | 4 |
| JN_Stadium | PM2.5 | 2023-11-13 | 4 |
| JN_Stadium | PM2.5 | 2023-11-16 | 2 |
| JN_Stadium | PM2.5 | 2023-11-18 | 1 |
| JN_Stadium | PM2.5 | 2023-11-21 | 1 |
| JN_Stadium | PM2.5 | 2023-12-05 | 1 |
| JN_Stadium | PM2.5 | 2023-12-09 | 1 |
| JN_Stadium | PM2.5 | 2023-12-24 | 2 |
| JN_Stadium | PM2.5 | 2023-12-25 | 1 |
| JN_Stadium | RH | 2023-08-17 | 4 |
| JN_Stadium | RH | 2023-08-23 | 1 |
| JN_Stadium | RH | 2023-09-13 | 7 |
| JN_Stadium | RH | 2023-09-22 | 5 |
| JN_Stadium | RH | 2023-09-27 | 2 |
| JN_Stadium | RH | 2023-09-28 | 4 |
| JN_Stadium | RH | 2023-10-11 | 5 |
| JN_Stadium | RH | 2023-10-12 | 2 |
| JN_Stadium | RH | 2023-10-14 | 6 |
| JN_Stadium | RH | 2023-10-15 | 6 |
| JN_Stadium | RH | 2023-10-17 | 8 |
| JN_Stadium | RH | 2023-10-27 | 7 |
| JN_Stadium | RH | 2023-10-29 | 2 |
| JN_Stadium | RH | 2023-10-30 | 6 |
| JN_Stadium | RH | 2023-11-07 | 4 |
| JN_Stadium | RH | 2023-11-16 | 5 |
| JN_Stadium | RH | 2023-11-18 | 9 |
| JN_Stadium | RH | 2023-11-20 | 3 |
| JN_Stadium | RH | 2023-11-23 | 3 |
| JN_Stadium | RH | 2023-11-24 | 6 |
| JN_Stadium | RH | 2023-11-25 | 8 |
| JN_Stadium | RH | 2023-11-27 | 3 |
| JN_Stadium | RH | 2023-11-28 | 8 |
| JN_Stadium | RH | 2023-12-01 | 7 |
| JN_Stadium | RH | 2023-12-02 | 2 |
| JN_Stadium | RH | 2023-12-03 | 8 |
| JN_Stadium | RH | 2023-12-04 | 2 |
| JN_Stadium | RH | 2023-12-06 | 3 |
| JN_Stadium | RH | 2023-12-08 | 4 |
| JN_Stadium | RH | 2023-12-09 | 5 |
| JN_Stadium | RH | 2023-12-10 | 4 |
| JN_Stadium | RH | 2023-12-19 | 1 |
| JN_Stadium | RH | 2023-12-20 | 5 |
| JN_Stadium | RH | 2023-12-21 | 7 |
| JN_Stadium | RH | 2023-12-22 | 4 |
| JN_Stadium | RH | 2023-12-26 | 4 |
| JN_Stadium | RH | 2023-12-29 | 2 |
| JN_Stadium | RH | 2023-12-31 | 2 |
| JN_Stadium | SO2 | 2023-07-27 | 3 |
| JN_Stadium | SO2 | 2023-08-01 | 2 |
| JN_Stadium | SO2 | 2023-08-05 | 1 |
| JN_Stadium | SO2 | 2023-08-18 | 2 |
| JN_Stadium | SO2 | 2023-08-23 | 4 |
| JN_Stadium | SO2 | 2023-08-24 | 3 |
| JN_Stadium | SO2 | 2023-08-26 | 2 |
| JN_Stadium | SO2 | 2023-08-31 | 1 |
| JN_Stadium | SO2 | 2023-09-02 | 2 |
| JN_Stadium | SO2 | 2023-09-08 | 3 |
| JN_Stadium | SO2 | 2023-10-06 | 6 |
| JN_Stadium | SO2 | 2023-10-11 | 5 |
| JN_Stadium | SO2 | 2023-10-18 | 3 |
| JN_Stadium | SO2 | 2023-10-27 | 2 |
| JN_Stadium | SO2 | 2023-11-01 | 3 |
| JN_Stadium | SO2 | 2023-11-05 | 1 |
| JN_Stadium | SO2 | 2023-11-12 | 5 |
| JN_Stadium | SO2 | 2023-11-17 | 1 |
| JN_Stadium | SO2 | 2023-12-03 | 1 |
| JN_Stadium | SO2 | 2023-12-08 | 1 |
| JN_Stadium | SO2 | 2023-12-09 | 1 |
| Lumpyngngad | CO | 2023-01-02 | 2 |
| Lumpyngngad | CO | 2023-01-09 | 2 |
| Lumpyngngad | CO | 2023-01-29 | 2 |
| Lumpyngngad | CO | 2023-02-09 | 1 |
| Lumpyngngad | CO | 2023-02-24 | 5 |
| Lumpyngngad | CO | 2023-03-02 | 3 |
| Lumpyngngad | CO | 2023-03-07 | 2 |
| Lumpyngngad | CO | 2023-03-13 | 1 |
| Lumpyngngad | CO | 2023-03-18 | 2 |
| Lumpyngngad | CO | 2023-03-24 | 5 |
| Lumpyngngad | CO | 2023-03-29 | 1 |
| Lumpyngngad | CO | 2023-04-06 | 9 |
| Lumpyngngad | CO | 2023-04-08 | 5 |
| Lumpyngngad | CO | 2023-04-11 | 2 |
| Lumpyngngad | CO | 2023-04-14 | 1 |
| Lumpyngngad | CO | 2023-04-26 | 1 |
| Lumpyngngad | CO | 2023-05-03 | 2 |
| Lumpyngngad | CO | 2023-05-04 | 1 |

_(truncated)_

## Stuck-run length distribution (for stuck_hours overrides)

| station | variable | n_runs | p50 | p90 | p99 | max | n_ge_default |
|---|---|---|---|---|---|---|---|
| Lumpyngngad | AT | 0 | NA | NA | NA | 0 | 0 |
| Lumpyngngad | CO | 7843 | 1 | 1 | 2 | 4 | 0 |
| Lumpyngngad | NO2 | 6447 | 1 | 1 | 1 | 2 | 0 |
| Lumpyngngad | O3 | 8104 | 1 | 1 | 1 | 2 | 0 |
| Lumpyngngad | PM10 | 4439 | 1 | 1 | 1 | 7 | 1 |
| Lumpyngngad | PM2.5 | 6653 | 1 | 1 | 2 | 7 | 2 |
| Lumpyngngad | RH | 8199 | 1 | 1 | 1 | 2 | 0 |
| Lumpyngngad | SO2 | 8159 | 1 | 1 | 1 | 2 | 0 |
| JN_Stadium | AT | 2894 | 1 | 1 | 1 | 1 | 0 |
| JN_Stadium | CO | 3174 | 1 | 1 | 2 | 3 | 0 |
| JN_Stadium | NO2 | 3198 | 1 | 1 | 1 | 1 | 0 |
| JN_Stadium | O3 | 1767 | 1 | 1 | 1 | 2 | 0 |
| JN_Stadium | PM10 | 2937 | 1 | 1 | 1 | 2 | 0 |
| JN_Stadium | PM2.5 | 2780 | 1 | 1 | 1 | 3 | 0 |
| JN_Stadium | RH | 2891 | 1 | 1 | 1 | 2 | 0 |
| JN_Stadium | SO2 | 3187 | 1 | 1 | 1 | 2 | 0 |

## Imputation choices

| variable | 1-3 | 4-24 | 25-72 | >72 |
|---|---|---|---|---|
| AT | M7 | M4 | M7 | M4 |
| CO | M1 | M8 | M7 | M8 |
| NO2 | M5 | M5 | M8 | M2 |
| O3 | M1 | M1 | M4 | M7 |
| PM10 | M8 | M8 | M8 | M1 |
| PM2.5 | M8 | M8 | M8 | M8 |
| RH | M1 | M7 | M7 | M7 |
| SO2 | M1 | M1 | M1 | M7 |

## Imputation benchmark MAE

| station | variable | method | bucket | n | mae | mae_log1p |
|---|---|---|---|---|---|---|
| Lumpyngngad | AT | M1 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M1 | >72 | 113 | NaN | NaN |
| Lumpyngngad | AT | M2 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M2 | >72 | 113 | NaN | NaN |
| Lumpyngngad | AT | M3 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M3 | >72 | 113 | NaN | NaN |
| Lumpyngngad | AT | M4 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M4 | >72 | 113 | NaN | NaN |
| Lumpyngngad | AT | M5 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M5 | >72 | 113 | NaN | NaN |
| Lumpyngngad | AT | M6 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M6 | >72 | 113 | NaN | NaN |
| Lumpyngngad | AT | M7 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M7 | >72 | 113 | NaN | NaN |
| Lumpyngngad | AT | M8 | 4-24 | 4 | NaN | NaN |
| Lumpyngngad | AT | M8 | >72 | 113 | NaN | NaN |
| Lumpyngngad | CO | M1 | 1-3 | 1063 | 0.0525 | 0.0414 |
| Lumpyngngad | CO | M1 | 4-24 | 524 | 0.0863 | 0.0689 |
| Lumpyngngad | CO | M1 | 25-72 | 28 | 0.0901 | 0.0703 |
| Lumpyngngad | CO | M2 | 1-3 | 1063 | 0.0731 | 0.0578 |
| Lumpyngngad | CO | M2 | 4-24 | 524 | 0.0756 | 0.0591 |
| Lumpyngngad | CO | M2 | 25-72 | 28 | 0.0731 | 0.0568 |
| Lumpyngngad | CO | M3 | 1-3 | 1063 | 0.0894 | 0.0711 |
| Lumpyngngad | CO | M3 | 4-24 | 524 | 0.0995 | 0.0782 |
| Lumpyngngad | CO | M3 | 25-72 | 28 | 0.1453 | 0.1049 |
| Lumpyngngad | CO | M4 | 1-3 | 1063 | 0.0525 | 0.0414 |
| Lumpyngngad | CO | M4 | 4-24 | 524 | 0.0737 | 0.0574 |
| Lumpyngngad | CO | M4 | 25-72 | 28 | 0.0590 | 0.0457 |
| Lumpyngngad | CO | M5 | 1-3 | 1063 | 0.0477 | 0.0380 |
| Lumpyngngad | CO | M5 | 4-24 | 524 | 0.0763 | 0.0605 |
| Lumpyngngad | CO | M5 | 25-72 | 28 | 0.0799 | 0.0604 |
| Lumpyngngad | CO | M6 | 1-3 | 1063 | 0.0741 | 0.0590 |
| Lumpyngngad | CO | M6 | 4-24 | 524 | 0.0788 | 0.0623 |
| Lumpyngngad | CO | M6 | 25-72 | 28 | 0.0799 | 0.0603 |
| Lumpyngngad | CO | M7 | 1-3 | 1063 | 0.0542 | 0.0432 |
| Lumpyngngad | CO | M7 | 4-24 | 524 | 0.0738 | 0.0587 |
| Lumpyngngad | CO | M7 | 25-72 | 28 | 0.0541 | 0.0417 |
| Lumpyngngad | CO | M8 | 1-3 | 1063 | 0.0644 | 0.0515 |
| Lumpyngngad | CO | M8 | 4-24 | 524 | 0.0731 | 0.0577 |
| Lumpyngngad | CO | M8 | 25-72 | 28 | 0.0603 | 0.0469 |
| Lumpyngngad | NO2 | M1 | 1-3 | 921 | 0.2088 | 0.0357 |
| Lumpyngngad | NO2 | M1 | 4-24 | 476 | 0.2010 | 0.0345 |
| Lumpyngngad | NO2 | M1 | 25-72 | 14 | 0.2061 | 0.0353 |
| Lumpyngngad | NO2 | M1 | >72 | 45 | NaN | NaN |
| Lumpyngngad | NO2 | M2 | 1-3 | 921 | 0.2167 | 0.0370 |
| Lumpyngngad | NO2 | M2 | 4-24 | 476 | 0.2033 | 0.0348 |
| Lumpyngngad | NO2 | M2 | 25-72 | 14 | 0.2470 | 0.0422 |
| Lumpyngngad | NO2 | M2 | >72 | 45 | NaN | NaN |
| Lumpyngngad | NO2 | M3 | 1-3 | 921 | 0.2072 | 0.0354 |
| Lumpyngngad | NO2 | M3 | 4-24 | 476 | 0.2004 | 0.0343 |
| Lumpyngngad | NO2 | M3 | 25-72 | 14 | 0.2409 | 0.0413 |
| Lumpyngngad | NO2 | M3 | >72 | 45 | NaN | NaN |
| Lumpyngngad | NO2 | M4 | 1-3 | 921 | 0.2088 | 0.0357 |
| Lumpyngngad | NO2 | M4 | 4-24 | 476 | 0.1985 | 0.0340 |
| Lumpyngngad | NO2 | M4 | 25-72 | 14 | 0.2252 | 0.0384 |
| Lumpyngngad | NO2 | M4 | >72 | 45 | NaN | NaN |
| Lumpyngngad | NO2 | M5 | 1-3 | 921 | 0.1755 | 0.0299 |
| Lumpyngngad | NO2 | M5 | 4-24 | 476 | 0.1464 | 0.0250 |
| Lumpyngngad | NO2 | M5 | 25-72 | 14 | 0.1502 | 0.0255 |
| Lumpyngngad | NO2 | M5 | >72 | 45 | NaN | NaN |
| Lumpyngngad | NO2 | M6 | 1-3 | 921 | 0.1590 | 0.0271 |
| Lumpyngngad | NO2 | M6 | 4-24 | 476 | 0.1548 | 0.0265 |
| Lumpyngngad | NO2 | M6 | 25-72 | 14 | 0.1509 | 0.0256 |
| Lumpyngngad | NO2 | M6 | >72 | 45 | NaN | NaN |
| Lumpyngngad | NO2 | M7 | 1-3 | 921 | 0.1879 | 0.0321 |
| Lumpyngngad | NO2 | M7 | 4-24 | 476 | 0.1810 | 0.0310 |
| Lumpyngngad | NO2 | M7 | 25-72 | 14 | 0.1763 | 0.0301 |
| Lumpyngngad | NO2 | M7 | >72 | 45 | NaN | NaN |
| Lumpyngngad | NO2 | M8 | 1-3 | 921 | 0.1565 | 0.0267 |
| Lumpyngngad | NO2 | M8 | 4-24 | 476 | 0.1514 | 0.0259 |
| Lumpyngngad | NO2 | M8 | 25-72 | 14 | 0.1392 | 0.0237 |
| Lumpyngngad | NO2 | M8 | >72 | 45 | NaN | NaN |
| Lumpyngngad | O3 | M1 | 1-3 | 915 | 0.1609 | 0.0962 |
| Lumpyngngad | O3 | M1 | 4-24 | 488 | 0.1586 | 0.0953 |
| Lumpyngngad | O3 | M1 | 25-72 | 45 | 0.1073 | 0.0641 |
| Lumpyngngad | O3 | M2 | 1-3 | 915 | 0.1627 | 0.0970 |
| Lumpyngngad | O3 | M2 | 4-24 | 488 | 0.2383 | 0.0978 |
| Lumpyngngad | O3 | M2 | 25-72 | 45 | 0.0943 | 0.0559 |
| Lumpyngngad | O3 | M3 | 1-3 | 915 | 0.1681 | 0.0990 |
| Lumpyngngad | O3 | M3 | 4-24 | 488 | 0.1628 | 0.0950 |
| Lumpyngngad | O3 | M3 | 25-72 | 45 | 0.1515 | 0.0861 |
| Lumpyngngad | O3 | M4 | 1-3 | 915 | 0.1609 | 0.0962 |
| Lumpyngngad | O3 | M4 | 4-24 | 488 | 0.2486 | 0.1042 |
| Lumpyngngad | O3 | M4 | 25-72 | 45 | 0.1033 | 0.0610 |
| Lumpyngngad | O3 | M5 | 1-3 | 915 | 0.1546 | 0.0903 |
| Lumpyngngad | O3 | M5 | 4-24 | 488 | 0.1656 | 0.0836 |
| Lumpyngngad | O3 | M5 | 25-72 | 45 | 0.1626 | 0.0795 |
| Lumpyngngad | O3 | M6 | 1-3 | 915 | 0.1917 | 0.0948 |
| Lumpyngngad | O3 | M6 | 4-24 | 488 | 0.1753 | 0.0845 |
| Lumpyngngad | O3 | M6 | 25-72 | 45 | 0.1627 | 0.0794 |
| Lumpyngngad | O3 | M7 | 1-3 | 915 | 0.1823 | 0.0972 |
| Lumpyngngad | O3 | M7 | 4-24 | 488 | 0.3427 | 0.1318 |
| Lumpyngngad | O3 | M7 | 25-72 | 45 | 0.1357 | 0.0818 |
| Lumpyngngad | O3 | M8 | 1-3 | 915 | 0.1609 | 0.0962 |
| Lumpyngngad | O3 | M8 | 4-24 | 488 | 0.2486 | 0.1042 |
| Lumpyngngad | O3 | M8 | 25-72 | 45 | 0.1033 | 0.0610 |
| Lumpyngngad | PM10 | M1 | 1-3 | 484 | 17.2028 | 0.2111 |
| Lumpyngngad | PM10 | M1 | 4-24 | 315 | 24.9955 | 0.4115 |
| Lumpyngngad | PM10 | M1 | 25-72 | 29 | 18.0125 | 0.2546 |
| Lumpyngngad | PM10 | M1 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM10 | M2 | 1-3 | 484 | 38.3930 | 0.4323 |
| Lumpyngngad | PM10 | M2 | 4-24 | 315 | 44.1004 | 0.4668 |
| Lumpyngngad | PM10 | M2 | 25-72 | 29 | 26.0086 | 0.3340 |
| Lumpyngngad | PM10 | M2 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM10 | M3 | 1-3 | 484 | 50.6687 | 0.6364 |
| Lumpyngngad | PM10 | M3 | 4-24 | 315 | 56.2086 | 0.6325 |
| Lumpyngngad | PM10 | M3 | 25-72 | 29 | 33.8480 | 0.6193 |
| Lumpyngngad | PM10 | M3 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM10 | M4 | 1-3 | 484 | 17.2028 | 0.2111 |
| Lumpyngngad | PM10 | M4 | 4-24 | 315 | 30.0836 | 0.4044 |
| Lumpyngngad | PM10 | M4 | 25-72 | 29 | 30.1363 | 0.3830 |
| Lumpyngngad | PM10 | M4 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM10 | M5 | 1-3 | 484 | 19.0723 | 0.2483 |
| Lumpyngngad | PM10 | M5 | 4-24 | 315 | 23.1062 | 0.3650 |
| Lumpyngngad | PM10 | M5 | 25-72 | 29 | 42.7233 | 0.6202 |
| Lumpyngngad | PM10 | M5 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM10 | M6 | 1-3 | 484 | 34.4890 | 0.4702 |
| Lumpyngngad | PM10 | M6 | 4-24 | 315 | 24.7043 | 0.3846 |
| Lumpyngngad | PM10 | M6 | 25-72 | 29 | 42.7157 | 0.6202 |
| Lumpyngngad | PM10 | M6 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM10 | M7 | 1-3 | 484 | 18.3233 | 0.2579 |
| Lumpyngngad | PM10 | M7 | 4-24 | 315 | 20.6811 | 0.3572 |
| Lumpyngngad | PM10 | M7 | 25-72 | 29 | 19.6665 | 0.2836 |
| Lumpyngngad | PM10 | M7 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM10 | M8 | 1-3 | 484 | 11.9378 | 0.1549 |
| Lumpyngngad | PM10 | M8 | 4-24 | 315 | 14.6762 | 0.2588 |
| Lumpyngngad | PM10 | M8 | 25-72 | 29 | 11.5512 | 0.1791 |
| Lumpyngngad | PM10 | M8 | >72 | 51 | NaN | NaN |
| Lumpyngngad | PM2.5 | M1 | 1-3 | 711 | 8.9947 | 0.3324 |
| Lumpyngngad | PM2.5 | M1 | 4-24 | 510 | 17.7964 | 0.5344 |
| Lumpyngngad | PM2.5 | M1 | 25-72 | 48 | 16.7177 | 0.4625 |
| Lumpyngngad | PM2.5 | M1 | >72 | 3 | 19.3333 | 0.5353 |
| Lumpyngngad | PM2.5 | M2 | 1-3 | 711 | 13.7234 | 0.5354 |
| Lumpyngngad | PM2.5 | M2 | 4-24 | 510 | 13.5452 | 0.5262 |
| Lumpyngngad | PM2.5 | M2 | 25-72 | 48 | 27.8427 | 1.2831 |
| Lumpyngngad | PM2.5 | M2 | >72 | 3 | 32.3333 | 1.3908 |
| Lumpyngngad | PM2.5 | M3 | 1-3 | 711 | 19.4604 | 0.7578 |
| Lumpyngngad | PM2.5 | M3 | 4-24 | 510 | 18.9657 | 0.7117 |
| Lumpyngngad | PM2.5 | M3 | 25-72 | 48 | 28.4159 | 1.2907 |
| Lumpyngngad | PM2.5 | M3 | >72 | 3 | 37.8608 | 1.7124 |
| Lumpyngngad | PM2.5 | M4 | 1-3 | 711 | 8.9947 | 0.3324 |
| Lumpyngngad | PM2.5 | M4 | 4-24 | 510 | 12.6992 | 0.5028 |
| Lumpyngngad | PM2.5 | M4 | 25-72 | 48 | 25.8010 | 1.1757 |
| Lumpyngngad | PM2.5 | M4 | >72 | 3 | 19.3333 | 0.5353 |
| Lumpyngngad | PM2.5 | M5 | 1-3 | 711 | 8.7901 | 0.3165 |
| Lumpyngngad | PM2.5 | M5 | 4-24 | 510 | 13.6759 | 0.4803 |
| Lumpyngngad | PM2.5 | M5 | 25-72 | 48 | 30.9218 | 1.2298 |
| Lumpyngngad | PM2.5 | M5 | >72 | 3 | 32.5584 | 1.2096 |
| Lumpyngngad | PM2.5 | M6 | 1-3 | 711 | 15.0309 | 0.5395 |
| Lumpyngngad | PM2.5 | M6 | 4-24 | 510 | 14.4734 | 0.5180 |
| Lumpyngngad | PM2.5 | M6 | 25-72 | 48 | 30.9229 | 1.2299 |
| Lumpyngngad | PM2.5 | M6 | >72 | 3 | 32.5584 | 1.2096 |
| Lumpyngngad | PM2.5 | M7 | 1-3 | 711 | 9.7237 | 0.4368 |
| Lumpyngngad | PM2.5 | M7 | 4-24 | 510 | 13.6573 | 0.6040 |
| Lumpyngngad | PM2.5 | M7 | 25-72 | 48 | 27.7140 | 1.1031 |
| Lumpyngngad | PM2.5 | M7 | >72 | 3 | 28.9359 | 1.0017 |
| Lumpyngngad | PM2.5 | M8 | 1-3 | 711 | 8.5712 | 0.3175 |
| Lumpyngngad | PM2.5 | M8 | 4-24 | 510 | 9.7965 | 0.4438 |
| Lumpyngngad | PM2.5 | M8 | 25-72 | 48 | 25.8010 | 1.1757 |
| Lumpyngngad | PM2.5 | M8 | >72 | 3 | 19.3333 | 0.5353 |
| Lumpyngngad | RH | M1 | 1-3 | 1026 | 5.8746 | 0.0862 |
| Lumpyngngad | RH | M1 | 4-24 | 535 | 12.9052 | 0.1879 |
| Lumpyngngad | RH | M1 | 25-72 | 3 | 6.0425 | 0.0765 |
| Lumpyngngad | RH | M2 | 1-3 | 1026 | 9.8955 | 0.1420 |
| Lumpyngngad | RH | M2 | 4-24 | 535 | 8.7270 | 0.1244 |
| Lumpyngngad | RH | M2 | 25-72 | 3 | 8.7325 | 0.1084 |
| Lumpyngngad | RH | M3 | 1-3 | 1026 | 11.8065 | 0.1745 |
| Lumpyngngad | RH | M3 | 4-24 | 535 | 13.1770 | 0.1920 |
| Lumpyngngad | RH | M3 | 25-72 | 3 | 11.5825 | 0.1368 |
| Lumpyngngad | RH | M4 | 1-3 | 1026 | 5.8746 | 0.0862 |
| Lumpyngngad | RH | M4 | 4-24 | 535 | 8.5004 | 0.1226 |
| Lumpyngngad | RH | M4 | 25-72 | 3 | 6.0425 | 0.0765 |
| Lumpyngngad | RH | M5 | 1-3 | 1026 | 5.5093 | 0.0789 |
| Lumpyngngad | RH | M5 | 4-24 | 535 | 9.1545 | 0.1316 |
| Lumpyngngad | RH | M5 | 25-72 | 3 | 9.4414 | 0.1158 |
| Lumpyngngad | RH | M6 | 1-3 | 1026 | 9.5727 | 0.1374 |
| Lumpyngngad | RH | M6 | 4-24 | 535 | 9.6441 | 0.1395 |
| Lumpyngngad | RH | M6 | 25-72 | 3 | 9.4358 | 0.1157 |
| Lumpyngngad | RH | M7 | 1-3 | 1026 | 6.1197 | 0.0869 |
| Lumpyngngad | RH | M7 | 4-24 | 535 | 7.9116 | 0.1172 |
| Lumpyngngad | RH | M7 | 25-72 | 3 | 4.0352 | 0.0519 |
| Lumpyngngad | RH | M8 | 1-3 | 1026 | 5.8746 | 0.0862 |
| Lumpyngngad | RH | M8 | 4-24 | 535 | 8.5004 | 0.1226 |
| Lumpyngngad | RH | M8 | 25-72 | 3 | 6.0425 | 0.0765 |
| Lumpyngngad | SO2 | M1 | 1-3 | 1026 | 0.2596 | 0.0117 |
| Lumpyngngad | SO2 | M1 | 4-24 | 527 | 0.3988 | 0.0171 |
| Lumpyngngad | SO2 | M1 | 25-72 | 12 | 0.2113 | 0.0080 |
| Lumpyngngad | SO2 | M2 | 1-3 | 1026 | 0.6548 | 0.0281 |
| Lumpyngngad | SO2 | M2 | 4-24 | 527 | 0.6430 | 0.0272 |
| Lumpyngngad | SO2 | M2 | 25-72 | 12 | 0.7037 | 0.0271 |
| Lumpyngngad | SO2 | M3 | 1-3 | 1026 | 1.3679 | 0.0600 |
| Lumpyngngad | SO2 | M3 | 4-24 | 527 | 1.4060 | 0.0604 |
| Lumpyngngad | SO2 | M3 | 25-72 | 12 | 0.7231 | 0.0280 |
| Lumpyngngad | SO2 | M4 | 1-3 | 1026 | 0.2596 | 0.0117 |
| Lumpyngngad | SO2 | M4 | 4-24 | 527 | 0.4588 | 0.0200 |
| Lumpyngngad | SO2 | M4 | 25-72 | 12 | 0.5392 | 0.0203 |
| Lumpyngngad | SO2 | M5 | 1-3 | 1026 | 0.5849 | 0.0259 |
| Lumpyngngad | SO2 | M5 | 4-24 | 527 | 1.3192 | 0.0583 |
| Lumpyngngad | SO2 | M5 | 25-72 | 12 | 0.5935 | 0.0243 |
| Lumpyngngad | SO2 | M6 | 1-3 | 1026 | 1.4370 | 0.0633 |
| Lumpyngngad | SO2 | M6 | 4-24 | 527 | 1.4308 | 0.0631 |
| Lumpyngngad | SO2 | M6 | 25-72 | 12 | 0.5933 | 0.0243 |
| Lumpyngngad | SO2 | M7 | 1-3 | 1026 | 0.4510 | 0.0210 |
| Lumpyngngad | SO2 | M7 | 4-24 | 527 | 0.5684 | 0.0260 |
| Lumpyngngad | SO2 | M7 | 25-72 | 12 | 0.6442 | 0.0252 |
| Lumpyngngad | SO2 | M8 | 1-3 | 1026 | 0.2596 | 0.0117 |
| Lumpyngngad | SO2 | M8 | 4-24 | 527 | 0.4588 | 0.0200 |
| Lumpyngngad | SO2 | M8 | 25-72 | 12 | 0.5392 | 0.0203 |
| JN_Stadium | AT | M1 | 1-3 | 128 | 1.3875 | 0.0573 |
| JN_Stadium | AT | M1 | 4-24 | 416 | 3.7644 | 0.1545 |
| JN_Stadium | AT | M1 | 25-72 | 351 | 3.0949 | 0.1276 |
| JN_Stadium | AT | M1 | >72 | 411 | 2.5196 | 0.1067 |
| JN_Stadium | AT | M2 | 1-3 | 128 | 2.6097 | 0.1056 |
| JN_Stadium | AT | M2 | 4-24 | 416 | 2.7393 | 0.1113 |
| JN_Stadium | AT | M2 | 25-72 | 351 | 3.0046 | 0.1193 |
| JN_Stadium | AT | M2 | >72 | 411 | 2.8533 | 0.1163 |
| JN_Stadium | AT | M3 | 1-3 | 128 | 3.1198 | 0.1276 |
| JN_Stadium | AT | M3 | 4-24 | 416 | 3.3950 | 0.1392 |
| JN_Stadium | AT | M3 | 25-72 | 351 | 3.0009 | 0.1231 |
| JN_Stadium | AT | M3 | >72 | 411 | 2.8304 | 0.1180 |
| JN_Stadium | AT | M4 | 1-3 | 128 | 1.3875 | 0.0573 |
| JN_Stadium | AT | M4 | 4-24 | 416 | 2.3384 | 0.0959 |
| JN_Stadium | AT | M4 | 25-72 | 351 | 2.0976 | 0.0836 |
| JN_Stadium | AT | M4 | >72 | 411 | 2.0839 | 0.0856 |
| JN_Stadium | AT | M5 | 1-3 | 128 | 1.3444 | 0.0563 |
| JN_Stadium | AT | M5 | 4-24 | 416 | 2.3400 | 0.0972 |
| JN_Stadium | AT | M5 | 25-72 | 351 | 2.1386 | 0.0876 |
| JN_Stadium | AT | M5 | >72 | 411 | 2.3242 | 0.0980 |
| JN_Stadium | AT | M6 | 1-3 | 128 | 2.2132 | 0.0915 |
| JN_Stadium | AT | M6 | 4-24 | 416 | 2.4322 | 0.1010 |
| JN_Stadium | AT | M6 | 25-72 | 351 | 2.1399 | 0.0876 |
| JN_Stadium | AT | M6 | >72 | 411 | 2.3242 | 0.0980 |
| JN_Stadium | AT | M7 | 1-3 | 128 | 0.8650 | 0.0353 |
| JN_Stadium | AT | M7 | 4-24 | 416 | 1.6254 | 0.0682 |
| JN_Stadium | AT | M7 | 25-72 | 351 | 1.3668 | 0.0579 |
| JN_Stadium | AT | M7 | >72 | 411 | 1.3800 | 0.0588 |
| JN_Stadium | AT | M8 | 1-3 | 128 | 1.3875 | 0.0573 |
| JN_Stadium | AT | M8 | 4-24 | 416 | 2.3384 | 0.0959 |
| JN_Stadium | AT | M8 | 25-72 | 351 | 2.0976 | 0.0836 |
| JN_Stadium | AT | M8 | >72 | 411 | 2.0839 | 0.0856 |
| JN_Stadium | CO | M1 | 1-3 | 214 | 0.0744 | 0.0490 |
| JN_Stadium | CO | M1 | 4-24 | 652 | 0.3073 | 0.1889 |
| JN_Stadium | CO | M1 | 25-72 | 312 | 0.2356 | 0.1529 |
| JN_Stadium | CO | M1 | >72 | 132 | 0.1827 | 0.1307 |
| JN_Stadium | CO | M2 | 1-3 | 214 | 0.1845 | 0.1170 |
| JN_Stadium | CO | M2 | 4-24 | 652 | 0.1792 | 0.1142 |
| JN_Stadium | CO | M2 | 25-72 | 312 | 0.2079 | 0.1356 |
| JN_Stadium | CO | M2 | >72 | 132 | 0.1885 | 0.1323 |
| JN_Stadium | CO | M3 | 1-3 | 214 | 0.2283 | 0.1448 |
| JN_Stadium | CO | M3 | 4-24 | 652 | 0.2522 | 0.1654 |
| JN_Stadium | CO | M3 | 25-72 | 312 | 0.2392 | 0.1576 |
| JN_Stadium | CO | M3 | >72 | 132 | 0.3562 | 0.2330 |
| JN_Stadium | CO | M4 | 1-3 | 214 | 0.0744 | 0.0490 |
| JN_Stadium | CO | M4 | 4-24 | 652 | 0.1836 | 0.1159 |
| JN_Stadium | CO | M4 | 25-72 | 312 | 0.2058 | 0.1325 |
| JN_Stadium | CO | M4 | >72 | 132 | 0.1808 | 0.1272 |
| JN_Stadium | CO | M5 | 1-3 | 214 | 0.0802 | 0.0497 |
| JN_Stadium | CO | M5 | 4-24 | 652 | 0.1435 | 0.0951 |
| JN_Stadium | CO | M5 | 25-72 | 312 | 0.1760 | 0.1157 |
| JN_Stadium | CO | M5 | >72 | 132 | 0.1619 | 0.1141 |
| JN_Stadium | CO | M6 | 1-3 | 214 | 0.1658 | 0.1036 |
| JN_Stadium | CO | M6 | 4-24 | 652 | 0.1502 | 0.0995 |
| JN_Stadium | CO | M6 | 25-72 | 312 | 0.1762 | 0.1159 |
| JN_Stadium | CO | M6 | >72 | 132 | 0.1619 | 0.1141 |
| JN_Stadium | CO | M7 | 1-3 | 214 | 0.0898 | 0.0585 |
| JN_Stadium | CO | M7 | 4-24 | 652 | 0.2385 | 0.1547 |
| JN_Stadium | CO | M7 | 25-72 | 312 | 0.1713 | 0.1124 |
| JN_Stadium | CO | M7 | >72 | 132 | 0.1485 | 0.1057 |
| JN_Stadium | CO | M8 | 1-3 | 214 | 0.1242 | 0.0795 |
| JN_Stadium | CO | M8 | 4-24 | 652 | 0.1360 | 0.0886 |
| JN_Stadium | CO | M8 | 25-72 | 312 | 0.1349 | 0.0884 |
| JN_Stadium | CO | M8 | >72 | 132 | 0.1407 | 0.0977 |
| JN_Stadium | NO2 | M1 | 1-3 | 130 | 2.9183 | 0.2771 |
| JN_Stadium | NO2 | M1 | 4-24 | 486 | 5.8630 | 0.5627 |
| JN_Stadium | NO2 | M1 | 25-72 | 461 | 4.7257 | 0.4793 |
| JN_Stadium | NO2 | M1 | >72 | 278 | 4.9143 | 0.5165 |
| JN_Stadium | NO2 | M2 | 1-3 | 130 | 3.9135 | 0.3737 |
| JN_Stadium | NO2 | M2 | 4-24 | 486 | 3.9988 | 0.3775 |
| JN_Stadium | NO2 | M2 | 25-72 | 461 | 3.9992 | 0.3990 |
| JN_Stadium | NO2 | M2 | >72 | 278 | 4.2700 | 0.4266 |
| JN_Stadium | NO2 | M3 | 1-3 | 130 | 4.1945 | 0.4031 |
| JN_Stadium | NO2 | M3 | 4-24 | 486 | 4.1087 | 0.4018 |
| JN_Stadium | NO2 | M3 | 25-72 | 461 | 4.0506 | 0.4032 |
| JN_Stadium | NO2 | M3 | >72 | 278 | 4.4874 | 0.4553 |
| JN_Stadium | NO2 | M4 | 1-3 | 130 | 2.9183 | 0.2771 |
| JN_Stadium | NO2 | M4 | 4-24 | 486 | 4.4384 | 0.3953 |
| JN_Stadium | NO2 | M4 | 25-72 | 461 | 4.1710 | 0.4048 |
| JN_Stadium | NO2 | M4 | >72 | 278 | 4.8636 | 0.4390 |
| JN_Stadium | NO2 | M5 | 1-3 | 130 | 2.1276 | 0.2141 |
| JN_Stadium | NO2 | M5 | 4-24 | 486 | 3.7110 | 0.3496 |
| JN_Stadium | NO2 | M5 | 25-72 | 461 | 3.7648 | 0.3714 |
| JN_Stadium | NO2 | M5 | >72 | 278 | 3.9675 | 0.3989 |
| JN_Stadium | NO2 | M6 | 1-3 | 130 | 3.5480 | 0.3347 |
| JN_Stadium | NO2 | M6 | 4-24 | 486 | 3.7400 | 0.3549 |
| JN_Stadium | NO2 | M6 | 25-72 | 461 | 3.7670 | 0.3717 |
| JN_Stadium | NO2 | M6 | >72 | 278 | 3.9675 | 0.3989 |
| JN_Stadium | NO2 | M7 | 1-3 | 130 | 2.7659 | 0.2667 |
| JN_Stadium | NO2 | M7 | 4-24 | 486 | 4.1272 | 0.4100 |
| JN_Stadium | NO2 | M7 | 25-72 | 461 | 3.8321 | 0.4064 |
| JN_Stadium | NO2 | M7 | >72 | 278 | 3.6270 | 0.3816 |
| JN_Stadium | NO2 | M8 | 1-3 | 130 | 3.0797 | 0.2761 |
| JN_Stadium | NO2 | M8 | 4-24 | 486 | 3.1379 | 0.2900 |
| JN_Stadium | NO2 | M8 | 25-72 | 461 | 3.3167 | 0.3234 |
| JN_Stadium | NO2 | M8 | >72 | 278 | 3.5715 | 0.3599 |
| JN_Stadium | O3 | M1 | 1-3 | 130 | 3.6517 | 0.4087 |
| JN_Stadium | O3 | M1 | 4-24 | 303 | 7.9858 | 1.0277 |
| JN_Stadium | O3 | M1 | 25-72 | 339 | 8.8646 | 1.1560 |
| JN_Stadium | O3 | M1 | >72 | 90 | 8.8174 | 1.4843 |
| JN_Stadium | O3 | M2 | 1-3 | 130 | 9.1020 | 1.1157 |
| JN_Stadium | O3 | M2 | 4-24 | 303 | 8.7597 | 1.1084 |
| JN_Stadium | O3 | M2 | 25-72 | 339 | 8.9955 | 1.1841 |
| JN_Stadium | O3 | M2 | >72 | 90 | 6.2717 | 0.9341 |
| JN_Stadium | O3 | M3 | 1-3 | 130 | 9.7390 | 1.4548 |
| JN_Stadium | O3 | M3 | 4-24 | 303 | 11.1532 | 1.5695 |
| JN_Stadium | O3 | M3 | 25-72 | 339 | 11.8655 | 1.6584 |
| JN_Stadium | O3 | M3 | >72 | 90 | 8.7186 | 1.4880 |
| JN_Stadium | O3 | M4 | 1-3 | 130 | 3.6517 | 0.4087 |
| JN_Stadium | O3 | M4 | 4-24 | 303 | 7.5897 | 0.9200 |
| JN_Stadium | O3 | M4 | 25-72 | 339 | 7.7267 | 0.9422 |
| JN_Stadium | O3 | M4 | >72 | 90 | 6.1123 | 0.8629 |
| JN_Stadium | O3 | M5 | 1-3 | 130 | 4.0768 | 0.4229 |
| JN_Stadium | O3 | M5 | 4-24 | 303 | 8.4374 | 0.8434 |
| JN_Stadium | O3 | M5 | 25-72 | 339 | 8.9348 | 0.9357 |
| JN_Stadium | O3 | M5 | >72 | 90 | 6.5546 | 0.8507 |
| JN_Stadium | O3 | M6 | 1-3 | 130 | 8.4321 | 0.9859 |
| JN_Stadium | O3 | M6 | 4-24 | 303 | 8.5912 | 0.8807 |
| JN_Stadium | O3 | M6 | 25-72 | 339 | 8.9371 | 0.9369 |
| JN_Stadium | O3 | M6 | >72 | 90 | 6.5546 | 0.8507 |
| JN_Stadium | O3 | M7 | 1-3 | 130 | 4.1558 | 0.4590 |
| JN_Stadium | O3 | M7 | 4-24 | 303 | 5.8776 | 0.5799 |
| JN_Stadium | O3 | M7 | 25-72 | 339 | 6.1383 | 0.6155 |
| JN_Stadium | O3 | M7 | >72 | 90 | 6.0040 | 0.6377 |
| JN_Stadium | O3 | M8 | 1-3 | 130 | 3.6517 | 0.4087 |
| JN_Stadium | O3 | M8 | 4-24 | 303 | 7.5897 | 0.9200 |
| JN_Stadium | O3 | M8 | 25-72 | 339 | 7.7267 | 0.9422 |
| JN_Stadium | O3 | M8 | >72 | 90 | 6.1123 | 0.8629 |
| JN_Stadium | PM10 | M1 | 1-3 | 157 | 17.6849 | 0.4144 |
| JN_Stadium | PM10 | M1 | 4-24 | 567 | 25.0950 | 0.7406 |
| JN_Stadium | PM10 | M1 | 25-72 | 412 | 24.3630 | 0.9504 |
| JN_Stadium | PM10 | M1 | >72 | 53 | 18.2645 | 0.5717 |
| JN_Stadium | PM10 | M2 | 1-3 | 157 | 32.9379 | 0.8042 |
| JN_Stadium | PM10 | M2 | 4-24 | 567 | 28.2388 | 0.8125 |
| JN_Stadium | PM10 | M2 | 25-72 | 412 | 25.1473 | 0.8164 |
| JN_Stadium | PM10 | M2 | >72 | 53 | 21.3903 | 0.7967 |
| JN_Stadium | PM10 | M3 | 1-3 | 157 | 39.5491 | 1.1759 |
| JN_Stadium | PM10 | M3 | 4-24 | 567 | 29.8404 | 0.9950 |
| JN_Stadium | PM10 | M3 | 25-72 | 412 | 27.6551 | 1.0234 |
| JN_Stadium | PM10 | M3 | >72 | 53 | 23.1194 | 0.9559 |
| JN_Stadium | PM10 | M4 | 1-3 | 157 | 17.6849 | 0.4144 |
| JN_Stadium | PM10 | M4 | 4-24 | 567 | 28.4854 | 0.8819 |
| JN_Stadium | PM10 | M4 | 25-72 | 412 | 24.9676 | 0.8562 |
| JN_Stadium | PM10 | M4 | >72 | 53 | 24.8452 | 0.8027 |
| JN_Stadium | PM10 | M5 | 1-3 | 157 | 18.0415 | 0.4069 |
| JN_Stadium | PM10 | M5 | 4-24 | 567 | 25.8073 | 0.6700 |
| JN_Stadium | PM10 | M5 | 25-72 | 412 | 24.5568 | 0.7198 |
| JN_Stadium | PM10 | M5 | >72 | 53 | 20.0515 | 0.7483 |
| JN_Stadium | PM10 | M6 | 1-3 | 157 | 33.4673 | 0.8002 |
| JN_Stadium | PM10 | M6 | 4-24 | 567 | 26.9508 | 0.7137 |
| JN_Stadium | PM10 | M6 | 25-72 | 412 | 24.5801 | 0.7207 |
| JN_Stadium | PM10 | M6 | >72 | 53 | 20.0515 | 0.7483 |
| JN_Stadium | PM10 | M7 | 1-3 | 157 | 17.3321 | 0.4965 |
| JN_Stadium | PM10 | M7 | 4-24 | 567 | 22.6229 | 0.6927 |
| JN_Stadium | PM10 | M7 | 25-72 | 412 | 23.5747 | 1.0523 |
| JN_Stadium | PM10 | M7 | >72 | 53 | 16.3315 | 0.6400 |
| JN_Stadium | PM10 | M8 | 1-3 | 157 | 13.1896 | 0.3163 |
| JN_Stadium | PM10 | M8 | 4-24 | 567 | 14.1598 | 0.3765 |
| JN_Stadium | PM10 | M8 | 25-72 | 412 | 16.2108 | 0.5123 |
| JN_Stadium | PM10 | M8 | >72 | 53 | 19.4999 | 0.5147 |
| JN_Stadium | PM2.5 | M1 | 1-3 | 154 | 8.0828 | 0.4401 |
| JN_Stadium | PM2.5 | M1 | 4-24 | 467 | 12.6852 | 0.7437 |
| JN_Stadium | PM2.5 | M1 | 25-72 | 360 | 12.3694 | 0.8645 |
| JN_Stadium | PM2.5 | M1 | >72 | 181 | 13.0412 | 0.7983 |
| JN_Stadium | PM2.5 | M2 | 1-3 | 154 | 13.8944 | 0.7914 |
| JN_Stadium | PM2.5 | M2 | 4-24 | 467 | 11.0033 | 0.7524 |
| JN_Stadium | PM2.5 | M2 | 25-72 | 360 | 11.0763 | 0.8566 |
| JN_Stadium | PM2.5 | M2 | >72 | 181 | 10.2637 | 0.7421 |
| JN_Stadium | PM2.5 | M3 | 1-3 | 154 | 16.2409 | 1.0346 |
| JN_Stadium | PM2.5 | M3 | 4-24 | 467 | 13.5780 | 0.9534 |
| JN_Stadium | PM2.5 | M3 | 25-72 | 360 | 11.0315 | 0.8510 |
| JN_Stadium | PM2.5 | M3 | >72 | 181 | 11.6489 | 0.8310 |
| JN_Stadium | PM2.5 | M4 | 1-3 | 154 | 8.0828 | 0.4401 |
| JN_Stadium | PM2.5 | M4 | 4-24 | 467 | 9.7831 | 0.6695 |
| JN_Stadium | PM2.5 | M4 | 25-72 | 360 | 10.6531 | 0.8170 |
| JN_Stadium | PM2.5 | M4 | >72 | 181 | 11.2196 | 0.7703 |
| JN_Stadium | PM2.5 | M5 | 1-3 | 154 | 8.4061 | 0.4613 |
| JN_Stadium | PM2.5 | M5 | 4-24 | 467 | 12.8840 | 0.8480 |
| JN_Stadium | PM2.5 | M5 | 25-72 | 360 | 10.9854 | 0.8486 |
| JN_Stadium | PM2.5 | M5 | >72 | 181 | 9.0716 | 0.6731 |
| JN_Stadium | PM2.5 | M6 | 1-3 | 154 | 15.6527 | 0.9495 |
| JN_Stadium | PM2.5 | M6 | 4-24 | 467 | 13.3425 | 0.8964 |
| JN_Stadium | PM2.5 | M6 | 25-72 | 360 | 10.9885 | 0.8490 |
| JN_Stadium | PM2.5 | M6 | >72 | 181 | 9.0716 | 0.6731 |
| JN_Stadium | PM2.5 | M7 | 1-3 | 154 | 6.8441 | 0.4200 |
| JN_Stadium | PM2.5 | M7 | 4-24 | 467 | 10.0065 | 0.7191 |
| JN_Stadium | PM2.5 | M7 | 25-72 | 360 | 10.5629 | 0.8849 |
| JN_Stadium | PM2.5 | M7 | >72 | 181 | 15.2109 | 1.3927 |
| JN_Stadium | PM2.5 | M8 | 1-3 | 154 | 5.6508 | 0.3611 |
| JN_Stadium | PM2.5 | M8 | 4-24 | 467 | 6.8239 | 0.4634 |
| JN_Stadium | PM2.5 | M8 | 25-72 | 360 | 7.8178 | 0.5522 |
| JN_Stadium | PM2.5 | M8 | >72 | 181 | 6.9550 | 0.3891 |
| JN_Stadium | RH | M1 | 1-3 | 128 | 4.4350 | 0.0555 |
| JN_Stadium | RH | M1 | 4-24 | 416 | 11.8592 | 0.1455 |
| JN_Stadium | RH | M1 | 25-72 | 351 | 10.5134 | 0.1258 |
| JN_Stadium | RH | M1 | >72 | 411 | 10.4568 | 0.1241 |
| JN_Stadium | RH | M2 | 1-3 | 128 | 10.2679 | 0.1281 |
| JN_Stadium | RH | M2 | 4-24 | 416 | 9.5982 | 0.1195 |
| JN_Stadium | RH | M2 | 25-72 | 351 | 10.8266 | 0.1365 |
| JN_Stadium | RH | M2 | >72 | 411 | 9.8473 | 0.1230 |
| JN_Stadium | RH | M3 | 1-3 | 128 | 11.4525 | 0.1408 |
| JN_Stadium | RH | M3 | 4-24 | 416 | 11.5909 | 0.1418 |
| JN_Stadium | RH | M3 | 25-72 | 351 | 10.8826 | 0.1313 |
| JN_Stadium | RH | M3 | >72 | 411 | 10.0445 | 0.1221 |
| JN_Stadium | RH | M4 | 1-3 | 128 | 4.4350 | 0.0555 |
| JN_Stadium | RH | M4 | 4-24 | 416 | 8.7500 | 0.1077 |
| JN_Stadium | RH | M4 | 25-72 | 351 | 8.0545 | 0.1003 |
| JN_Stadium | RH | M4 | >72 | 411 | 7.4366 | 0.0916 |
| JN_Stadium | RH | M5 | 1-3 | 128 | 4.8610 | 0.0599 |
| JN_Stadium | RH | M5 | 4-24 | 416 | 7.8596 | 0.0951 |
| JN_Stadium | RH | M5 | 25-72 | 351 | 7.2453 | 0.0880 |
| JN_Stadium | RH | M5 | >72 | 411 | 7.7489 | 0.0940 |
| JN_Stadium | RH | M6 | 1-3 | 128 | 7.9852 | 0.0978 |
| JN_Stadium | RH | M6 | 4-24 | 416 | 8.1673 | 0.0988 |
| JN_Stadium | RH | M6 | 25-72 | 351 | 7.2507 | 0.0881 |
| JN_Stadium | RH | M6 | >72 | 411 | 7.7489 | 0.0940 |
| JN_Stadium | RH | M7 | 1-3 | 128 | 3.3117 | 0.0420 |
| JN_Stadium | RH | M7 | 4-24 | 416 | 5.9048 | 0.0715 |
| JN_Stadium | RH | M7 | 25-72 | 351 | 5.7616 | 0.0685 |
| JN_Stadium | RH | M7 | >72 | 411 | 5.0397 | 0.0608 |
| JN_Stadium | RH | M8 | 1-3 | 128 | 4.4350 | 0.0555 |
| JN_Stadium | RH | M8 | 4-24 | 416 | 8.7500 | 0.1077 |
| JN_Stadium | RH | M8 | 25-72 | 351 | 8.0545 | 0.1003 |
| JN_Stadium | RH | M8 | >72 | 411 | 7.4366 | 0.0916 |
| JN_Stadium | SO2 | M1 | 1-3 | 130 | 0.5153 | 0.0285 |
| JN_Stadium | SO2 | M1 | 4-24 | 486 | 0.8572 | 0.0493 |
| JN_Stadium | SO2 | M1 | 25-72 | 461 | 0.8477 | 0.0493 |
| JN_Stadium | SO2 | M1 | >72 | 278 | 1.2216 | 0.0695 |
| JN_Stadium | SO2 | M2 | 1-3 | 130 | 1.6625 | 0.0914 |
| JN_Stadium | SO2 | M2 | 4-24 | 486 | 1.4093 | 0.0797 |
| JN_Stadium | SO2 | M2 | 25-72 | 461 | 1.2116 | 0.0705 |
| JN_Stadium | SO2 | M2 | >72 | 278 | 1.7097 | 0.0975 |
| JN_Stadium | SO2 | M3 | 1-3 | 130 | 2.4418 | 0.1355 |
| JN_Stadium | SO2 | M3 | 4-24 | 486 | 1.7855 | 0.1019 |
| JN_Stadium | SO2 | M3 | 25-72 | 461 | 1.2562 | 0.0752 |
| JN_Stadium | SO2 | M3 | >72 | 278 | 2.0826 | 0.1214 |
| JN_Stadium | SO2 | M4 | 1-3 | 130 | 0.5153 | 0.0285 |
| JN_Stadium | SO2 | M4 | 4-24 | 486 | 1.2950 | 0.0736 |
| JN_Stadium | SO2 | M4 | 25-72 | 461 | 1.2902 | 0.0736 |
| JN_Stadium | SO2 | M4 | >72 | 278 | 1.6310 | 0.0901 |
| JN_Stadium | SO2 | M5 | 1-3 | 130 | 0.7280 | 0.0387 |
| JN_Stadium | SO2 | M5 | 4-24 | 486 | 1.2163 | 0.0681 |
| JN_Stadium | SO2 | M5 | 25-72 | 461 | 1.1323 | 0.0662 |
| JN_Stadium | SO2 | M5 | >72 | 278 | 1.5134 | 0.0867 |
| JN_Stadium | SO2 | M6 | 1-3 | 130 | 1.4750 | 0.0796 |
| JN_Stadium | SO2 | M6 | 4-24 | 486 | 1.2619 | 0.0709 |
| JN_Stadium | SO2 | M6 | 25-72 | 461 | 1.1328 | 0.0663 |
| JN_Stadium | SO2 | M6 | >72 | 278 | 1.5134 | 0.0867 |
| JN_Stadium | SO2 | M7 | 1-3 | 130 | 0.5833 | 0.0319 |
| JN_Stadium | SO2 | M7 | 4-24 | 486 | 0.7775 | 0.0449 |
| JN_Stadium | SO2 | M7 | 25-72 | 461 | 0.6884 | 0.0402 |
| JN_Stadium | SO2 | M7 | >72 | 278 | 1.1633 | 0.0664 |
| JN_Stadium | SO2 | M8 | 1-3 | 130 | 0.5153 | 0.0285 |
| JN_Stadium | SO2 | M8 | 4-24 | 486 | 1.2950 | 0.0736 |
| JN_Stadium | SO2 | M8 | 25-72 | 461 | 1.2902 | 0.0736 |
| JN_Stadium | SO2 | M8 | >72 | 278 | 1.6310 | 0.0901 |

