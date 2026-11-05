# Parquet writers, manifests, and loaders for the decomposition store.

decomp_root <- function() file.path(PROJECT_ROOT, "store", "decomp")

decomp_parquet_path <- function(method_full, station, variable) {
  file.path(decomp_root(), paste0("method=", method_full),
            paste0("station=", station), paste0("variable=", variable, ".parquet"))
}

decomp_manifest_path <- function(method_full) {
  file.path(decomp_root(), "manifests", paste0(method_full, ".json"))
}

write_decomp_parquet <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  for (nm in names(df)) {
    x <- df[[nm]]
    if (inherits(x, "POSIXt")) {
      df[[nm]] <- as.POSIXct(as.numeric(x), origin = "1970-01-01", tz = "UTC")
      next
    }
    if (is.character(x) || is.logical(x)) next
    df[[nm]] <- as.numeric(x)
  }
  tmp <- paste0(path, ".tmp")
  arrow::write_parquet(df, tmp, compression = "zstd")
  if (file.exists(path)) unlink(path)
  ok <- file.rename(tmp, path)
  if (!isTRUE(ok) && file.exists(tmp)) {
    file.copy(tmp, path, overwrite = TRUE)
    unlink(tmp)
  }
  path
}

write_decomp_manifest <- function(entry, scale, cfg, input_hash, done, partial,
                                  elapsed, max_add) {
  mid <- method_full_id(entry$id, scale)
  stations <- unique(vapply(done, `[[`, "", "station"))
  variables <- unique(vapply(done, `[[`, "", "variable"))
  man <- list(
    method_id = entry$id,
    scale = scale,
    method_full = mid,
    family = entry$family,
    additive = isTRUE(entry$additive),
    causal = TRUE,
    params = entry$params %||% list(),
    warmup_rule = entry$warmup_rule %||% "",
    component_names = decomp_component_names(entry),
    packages = pkg_versions(c("waveslim", "EMD", "Rlibeemd", "VMDecomp",
                              "Rssa", "forecast", "arrow")),
    input_hash = input_hash,
    git = git_commit_hash(),
    stations = stations,
    variables = variables,
    partial = isTRUE(partial),
    complete = TRUE,
    runtime_sec = as.numeric(elapsed),
    max_additivity_error = if (is.finite(max_add)) max_add else NA,
    seed_policy = if (identical(entry$fn, "decomp_ceemdan"))
      "digest(station|variable|t) -> rng_seed" else "none"
  )
  path <- decomp_manifest_path(mid)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(man, path, auto_unbox = TRUE, pretty = TRUE)
  path
}

list_methods <- function() {
  man_dir <- file.path(decomp_root(), "manifests")
  if (!dir.exists(man_dir)) return(tibble::tibble())
  files <- list.files(man_dir, pattern = "\\.json$", full.names = TRUE)
  dplyr::bind_rows(lapply(files, function(f) {
    m <- jsonlite::fromJSON(f, simplifyVector = TRUE)
    tibble::tibble(
      method_id = m$method_id,
      scale = m$scale,
      family = m$family,
      additive = isTRUE(m$additive),
      partial = isTRUE(m$partial),
      variables = paste(m$variables, collapse = ","),
      runtime_sec = as.numeric(m$runtime_sec %||% NA)
    )
  }))
}

get_manifest <- function(method_id, scale) {
  path <- decomp_manifest_path(method_full_id(method_id, scale))
  if (!file.exists(path)) stop("No manifest for ", method_id, "__", scale)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

get_decomp <- function(station, variable, method_id, scale,
                       validity = "basic", cols = NULL, start = NULL, end = NULL) {
  path <- decomp_parquet_path(method_full_id(method_id, scale), station, variable)
  if (!file.exists(path))
    stop("Missing decomp file: ", path)
  df <- tibble::as_tibble(arrow::read_parquet(path))
  if (inherits(df$timestamp, "POSIXt"))
    df$timestamp <- lubridate::with_tz(df$timestamp, "Asia/Kolkata")
  flag <- if (identical(validity, "strict")) "valid_strict" else "valid_basic"
  if (!flag %in% names(df)) stop("validity column missing: ", flag)
  if (!is.null(start)) df <- df[df$timestamp >= start, ]
  if (!is.null(end)) df <- df[df$timestamp <= end, ]
  df$.valid <- df[[flag]]
  if (!is.null(cols)) {
    keep <- unique(c("timestamp", flag, "valid_warmup", "valid_basic",
                     "valid_strict", "frac_filled_window", cols))
    df <- df[, intersect(keep, names(df)), drop = FALSE]
  }
  df
}

get_decomp_multi <- function(station, variable, methods,
                             validity = "basic") {
  # methods: list of c(id, scale) or data.frame
  acc <- NULL
  for (m in methods) {
    id <- m[[1]]; sc <- m[[2]]
    d <- get_decomp(station, variable, id, sc, validity = validity)
    prefix <- paste0(id, "__", sc, "__")
    comps <- setdiff(names(d), c("timestamp", "valid_warmup", "valid_basic",
                                 "valid_strict", "frac_filled_window", ".valid",
                                 grep("^valid_warmup_", names(d), value = TRUE),
                                 "resid", "n_imf_raw"))
    extra <- c(comps, intersect(c("resid", "n_imf_raw"), names(d)))
    take <- d[, c("timestamp", extra), drop = FALSE]
    names(take)[-1] <- paste0(prefix, names(take)[-1])
    acc <- if (is.null(acc)) take else dplyr::full_join(acc, take, by = "timestamp")
  }
  acc
}
