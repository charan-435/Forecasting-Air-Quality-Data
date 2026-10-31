# Load and standardise the GitHub datasets, plus extra 15-min CAAQMS groups.

dataset_group_choices <- function() {
  c("Original (paper CPCB / ID1)" = "paper",
    "Extra: Shillong (15-min CAAQMS)" = "shillong",
    "Extra: Delhi (15-min CAAQMS)" = "delhi")
}

sources_in_group <- function(active, cfg = NULL) {
  if (is.null(cfg)) cfg <- tryCatch(pp_cfg(), error = function(e) NULL)
  if (is.null(cfg)) return(list())
  srcs <- cfg$sources
  if (is.null(srcs)) return(list())
  Filter(function(s) identical(s$group, active), srcs)
}

sensors_in_group <- function(active, cfg = NULL) {
  srcs <- sources_in_group(active, cfg)
  unique(vapply(srcs, function(s) as.character(s$station), character(1)))
}

sensor_source <- function(sensor, cfg = NULL) {
  if (is.null(cfg)) cfg <- tryCatch(pp_cfg(), error = function(e) NULL)
  if (is.null(cfg)) return(NULL)
  srcs <- cfg$sources
  if (is.null(srcs)) return(NULL)
  hit <- Filter(function(s) identical(as.character(s$station), as.character(sensor)),
                srcs)
  if (!length(hit)) return(NULL)
  hit[[1]]
}

sensor_needs_preprocess <- function(sensor) {
  st <- as.character(sensor)
  if (identical(st, NEW_SENSOR)) return(TRUE)
  src <- sensor_source(st)
  if (is.null(src)) return(FALSE)
  !isTRUE(src$skip_preprocess)
}

group_store_dir <- function(active) {
  if (identical(active, "paper") || is.null(active) || !nzchar(active))
    return(file.path(PROJECT_ROOT, "store", "clean"))
  file.path(PROJECT_ROOT, "store", active, "clean")
}

series_from_clean_long <- function(long) {
  long <- tibble::as_tibble(long)
  out <- list()
  raw <- list()
  for (stn in unique(as.character(long$station))) {
    svs <- long[long$station == stn, ]
    wide <- svs %>%
      dplyr::select(timestamp, variable, value_filled_causal) %>%
      tidyr::pivot_wider(names_from = "variable", values_from = "value_filled_causal") %>%
      dplyr::rename(Datetime = timestamp) %>%
      dplyr::mutate(sensor = stn)
    raw[[stn]] <- wide
    pols <- intersect(c(POLLUTANTS, "AT", "RH"), unique(svs$variable))
    for (p in pols) {
      sv <- svs[svs$variable == p, ]
      sv <- sv[order(sv$timestamp), ]
      out[[paste(stn, p, sep = "_")]] <- list(
        times = sv$timestamp,
        y = as.numeric(sv$value_filled_causal),
        y_raw = as.numeric(sv$value_hourly_raw),
        n_missing = sum(sv$is_na_source, na.rm = TRUE),
        n_impossible = sum(sv$is_negative | sv$is_out_of_bounds, na.rm = TRUE),
        n_filled = sum(!is.na(sv$fill_method)),
        n_hourly = nrow(sv),
        pollutant = p,
        sensor = stn,
        preprocess = "phase1a_causal"
      )
    }
  }
  list(series = out, raw = raw, long = long)
}

.extra_group_cache <- new.env(parent = emptyenv())

ensure_dataset_group <- function(active, force = FALSE) {
  active <- as.character(active)
  if (identical(active, "paper")) {
    return(list(kind = "paper", skipped_preprocess = TRUE, active = active))
  }
  if (!force && exists(active, envir = .extra_group_cache, inherits = FALSE))
    return(get(active, envir = .extra_group_cache))

  cfg <- pp_cfg()
  srcs <- sources_in_group(active, cfg)
  if (!length(srcs))
    stop("No sources configured for dataset group '", active, "'.")
  missing <- character()
  for (s in srcs) {
    p_raw <- s$path
    if (is.null(p_raw) || !nzchar(p_raw)) {
      missing <- c(missing, "(empty path)")
      next
    }
    p <- file.path(PROJECT_ROOT, p_raw)
    if (!file.exists(p)) missing <- c(missing, p_raw)
  }
  if (length(missing))
    stop("Raw files missing for ", active, ": ", paste(unique(missing), collapse = ", "))

  store_dir <- group_store_dir(active)
  run_preprocess(active = active, force = isTRUE(force), store_dir = store_dir)
  ser <- file.path(store_dir, "series.parquet")
  if (!file.exists(ser))
    stop("Preprocess did not write ", ser)
  long <- tibble::as_tibble(arrow::read_parquet(ser))
  packed <- series_from_clean_long(long)
  packed$kind <- "extra"
  packed$skipped_preprocess <- FALSE
  packed$active <- active
  packed$store_dir <- store_dir
  assign(active, packed, envir = .extra_group_cache)
  packed
}

.read_paper_csv <- function(path, sensor) {
  raw <- readr::read_csv(
    path,
    col_types = readr::cols(Datetime = readr::col_character(),
                            .default = readr::col_guess()),
    show_col_types = FALSE
  )
  drop <- intersect(names(raw), c("...1", "Unnamed: 0", "id", "X", "X1"))
  if (length(drop)) raw <- dplyr::select(raw, -dplyr::any_of(drop))
  if ("Ozone" %in% names(raw) && !"O3" %in% names(raw)) {
    raw <- dplyr::rename(raw, O3 = Ozone)
  }
  if ("Temp" %in% names(raw) && !"AT" %in% names(raw)) {
    raw <- dplyr::rename(raw, AT = Temp)
  }
  raw %>%
    dplyr::mutate(Datetime = lubridate::dmy_hm(Datetime)) %>%
    dplyr::select(Datetime, dplyr::any_of(c(POLLUTANTS, "AT", "RH"))) %>%
    dplyr::mutate(sensor = sensor)
}

load_raw_datasets <- function(include_new = FALSE, force_new = FALSE) {
  cpcb_path <- file.path(RAW_DIR, "CPCB.csv")
  id1_path <- file.path(RAW_DIR, "ID1.csv")
  if (!file.exists(cpcb_path) || !file.exists(id1_path)) {
    stop("Raw CSVs not found in data/raw/. Download CPCB.csv and ID1.csv first.")
  }

  out <- list(
    CPCB = .read_paper_csv(cpcb_path, "CPCB"),
    ID1  = .read_paper_csv(id1_path, "ID1")
  )

  if (isTRUE(include_new)) {
    sh <- ensure_new_dataset(force = force_new)
    if (!is.null(sh$hourly)) out[[NEW_SENSOR]] <- sh$hourly
  }
  out
}

combine_long <- function(raw_list) {
  dplyr::bind_rows(raw_list) %>%
    tidyr::pivot_longer(
      cols = dplyr::any_of(POLLUTANTS),
      names_to = "pollutant",
      values_to = "value"
    )
}

sampling_hours <- function(dt) {
  d <- as.numeric(diff(dt), units = "hours")
  stats::median(d, na.rm = TRUE)
}
