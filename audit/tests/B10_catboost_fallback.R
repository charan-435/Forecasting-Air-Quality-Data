# B10: did catboost / wavecatboost rows actually use CatBoost?
source("audit/tests/_lib.R")

cache <- readRDS(file.path(RES_DIR, "forecast_cache.rds"))
rows <- lapply(cache, function(z) {
  if (is.null(z$method)) return(NULL)
  tibble::tibble(
    key = paste(z$sensor, z$pollutant, z$horizon, z$method, sep = "|"),
    method = z$method,
    fallback = isTRUE(z$fallback),
    error = isTRUE(z$error),
    elapsed = if (is.null(z$elapsed)) NA_real_ else z$elapsed
  )
})
tab <- dplyr::bind_rows(rows)
cb <- dplyr::filter(tab, method %in% c("catboost", "wavecatboost"), !error)
write_tbl(cb, "B10_catboost_fallback_flags.csv")

n_fb <- sum(cb$fallback)
n_cb <- nrow(cb)
audit_info("catboost/wavecatboost cached jobs: ", n_cb, " fallback=TRUE: ", n_fb)
audit_info("CATBOOST_AVAILABLE now: ", isTRUE(get0("CATBOOST_AVAILABLE", ifnotfound = FALSE)))
audit_info("median elapsed catboost=",
           round(median(cb$elapsed[cb$method == "catboost"], na.rm = TRUE), 2),
           " wavecatboost=",
           round(median(cb$elapsed[cb$method == "wavecatboost"], na.rm = TRUE), 2),
           " xgb=",
           round(median(tab$elapsed[tab$method == "xgb"], na.rm = TRUE), 2))

audit_ok("B10_no_silent_xgb_fallback", n_fb == 0,
         sprintf("%s / %s catboost-family cache rows have fallback=TRUE", n_fb, n_cb))
audit_ok("B10_catboost_package_present",
         isTRUE(get0("CATBOOST_AVAILABLE", ifnotfound = FALSE)),
         "CATBOOST_AVAILABLE is TRUE in this session")
