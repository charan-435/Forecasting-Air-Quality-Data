# Export browser-ready JSON for WaveCatBoost Lab (static React app).
# Run from repo root: Rscript scripts/figures/export_lab_assets.R

out_dir <- "lab/public/data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fig_dir <- file.path(out_dir, "eda")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

N_KEEP <- 24L * 21L

pack_from_list <- function(obj, sensor, pollutant = "PM2.5") {
  y <- as.numeric(obj$y)
  t <- as.character(obj$times)
  n <- length(y)
  i0 <- max(1L, n - N_KEEP + 1L)
  yy <- y[i0:n]
  list(
    sensor = sensor,
    pollutant = pollutant,
    n_full = n,
    t0 = t[i0],
    t1 = t[n],
    freq = "hourly",
    units = "µg/m³ (as recorded; verify station docs)",
    t = t[i0:n],
    y = round(yy, 4),
    stats = list(
      mean = round(mean(yy, na.rm = TRUE), 3),
      sd = round(sd(yy, na.rm = TRUE), 3),
      min = round(min(yy, na.rm = TRUE), 3),
      max = round(max(yy, na.rm = TRUE), 3)
    )
  )
}

POLLUTANTS <- c("PM2.5", "PM10", "NO2", "O3", "CO", "SO2")
safe_name <- function(sensor, pollutant) {
  paste0("series_", sensor, "_", gsub("\\.", "_", pollutant), ".json")
}

# Prefer long keys in series.rds (SENSOR_POLLUTANT); fall back to station CSVs.
datasets <- list() # sensor -> named list of packed pollutant series
ser <- tryCatch(readRDS("data/processed/series.rds"), error = function(e) NULL)
if (!is.null(ser)) {
  series <- if (!is.null(ser$series)) ser$series else ser
  for (sensor in c("CPCB", "ID1")) {
    for (pol in POLLUTANTS) {
      key <- paste0(sensor, "_", pol)
      if (!is.null(series[[key]])) {
        if (is.null(datasets[[sensor]])) datasets[[sensor]] <- list()
        datasets[[sensor]][[pol]] <- pack_from_list(series[[key]], sensor, pol)
        message("packed ", key)
      }
    }
  }
}

pack_station_csv <- function(path, sensor) {
  if (!file.exists(path)) return(invisible(NULL))
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  if ("Ozone" %in% names(df) && !"O3" %in% names(df)) {
    names(df)[names(df) == "Ozone"] <- "O3"
  }
  tcol <- if ("Datetime" %in% names(df)) "Datetime" else names(df)[1]
  for (pol in POLLUTANTS) {
    if (!(pol %in% names(df))) next
    if (is.null(datasets[[sensor]])) datasets[[sensor]] <<- list()
    # do not overwrite RDS-backed packs
    if (!is.null(datasets[[sensor]][[pol]])) next
    datasets[[sensor]][[pol]] <<- pack_from_list(
      list(y = df[[pol]], times = df[[tcol]]), sensor, pol
    )
    message("packed ", sensor, " ", pol, " from CSV")
  }
}

pack_station_csv("data/raw/CPCB.csv", "CPCB")
pack_station_csv("data/raw/ID1.csv", "ID1")
pack_station_csv("data/processed/SHILLONG.csv", "SHILLONG")

# Scores
scores <- NULL
if (file.exists("results/paper/scores.csv")) {
  scores <- utils::read.csv("results/paper/scores.csv", stringsAsFactors = FALSE)
  scores$protocol <- "recursive_bakeoff"
}

