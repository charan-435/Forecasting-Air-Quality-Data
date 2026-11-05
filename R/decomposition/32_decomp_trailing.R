# Two-sided methods on a trailing window ending at t. The engine keeps the last
# (unpadded) row, so the stored value at t uses only data ≤ t.

ar_forecast_ls <- function(y, h = 48L, p = 48L) {
  y <- as.numeric(y)
  n <- length(y)
  h <- as.integer(h)
  p <- min(as.integer(p), n - 2L)
  if (p < 1L || n < p + 2L) return(rep(tail(y[is.finite(y)], 1), h))
  Y <- y[(p + 1L):n]
  X <- matrix(NA_real_, n - p, p)
  for (k in seq_len(p)) X[, k] <- y[(p + 1L - k):(n - k)]
  keep <- is.finite(Y) & rowSums(!is.finite(X)) == 0
  if (sum(keep) < p + 1L) return(rep(tail(y[is.finite(y)], 1), h))
  coef <- tryCatch(qr.solve(cbind(1, X[keep, , drop = FALSE]), Y[keep]),
                   error = function(e) NULL)
  if (is.null(coef) || !all(is.finite(coef)))
    return(rep(tail(y[is.finite(y)], 1), h))
  buf <- y
  out <- numeric(h)
  for (i in seq_len(h)) {
    lags <- buf[length(buf):(length(buf) - p + 1L)]
    lags[!is.finite(lags)] <- 0
    yhat <- coef[1] + sum(coef[-1] * lags)
    if (!is.finite(yhat)) yhat <- buf[length(buf)]
    out[i] <- yhat
    buf <- c(buf, yhat)
  }
  out
}

run_trailing_series <- function(x, fn, params, W, pad,
                                station = "", variable = "") {
  n <- length(x)
  probe <- tryCatch({
    xx <- x[seq_len(min(W, n))]
    if (pad > 0L) xx <- c(xx, ar_forecast_ls(xx, pad))
    fn(xx, params)
  }, error = function(e) NULL)
  if (is.null(probe)) {
    return(matrix(NA_real_, n, 1, dimnames = list(NULL, "NA_comp")))
  }
  if (is.null(dim(probe))) probe <- matrix(probe, ncol = 1)
  K <- ncol(probe)
  cn <- colnames(probe)
  if (is.null(cn) || any(!nzchar(cn))) cn <- paste0("C", seq_len(K))
  M <- matrix(NA_real_, n, K)
  colnames(M) <- cn
  extra_imf <- grepl("emd", params %||% list())
  n_imf_raw <- NULL
  if ("n_imf_raw" %in% cn) {
    # fn already stores it as a column; keep it
  }
  ckpt_every <- as.integer(decomp_cfg()$checkpoint_every %||% 500L)
  stop_after <- get0(".DECOMP_STOP_AFTER", envir = .GlobalEnv, ifnotfound = NULL)
  ckpt <- get0(".DECOMP_CKPT_PATH", envir = .GlobalEnv, ifnotfound = NULL)
  t_start <- W
  if (!is.null(ckpt) && file.exists(ckpt)) {
    saved <- readRDS(ckpt)
    if (is.matrix(saved$M) && ncol(saved$M) == K && nrow(saved$M) == n) {
      M <- saved$M
      t_start <- as.integer(saved$last_t) + 1L
    }
  }

  t_seq <- seq.int(max(W, t_start), n)
  for (ii in seq_along(t_seq)) {
    t <- t_seq[ii]
    if (!is.null(stop_after) && t > as.integer(stop_after)) {
      if (!is.null(ckpt)) saveRDS(list(M = M, last_t = t - 1L), ckpt)
      stop("DECOMP_STOP_AFTER=", stop_after, call. = FALSE)
    }
    win <- x[(t - W + 1L):t]
    xx <- if (pad > 0L) c(win, ar_forecast_ls(win, pad)) else win
    p2 <- params
    p2$.station <- station
    p2$.variable <- variable
    p2$.t <- t
    mat <- tryCatch(fn(xx, p2), error = function(e) NULL)
    if (is.null(mat)) next
    if (is.null(dim(mat))) mat <- matrix(mat, ncol = 1)
    row <- mat[length(win), ]
    ntake <- min(length(row), K)
    M[t, seq_len(ntake)] <- row[seq_len(ntake)]
    if (!is.null(ckpt) && ckpt_every > 0L && (t - W + 1L) %% ckpt_every == 0L) {
      saveRDS(list(M = M, last_t = t), ckpt)
    }
  }
  if (!is.null(ckpt) && file.exists(ckpt)) unlink(ckpt)
  M
}

