# A1: Haar / D4 / LA8 MRA components at time t change when Y[t+k] is bumped.
source("docs/audit/tests/_lib.R")

lookahead_profile <- function(mra_fun, y, t0, max_k = 64L) {
  m0 <- mra_fun(y)
  J <- m0$J
  out <- list()
  for (k in 0:max_k) {
    tk <- t0 + k
    if (tk > length(y) || tk < 1L) next
    y2 <- y
    y2[tk] <- y2[tk] + 10
    m2 <- mra_fun(y2)
    row <- list(k = k)
    for (j in seq_len(J)) {
      row[[paste0("D", j)]] <- abs(m2$D[[j]][t0] - m0$D[[j]][t0])
    }
    row$S <- abs(m2$S[t0] - m0$S[t0])
    out[[length(out) + 1L]] <- row
  }
  dplyr::bind_rows(out)
}

max_k_with_effect <- function(prof, col, eps = 1e-10) {
  v <- prof[[col]]
  hit <- which(v > eps)
  if (!length(hit)) return(NA_integer_)
  as.integer(max(prof$k[hit]))
}

set.seed(1)
n <- 512L
y <- as.numeric(stats::arima.sim(list(ar = 0.6), n = n))
t0 <- 200L
J <- 5L

haar_fun <- function(x) haar_mra(x, J)
d4_fun   <- function(x) generic_mra(x, J, "d4")
la8_fun  <- function(x) generic_mra(x, J, "la8")

ph <- lookahead_profile(haar_fun, y, t0)
pd <- lookahead_profile(d4_fun, y, t0)
pl <- lookahead_profile(la8_fun, y, t0)
ph$filter <- "haar"; pd$filter <- "d4"; pl$filter <- "la8"
write_tbl(dplyr::bind_rows(ph, pd, pl), "A1_lookahead_profiles.csv")

haar_D5 <- max_k_with_effect(ph, "D5")
haar_S  <- max_k_with_effect(ph, "S")
d4_D5   <- max_k_with_effect(pd, "D5")
la8_D5  <- max_k_with_effect(pl, "D5")

audit_info("Haar D5 at t0 sees k<=", haar_D5, " future hours; S sees k<=", haar_S)
audit_info("D4 D5 sees k<=", d4_D5, "; LA8 D5 sees k<=", la8_D5)
audit_info("Theory: Haar D_j / S_J at t uses Y up to t+2^j-1; J=5 => 31.")

# Circular wrap: bump the LAST point, see the FIRST point's D, and vice versa.
m0 <- haar_mra(y, J)
y_end <- y; y_end[n] <- y_end[n] + 10
m_end <- haar_mra(y_end, J)
wrap_start <- max(abs(m_end$D$D5[1] - m0$D$D5[1]), abs(m_end$S[1] - m0$S[1]))
y_start <- y; y_start[1] <- y_start[1] + 10
m_start <- haar_mra(y_start, J)
wrap_end <- max(abs(m_start$D$D5[n] - m0$D$D5[n]), abs(m_start$S[n] - m0$S[n]))
audit_info("Wrap: bump Y[n] changes D5/S at t=1 by ", signif(wrap_start, 3),
           "; bump Y[1] changes D5/S at t=n by ", signif(wrap_end, 3))

# How many origin-adjacent training rows are wrap-contaminated at J used.
n_wrap <- 2^J - 1L
audit_info("At J=5, last ", n_wrap, " MRA values mix Y via two-sided/circular filters.",
           " With p=24 lags, every lag of D5/S5 at the origin is contaminated.")

# Invariant we want after a fix: no future Y in the component at t.
audit_ok("A1_haar_no_future", isTRUE(haar_D5 == 0L && haar_S == 0L),
         sprintf("Haar D5/S lookahead hours (want 0, got D5=%s S=%s)", haar_D5, haar_S))
audit_ok("A1_d4_no_future", isTRUE(d4_D5 == 0L),
         sprintf("D4 D5 lookahead hours (want 0, got %s)", d4_D5))
audit_ok("A1_la8_no_future", isTRUE(la8_D5 == 0L),
         sprintf("LA8 D5 lookahead hours (want 0, got %s)", la8_D5))
audit_ok("A1_no_circular_wrap", wrap_start < 1e-12 && wrap_end < 1e-12,
         sprintf("circular wrap effect at ends (want 0, start=%g end=%g)", wrap_start, wrap_end))