# Hparams (best-effort)
hparams <- NULL
hp <- tryCatch(readRDS("results/paper/hparams.rds"), error = function(e) NULL)
if (!is.null(hp)) {
  hparams <- tryCatch({
    if (is.data.frame(hp)) hp else as.data.frame(hp)
  }, error = function(e) list(note = "hparams present but non-tabular; see results/paper/hparams.rds"))
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

# Conformal
conformal <- NULL
cf <- tryCatch(readRDS("results/paper/conformal.rds"), error = function(e) NULL)
if (!is.null(cf)) {
  y <- cf$y_test %||% cf$y %||% NULL
  yhat <- cf$yhat_test %||% cf$yhat %||% NULL
  lower <- cf$lower %||% NULL
  upper <- cf$upper %||% NULL
  if (!is.null(y) && !is.null(yhat)) {
    conformal <- list(
      source = "results/paper/conformal.rds",
      provenance = "our_recorded",
      sensor = cf$sensor %||% "CPCB",
      pollutant = cf$pollutant %||% "PM2.5",
      horizon = cf$horizon %||% "7d",
      alpha = cf$alpha %||% 0.05,
      cq = cf$cq %||% NULL,
      y = round(as.numeric(y), 4),
      yhat = round(as.numeric(yhat), 4),
      lower = if (!is.null(lower)) round(as.numeric(lower), 4) else NULL,
      upper = if (!is.null(upper)) round(as.numeric(upper), 4) else NULL
    )
  }
}

cpcb_pm25 <- datasets$CPCB[["PM2.5"]]
if (is.null(conformal) && !is.null(cpcb_pm25)) {
  y <- cpcb_pm25$y
  n <- length(y)
  set.seed(42)
  yhat <- c(y[1], y[-n]) + stats::rnorm(n, 0, stats::sd(diff(y), na.rm = TRUE) * 0.35)
  r <- abs(y - yhat)
  conformal <- list(
    source = "demo_from_series_window",
    provenance = "teaching_simulation",
    note = "Retrospective illustration from series window (no held-out conformal cache shape matched).",
    sensor = "CPCB", pollutant = "PM2.5", horizon = "7d",
    alpha = 0.05,
    y = round(y, 4), yhat = round(yhat, 4),
    abs_resid = round(r, 4),
    q95 = as.numeric(stats::quantile(r, 0.95, names = FALSE, na.rm = TRUE))
  )
}

# EDA decisions
eda_path <- "presentation/images/eda/eda_design_decisions_cpcb_pm25.csv"
if (!file.exists(eda_path)) eda_path <- "presentation/learn/assets/eda_design_decisions_cpcb_pm25.csv"
eda_decisions <- if (file.exists(eda_path)) utils::read.csv(eda_path, stringsAsFactors = FALSE) else data.frame()

# Copy key EDA PNGs
eda_src <- if (dir.exists("presentation/images/eda")) "presentation/images/eda" else "presentation/learn/assets"
imgs <- c(
  "diag_2x2_cpcb_pm25.png", "acf_pacf_cpcb_pm25.png", "boxes_cpcb_pm25.png",
  "eda_energy_cpcb_pm25.png", "mra_d1d4_s4_cpcb_pm25.png",
  "eda_design_board_cpcb_pm25.png", "eda_to_pipeline_cpcb_pm25.png",
  "eda_snaive_resid_acf_cpcb_pm25.png"
)
for (f in imgs) {
  p <- file.path(eda_src, f)
  if (file.exists(p)) file.copy(p, file.path(fig_dir, f), overwrite = TRUE)
}

# MODWT Haar fixture (match R/core/04_modwt.R) for browser checks
haar_modwt_mra <- function(x, J) {
  roll_right <- function(v, s) {
    n <- length(v); s <- s %% n
    if (s == 0) return(v)
    c(v[(n - s + 1):n], v[1:(n - s)])
  }
  roll_left <- function(v, s) {
    n <- length(v); s <- s %% n
    if (s == 0) return(v)
    c(v[(s + 1):n], v[1:s])
  }
  V <- as.numeric(x)
  W <- vector("list", J)
  for (j in seq_len(J)) {
    s <- 2^(j - 1)
    Vlag <- roll_right(V, s)
    W[[j]] <- (V - Vlag) / 2
    V <- (V + Vlag) / 2
  }
  zeros <- lapply(W, function(w) rep(0, length(w)))
  inv_step <- function(Wj, Vj, j) {
    s <- 2^(j - 1)
    (Wj - roll_left(Wj, s) + Vj + roll_left(Vj, s)) / 2
  }
  imodwt <- function(WW, VJ) {
    VV <- VJ
    for (j in rev(seq_along(WW))) VV <- inv_step(WW[[j]], VV, j)
    VV
  }
  D <- vector("list", J)
  for (j in seq_len(J)) {
    Wj <- zeros
    Wj[[j]] <- W[[j]]
    D[[j]] <- imodwt(Wj, rep(0, length(V)))
  }
  S <- imodwt(zeros, V)
  list(D = D, S = S, J = J)
}

fixture_y <- if (!is.null(cpcb_pm25)) head(cpcb_pm25$y, 128) else sin(seq(0, 4 * pi, length.out = 128))
fx <- haar_modwt_mra(fixture_y, 4)
modwt_fixture <- list(
  filter = "haar",
  J = 4,
  y = round(as.numeric(fixture_y), 6),
  D = lapply(fx$D, function(d) round(as.numeric(d), 6)),
  S = round(as.numeric(fx$S), 6)
)

manifest_datasets <- lapply(names(datasets), function(sensor) {
  pols <- names(datasets[[sensor]])
  pols <- POLLUTANTS[POLLUTANTS %in% pols]
  series_meta <- lapply(pols, function(pol) {
    d <- datasets[[sensor]][[pol]]
    list(
      sensor = d$sensor, pollutant = d$pollutant, n_full = d$n_full,
      t0 = d$t0, t1 = d$t1, freq = d$freq, units = d$units, stats = d$stats,
      file = safe_name(sensor, pol)
    )
  })
  names(series_meta) <- pols
  list(
    sensor = sensor,
    default_pollutant = if ("PM2.5" %in% pols) "PM2.5" else pols[[1]],
    pollutants = pols,
    series = series_meta
  )
})
names(manifest_datasets) <- names(datasets)

manifest <- list(
  app = "WaveCatBoost Lab",
  paper = "https://ieeexplore.ieee.org/document/10806566",
  paper_code = "https://github.com/jborah2/WaveCatBoost-Time-Series-Model",
  links = list(
    cpcb = "https://cpcb.nic.in/",
    caaqms = "https://airquality.cpcb.gov.in/ccr/#/caaqm-dashboard-all/caaqm-landing"
  ),
  datasets = manifest_datasets,
  scores_file = "scores.json",
  conformal_file = "conformal.json",
  eda_decisions_file = "eda_decisions.json",
  modwt_fixture_file = "modwt_haar_fixture.json",
  notes = list(
    id1 = "ID1 is a station series from the paper release — not a separate pollution board.",
    scores = "results/paper/scores.csv are our recursive bake-off scores, not paper Table 1 rolling 1-step.",
    series = "Hourly windows (last ~21 days) for PM2.5/PM10/NO2/O3/CO/SO2. CPCB Ozone renamed to O3."
  )
)

write_json <- function(obj, path) {
  jsonlite::write_json(obj, path, auto_unbox = TRUE, pretty = TRUE, digits = 8, null = "null")
}

write_json(manifest, file.path(out_dir, "manifest.json"))
for (sensor in names(datasets)) {
  for (pol in names(datasets[[sensor]])) {
    write_json(datasets[[sensor]][[pol]], file.path(out_dir, safe_name(sensor, pol)))
  }
}
if (!is.null(scores)) write_json(scores, file.path(out_dir, "scores.json"))
write_json(conformal, file.path(out_dir, "conformal.json"))
write_json(eda_decisions, file.path(out_dir, "eda_decisions.json"))
write_json(modwt_fixture, file.path(out_dir, "modwt_haar_fixture.json"))
if (!is.null(hparams) && is.data.frame(hparams)) {
  write_json(hparams, file.path(out_dir, "hparams.json"))
} else {
  write_json(list(note = "See results/paper/hparams.rds; grid on val MASE for p/depth/eta."), file.path(out_dir, "hparams.json"))
}

message("Wrote ", out_dir)
