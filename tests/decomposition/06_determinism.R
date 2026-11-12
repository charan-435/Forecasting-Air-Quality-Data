source("tests/decomposition/_lib.R")
old_root <- PROJECT_ROOT
tmp <- tempfile("p1b_det")
ok <- TRUE
msg <- "ok"
tryCatch({
  dir.create(file.path(tmp, "store", "clean"), recursive = TRUE)
  assign("PROJECT_ROOT", tmp, envir = .GlobalEnv)
  sv <- .p1b_synth_sv(160L)
  .p1b_write_clean(sv, tmp)
  cfg <- .p1b_cfg(32L)
  entry <- list(id = "ma_rem", family = "trailing", fn = "decomp_ma_rem",
                additive = TRUE, params = list(window_h = 32L, pad = 0L),
                variables = "pollutants")
  .GlobalEnv$.DECOMP_CFG <- cfg
  run_one_method_scale(sv, entry, decomp_ma_rem, "raw", cfg, "d", force = TRUE)
  p <- decomp_parquet_path("ma_rem__raw", "S", "PM2.5")
  h1 <- digest::digest(file = p, algo = "xxhash64")
  run_one_method_scale(sv, entry, decomp_ma_rem, "raw", cfg, "d", force = TRUE)
  h2 <- digest::digest(file = p, algo = "xxhash64")
  stopifnot(identical(h1, h2))
}, error = function(e) { ok <<- FALSE; msg <<- conditionMessage(e) })
assign("PROJECT_ROOT", old_root, envir = .GlobalEnv)
.GlobalEnv$.DECOMP_CFG <- NULL
unlink(tmp, recursive = TRUE)
p1b_ok("determinism_ma", ok, msg)