decomp_mra_haar <- function(x_window, params = list(J = 5L)) {
  J <- as.integer(params$J %||% 5L)
  mra <- haar_mra(as.numeric(x_window), J)
  M <- cbind(do.call(cbind, mra$D), S = mra$S)
  colnames(M) <- c(paste0("D", seq_len(J)), paste0("S", J))
  M
}

decomp_mra_waveslim <- function(x_window, params = list(J = 5L, filter = "d4")) {
  J <- as.integer(params$J %||% 5L)
  wf <- tolower(params$filter %||% "d4")
  a <- waveslim::mra(as.numeric(x_window), wf = wf, J = J,
                     method = "modwt", boundary = "periodic")
  M <- do.call(cbind, a)
  colnames(M) <- c(paste0("D", seq_len(J)), paste0("S", J))
  storage.mode(M) <- "double"
  M
}

.fold_imfs <- function(imf, residue, n_keep = 6L) {
  imf <- as.matrix(imf)
  n <- nrow(imf)
  k <- ncol(imf)
  residue <- as.numeric(residue)
  if (length(residue) != n) residue <- rep(residue[1], n)
  n_raw <- k
  if (k > n_keep) {
    residue <- residue + rowSums(imf[, (n_keep + 1L):k, drop = FALSE])
    imf <- imf[, seq_len(n_keep), drop = FALSE]
  } else if (k < n_keep) {
    imf <- cbind(imf, matrix(0, n, n_keep - k))
  }
  M <- cbind(imf, RES = residue, n_imf_raw = n_raw)
  colnames(M) <- c(paste0("IMF", seq_len(n_keep)), "RES", "n_imf_raw")
  M
}

decomp_emd <- function(x_window, params = list()) {
  if (!requireNamespace("EMD", quietly = TRUE)) stop("EMD package missing")
  x <- as.numeric(x_window)
  n_keep <- as.integer(params$n_imf %||% decomp_cfg()$n_imf %||% 6L)
  fit <- EMD::emd(x, boundary = "wave")
  imf <- if (is.null(dim(fit$imf))) matrix(fit$imf, ncol = 1) else fit$imf
  residue <- fit$residue
  if (is.null(residue)) residue <- x - rowSums(imf)
  .fold_imfs(imf, residue, n_keep)
}

.ceemdan_seed <- function(params) {
  st <- params$.station %||% "S"
  va <- params$.variable %||% "V"
  t <- params$.t %||% 0L
  hex <- digest::digest(paste(st, va, t, sep = "|"), algo = "xxhash32")
  strtoi(substr(hex, 1L, 7L), 16L)
}

decomp_ceemdan <- function(x_window, params = list()) {
  if (!requireNamespace("Rlibeemd", quietly = TRUE)) stop("Rlibeemd package missing")
  x <- as.numeric(x_window)
  n_keep <- as.integer(params$n_imf %||% decomp_cfg()$n_imf %||% 6L)
  cfg <- decomp_cfg()$ceemdan
  ens <- as.integer(params$ensemble %||% cfg$ensemble %||% 50L)
  noise <- as.numeric(params$noise %||% cfg$noise %||% 0.2)
  seed <- .ceemdan_seed(params)
  set.seed(seed)
  mat <- Rlibeemd::ceemdan(x, num_imfs = 0, ensemble_size = ens,
                           noise_strength = noise, rng_seed = as.integer(seed %% 2147483647))
  mat <- as.matrix(mat)
  if (ncol(mat) < 2L) {
    imf <- matrix(mat, ncol = 1)
    residue <- x - as.numeric(imf)
  } else {
    imf <- mat[, seq_len(ncol(mat) - 1L), drop = FALSE]
    residue <- mat[, ncol(mat)]
  }
  .fold_imfs(imf, residue, n_keep)
}

