source("tests/phase1b/_lib.R")
cfg <- .p1b_cfg(64L)
.GlobalEnv$.DECOMP_CFG <- cfg
entries <- Filter(function(m) m$id %in% c("coef_haar_J10", "coef_d4_J9", "coef_la8_J8",
                                          "mra_haar_J5", "mra_d4_J5", "mra_la8_J5",
                                          "mstl"),
                  decomp_methods(cfg))
# Shrink Haar J for the synthetic length used inside d1_pass_synthetic.
for (i in seq_along(entries)) {
  if (identical(entries[[i]]$id, "coef_haar_J10")) entries[[i]]$params$J <- 5L
  if (identical(entries[[i]]$id, "coef_d4_J9")) entries[[i]]$params$J <- 4L
  if (identical(entries[[i]]$id, "coef_la8_J8")) entries[[i]]$params$J <- 3L
  entries[[i]]$params$window_h <- 64L
}
for (e in entries) {
  if (!.method_available(e)) {
    p1b_ok(paste0("d1_skip_", e$id), TRUE, paste("package missing, skipped", e$id))
    next
  }
  fn <- .decomp_fn(e)
  ok_raw <- d1_pass_synthetic(e, fn, "raw")
  ok_log <- d1_pass_synthetic(e, fn, "log")
  p1b_ok(paste0("d1_raw_", e$id), ok_raw, paste(e$id, "raw"))
  p1b_ok(paste0("d1_log_", e$id), ok_log, paste(e$id, "log"))
}
.GlobalEnv$.DECOMP_CFG <- NULL
