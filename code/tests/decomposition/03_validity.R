# Checks which component rows are usable after warmup and filled-input rules.

source("code/tests/decomposition/_lib.R")
sv <- .p1b_synth_sv(200L)
sv$fill_method[50:80] <- "M1"
sv$frac_filled_24h[60:90] <- 0.8
sv$in_long_gap[100:110] <- TRUE
entry <- list(id = "coef_haar_J10", family = "causal_full", fn = "decomp_coef_haar",
              additive = TRUE, params = list(J = 5L, filter = "haar"),
              variables = "pollutants")
cfg <- .p1b_cfg()
res <- compute_decomp_series(sv, entry, decomp_coef_haar, "raw", cfg)
df <- res$df
p1b_ok("valid_strict_subset", all(df$valid_strict[df$valid_strict] %in% TRUE) &&
         all(df$valid_strict <= df$valid_basic),
       "valid_strict ⊆ valid_basic")
p1b_ok("valid_basic_eq_warmup", isTRUE(all(df$valid_basic == df$valid_warmup)),
       "valid_basic = valid_warmup")
# hours 60-90 have frac_filled_24h = 0.8 > 0.5 so strict is false where warmup is true
p1b_ok("valid_strict_fill_policy", !any(df$valid_strict[60:90]),
       "frac_filled_24h > 0.5 drops strict")
p1b_ok("valid_strict_long_gap", !any(df$valid_strict[100:110]),
       "in_long_gap drops strict")
p1b_ok("frac_filled_window", "frac_filled_window" %in% names(df) &&
         isTRUE(df$frac_filled_window[80] > 0),
       "frac_filled_window tracks filled support")
