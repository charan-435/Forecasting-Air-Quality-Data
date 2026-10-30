# Weighted conformal prediction intervals (paper §II-C), plus a simple alert rule.
# CS_t = |Y_t - Yhat_t| / U_t
# CQ_t = (1-alpha) quantile of CS in a trailing window of length kappa
# PI_t = Yhat_t ± CQ_t * U_t

rolling_mae <- function(err, win) {
  e <- abs(as.numeric(err))
  n <- length(e)
  u <- numeric(n)
  for (i in seq_len(n)) {
    lo <- max(1L, i - win + 1L)
    u[i] <- mean(e[lo:i], na.rm = TRUE)
  }
  pmax(u, .Machine$double.eps)
}

conformal_from_residuals <- function(y_cal, yhat_cal, yhat_test,
                                     alpha = 0.05, kappa = 168L, u_win = 24L) {
  err <- as.numeric(y_cal) - as.numeric(yhat_cal)
  u_cal <- rolling_mae(err, u_win)
  cs <- abs(err) / u_cal
  n <- length(cs)
  k <- min(as.integer(kappa), n)
  cq <- as.numeric(stats::quantile(cs[(n - k + 1):n], probs = 1 - alpha, na.rm = TRUE, names = FALSE))
  # Deployed form: no test actuals. Last calibration U scales the test band.
  u_test <- rep(u_cal[n], length(yhat_test))
  half <- cq * u_test
  list(
    lower = as.numeric(yhat_test) - half,
    upper = as.numeric(yhat_test) + half,
    cq = cq,
    alpha = alpha,
    kappa = k,
    u_test = u_test,
    coverage_cal = mean(abs(err) <= cq * u_cal, na.rm = TRUE)
  )
}

tree_insample <- function(fit, y_train) {
  sup <- supervised_from_series(y_train, fit$p)
  yhat <- vapply(seq_len(nrow(sup$X)), function(i) {
    predict_tree_row(fit, sup$X[i, , drop = FALSE])
  }, numeric(1))
  list(y = sup$y, yhat = yhat)
}

wave_insample <- function(wave_fit, y_train) {
  filt <- if (!is.null(wave_fit$filter)) wave_fit$filter else "haar"
  mra <- generic_mra(y_train, wave_fit$J, filter = filt)
  comps <- c(mra$D, list(S = mra$S))
  parts <- lapply(names(comps), function(nm) {
    fit <- wave_fit$models[[nm]]
    if (!is.null(fit$p)) tree_insample(fit, comps[[nm]])
    else list(y = comps[[nm]], yhat = as.numeric(stats::fitted(fit)))
  })
  lens <- vapply(parts, function(z) length(z$yhat), integer(1))
  L <- min(lens)
  yhat <- Reduce(`+`, lapply(parts, function(z) tail(z$yhat, L)))
  list(y = tail(as.numeric(y_train), L), yhat = yhat)
}

interval_coverage <- function(y, lo, hi) {
  mean(y >= lo & y <= hi, na.rm = TRUE)
}

interval_width <- function(lo, hi) {
  mean(hi - lo, na.rm = TRUE)
}

# Extra decision rule (not in the paper): mean of the lower PI bound vs WHO / NAAQS.
alert_from_interval <- function(pollutant, lower, upper, yhat) {
  thr <- ALERT_THRESHOLDS[[pollutant]]
  if (is.null(thr)) {
    return(tibble::tibble(rule = character(), threshold = numeric(),
                          mean_lower = NA_real_, exceedance_likely = logical()))
  }
  ml <- mean(lower, na.rm = TRUE)
  tibble::tibble(
    rule = c("WHO_24h", "NAAQS_24h"),
    threshold = c(thr$who, thr$naaqs),
    unit = thr$unit,
    mean_forecast = mean(yhat, na.rm = TRUE),
    mean_lower = ml,
    exceedance_likely = c(ml > thr$who, ml > thr$naaqs)
  )
}
