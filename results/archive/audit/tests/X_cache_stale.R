# Cache key ignores J, p, nrounds, filter, and code version.
source("docs/audit/tests/_lib.R")

exp <- paste(readLines("scripts/experiments/run_experiments.R"), collapse = "\n")
key_line <- grepl("key <- paste\\(s\\$sensor, s\\$pollutant, hn, m, sep = \"\\|\"\\)", exp)

cache <- readRDS(file.path(RES_DIR, "forecast_cache.rds"))
scores <- readRDS(file.path(RES_DIR, "scores.rds"))
info <- file.info(file.path(RES_DIR, "forecast_cache.rds"),
                  file.path("R", "06_models.R"),
                  file.path("R", "04_modwt.R"),
                  file.path("R", "03_preprocess.R"),
                  file.path(RES_DIR, "scores.csv"))
write_tbl(tibble::tibble(file = rownames(info), mtime = as.character(info$mtime),
                         size = info$size),
          "X_cache_mtimes.csv")
print(info[, c("mtime", "size")])

n_fb <- sum(vapply(cache, function(z) isTRUE(z$fallback), logical(1)))
keys_have_filter <- any(grepl("\\|haar$|\\|d4$", names(cache)))

audit_info("cache entries=", length(cache), " scores rows=", nrow(scores),
           " fallback flags=", n_fb)

audit_ok("X_cache_key_includes_hparams_or_code_hash", !key_line,
         "forecast_cache key is sensor|pollutant|horizon|method — no J, p, nrounds, git sha")
audit_ok("X_model_code_not_newer_than_cache",
         info["R/core/06_models.R", "mtime"] <= info[file.path(RES_DIR, "forecast_cache.rds"), "mtime"],
         sprintf("R/core/06_models.R mtime=%s cache mtime=%s",
                 info["R/core/06_models.R", "mtime"],
                 info[file.path(RES_DIR, "forecast_cache.rds"), "mtime"]))
