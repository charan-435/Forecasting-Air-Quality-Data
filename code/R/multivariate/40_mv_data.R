# Multivariate data layer (Phase 1). Reads data/processed/store/clean only, never writes it.
# No quality mask: every aligned hour is kept (config quality_mask: none).
# Self-contained: does not source R/00 to R/35.

`%||%` <- function(a, b) if (is.null(a)) b else a

mv_root <- function(root = NULL) {
  if (!is.null(root)) return(normalizePath(root, mustWork = TRUE))
  normalizePath(getwd(), mustWork = TRUE)
}

# Locale-independent YAML reader (config files contain UTF-8 comments).
mv_read_yaml <- function(path) {
  txt <- rawToChar(readBin(path, "raw", file.size(path)))
  Encoding(txt) <- "UTF-8"
  yaml::yaml.load(txt)
}

mv_cfg <- function(path = "code/config/multivariate.yaml", root = NULL) {
  p <- file.path(mv_root(root), path)
  if (!file.exists(p)) stop("Missing config: ", p)
  cfg <- mv_read_yaml(p)
  if (!identical(cfg$quality_mask, "none"))
    stop("Phase 1 primary experiment requires quality_mask: none (got '",
         format(cfg$quality_mask), "').")
  cfg
}

mv_parse_ts <- function(x, tz = "Asia/Kolkata") {
  out <- as.POSIXct(as.character(x), tz = tz, format = "%Y-%m-%d %H:%M")
  if (anyNA(out)) stop("Could not parse timestamp(s): ", paste(x[is.na(out)], collapse = ", "))
  out
}

mv_fmt_ts <- function(x, tz = "Asia/Kolkata") format(x, "%Y-%m-%d %H:%M", tz = tz)

# arrow is the project reader; nanoparquet is accepted when arrow is absent.
mv_read_parquet <- function(path) {
  if (requireNamespace("arrow", quietly = TRUE)) {
    df <- as.data.frame(arrow::read_parquet(path))
    attr(df, "reader") <- paste0("arrow ", utils::packageVersion("arrow"))
  } else if (requireNamespace("nanoparquet", quietly = TRUE)) {
    df <- as.data.frame(nanoparquet::read_parquet(path))
    attr(df, "reader") <- paste0("nanoparquet ", utils::packageVersion("nanoparquet"))
  } else {
    stop("Install arrow (or nanoparquet) to read ", path)
  }
  df
}

