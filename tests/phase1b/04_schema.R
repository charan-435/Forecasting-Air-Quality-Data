source("tests/phase1b/_lib.R")
old_root <- PROJECT_ROOT
tmp <- tempfile("p1b_schema")
ok <- TRUE
msg <- "ok"
tryCatch({
  dir.create(file.path(tmp, "store", "decomp", "manifests"), recursive = TRUE)
  assign("PROJECT_ROOT", tmp, envir = .GlobalEnv)
  sv <- .p1b_synth_sv(256L)
  cfg <- .p1b_cfg(64L)
  entry <- list(id = "coef_haar_J10", family = "causal_full", fn = "decomp_coef_haar",
                additive = TRUE, params = list(J = 5L, filter = "haar"),
                warmup_rule = "L_j Haar", variables = "pollutants")
  .GlobalEnv$.DECOMP_CFG <- cfg
  res <- compute_decomp_series(sv, entry, decomp_coef_haar, "raw", cfg)
  need <- c("timestamp", "valid_warmup", "valid_basic", "valid_strict",
            "frac_filled_window", paste0("W", 1:5), paste0("V", 1:5))
  stopifnot(all(need %in% names(res$df)))
  write_decomp_parquet(res$df, decomp_parquet_path("coef_haar_J10__raw", "S", "PM2.5"))
  write_decomp_manifest(entry, "raw", cfg, "test",
                        list(list(station = "S", variable = "PM2.5")),
                        FALSE, 0, res$max_add)
  d <- tibble::as_tibble(arrow::read_parquet(
    decomp_parquet_path("coef_haar_J10__raw", "S", "PM2.5")))
  stopifnot(all(need %in% names(d)))
  man <- jsonlite::fromJSON(decomp_manifest_path("coef_haar_J10__raw"))
  stopifnot(isTRUE(man$causal), identical(man$family, "causal_full"))
}, error = function(e) { ok <<- FALSE; msg <<- conditionMessage(e) })
assign("PROJECT_ROOT", old_root, envir = .GlobalEnv)
.GlobalEnv$.DECOMP_CFG <- NULL
unlink(tmp, recursive = TRUE)
p1b_ok("schema_coef_haar", ok, msg)