decomp_vmd <- function(x_window, params = list(K = 6L)) {
  if (!requireNamespace("VMDecomp", quietly = TRUE)) stop("VMDecomp package missing")
  x <- as.numeric(x_window)
  K <- as.integer(params$K %||% 6L)
  cfg <- decomp_cfg()$vmd
  alpha <- as.numeric(cfg$alpha %||% 2000)
  tau <- as.numeric(cfg$tau %||% 0)
  DC <- isTRUE(cfg$DC %||% FALSE)
  tol <- as.numeric(cfg$tol %||% 1e-7)
  fit <- VMDecomp::vmd(x, alpha = alpha, tau = tau, K = K, DC = DC, init = 0, tol = tol)
  u <- as.matrix(fit$u)
  omega <- as.numeric(fit$omega)
  if (length(omega) >= ncol(u)) {
    ord <- order(omega[seq_len(ncol(u))])
    u <- u[, ord, drop = FALSE]
  }
  colnames(u) <- paste0("M", seq_len(ncol(u)))
  storage.mode(u) <- "double"
  u
}

decomp_mstl <- function(x_window, params = list()) {
  x <- as.numeric(x_window)
  n <- length(x)
  m <- tryCatch({
    tsx <- forecast::msts(x, seasonal.periods = c(24, 168))
    forecast::mstl(tsx, iterate = 1)
  }, error = function(e) NULL)
  if (is.null(m)) {
    out <- cbind(TREND = x, SEAS24 = 0, SEAS168 = 0, REM = 0)
    return(out)
  }
  cn <- colnames(m)
  trend <- if ("Trend" %in% cn) m[, "Trend"] else m[, 1]
  s24 <- if ("Seasonal24" %in% cn) m[, "Seasonal24"] else if (ncol(m) >= 2) m[, 2] else 0
  s168 <- if ("Seasonal168" %in% cn) m[, "Seasonal168"] else if (ncol(m) >= 3) m[, 3] else 0
  rem <- x - trend - s24 - s168
  cbind(TREND = as.numeric(trend), SEAS24 = as.numeric(s24),
        SEAS168 = as.numeric(s168), REM = as.numeric(rem))
}

decomp_ssa <- function(x_window, params = list(L = 168L, n_rc = 8L)) {
  if (!requireNamespace("Rssa", quietly = TRUE)) stop("Rssa package missing")
  x <- as.numeric(x_window)
  L <- as.integer(params$L %||% 168L)
  n_rc <- as.integer(params$n_rc %||% 8L)
  L <- min(L, max(2L, floor(length(x) / 2)))
  s <- Rssa::ssa(x, L = L)
  rec <- tryCatch(Rssa::reconstruct(s, groups = as.list(seq_len(min(n_rc, s$nu)))),
                  error = function(e) NULL)
  n <- length(x)
  M <- matrix(0, n, n_rc)
  if (!is.null(rec)) {
    for (i in seq_along(rec)) M[, i] <- as.numeric(rec[[i]])
  }
  rem <- x - rowSums(M)
  colnames(M) <- paste0("RC", seq_len(n_rc))
  cbind(M, REM = rem)
}

# Dummy trailing method used by tests/phase1b/08_dummy_method.R.
# Mean of the window plus remainder. Additive, causal at the last row.
decomp_ma_rem <- function(x_window, params = list()) {
  x <- as.numeric(x_window)
  ma <- mean(x, na.rm = TRUE)
  cbind(MA = rep(ma, length(x)), REM = x - ma)
}
