# Shillong architecture study: clean store, covariates and causal decomposition.
# Reuses the Phase 1a preprocess (R/20-23) and the causal Haar pyramid (R/31).
# Nothing here writes to data/processed/store/clean, data/processed/store/decomp or code/config/.

SH_STATIONS <- c(Lumpyngngad = "site_5131", JN_Stadium = "site_5593")
SH_POLLUTANTS <- c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO")

sh_store_dir <- function(cfg) file.path(PROJECT_ROOT, cfg$store_dir)

# Run the existing causal preprocess with the Shillong sources into a separate
# store. write_imputation_choice() defaults to code/config/imputation_choice.yaml
# (the paper store's file), so it is redirected into the Shillong store.
sh_build_clean_store <- function(cfg, force = FALSE) {
  clean_dir <- file.path(sh_store_dir(cfg), "clean")
  choice_path <- file.path(clean_dir, "imputation_choice.yaml")
  orig <- get("write_imputation_choice", envir = .GlobalEnv)
  assign("write_imputation_choice", function(choice, path = NULL)
    orig(choice, path = choice_path), envir = .GlobalEnv)
  on.exit(assign("write_imputation_choice", orig, envir = .GlobalEnv), add = TRUE)
  dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
  run_preprocess(active = "shillong", force = force, store_dir = clean_dir)
  invisible(clean_dir)
}

sh_read_long <- function(cfg) {
  p <- file.path(sh_store_dir(cfg), "clean", "series.parquet")
  if (!file.exists(p)) stop("Shillong clean store missing: ", p,
                            " (run --stage=preprocess)")
  d <- data.table::as.data.table(arrow::read_parquet(p))
  d[, timestamp := lubridate::with_tz(timestamp, "Asia/Kolkata")]
  d[, station := as.character(station)]
  d[, variable := as.character(variable)]
  d[]
}

# Station meteorology that the Phase 1a adapter does not keep (WS, WD, RF, SR,
# BP, plus AT and RH again for one consistent table). Same hour-end rule as
# regularize_hourly(): start-labelled 15-min stamps shift +15 min, hour t is the
# mean of slots in (t-1h, t], and an hour needs >= min_subhour_coverage of its
# slots. Wind direction is averaged as a unit vector. No imputation: LightGBM
# and the linear wrappers handle NA explicitly.
SH_MET_COLS <- c(AT = "^AT ", RH = "^RH ", WS = "^WS ", WD = "^WD ",
                 RF = "^RF ", SR = "^SR ", BP = "^BP ")

