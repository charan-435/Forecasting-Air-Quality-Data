# Paper notebook protocol (jborah2/WaveCatBoost-Time-Series-Model):
#   Haar MODWT on the full series, K = ln N, CatBoost(lags=24, 1000 trees, auto η)
#   per coefficient, walk-forward 1-step (teacher forcing), then IMODWT.
# AUDIT F2 / F7: test sits in the circular filter. Do not mix with scores.csv.
#
#   "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" run_paper_protocol.R

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
if (!file.exists("R/load_all.R")) stop("Run this script from the project root.")
source("R/load_all.R")

out_path <- file.path(RES_DIR, "paper_notebook_protocol_leaky_rolling_1step.rds")
alias_path <- file.path(RES_DIR, "paper_protocol.rds")

if (file.exists(file.path(PROC_DIR, "series.rds"))) {
  packed <- readRDS(file.path(PROC_DIR, "series.rds"))
  series <- packed$series
} else {
  series <- prepare_all_series(load_raw_datasets(include_new = FALSE))
}
sh <- ensure_new_dataset(force = FALSE)
if (!is.null(sh$hourly)) {
  for (p in unique(c("PM2.5", FOUR_POLLUTANTS))) {
    if (!p %in% names(sh$hourly)) next
    series[[paste(NEW_SENSOR, p, sep = "_")]] <- prepare_series(sh$hourly, p, NEW_SENSOR)
  }
}

params_paper <- paper_tree_params()
params_lgb <- default_tree_params()
H <- HORIZONS[["7d"]]
pollutant <- "PM2.5"
sensors_use <- c("CPCB", "ID1", NEW_SENSOR)
methods <- c("snaive", "lgb", "wavecatboost")

out <- if (file.exists(out_path)) readRDS(out_path) else list()

for (sensor in sensors_use) {
  key_s <- paste(sensor, pollutant, sep = "_")
  s <- series[[key_s]]
  if (is.null(s)) {
    message("Skip ", sensor, ": series not loaded")
    next
  }
  n <- length(s$y)
  J <- max(1L, min(9L, as.integer(floor(log(n)))))
  split <- chrono_split(s$y, s$times, H)
  sc <- minmax_fit(split$y_train)
  y_all <- minmax_apply(s$y, sc)
  y_tr  <- minmax_apply(split$y_train, sc)
  y_te  <- minmax_apply(split$y_test, sc)

  if (is.null(out[[sensor]])) out[[sensor]] <- list(methods = list())
  if (is.null(out[[sensor]]$methods)) out[[sensor]]$methods <- list()
  out[[sensor]]$sensor <- sensor
  out[[sensor]]$pollutant <- pollutant
  out[[sensor]]$horizon <- "7d"
  out[[sensor]]$J <- J
  out[[sensor]]$t_test <- split$t_test
  out[[sensor]]$y_test <- split$y_test
  out[[sensor]]$protocol <- paste0(
    "paper notebook: leaky rolling 1-step, full-series Haar MODWT, K=", J,
    ", CatBoost 1000 trees auto-eta"
  )
  out[[sensor]]$nrounds <- 1000L

  for (m in methods) {
    cached <- out[[sensor]]$methods[[m]]
    paper_ok <- isTRUE(cached$nrounds == 1000L) || identical(m, "snaive") || identical(m, "lgb")
    if (!is.null(cached) && !isTRUE(cached$error) &&
        (identical(m, "snaive") || identical(m, "lgb") ||
         isTRUE(cached$nrounds == 1000L))) {
      message("Skip cached ", sensor, " ", m)
      next
    }
    message(sprintf("[%s] %s PM2.5 7d paper rolling 1-step %s  J=%s  trees=%s",
                    format(Sys.time(), "%H:%M:%S"), sensor, m, J,
                    if (m == "wavecatboost") 1000L else params_lgb$nrounds))
    t0 <- proc.time()[3]
    z <- tryCatch({
      if (m == "snaive") {
        list(yhat = walkforward_snaive(split$y_train, split$y_test),
             fallback = FALSE, nrounds = NA_integer_)
      } else if (m == "wavecatboost") {
        wf <- paper_wave_walkforward(y_all, H, J, fit_cat_paper, params_paper)
        yhat <- minmax_invert(wf$yhat, sc)
        half <- as.numeric(stats::quantile(abs(split$y_test - yhat),
                                           probs = 0.95, names = FALSE, na.rm = TRUE))
        lower <- yhat - half
        upper <- yhat + half
        list(
          yhat = yhat, lower = lower, upper = upper,
          kappa = NA_integer_, cq = half,
          coverage_cal = NA_real_,
          coverage_test = interval_coverage(split$y_test, lower, upper),
          width = interval_width(lower, upper),
          fallback = isTRUE(wf$models[[1]]$fallback),
          nrounds = 1000L, J = J
        )
      } else {
        fit <- fit_lgb(y_tr, params_lgb)
        yhat <- minmax_invert(walkforward_tree_forecast(fit, y_tr, y_te), sc)
        list(yhat = yhat, fallback = isTRUE(fit$fallback),
             nrounds = params_lgb$nrounds)
      }
    }, error = function(e) {
      message("  ERROR: ", e$message)
      list(error = TRUE, message = e$message)
    })
    elapsed <- proc.time()[3] - t0
    if (isTRUE(z$error)) {
      out[[sensor]]$methods[[m]] <- list(error = TRUE, message = z$message,
                                         elapsed = elapsed)
    } else {
      sc_tbl <- score_forecast(split$y_train, split$y_test, z$yhat)
      slot <- list(method = m, elapsed = elapsed, scores = sc_tbl,
                   yhat = z$yhat, fallback = isTRUE(z$fallback), error = FALSE,
                   nrounds = z$nrounds)
      for (nm in c("lower", "upper", "kappa", "cq", "coverage_cal",
                   "coverage_test", "width", "J")) {
        if (!is.null(z[[nm]])) slot[[nm]] <- z[[nm]]
      }
      out[[sensor]]$methods[[m]] <- slot
      message("  MASE=", round(sc_tbl$MASE, 3), " elapsed=", round(elapsed, 1), "s")
    }
    saveRDS(out, out_path)
    saveRDS(out, alias_path)
  }
}

