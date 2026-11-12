if (!isTRUE(get0(".P1B_LIB", ifnotfound = FALSE))) {
  if (!file.exists("code/R/load_all.R")) stop("Run the test from the repository root.")
  source("code/R/load_all.R")
  P1B_FAILS <<- character()
  P1B_PASSES <<- character()
  p1b_ok <- function(id, cond, msg) {
    ok <- isTRUE(cond)
    cat(sprintf("%s %s: %s\n", if (ok) "PASS" else "FAIL", id, msg))
    if (ok) P1B_PASSES <<- c(P1B_PASSES, id) else P1B_FAILS <<- c(P1B_FAILS, id)
    ok
  }
  .P1B_LIB <- TRUE
  P1B_ORIG_ROOT <<- PROJECT_ROOT
}

.p1b_synth_sv <- function(n = 300L, W = 64L) {
  tz <- "UTC"
  times <- seq(as.POSIXct("2023-01-01 00:00:00", tz = tz), by = "hour", length.out = n)
  y <- pmax(20 + 5 * sin(2 * pi * seq_len(n) / 24) + rnorm(n, 0, 0.3), 0)
  tibble::tibble(
    station = "S", variable = "PM2.5", timestamp = times,
    value_filled_causal = y, fill_method = NA_character_,
    frac_filled_24h = 0, in_long_gap = FALSE,
    is_scorable = TRUE, hours_since_observed = 0
  )
}

.p1b_write_clean <- function(sv, root = PROJECT_ROOT) {
  dir.create(file.path(root, "data", "processed", "store", "clean"), recursive = TRUE, showWarnings = FALSE)
  sv$value_filled_causal <- as.numeric(sv$value_filled_causal)
  sv$frac_filled_24h <- as.numeric(sv$frac_filled_24h)
  sv$hours_since_observed <- as.numeric(sv$hours_since_observed)
  path <- file.path(root, "data", "processed", "store", "clean", "series.parquet")
  write_decomp_parquet(sv, path)
  yaml::write_yaml(list(exclude_training_row_if_frac_filled_24h_gt = 0.5),
                   file.path(root, "data", "processed", "store", "clean", "policy.yaml"))
}

.p1b_cfg <- function(window_h = 64L) {
  cfg <- decomp_cfg(file.path(P1B_ORIG_ROOT, "code", "config", "decomp.yaml"))
  cfg$window_h <- window_h
  cfg$checkpoint_every <- 8L
  cfg$n_benchmark_windows <- 5L
  cfg$n_d3_samples <- 8L
  cfg$d3_horizon <- 16L
  cfg$screen$horizons <- c(1L, 6L)
  cfg$screen$lookback_days <- 5
  cfg$screen$lgb$nrounds <- 20L
  cfg$screen$bootstrap_reps <- 21L
  cfg$selection_end <- "2023-01-12 00:00"
  cfg$max_hours_per_method_scale <- 6
  cfg
}
