# Checks that a stopped component run can resume from its saved checkpoint.

source("code/tests/decomposition/_lib.R")
old_root <- PROJECT_ROOT
tmp <- tempfile("p1b_resume")
ok <- TRUE
msg <- "ok"
tryCatch({
  dir.create(file.path(tmp, "data", "processed", "store", "clean"), recursive = TRUE)
  dir.create(file.path(tmp, "code", "config"), recursive = TRUE)
  assign("PROJECT_ROOT", tmp, envir = .GlobalEnv)
  sv <- .p1b_synth_sv(120L)
  .p1b_write_clean(sv, tmp)
  file.copy(file.path(P1B_ORIG_ROOT, "code", "config", "decomp.yaml"),
            file.path(tmp, "code", "config", "decomp.yaml"), overwrite = TRUE)
  cfg <- .p1b_cfg(32L)
  cfg$checkpoint_every <- 8L
  entry <- list(id = "ma_rem", family = "trailing", fn = "decomp_ma_rem",
                additive = TRUE, params = list(window_h = 32L, pad = 0L),
                warmup_rule = "t>=W", variables = "pollutants")
  .GlobalEnv$.DECOMP_CFG <- cfg
  hash_of <- function() {
    digest::digest(file = decomp_parquet_path("ma_rem__raw", "S", "PM2.5"),
                   algo = "xxhash64")
  }
  run_one_method_scale(sv, entry, decomp_ma_rem, "raw", cfg, "h1", force = TRUE)
  h_full <- hash_of()
  unlink(decomp_parquet_path("ma_rem__raw", "S", "PM2.5"))
  .GlobalEnv$.DECOMP_STOP_AFTER <- 50L
  tryCatch(run_one_method_scale(sv, entry, decomp_ma_rem, "raw", cfg, "h1", force = TRUE),
           error = function(e) invisible(NULL))
  .GlobalEnv$.DECOMP_STOP_AFTER <- NULL
  run_one_method_scale(sv, entry, decomp_ma_rem, "raw", cfg, "h1", force = TRUE)
  stopifnot(identical(h_full, hash_of()))
}, error = function(e) { ok <<- FALSE; msg <<- conditionMessage(e) })
.GlobalEnv$.DECOMP_STOP_AFTER <- NULL
assign("PROJECT_ROOT", old_root, envir = .GlobalEnv)
.GlobalEnv$.DECOMP_CFG <- NULL
unlink(tmp, recursive = TRUE)
p1b_ok("resume_hash", ok, msg)