# Section 8.1: same notebook protocol for PM10 / NO2 / O3 (and PM2.5 copy).
if (is.null(out$four)) out$four <- list()
for (sensor in sensors_use) {
  wpm <- out[[sensor]]$methods$wavecatboost
  if (!is.null(wpm) && !isTRUE(wpm$error) && !is.null(wpm$yhat)) {
    out$four[[paste(sensor, "PM2.5", sep = "|")]] <- list(
      sensor = sensor, pollutant = "PM2.5",
      t_test = out[[sensor]]$t_test, y_test = out[[sensor]]$y_test,
      yhat = wpm$yhat, lower = wpm$lower, upper = wpm$upper,
      scores = wpm$scores, nrounds = wpm$nrounds, error = FALSE
    )
  }
  for (pol in setdiff(FOUR_POLLUTANTS, "PM2.5")) {
    key <- paste(sensor, pol, sep = "|")
    cached <- out$four[[key]]
    if (!is.null(cached) && !isTRUE(cached$error) &&
        isTRUE(cached$nrounds == 1000L) && !is.null(cached$yhat)) {
      message("Skip cached four ", key)
      next
    }
    s <- series[[paste(sensor, pol, sep = "_")]]
    if (is.null(s)) {
      message("Skip ", key, ": series not loaded")
      next
    }
    n <- length(s$y)
    J <- max(1L, min(9L, as.integer(floor(log(n)))))
    if (H >= n) next
    split <- chrono_split(s$y, s$times, H)
    sc <- minmax_fit(split$y_train)
    y_all <- minmax_apply(s$y, sc)
    message(sprintf("[%s] %s %s 7d paper rolling 1-step wavecatboost  J=%s  trees=1000",
                    format(Sys.time(), "%H:%M:%S"), sensor, pol, J))
    t0 <- proc.time()[3]
    z <- tryCatch({
      wf <- paper_wave_walkforward(y_all, H, J, fit_cat_paper, params_paper)
      yhat <- minmax_invert(wf$yhat, sc)
      half <- as.numeric(stats::quantile(abs(split$y_test - yhat),
                                         probs = 0.95, names = FALSE, na.rm = TRUE))
      list(
        sensor = sensor, pollutant = pol,
        t_test = split$t_test, y_test = split$y_test,
        yhat = yhat, lower = yhat - half, upper = yhat + half,
        scores = score_forecast(split$y_train, split$y_test, yhat),
        nrounds = 1000L, J = J, error = FALSE,
        fallback = isTRUE(wf$models[[1]]$fallback),
        elapsed = NA_real_
      )
    }, error = function(e) {
      message("  ERROR: ", e$message)
      list(error = TRUE, message = e$message, nrounds = 1000L)
    })
    z$elapsed <- proc.time()[3] - t0
    out$four[[key]] <- z
    if (!isTRUE(z$error)) {
      message("  MASE=", round(z$scores$MASE, 3), " elapsed=", round(z$elapsed, 1), "s")
    }
    saveRDS(out, out_path)
    saveRDS(out, alias_path)
  }
}

rows <- list()
for (sensor in setdiff(names(out), c("scores", "four"))) {
  if (!is.list(out[[sensor]]$methods)) next
  for (m in names(out[[sensor]]$methods)) {
    z <- out[[sensor]]$methods[[m]]
    if (isTRUE(z$error) || is.null(z$scores)) next
    rows[[length(rows) + 1L]] <- dplyr::bind_cols(
      tibble::tibble(sensor = sensor, pollutant = "PM2.5",
                     horizon = "7d", method = m,
                     protocol = "leaky rolling 1-step (full-series MODWT, 1000 trees)",
                     elapsed = z$elapsed),
      z$scores
    )
  }
}
if (length(out$four)) {
  for (key in names(out$four)) {
    z <- out$four[[key]]
    if (isTRUE(z$error) || is.null(z$scores)) next
    rows[[length(rows) + 1L]] <- dplyr::bind_cols(
      tibble::tibble(sensor = z$sensor, pollutant = z$pollutant,
                     horizon = "7d", method = "wavecatboost",
                     protocol = "leaky rolling 1-step (full-series MODWT, 1000 trees)",
                     elapsed = z$elapsed),
      z$scores
    )
  }
}
out$scores <- dplyr::bind_rows(rows)
saveRDS(out, out_path)
saveRDS(out, alias_path)
message("Wrote ", out_path)
if (nrow(out$scores)) print(out$scores)
