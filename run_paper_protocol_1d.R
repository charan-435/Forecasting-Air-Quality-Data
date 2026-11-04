# Letter notebook protocol, 1-day horizon only — for Table 1 comparison.
# Haar MODWT on full series, walk-forward 1-step, WaveCatBoost / LGB / snaive.
#
#   "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" run_paper_protocol_1d.R

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
if (!file.exists("R/load_all.R")) stop("Run from the project root.")
source("R/load_all.R")

out_path <- file.path(RES_DIR, "paper_protocol_1d.rds")

if (file.exists(file.path(PROC_DIR, "series.rds"))) {
  series <- readRDS(file.path(PROC_DIR, "series.rds"))$series
} else {
  series <- prepare_all_series(load_raw_datasets(include_new = FALSE))
}

params_paper <- paper_tree_params()
params_lgb <- default_tree_params()
H <- HORIZONS[["1d"]]  # 24
# Only cells that appear in paper Table 1 (1d) for a direct comparison.
jobs <- list(
  list(sensor = "CPCB", pollutant = "PM2.5"),
  list(sensor = "CPCB", pollutant = "NO2"),
  list(sensor = "CPCB", pollutant = "O3"),
  list(sensor = "ID1",  pollutant = "PM2.5")
)
methods <- c("snaive", "lgb", "catboost", "wavecatboost")

out <- if (file.exists(out_path)) readRDS(out_path) else list(cells = list())
if (is.null(out$cells)) out$cells <- list()

# Paper Table 1 (rolling 1-step MASE) — overlapping cells we will score
paper_t1 <- tibble::tribble(
  ~sensor, ~pollutant, ~horizon, ~paper_lgb, ~paper_xgb, ~paper_cat, ~paper_wave,
  "CPCB", "NO2",   "1d", 0.79, 0.91, 0.82, 0.57,
  "CPCB", "O3",    "1d", 1.87, 1.52, 2.89, 0.98,
  "CPCB", "PM2.5", "1d", 3.81, 2.85, 5.32, 0.57,
  "ID1",  "PM2.5", "1d", 7.31, 6.53, 4.45, 0.85
)

for (job in jobs) {
  sensor <- job$sensor
  pol <- job$pollutant
  key_s <- paste(sensor, pol, sep = "_")
  s <- series[[key_s]]
  if (is.null(s)) {
    message("Skip missing series ", key_s)
    next
  }
  n <- length(s$y)
  J <- max(1L, min(9L, as.integer(floor(log(n)))))
  split <- chrono_split(s$y, s$times, H)
  sc <- minmax_fit(split$y_train)
  y_all <- minmax_apply(s$y, sc)
  y_tr  <- minmax_apply(split$y_train, sc)
  y_te  <- minmax_apply(split$y_test, sc)

  for (m in methods) {
    cell <- paste(sensor, pol, "1d", m, sep = "|")
    cached <- out$cells[[cell]]
    if (!is.null(cached) && !isTRUE(cached$error) && !is.null(cached$scores)) {
      message("Skip cached ", cell)
      next
    }
    message(sprintf("[%s] 1d rolling %s | %s %s  J=%s",
                    format(Sys.time(), "%H:%M:%S"), m, sensor, pol, J))
    t0 <- proc.time()[3]
    z <- tryCatch({
      if (identical(m, "snaive")) {
        list(yhat = walkforward_snaive(split$y_train, split$y_test),
             nrounds = NA_integer_)
      } else if (identical(m, "lgb")) {
        fit <- fit_lgb(y_tr, params_lgb)
        list(yhat = minmax_invert(walkforward_tree_forecast(fit, y_tr, y_te), sc),
             nrounds = params_lgb$nrounds)
      } else if (identical(m, "catboost")) {
        fit <- fit_cat(y_tr, params_lgb)
        list(yhat = minmax_invert(walkforward_tree_forecast(fit, y_tr, y_te), sc),
             nrounds = params_lgb$nrounds)
      } else if (identical(m, "wavecatboost")) {
        wf <- paper_wave_walkforward(y_all, H, J, fit_cat_paper, params_paper)
        list(yhat = minmax_invert(wf$yhat, sc), nrounds = 1000L, J = J)
      } else stop("bad method")
    }, error = function(e) {
      message("  ERROR: ", e$message)
      list(error = TRUE, message = e$message)
    })
    elapsed <- proc.time()[3] - t0
    if (isTRUE(z$error)) {
      out$cells[[cell]] <- list(error = TRUE, message = z$message, elapsed = elapsed)
    } else {
      sc_tbl <- score_forecast(split$y_train, split$y_test, z$yhat)
      out$cells[[cell]] <- list(
        error = FALSE, sensor = sensor, pollutant = pol, horizon = "1d",
        method = m, protocol = "leaky rolling 1-step (paper notebook)",
        J = J, nrounds = z$nrounds, elapsed = elapsed,
        scores = sc_tbl, yhat = z$yhat,
        y_test = split$y_test, t_test = split$t_test
      )
      message(sprintf("  MASE=%.3f  elapsed=%.1fs", sc_tbl$MASE, elapsed))
    }
    saveRDS(out, out_path)
  }
}

rows <- list()
for (cell in names(out$cells)) {
  z <- out$cells[[cell]]
  if (isTRUE(z$error) || is.null(z$scores)) next
  rows[[length(rows) + 1L]] <- dplyr::bind_cols(
    tibble::tibble(
      sensor = z$sensor, pollutant = z$pollutant, horizon = z$horizon,
      method = z$method, protocol = z$protocol, elapsed = z$elapsed
    ),
    z$scores
  )
}
out$scores <- dplyr::bind_rows(rows)

# Side-by-side with Table 1 where paper numbers exist
ours_w <- out$scores %>%
  dplyr::filter(.data$method %in% c("lgb", "catboost", "wavecatboost")) %>%
  dplyr::select(sensor, pollutant, horizon, method, MASE) %>%
  tidyr::pivot_wider(names_from = method, values_from = MASE)
cmp <- dplyr::left_join(paper_t1, ours_w, by = c("sensor", "pollutant", "horizon"))
out$compare_table1 <- cmp
saveRDS(out, out_path)
readr::write_csv(out$scores, file.path(RES_DIR, "paper_protocol_1d_scores.csv"))
readr::write_csv(cmp, file.path(RES_DIR, "paper_protocol_1d_vs_table1.csv"))

message("Wrote ", out_path)
print(cmp)
message("Done.")
