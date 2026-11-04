source("tests/phase1b/_lib.R")
set.seed(3)
sv <- .p1b_synth_sv(512L)
x <- sv$value_filled_causal
# Haar pyramid identity on valid rows for J = 1..5
M <- decomp_coef_haar(x, list(J = 5L))
ok <- TRUE
msg <- "ok"
for (j in 1:5) {
  hat <- rowSums(M[, c(paste0("W", seq_len(j)), paste0("V", j)), drop = FALSE])
  wu <- seq_along(x) >= warmup_length(j, 2L)
  err <- max(abs(hat - x)[wu], na.rm = TRUE)
  if (!is.finite(err) || err > 1e-10) {
    ok <- FALSE
    msg <- sprintf("J=%s err=%s", j, err)
  }
}
p1b_ok("d2_haar_pyramid", ok, msg)

mra <- decomp_mra_haar(x, list(J = 5L))
hat <- rowSums(mra)
p1b_ok("d2_mra_haar", max(abs(hat - x), na.rm = TRUE) < 1e-8,
       sprintf("mra reconstr err=%s", max(abs(hat - x))))

ma <- decomp_ma_rem(x)
p1b_ok("d2_ma_rem", max(abs(ma[, "MA"] + ma[, "REM"] - x)) < 1e-12, "dummy additive")