sh_station_met <- function(cfg, station) {
  raw <- arrow::read_parquet(file.path(PROJECT_ROOT, cfg$raw_path))
  raw <- data.table::as.data.table(raw)
  raw <- raw[raw[["Station ID"]] == SH_STATIONS[[station]]]
  clock <- format(raw$Timestamp, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
  ts <- lubridate::as_datetime(clock, tz = "Asia/Kolkata") + 15 * 60
  hour <- .hour_end(ts)
  out <- data.table::data.table(timestamp = sort(unique(hour)))
  min_cov <- as.numeric(cfg$min_subhour_coverage)
  for (v in names(SH_MET_COLS)) {
    nm <- grep(SH_MET_COLS[[v]], names(raw), value = TRUE)[1]
    x <- if (is.na(nm)) rep(NA_real_, nrow(raw)) else as.numeric(raw[[nm]])
    if (v == "WD") {
      d <- data.table::data.table(hour, s = sin(x * pi / 180), c = cos(x * pi / 180))
      a <- d[, .(n = sum(is.finite(s)), s = mean(s, na.rm = TRUE),
                 c = mean(c, na.rm = TRUE)), by = hour]
      a[n / 4 < min_cov, `:=`(s = NA_real_, c = NA_real_)]
      out[a, `:=`(WD_sin = i.s, WD_cos = i.c), on = c(timestamp = "hour")]
    } else {
      d <- data.table::data.table(hour, x)
      a <- d[, .(n = sum(is.finite(x)), m = mean(x, na.rm = TRUE)), by = hour]
      a[n / 4 < min_cov, m := NA_real_]
      out[a, (v) := i.m, on = c(timestamp = "hour")]
    }
  }
  for (v in names(out)[-1]) out[!is.finite(get(v)), (v) := NA_real_]
  out[]
}

# Causal additive Haar pyramid (decomp_coef_haar): D_j = W_j, S_J = V_J and
# x_t = sum_j D_j,t + S_J,t exactly. Component values at t use x over
# [t - 2^J + 1, t] only, so the warmup is 2^J - 1 hours.
sh_decompose <- function(x, J) {
  M <- decomp_coef_haar(x, list(J = J))
  out <- M[, c(paste0("W", seq_len(J)), paste0("V", J)), drop = FALSE]
  colnames(out) <- c(paste0("D", seq_len(J)), paste0("S", J))
  out
}

sh_components <- function(J) c(paste0("D", seq_len(J)), paste0("S", J))

# One station panel: hourly grid, causal-filled pollutants (model inputs),
# observed/scorable flags, decomposition of each pollutant, met covariates.
sh_panel <- function(cfg, long, station) {
  stn <- station
  st <- long[long$station == stn]   # not long[station == station]: data.table scoping
  pols <- intersect(cfg$pollutants, unique(st$variable))
  grid <- data.table::data.table(timestamp = sort(unique(st$timestamp)))
  fill <- data.table::copy(grid)
  score <- data.table::copy(grid)
  observed <- data.table::copy(grid)
  for (v in pols) {
    sv <- st[variable == v][order(timestamp)]
    fill[sv, (v) := i.value_filled_causal, on = "timestamp"]
    score[sv, (v) := i.is_scorable, on = "timestamp"]
    observed[sv, (v) := i.value_masked, on = "timestamp"]
    # Before a series' first observation the imputer has nothing to carry
    # forward; those "fills" are model constants, so they are not inputs.
    first <- which(is.finite(observed[[v]]))[1]
    if (!is.na(first) && first > 1L) fill[seq_len(first - 1L), (v) := NA_real_]
  }
  J <- as.integer(cfg$decomp$J)
  comps <- list()
  for (v in pols) {
    x <- fill[[v]]
    comps[[v]] <- sh_decompose(x, J)
  }
  met <- sh_station_met(cfg, station)
  met <- met[grid, on = "timestamp"]
  ff24 <- data.table::copy(grid); inlong <- data.table::copy(grid)
  filled_flag <- data.table::copy(grid)
  for (v in pols) {
    sv <- st[variable == v][order(timestamp)]
    ff24[sv, (v) := i.frac_filled_24h, on = "timestamp"]
    inlong[sv, (v) := i.in_long_gap, on = "timestamp"]
    filled_flag[sv, (v) := !is.na(i.fill_method), on = "timestamp"]
  }
  list(station = station, timestamps = grid$timestamp, pollutants = pols,
       fill = fill, scorable = score, observed = observed,
       comps = comps, J = J, components = sh_components(J), met = met,
       frac_filled_24h = ff24, in_long_gap = inlong, filled = filled_flag)
}

# Pollutants usable as inputs/targets at a station: scorable share >= threshold
# in every block. Covariates: available share >= threshold in every block.
sh_available <- function(cfg, panel, splits) {
  thr <- as.numeric(cfg$availability$min_pct) / 100
  ts <- panel$timestamps
  inb <- lapply(splits, function(r) ts >= r[1] & ts <= r[2])
  # ... and observed from the start of the train block (leading unobserved
  # stretch <= max_leading_gap_pct of it), so no block is built on fabricated inputs
  lead_max <- as.numeric(cfg$availability$max_leading_gap_pct) / 100
  tr <- which(inb$train)
  pol_ok <- vapply(panel$pollutants, function(v) {
    first <- which(is.finite(panel$observed[[v]][tr]))[1]
    all(vapply(inb, function(w) mean(panel$scorable[[v]][w] %in% TRUE) >= thr, logical(1))) &&
      !is.na(first) && (first - 1) / length(tr) <= lead_max
  }, logical(1))
  # explicit exclusions after the audit (e.g. a calibration regime change that
  # the coverage rules cannot see); reasons live in the config
  excl <- names(cfg$exclude_pollutants[[panel$station]] %||% list())
  pol_ok[panel$pollutants %in% excl] <- FALSE
  cov_names <- setdiff(names(panel$met), "timestamp")
  cov_ok <- vapply(cov_names, function(v) all(vapply(inb, function(w)
    mean(is.finite(panel$met[[v]][w])) >= thr, logical(1))), logical(1))
  list(pollutants = panel$pollutants[pol_ok], covariates = cov_names[cov_ok],
       dropped_pollutants = panel$pollutants[!pol_ok], dropped_covariates = cov_names[!cov_ok])
}

# Block boundaries (target timestamps, inclusive) for one station.
sh_splits <- function(cfg, station) {
  s <- cfg$splits[[station]]
  P <- function(x) as.POSIXct(x, tz = "Asia/Kolkata")
  lapply(s, function(r) P(unlist(r)))
}
