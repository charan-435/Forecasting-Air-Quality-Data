# Natively causal MODWT analysis coefficients.
# Haar: the repo pyramid h̃=(1,−1)/2, g̃=(1,1)/2 looking only backward.
# D4/LA8: à trous with the same taps looking only backward. waveslim
# periodic MODWT fails D1 (AUDIT F1) and is never stored.

decomp_coef_haar <- function(x_full, params = list(J = 10L)) {
  J <- as.integer(params$J %||% 10L)
  x <- as.numeric(x_full)
  n <- length(x)
  Vprev <- x
  W <- matrix(NA_real_, n, J)
  V <- matrix(NA_real_, n, J)
  colnames(W) <- paste0("W", seq_len(J))
  colnames(V) <- paste0("V", seq_len(J))
  for (j in seq_len(J)) {
    s <- as.integer(2^(j - 1L))
    lagged <- c(rep(NA_real_, s), Vprev[seq_len(n - s)])
    W[, j] <- (Vprev - lagged) / 2
    V[, j] <- (Vprev + lagged) / 2
    Vprev <- V[, j]
  }
  cbind(W, V)
}

.modwt_filters <- function(name) {
  if (identical(tolower(name), "haar")) {
    return(list(h = c(0.5, 0.5), g = c(0.5, -0.5), L = 2L))
  }
  if (!requireNamespace("waveslim", quietly = TRUE))
    stop("waveslim is required for ", name)
  wf <- waveslim::wave.filter(tolower(name))
  h <- as.numeric(wf$h)
  g <- as.numeric(wf$g)
  list(h = h, g = g, L = length(h))
}

# Causal à trous MODWT: W_j[t] = Σ_l g[l] V_{j-1}[t - l·2^{j-1}], l ≥ 0.
decomp_coef_modwt <- function(x_full, params = list(J = 8L, filter = "d4")) {
  J <- as.integer(params$J %||% 8L)
  fil <- .modwt_filters(params$filter %||% "d4")
  x <- as.numeric(x_full)
  n <- length(x)
  Vprev <- x
  W <- matrix(NA_real_, n, J)
  V <- matrix(NA_real_, n, J)
  colnames(W) <- paste0("W", seq_len(J))
  colnames(V) <- paste0("V", seq_len(J))
  h <- fil$h; g <- fil$g; L <- length(h)
  for (j in seq_len(J)) {
    dil <- as.integer(2^(j - 1L))
    span <- (L - 1L) * dil
    wj <- rep(0, n)
    vj <- rep(0, n)
    finite <- is.finite(Vprev)
    for (l in seq_len(L)) {
      lag <- (l - 1L) * dil
      z <- if (lag == 0L) Vprev else c(rep(NA_real_, lag), Vprev[seq_len(n - lag)])
      finite <- finite & is.finite(z)
      z[!is.finite(z)] <- 0
      wj <- wj + g[l] * z
      vj <- vj + h[l] * z
    }
    wj[seq_len(span)] <- NA_real_
    vj[seq_len(span)] <- NA_real_
    wj[!finite] <- NA_real_
    vj[!finite] <- NA_real_
    W[, j] <- wj
    V[, j] <- vj
    Vprev <- vj
  }
  cbind(W, V)
}
