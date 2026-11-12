source("code/tests/decomposition/_lib.R")
old_root <- PROJECT_ROOT
tmp <- tempfile("p1b_dummy")
ok <- TRUE
msg <- "ok"
tryCatch({
  dir.create(file.path(tmp, "data", "processed", "store", "clean"), recursive = TRUE)
  dir.create(file.path(tmp, "code", "config"), recursive = TRUE)
  assign("PROJECT_ROOT", tmp, envir = .GlobalEnv)
  sv <- .p1b_synth_sv(180L)
  .p1b_write_clean(sv, tmp)
  file.copy(file.path(P1B_ORIG_ROOT, "code", "config", "decomp.yaml"),
            file.path(tmp, "code", "config", "decomp.yaml"), overwrite = TRUE)
  cfg <- .p1b_cfg(32L)
  register_decomp_method(list(
    id = "ma_rem", family = "trailing", fn = "decomp_ma_rem",
    additive = TRUE, params = list(window_h = 32L, pad = 0L),
    warmup_rule = "t>=W", variables = "pollutants"
  ))
  cfg <- decomp_cfg()
  cfg$window_h <- 32L
  cfg$screen$horizons <- 1L
  cfg$screen$lgb$nrounds <- 10L
  cfg$methods <- Filter(function(m) m$id == "ma_rem", cfg$methods)
  .GlobalEnv$.DECOMP_CFG <- cfg
  stopifnot(exists("decomp_ma_rem"), length(cfg$methods) == 1L)
  run_one_method_scale(sv, cfg$methods[[1]], decomp_ma_rem, "raw", cfg, "dummy", TRUE)
  d <- get_decomp("S", "PM2.5", "ma_rem", "raw", validity = "basic")
  stopifnot(all(c("MA", "REM") %in% names(d)))
  x <- sv$value_filled_causal
  wu <- d$valid_warmup
  err <- max(abs(d$MA[wu] + d$REM[wu] - x[wu]), na.rm = TRUE)
  stopifnot(err < 1e-8)
  d1 <- d1_pass_synthetic(cfg$methods[[1]], decomp_ma_rem, "raw")
  stopifnot(isTRUE(d1))
  scr <- run_decomp_screen(cfg = cfg, long = sv)
  stopifnot(!is.null(scr))
}, error = function(e) { ok <<- FALSE; msg <<- conditionMessage(e) })
assign("PROJECT_ROOT", old_root, envir = .GlobalEnv)
.GlobalEnv$.DECOMP_CFG <- NULL
unlink(tmp, recursive = TRUE)
p1b_ok("dummy_pluggable", ok, msg)
