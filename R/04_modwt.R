# MODWT / IMODWT / MRA — paper method: Haar (Percival pyramid).
# Extension: generic_mra() also supports D4, LA8 (waveslim), Fourier bands, and EMD.
# Circular convolution: decompose TRAIN only so test values never leak into coefficients.

roll_right <- function(x, s) {
  n <- length(x)
  if (s %% n == 0) return(x)
  s <- s %% n
  c(x[(n - s + 1):n], x[1:(n - s)])
}

roll_left <- function(x, s) {
  n <- length(x)
  if (s %% n == 0) return(x)
  s <- s %% n
  c(x[(s + 1):n], x[1:s])
}

haar_modwt <- function(x, J) {
  V <- as.numeric(x)
  W <- vector("list", J)
  names(W) <- paste0("W", seq_len(J))
  for (j in seq_len(J)) {
    s <- 2^(j - 1)
    V_lag <- roll_right(V, s)
    W[[j]] <- (V - V_lag) / 2
    V <- (V + V_lag) / 2
  }
  list(W = W, V = V, J = J)
}

haar_inverse_step <- function(Wj, Vj, j) {
  s <- 2^(j - 1)
  (Wj - roll_left(Wj, s) + Vj + roll_left(Vj, s)) / 2
}

haar_imodwt <- function(W, V_J) {
  V <- V_J
  for (j in rev(seq_along(W))) {
    V <- haar_inverse_step(W[[j]], V, j)
  }
  V
}

# Additive MRA: Y = D1 + ... + DJ + SJ. These are what we forecast (paper's D_k, S_K).
haar_mra <- function(x, J) {
  wt <- haar_modwt(x, J)
  zeros_W <- lapply(wt$W, function(w) rep(0, length(w)))
  D <- vector("list", J)
  names(D) <- paste0("D", seq_len(J))
  for (j in seq_len(J)) {
    Wj <- zeros_W
    Wj[[j]] <- wt$W[[j]]
    D[[j]] <- haar_imodwt(Wj, rep(0, length(wt$V)))
  }
  S <- haar_imodwt(zeros_W, wt$V)
  names(S) <- NULL
  list(D = D, S = S, J = J)
}

mra_reconstruct <- function(mra) {
  Reduce(`+`, mra$D, init = mra$S)
}

energy_by_level <- function(mra) {
  d_e <- vapply(mra$D, function(d) sum(d^2), numeric(1))
  s_e <- sum(mra$S^2)
  tot <- sum(d_e) + s_e
  tibble::tibble(
    component = c(names(mra$D), paste0("S", mra$J)),
    energy = c(d_e, s_e),
    share = c(d_e, s_e) / tot
  )
}

choose_J <- function(x, max_J = 9, energy_cut = 0.02) {
  # Paper uses K = ln N (~9). We also report the energy elbow.
  n <- length(x)
  J_paper <- max(1L, min(max_J, floor(log(n))))
  mra <- haar_mra(x, J_paper)
  en <- energy_by_level(mra)
  # Keep levels until remaining smooth + last details hold most energy.
  # Drop trailing detail levels whose share is below energy_cut AND after the peak.
  shares <- en$share[seq_len(J_paper)]
  keep <- which(shares >= energy_cut)
  J_from_energy <- if (length(keep)) max(keep) else J_paper
  # Level j ~ scale 2^j hours. J = 5 covers 32 h (the daily cycle from EDA).
  # Extra levels beyond that add a CatBoost model each and mostly fit noise.
  J_elbow <- max(3L, min(J_from_energy, 5L, J_paper))
  list(J_paper = J_paper, J_elbow = J_elbow, energy = en)
}

# Forecast-time reconstruction: component forecasts of length h, added (MRA).
mra_forecast_sum <- function(comp_fc) {
  # comp_fc: list of numeric vectors of equal length h
  Reduce(`+`, comp_fc)
}

