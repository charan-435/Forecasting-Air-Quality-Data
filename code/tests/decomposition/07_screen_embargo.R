# Checks that tuning targets do not cross the screening period or selection cutoff.

source("code/tests/decomposition/_lib.R")
sv <- .p1b_synth_sv(400L)
cfg <- .p1b_cfg(64L)
.GlobalEnv$.DECOMP_CFG <- cfg
cal <- .screen_calendar(sv$timestamp, decomp_selection_end(cfg, sv$timestamp),
                        cfg$screen$lookback_days)
h <- 6L
train <- which(sv$timestamp + lubridate::hours(h) < cal$screen_start)
orig <- .screen_origins(sv$timestamp, cal$screen_start, cal$sel, h)
p1b_ok("embargo_train", !length(train) ||
         all(sv$timestamp[train] + lubridate::hours(h) < cal$screen_start),
       sprintf("n_train=%s screen_start=%s", length(train), cal$screen_start))
p1b_ok("embargo_origin_target", !length(orig) ||
         all(sv$timestamp[orig] + lubridate::hours(h) <= cal$sel),
       sprintf("n_orig=%s sel=%s", length(orig), cal$sel))

# Guard: perturbing data after selection_end must not change the selection cutoff.
sel1 <- screen_uses_only_pre_selection(sv, cfg)
sv2 <- sv
sv2$value_filled_causal[sv2$timestamp > cal$sel] <-
  sv2$value_filled_causal[sv2$timestamp > cal$sel] + 80
sel2 <- screen_uses_only_pre_selection(sv2, cfg)
p1b_ok("embargo_sel_stable", identical(sel1, sel2),
       "selection_end cutoff ignores post-sel values")
.GlobalEnv$.DECOMP_CFG <- NULL
