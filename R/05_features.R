# Lag matrices. lag_k = y_{t-k}. No future values.

make_lags <- function(y, p) {
  y <- as.numeric(y)
  n <- length(y)
  X <- matrix(NA_real_, n, p)
  for (k in seq_len(p)) {
    if (n > k) X[(k + 1):n, k] <- y[1:(n - k)]
  }
  colnames(X) <- paste0("lag", seq_len(p))
  X
}

supervised_from_series <- function(y, p) {
  X <- make_lags(y, p)
  ok <- stats::complete.cases(X)
  list(X = X[ok, , drop = FALSE], y = as.numeric(y)[ok], index = which(ok))
}

last_lag_row <- function(y, p) {
  y <- as.numeric(y)
  n <- length(y)
  if (n < p) stop("Not enough history for lag row.")
  matrix(y[n:(n - p + 1)], nrow = 1, dimnames = list(NULL, paste0("lag", seq_len(p))))
}

pacf_cutoff <- function(y, max_lag = 72, sig = 0.05) {
  y <- as.numeric(y)
  y <- y[is.finite(y)]
  pc <- stats::pacf(y, lag.max = max_lag, plot = FALSE)
  n <- length(y)
  thresh <- stats::qnorm(1 - sig / 2) / sqrt(n)
  sig_lags <- which(abs(as.numeric(pc$acf)) > thresh)
  if (!length(sig_lags)) return(1L)
  as.integer(max(sig_lags))
}
