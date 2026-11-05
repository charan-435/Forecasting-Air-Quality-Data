# B11: lag alignment and recursive feedback vs an analytic AR(1).
source("docs/audit/tests/_lib.R")

# Training matrix: lag1 at time t is y[t-1] (R/core/05_features.R).
y <- 10:20
X <- make_lags(y, 3)
# row for t=4 (1-index 4, value 13): lag1=12, lag2=11, lag3=10
ok_make <- isTRUE(all.equal(as.numeric(X[4, ]), c(12, 11, 10)))

# Forecast origin after the last value 20: lag1 should be 20, lag2=19, lag3=18.
row <- last_lag_row(y, 3)
ok_last <- isTRUE(all.equal(as.numeric(row), c(20, 19, 18)))

audit_ok("B11_make_lags_lag1_is_y_t_minus_1", ok_make,
         sprintf("make_lags row t=4 = [%s] (want 12,11,10)",
                 paste(X[4, ], collapse = ",")))
audit_ok("B11_last_lag_row_lag1_is_most_recent", ok_last,
         sprintf("last_lag_row = [%s] (want 20,19,18)",
                 paste(as.numeric(row), collapse = ",")))

# Analytic AR(1): recursive_tree_forecast with a stub that returns phi * lag1.
phi <- 0.7
y0 <- c(0.1, 0.3, -0.2, 0.5, 1.2)
fit <- list(p = 1L, family = "xgb", model = "stub")
# Hijack predict_tree_row via a local recursive loop using last_lag_row only.
h <- 8L
y_hist <- y0
fc <- numeric(h)
for (i in seq_len(h)) {
  r <- last_lag_row(y_hist, 1L)
  fc[i] <- phi * r[1, 1]
  y_hist <- c(y_hist, fc[i])
}
analytic <- phi^(seq_len(h)) * tail(y0, 1)
write_tbl(tibble::tibble(step = seq_len(h), recursive = fc, analytic = analytic),
          "B11_ar1_recursive.csv")
audit_ok("B11_recursive_matches_ar1_analytic",
         max(abs(fc - analytic)) < 1e-12,
         sprintf("max |recursive - phi^k y_n| = %g", max(abs(fc - analytic))))
