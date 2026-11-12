# Export the saved interval arrays without loading models or installing packages.
# The Python report-figure script calls this helper with cache and output paths.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: Rscript export_conformal_cache.R <conformal.rds> <output-directory>")
}

cache <- readRDS(args[1])
dir.create(args[2], recursive = TRUE, showWarnings = FALSE)
for (sensor in names(cache)) {
  result <- cache[[sensor]]
  # Bounds and point predictions must refer to the same ordered test hours.
  predictions <- data.frame(
    y_test = result$y_test,
    yhat = result$yhat,
    lower = result$lower,
    upper = result$upper
  )
  metadata <- data.frame(
    kappa = result$kappa,
    coverage_cal = result$coverage_cal,
    coverage_test = result$coverage_test,
    width = result$width
  )
  write.csv(predictions, file.path(args[2], paste0(sensor, ".csv")), row.names = FALSE)
  write.csv(metadata, file.path(args[2], paste0(sensor, "_meta.csv")), row.names = FALSE)
}