# Octave-band Fourier split with the same additive layout as Haar MRA:
#   D_k  = inverse FFT of frequencies whose period sits in [2^k, 2^{k+1})
#   S_K  = DC + leftover low frequencies
# Reconstruction is exact because the bins partition the spectrum.
fourier_mra <- function(x, J) {
  x  <- as.numeric(x)
  n  <- length(x)
  Xf <- fft(x)
  Dspec <- lapply(seq_len(J), function(i) complex(length.out = n))
  Sspec <- complex(length.out = n)
  Sspec[1] <- Xf[1]  # DC

  half <- floor(n / 2)
  for (k in seq_len(half)) {
    per <- n / k
    j <- NA_integer_
    for (jj in seq_len(J)) {
      if (per >= 2^jj && per < 2^(jj + 1)) {
        j <- jj
        break
      }
    }
    bins <- unique(c(k + 1L, n - k + 1L))
    bins <- bins[bins >= 1L & bins <= n]
    if (is.na(j)) {
      Sspec[bins] <- Xf[bins]
    } else {
      Dspec[[j]][bins] <- Xf[bins]
    }
  }

  D <- lapply(seq_len(J), function(j) Re(fft(Dspec[[j]], inverse = TRUE)) / n)
  names(D) <- paste0("D", seq_len(J))
  S <- Re(fft(Sspec, inverse = TRUE)) / n
  list(D = D, S = S, J = J, filter = "fourier")
}

# EMD mapped onto the paper's (D_1..D_K, S_K) slots.
# IMF 1 is the fastest oscillation -> D_1; leftover IMFs fold into S_K.
emd_mra <- function(x, J) {
  if (!requireNamespace("EMD", quietly = TRUE))
    stop("Install the EMD package to use this decomposition.")
  x  <- as.numeric(x)
  n  <- length(x)
  tt <- seq_len(n)
  emd_out <- EMD::emd(x, tt, boundary = "periodic")
  n_imf <- if (is.null(emd_out$imf)) 0L else ncol(emd_out$imf)
  D <- vector("list", J)
  names(D) <- paste0("D", seq_len(J))
  for (j in seq_len(J)) {
    D[[j]] <- if (j <= n_imf) as.numeric(emd_out$imf[, j]) else rep(0, n)
  }
  S <- as.numeric(emd_out$residue)
  if (n_imf > J) {
    for (j in (J + 1L):n_imf) S <- S + as.numeric(emd_out$imf[, j])
  }
  list(D = D, S = S, J = J, filter = "emd")
}

# ── generic_mra: paper Haar, plus D4 / LA8 / Fourier / EMD ──────────────────
#   haar    – paper default (our pyramid)
#   d4      – Daubechies-4 (extension)
#   la8     – Least-Asymmetric-8 (extension)
#   fourier – octave-band FFT (cross-question)
#   emd     – Empirical Mode Decomposition (extension)

generic_mra <- function(x, J, filter = c("haar", "d4", "la8", "fourier", "emd")) {
  filter <- match.arg(filter)

  if (filter == "haar") {
    obj <- haar_mra(x, J)
    obj$filter <- "haar"
    return(obj)
  }
  if (filter == "fourier") return(fourier_mra(x, J))
  if (filter == "emd")     return(emd_mra(x, J))

  if (!requireNamespace("waveslim", quietly = TRUE))
    stop("waveslim package is required for D4 / LA8 filter families.")

  wm <- waveslim::mra(x, wf = filter, J = J, method = "modwt",
                      boundary = "periodic")
  D <- vector("list", J)
  names(D) <- paste0("D", seq_len(J))
  for (j in seq_len(J)) {
    key <- paste0("D", j)
    if (!key %in% names(wm))
      stop(sprintf("waveslim mra did not return component '%s'. Check J.", key))
    D[[j]] <- as.numeric(wm[[key]])
  }
  S_key <- paste0("S", J)
  if (!S_key %in% names(wm))
    stop(sprintf("waveslim mra did not return smooth component '%s'.", S_key))
  S <- as.numeric(wm[[S_key]])
  list(D = D, S = S, J = J, filter = filter)
}

# Compare energy profiles across filter families at the same J.
# Returns a tidy tibble with columns: filter, component, energy, share.
compare_filter_energy <- function(x, J, filters = c("haar", "d4", "la8")) {
  dplyr::bind_rows(lapply(filters, function(f) {
    mra <- generic_mra(x, J, filter = f)
    en  <- energy_by_level(mra)
    en$filter <- f
    en
  }))
}
