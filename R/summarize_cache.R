# Rebuild scores.csv from the resume cache (safe to run while experiments continue).

root <- getwd()
if (!file.exists(file.path(root, "results", "forecast_cache.rds"))) {
  stop("No forecast cache yet.")
}
source("R/load_all.R")
cache <- readRDS(file.path(RES_DIR, "forecast_cache.rds"))
n_err <- sum(vapply(cache, function(z) isTRUE(z$error), logical(1)))
scores <- dplyr::bind_rows(lapply(cache, function(z) {
  if (isTRUE(z$error) || is.null(z$scores)) return(NULL)
  dplyr::bind_cols(
    tibble::tibble(sensor = z$sensor, pollutant = z$pollutant,
                   horizon = z$horizon, method = z$method, elapsed = z$elapsed),
    z$scores
  )
}))
saveRDS(scores, file.path(RES_DIR, "scores.rds"))
readr::write_csv(scores, file.path(RES_DIR, "scores.csv"))
cat("Cached jobs:", length(cache), " errors:", n_err, " scored:", nrow(scores), "\n")
if (nrow(scores)) {
  print(scores %>%
          dplyr::count(pollutant, horizon) %>%
          dplyr::arrange(pollutant, horizon))
}
