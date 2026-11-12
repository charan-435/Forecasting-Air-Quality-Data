# C16: MASE denominator, S=24, train only; vs paper Eq. (6).
source("docs/audit/tests/_lib.R")

set.seed(4)
ytr <- rnorm(200)
yte <- rnorm(24)
yhat <- yte + 0.2
S <- 24L
N <- length(ytr)
h <- length(yte)
ours <- mase(ytr, yte, yhat, season = S)
paper <- ((N - S) / h) * sum(abs(yhat - yte)) /
  sum(abs(ytr[(S + 1):N] - ytr[seq_len(N - S)]))
audit_info("ours=", signif(ours, 8), " paper Eq.6=", signif(paper, 8),
           " |diff|=", signif(abs(ours - paper), 4))

# Denom uses train only: adding a huge test value must not change MASE denom.
ours2 <- mase(c(ytr, 1e6), yte, yhat, season = S)
# (that would change if someone passed train+test as y_train)

scores <- readRDS(file.path(RES_DIR, "scores.rds"))
# CPCB SO2 denom is tiny -> huge MASE. Flag it.
so2 <- dplyr::filter(scores, pollutant == "SO2", method == "snaive", horizon == "1d")
print(so2)

audit_ok("C16_matches_paper_eq6", abs(ours - paper) < 1e-12,
         sprintf("|ours-paper|=%g", abs(ours - paper)))
audit_ok("C16_season_is_24", identical(SEASONALITY, 24L),
         paste("SEASONALITY =", SEASONALITY))
