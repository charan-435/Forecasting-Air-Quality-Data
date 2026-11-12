source("tests/preprocessing/_lib.R")
path <- file.path(PROJECT_ROOT, "store", "clean", "series.parquet")
if (!file.exists(path)) {
  p1a_ok("scoring_guard_skip", TRUE, "no series.parquet yet — run preprocess first (checked in 08/09)")
} else {
  d <- tibble::as_tibble(arrow::read_parquet(path))
  bad <- !is.na(d$fill_method) & d$is_scorable
  p1a_ok("scoring_guard", !any(bad),
         sprintf("rows with fill_method and is_scorable: %d", sum(bad)))
}
