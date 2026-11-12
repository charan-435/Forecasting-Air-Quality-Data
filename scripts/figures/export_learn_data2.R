# Export PM2.5 windows from series.rds + Shillong preprocess for learn app
suppressPackageStartupMessages({
  if (file.exists("R/load_all.R")) try(source("R/load_all.R"), silent = TRUE)
})

out_dir <- "presentation/learn/js/data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
N_KEEP <- 24L * 21L

pack_from_list <- function(obj, sensor, pollutant = "PM2.5") {
  y <- as.numeric(obj$y)
  t <- as.character(obj$times)
  n <- length(y)
  i0 <- max(1L, n - N_KEEP + 1L)
  list(
    sensor = sensor,
    pollutant = pollutant,
    n_full = n,
    t = t[i0:n],
    y = round(y[i0:n], 4)
  )
}

datasets <- list()

ser <- tryCatch(readRDS("data/processed/series.rds"), error = function(e) NULL)
if (!is.null(ser)) {
  series <- if (!is.null(ser$series)) ser$series else ser
  for (sensor in c("CPCB", "ID1")) {
    key <- paste0(sensor, "_PM2.5")
    if (!is.null(series[[key]])) {
      datasets[[sensor]] <- pack_from_list(series[[key]], sensor)
      message("packed ", key, " n=", datasets[[sensor]]$n_full)
    }
  }
}

# Shillong: preprocess rds or csv
sh <- tryCatch(readRDS("data/processed/SHILLONG_preprocess.rds"), error = function(e) NULL)
if (!is.null(sh)) {
  # shapes vary: list with series / y / PM2.5
  obj <- NULL
  if (!is.null(sh$series) && !is.null(sh$series$y)) {
    obj <- sh$series
  } else if (!is.null(sh$y)) {
    obj <- sh
  } else if (!is.null(sh$PM2.5) && !is.null(sh$Datetime)) {
    obj <- list(y = sh$PM2.5, times = sh$Datetime)
  } else if (!is.null(sh$hourly)) {
    h <- sh$hourly
    col <- if ("PM2.5" %in% names(h)) "PM2.5" else names(h)[grep("PM", names(h))[1]]
    obj <- list(y = h[[col]], times = h$Datetime)
  }
  if (!is.null(obj)) {
    datasets[["SHILLONG"]] <- pack_from_list(obj, "SHILLONG")
    message("packed SHILLONG n=", datasets$SHILLONG$n_full)
  } else {
    message("SHILLONG preprocess shape unrecognized: ", paste(names(sh), collapse = ","))
  }
}

if (is.null(datasets$SHILLONG) && file.exists("data/processed/SHILLONG.csv")) {
  df <- read.csv("data/processed/SHILLONG.csv", stringsAsFactors = FALSE)
  tcol <- if ("Datetime" %in% names(df)) "Datetime" else names(df)[1]
  ycol <- if ("PM2.5" %in% names(df)) "PM2.5" else grep("PM", names(df), value = TRUE)[1]
  datasets[["SHILLONG"]] <- pack_from_list(list(y = df[[ycol]], times = df[[tcol]]), "SHILLONG")
  message("packed SHILLONG from csv")
}

# Conformal: prefer real residuals; else synthesize from series + RMSE scale
resid_q <- NULL
fc <- tryCatch(readRDS("results/paper/forecast_cache.rds"), error = function(e) NULL)
if (!is.null(fc)) {
  key <- "CPCB|PM2.5|7d"
  if (!is.null(fc[[key]]$wavecatboost)) {
    w <- fc[[key]]$wavecatboost
    if (!is.null(w$y) && !is.null(w$yhat)) {
      yy <- as.numeric(w$y)
      yh <- as.numeric(w$yhat)
      r <- abs(yy - yh)
      if (isTRUE(max(r, na.rm = TRUE) > 1e-8)) {
        resid_q <- list(
          sensor = "CPCB", pollutant = "PM2.5", horizon = "7d",
          y = round(yy, 4), yhat = round(yh, 4),
          abs_resid = round(r, 4),
          q95 = as.numeric(stats::quantile(r, 0.95, names = FALSE, na.rm = TRUE))
        )
      }
    }
  }
}

# Build demo conformal from last window of CPCB if cache empty/identical
if (is.null(resid_q) && !is.null(datasets$CPCB)) {
  y <- datasets$CPCB$y
  n <- length(y)
  # simple persistence-ish "forecast" with noise scale from local sd
  yhat <- c(y[1], y[-n])
  # inject realistic residual magnitude ~ 15% of rolling sd
  set.seed(42)
  noise <- stats::rnorm(n, 0, stats::sd(diff(y), na.rm = TRUE) * 0.35)
  yhat <- yhat + noise
  r <- abs(y - yhat)
  resid_q <- list(
    sensor = "CPCB", pollutant = "PM2.5", horizon = "7d",
    y = round(y, 4), yhat = round(yhat, 4),
    abs_resid = round(r, 4),
    q95 = as.numeric(stats::quantile(r, 0.95, names = FALSE, na.rm = TRUE)),
    note = "demo intervals from series window (cache had zero residual)"
  )
  message("conformal demo q95=", resid_q$q95)
}

eda_path <- "presentation/images/eda/eda_design_decisions_cpcb_pm25.csv"
if (!file.exists(eda_path)) eda_path <- "presentation/learn/assets/eda_design_decisions_cpcb_pm25.csv"
eda <- if (file.exists(eda_path)) read.csv(eda_path, stringsAsFactors = FALSE) else data.frame()

payload <- list(
  datasets = datasets,
  conformal = resid_q,
  eda_decisions = eda,
  links = list(
    paper = "https://ieeexplore.ieee.org/document/10806566",
    paper_code = "https://github.com/jborah2/WaveCatBoost-Time-Series-Model",
    cpcb = "https://cpcb.nic.in/",
    caaqms = "https://airquality.cpcb.gov.in/ccr/#/caaqm-dashboard-all/caaqm-landing",
    who = "https://www.who.int/teams/environment-climate-change-and-health/air-quality-and-health"
  )
)

js <- paste0("window.LEARN = ", jsonlite::toJSON(payload, auto_unbox = TRUE, digits = 8, null = "null"), ";\n")
writeLines(js, file.path(out_dir, "learn_data.js"), useBytes = TRUE)

if (file.exists("results/paper/scores.csv")) {
  sc <- read.csv("results/paper/scores.csv", stringsAsFactors = FALSE)
  writeLines(
    paste0("window.SCORES = ", jsonlite::toJSON(sc, dataframe = "rows"), ";\n"),
    file.path(out_dir, "scores.js"),
    useBytes = TRUE
  )
}

message("datasets: ", paste(names(datasets), collapse = ", "))
message("Wrote ", out_dir)
