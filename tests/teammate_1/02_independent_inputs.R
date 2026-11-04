# Independent models may only see lags of the target component.

set.seed(7)
n <- 200L
p <- 24L
D1 <- sin(2 * pi * seq_len(n) / 8) + rnorm(n, 0, 0.01)
D2 <- 50 + sin(2 * pi * seq_len(n) / 24)
X <- t1_independent_lags(D1, p)

t1_ok("T1-02a", identical(colnames(X), paste0("lag", seq_len(p))),
      "lag matrix columns are lag1..lagp only")
t1_ok("T1-02b", isTRUE(attr(X, "t1_source_is_univariate")),
      "builder marks the design as univariate")
t1_ok("T1-02c", ncol(X) == p, "feature count equals p, not 6*p")

# Plant a unique D2 spike. Independent D1 lags must not contain 50-ish D2 mean.
lag_means <- colMeans(X, na.rm = TRUE)
t1_ok("T1-02d", max(abs(lag_means - mean(D2))) > 10,
      "D1 lags are not D2 values")

t1_ok("T1-02e", isTRUE(all.equal(as.numeric(X[p + 1L, 1]), as.numeric(D1[p]),
                                 check.attributes = FALSE)),
      "lag1 equals previous D1 (no future, no other band)")
t1_ok("T1-02f", isTRUE(all.equal(as.numeric(X[50L, 1]), as.numeric(D1[49L]),
                                 check.attributes = FALSE)),
      "X[50, lag1] == D1[49]")
t1_ok("T1-02g", isTRUE(all.equal(as.numeric(X[p + 1L, p]), as.numeric(D1[1L]),
                                 check.attributes = FALSE)),
      "X[p+1, lagp] == D1[1]")

src <- readLines("R/teammate_1/t1_pipeline.R")
t1_ok("T1-02h",
      any(grepl("t1_independent_lags\\(y_hist", src)),
      "fit path builds lags from y_hist of one component")
t1_ok("T1-02i",
      !any(grepl("cbind\\(.*D1.*D2|get_decomp_multi", src)),
      "pipeline does not cbind other frequency bands as features")
