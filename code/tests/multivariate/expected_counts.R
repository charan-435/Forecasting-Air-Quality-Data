# Independent expected sample counts for the S3 split, unmasked policy.
# Uses only the calendar strings in code/config/multivariate.yaml and clock
# arithmetic (strptime + seconds). It does not use the panel, row indices or
# any function from R/40-R/44, so it can check them.

mv_expected_counts <- function(cfg) {
  tz <- cfg$data$timezone
  P <- function(s) as.numeric(as.POSIXct(strptime(s, "%Y-%m-%d %H:%M", tz = tz)))
  F <- function(x) format(as.POSIXct(x, origin = "1970-01-01", tz = tz), "%Y-%m-%d %H:%M")
  hr <- 3600
  b <- cfg$split$blocks
  first <- c(train = P(cfg$split$first_origin),
             validation = P(b$validation$start), test = P(b$test$start))
  rows <- list()
  for (h in as.integer(unlist(cfg$horizons))) {
    for (k in c("train", "validation", "test")) {
      end <- P(b[[k]]$end)
      last_origin <- end - h * hr
      n <- if (last_origin >= first[[k]]) (last_origin - first[[k]]) / hr + 1 else 0
      rows[[length(rows) + 1L]] <- data.frame(
        horizon_h = h, block = k,
        expected_eligible_origins = (end - first[[k]]) / hr + 1,
        expected_samples = n,
        expected_first_origin = F(first[[k]]), expected_last_origin = F(last_origin),
        expected_first_target = F(first[[k]] + h * hr), expected_last_target = F(end),
        stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}
