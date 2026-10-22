# Haar MODWT / IMODWT / MRA (Percival pyramid, matching modwt_report/haar_modwt.py).
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
  # Level j ≈ scale 2^j hours. J = 5 covers 32 h (the daily cycle from EDA).
  # Extra levels beyond that add a CatBoost model each and mostly fit noise.
  J_elbow <- max(3L, min(J_from_energy, 5L, J_paper))
  list(J_paper = J_paper, J_elbow = J_elbow, energy = en)
}

# Forecast-time reconstruction: component forecasts of length h, added (MRA).
mra_forecast_sum <- function(comp_fc) {
  # comp_fc: list of numeric vectors of equal length h
  Reduce(`+`, comp_fc)
}