# Hash the file bytes. Some Windows sessions report the wrong file.access value.
# readBin still reports a clear error if the file cannot be read.
mv_file_sha256 <- function(path) {
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

.mv_fail <- function(...) stop("[mv data check] ", ..., call. = FALSE)

# Load the six pollutant series, verify them, and join on the timestamp instant.
# Returns list(times, X, checks, source).
mv_load_panel <- function(cfg, root = NULL) {
  root <- mv_root(root)
  path <- file.path(root, cfg$data$source)
  if (!file.exists(path)) .mv_fail("missing ", path)
  long <- mv_read_parquet(path)
  reader <- attr(long, "reader")
  need <- c("station", "variable", "timestamp", cfg$data$value_column)
  miss <- setdiff(need, names(long))
  if (length(miss)) .mv_fail("store is missing columns: ", paste(miss, collapse = ", "))
  long <- long[as.character(long$station) == cfg$data$station, , drop = FALSE]
  pols <- unlist(cfg$data$pollutants)
  tz <- cfg$data$timezone %||% "Asia/Kolkata"

  checks <- list()
  add <- function(name, ok, detail) {
    checks[[length(checks) + 1L]] <<- data.frame(check = name, pass = isTRUE(ok),
                                                  detail = detail, stringsAsFactors = FALSE)
    if (!isTRUE(ok)) .mv_fail(name, ": ", detail)
  }

  inst <- list(); vals <- list()
  for (p in pols) {
    sv <- long[as.character(long$variable) == p, , drop = FALSE]
    add(paste0("present:", p), nrow(sv) > 0, sprintf("%d rows", nrow(sv)))
    secs <- as.numeric(as.POSIXct(sv$timestamp))
    v <- as.numeric(sv[[cfg$data$value_column]])
    add(paste0("no_duplicate_timestamps:", p), !anyDuplicated(secs),
        sprintf("%d duplicated", sum(duplicated(secs))))
    o <- order(secs)
    add(paste0("chronological_in_store:", p), identical(o, seq_along(o)),
        if (identical(o, seq_along(o))) "already sorted" else "store rows not sorted")
    secs <- secs[o]; v <- v[o]
    add(paste0("n_hours:", p), length(secs) == cfg$data$expected_n_hours,
        sprintf("%d (expected %d)", length(secs), cfg$data$expected_n_hours))
    add(paste0("regular_hourly:", p), all(diff(secs) == 3600),
        sprintf("%d steps differ from 3600 s", sum(diff(secs) != 3600)))
    add(paste0("no_missing_values:", p), all(is.finite(v)),
        sprintf("%d non-finite", sum(!is.finite(v))))
    inst[[p]] <- secs; vals[[p]] <- v
  }
  ref <- inst[[pols[1]]]
  for (p in pols[-1]) {
    add(paste0("timestamps_identical:", pols[1], "~", p), identical(inst[[p]], ref),
        if (identical(inst[[p]], ref)) "identical instants" else
          sprintf("%d differ", sum(inst[[p]] != ref)))
  }
  # Join by instant: match each series to the reference instants.
  X <- matrix(NA_real_, length(ref), length(pols), dimnames = list(NULL, pols))
  for (p in pols) {
    m <- match(ref, inst[[p]])
    add(paste0("join_complete:", p), !anyNA(m), sprintf("%d unmatched", sum(is.na(m))))
    X[, p] <- vals[[p]][m]
  }
  times <- as.POSIXct(ref, origin = "1970-01-01", tz = tz)
  add("start", identical(mv_fmt_ts(times[1], tz), cfg$data$expected_start),
      mv_fmt_ts(times[1], tz))
  add("end", identical(mv_fmt_ts(times[length(times)], tz), cfg$data$expected_end),
      mv_fmt_ts(times[length(times)], tz))

  list(times = times, X = X, pollutants = pols, tz = tz,
       checks = do.call(rbind, checks),
       source = list(path = cfg$data$source, sha256 = mv_file_sha256(path),
                     reader = reader, value_column = cfg$data$value_column,
                     station = cfg$data$station))
}

# Unit check: declared units must equal preprocess canonical units, and the
# stored magnitudes must sit inside the canonical bounds (CO in mg/m3).
mv_check_units <- function(cfg, panel, root = NULL) {
  pp <- mv_read_yaml(file.path(mv_root(root), "code", "config", "preprocess.yaml"))
  rows <- list()
  for (p in panel$pollutants) {
    declared <- cfg$data$units[[p]]
    canon <- pp$canonical_units[[p]]
    b <- unlist(pp$bounds[[p]])
    x <- panel$X[, p]
    ok <- identical(declared, canon) && min(x) >= b[1] && max(x) <= b[2]
    rows[[p]] <- data.frame(pollutant = p, declared_unit = declared, canonical_unit = canon,
                            bound_lo = b[1], bound_hi = b[2], min = min(x),
                            median = stats::median(x), max = max(x), pass = ok,
                            stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  # CO came from the paper CSV in ug/m3; the store converts it to mg/m3.
  co_ok <- stats::median(panel$X[, "CO"]) < 5
  out$pass[out$pollutant == "CO"] <- out$pass[out$pollutant == "CO"] & co_ok
  if (!all(out$pass)) .mv_fail("unit check failed for ", paste(out$pollutant[!out$pass], collapse = ", "))
  rownames(out) <- NULL
  out
}

# ---- S3 blocks and samples ---------------------------------------------------

mv_blocks <- function(cfg, times) {
  tz <- cfg$data$timezone %||% "Asia/Kolkata"
  b <- cfg$split$blocks
  nm <- c("train", "validation", "test")
  idx <- function(s) {
    i <- match(as.numeric(mv_parse_ts(s, tz)), as.numeric(times))
    if (is.na(i)) .mv_fail("split boundary not on the hourly grid: ", s)
    i
  }
  out <- data.frame(block = nm,
                    start = vapply(nm, function(k) b[[k]]$start, ""),
                    end = vapply(nm, function(k) b[[k]]$end, ""),
                    stringsAsFactors = FALSE)
  out$start_idx <- vapply(out$start, idx, 1L)
  out$end_idx <- vapply(out$end, idx, 1L)
  out$hours <- out$end_idx - out$start_idx + 1L
  if (any(out$hours <= 0)) .mv_fail("empty block")
  if (any(out$start_idx[-1] != out$end_idx[-3] + 1L)) .mv_fail("blocks are not contiguous")
  first_origin_idx <- idx(cfg$split$first_origin)
  L <- as.integer(cfg$lookback_h)
  if (first_origin_idx - (L - 1L) != out$start_idx[1])
    .mv_fail("first_origin must have exactly ", L, " hours of history inside train")
  out$first_origin_idx <- c(first_origin_idx, out$start_idx[2:3])
  # earliest hour a lag window of this block may touch
  out$lag_floor_idx <- c(out$start_idx[1], out$start_idx[1:2])
  rownames(out) <- NULL
  out
}

# Samples for one horizon. Origin and target inside the same block; lags may
# reach into the immediately preceding block. No mask, no origin thresholds.
mv_samples <- function(cfg, times, h) {
  h <- as.integer(h)
  bl <- mv_blocks(cfg, times)
  L <- as.integer(cfg$lookback_h)
  out <- list()
  for (i in seq_len(nrow(bl))) {
    o <- if (bl$end_idx[i] - h >= bl$first_origin_idx[i])
      seq.int(bl$first_origin_idx[i], bl$end_idx[i] - h) else integer(0)
    if (length(o) && any(o - (L - 1L) < bl$lag_floor_idx[i]))
      .mv_fail("lag window leaves the allowed range in block ", bl$block[i])
    out[[i]] <- data.frame(block = rep(bl$block[i], length(o)), origin_idx = o,
                           target_idx = o + h, stringsAsFactors = FALSE)
  }
  s <- do.call(rbind, out)
  s$h <- h
  s
}

mv_sample_counts <- function(cfg, times) {
  bl <- mv_blocks(cfg, times)
  tz <- cfg$data$timezone %||% "Asia/Kolkata"
  rows <- list()
  for (h in as.integer(unlist(cfg$horizons))) {
    s <- mv_samples(cfg, times, h)
    for (i in seq_len(nrow(bl))) {
      si <- s[s$block == bl$block[i], ]
      n <- nrow(si)
      rows[[length(rows) + 1L]] <- data.frame(
        horizon_h = h, block = bl$block[i],
        block_start = bl$start[i], block_end = bl$end[i], block_hours = bl$hours[i],
        eligible_origins = bl$end_idx[i] - bl$first_origin_idx[i] + 1L,
        samples = n,
        first_origin = if (n) mv_fmt_ts(times[si$origin_idx[1]], tz) else NA,
        last_origin = if (n) mv_fmt_ts(times[si$origin_idx[n]], tz) else NA,
        first_target = if (n) mv_fmt_ts(times[si$target_idx[1]], tz) else NA,
        last_target = if (n) mv_fmt_ts(times[si$target_idx[n]], tz) else NA,
        earliest_lag_hour = if (n) mv_fmt_ts(times[si$origin_idx[1] - (cfg$lookback_h - 1L)], tz) else NA,
        quality_mask = "none", stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}
