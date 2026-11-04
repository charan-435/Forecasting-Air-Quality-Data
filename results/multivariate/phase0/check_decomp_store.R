# Phase 0 read-only check of a stored decomposition against store/clean.
# Writes one new CSV and changes nothing else.
#
#   Rscript results/multivariate/phase0/check_decomp_store.R
#   Rscript results/multivariate/phase0/check_decomp_store.R mra_haar_J5__raw CPCB
#
# Run from the project root. Needs arrow, jsonlite, yaml, dplyr.

args <- commandArgs(trailingOnly = TRUE)
method_full <- if (length(args) >= 1) args[1] else "mra_haar_J5__raw"
station <- if (length(args) >= 2) args[2] else "CPCB"
n_recompute <- 30L
if (!file.exists("R/04_modwt.R")) stop("Run from the project root.")

suppressPackageStartupMessages({
  library(arrow); library(jsonlite); library(yaml); library(dplyr)
})
`%||%` <- function(a, b) if (is.null(a)) b else a
PROJECT_ROOT <- normalizePath(".")
for (f in c("R/04_modwt.R", "R/30_decomp_registry.R", "R/32_decomp_trailing.R"))
  sys.source(f, envir = .GlobalEnv)

pols <- c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO")
method_id <- sub("__(raw|log)$", "", method_full)
scale <- sub("^.*__", "", method_full)
cfg <- yaml::read_yaml("config/decomp.yaml")
.GlobalEnv$.DECOMP_CFG <- cfg
entry <- Filter(function(m) identical(m$id, method_id), cfg$methods)
if (!length(entry)) stop("method ", method_id, " not in config/decomp.yaml")
entry <- entry[[1]]
fn <- get(entry$fn)
W <- as.integer(entry$params$window_h %||% cfg$window_h)
J <- as.integer(entry$params$J)
comps <- decomp_component_names(entry)

to_ist <- function(x) {
  x <- as.POSIXct(x)
  attr(x, "tzone") <- "Asia/Kolkata"
  x
}

clean <- as.data.frame(arrow::read_parquet("store/clean/series.parquet"))
clean <- clean[clean$station == station, ]
clean$timestamp <- to_ist(clean$timestamp)

man_path <- file.path("store", "decomp", "manifests", paste0(method_full, ".json"))
man <- if (file.exists(man_path)) jsonlite::fromJSON(man_path) else NULL
cur_hash <- tryCatch(decomp_input_hash(cfg), error = function(e) NA_character_)

rows <- list()
ts_ref <- NULL
for (p in pols) {
  path <- file.path("store", "decomp", paste0("method=", method_full),
                    paste0("station=", station), paste0("variable=", p, ".parquet"))
  sv <- clean[clean$variable == p, ]
  sv <- sv[order(sv$timestamp), ]
  r <- list(variable = p, method_full = method_full, station = station,
            file = path, file_exists = file.exists(path))
  if (!file.exists(path)) {
    rows[[p]] <- as.data.frame(r)
    next
  }
  d <- as.data.frame(arrow::read_parquet(path))
  d$timestamp <- to_ist(d$timestamp)
  x <- apply_decomp_scale(sv$value_filled_causal, scale, p)
  have <- intersect(comps, names(d))
  M <- as.matrix(d[, have, drop = FALSE])
  ok_rows <- stats::complete.cases(M)
  first_ok <- which(ok_rows)[1]
  same_len <- nrow(d) == nrow(sv)
  r$components_expected <- paste(comps, collapse = ",")
  r$components_found <- paste(have, collapse = ",")
  r$components_ok <- identical(have, comps)
  r$n_rows_decomp <- nrow(d)
  r$n_rows_clean <- nrow(sv)
  r$timestamps_match_clean <- same_len && isTRUE(all(d$timestamp == sv$timestamp))
  r$timestamps_match_PM25_file <- if (is.null(ts_ref)) NA else
    (length(ts_ref) == nrow(d) && isTRUE(all(ts_ref == d$timestamp)))
  if (identical(p, "PM2.5")) ts_ref <- d$timestamp
  r$n_warmup_na_rows <- sum(!ok_rows)
  r$first_valid_ts <- if (is.na(first_ok)) NA else format(d$timestamp[first_ok], "%Y-%m-%d %H:%M")
  r$warmup_matches_window <- isTRUE(first_ok == W) && all(ok_rows[seq.int(W, nrow(d))])
  r$valid_warmup_flag_consistent <- "valid_warmup" %in% names(d) &&
    isTRUE(all(as.logical(d$valid_warmup) == ok_rows))
  r$n_valid_strict_differs_from_basic <- if (all(c("valid_strict", "valid_basic") %in% names(d)))
    sum(as.logical(d$valid_strict) != as.logical(d$valid_basic), na.rm = TRUE) else NA
  if (same_len) {
    err <- abs(rowSums(M) - x)
    r$max_additivity_error <- max(err[ok_rows])
  } else r$max_additivity_error <- NA
  # stored values vs a fresh causal recomputation at sampled t (detects stale/two-sided stores)
  if (same_len && !is.na(first_ok)) {
    set.seed(7)
    pool <- which(ok_rows)
    tt <- sort(sample(pool, min(n_recompute, length(pool))))
    dev <- vapply(tt, function(t) {
      fresh <- .decomp_at_t(x, t, entry, fn, W)
      max(abs(fresh - M[t, ]))
    }, numeric(1))
    r$max_abs_diff_vs_fresh_trailing_recompute <- max(dev)
  } else r$max_abs_diff_vs_fresh_trailing_recompute <- NA
  rows[[p]] <- as.data.frame(r)
}
res <- dplyr::bind_rows(rows)
res$manifest_exists <- !is.null(man)
res$manifest_partial <- if (is.null(man)) NA else isTRUE(man$partial)
res$manifest_family <- if (is.null(man)) NA else man$family %||% NA
res$manifest_J <- if (is.null(man)) NA else man$params$J %||% NA
res$manifest_filter <- if (is.null(man)) NA else man$params$filter %||% NA
res$manifest_variables <- if (is.null(man)) NA else paste(man$variables, collapse = ",")
res$manifest_input_hash_matches_current <- if (is.null(man)) NA else
  identical(man$input_hash, cur_hash)
res$manifest_max_additivity_error <- if (is.null(man)) NA else man$max_additivity_error %||% NA

out <- file.path("results", "multivariate", "phase0",
                 paste0("decomposition_store_check_", method_full, "_", station, ".csv"))
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
write.csv(res, out, row.names = FALSE)
print(res[, c("variable", "file_exists", "components_ok", "timestamps_match_clean",
              "n_warmup_na_rows", "first_valid_ts", "max_additivity_error",
              "max_abs_diff_vs_fresh_trailing_recompute")])
cat("wrote", out, "\n")
