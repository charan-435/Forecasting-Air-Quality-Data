# MASE (paper), MAE, RMSE, and MCB / Nemenyi ranks.

mase <- function(y_train, y_test, yhat, season = SEASONALITY) {
  y_test <- as.numeric(y_test)
  yhat <- as.numeric(yhat)
  y_train <- as.numeric(y_train)
  h <- length(y_test)
  num <- mean(abs(yhat - y_test))
  denom <- mean(abs(diff(y_train, lag = season)))
  if (!is.finite(denom) || denom == 0) denom <- mean(abs(diff(y_train)))
  num / denom
}

mae <- function(y, yhat) mean(abs(as.numeric(y) - as.numeric(yhat)))
rmse <- function(y, yhat) sqrt(mean((as.numeric(y) - as.numeric(yhat))^2))

score_forecast <- function(y_train, y_test, yhat, season = SEASONALITY) {
  tibble::tibble(
    MASE = mase(y_train, y_test, yhat, season),
    MAE = mae(y_test, yhat),
    RMSE = rmse(y_test, yhat)
  )
}

# MCB-style average rank + critical distance (Nemenyi), Koning et al. idea.
# `mat` is models (columns) x cases (rows), lower better.
mcb_ranks <- function(mat) {
  r <- t(apply(mat, 1, rank, ties.method = "average"))
  k <- ncol(mat)
  n <- nrow(mat)
  avg <- colMeans(r)
  # Nemenyi critical distance at 5%.
  q <- 2.343  # studentised range q_0.05 for a typical 8–10 model set; see note
  # More accurately use Tukey studentised range; fallback formula:
  cd <- q * sqrt(k * (k + 1) / (6 * n))
  tibble::tibble(
    model = colnames(mat),
    mean_rank = as.numeric(avg),
    cd = cd,
    best = min(avg),
    lo = as.numeric(avg) - cd / 2,
    hi = as.numeric(avg) + cd / 2
  ) %>% dplyr::arrange(.data$mean_rank)
}

nemenyi_q <- function(k, alpha = 0.05) {
  # Approximate studentised-range critical values for alpha=0.05.
  qs <- c(
    `2` = 1.960, `3` = 2.344, `4` = 2.569, `5` = 2.728,
    `6` = 2.850, `7` = 2.949, `8` = 3.031, `9` = 3.102, `10` = 3.164
  )
  unname(qs[as.character(min(10L, max(2L, k)))])
}

mcb_from_table <- function(df, value_col = "MASE", model_col = "method", case_cols = c("sensor", "pollutant", "horizon")) {
  wide <- df %>%
    dplyr::select(dplyr::all_of(c(case_cols, model_col, value_col))) %>%
    tidyr::pivot_wider(names_from = dplyr::all_of(model_col), values_from = dplyr::all_of(value_col))
  mat <- as.matrix(wide[, setdiff(names(wide), case_cols)])
  k <- ncol(mat)
  n <- nrow(mat)
  r <- t(apply(mat, 1, rank, ties.method = "average"))
  avg <- colMeans(r, na.rm = TRUE)
  q <- nemenyi_q(k)
  cd <- q * sqrt(k * (k + 1) / (6 * n))
  tibble::tibble(
    model = names(avg),
    mean_rank = as.numeric(avg),
    critical_distance = cd,
    lo = as.numeric(avg) - cd / 2,
    hi = as.numeric(avg) + cd / 2
  ) %>% dplyr::arrange(.data$mean_rank)
}
