# Generate figures for IITG slides.
options(warn = 1)
args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg))) else getwd()
proj <- if (length(file_arg)) normalizePath(file.path(script_dir, "..", "..")) else getwd()
setwd(proj)
if (!file.exists("R/load_all.R")) stop("Cannot find project root with R/load_all.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})
source("R/load_all.R")

outdir <- file.path("presentation", "images", "eda")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

raw <- load_raw_datasets(include_new = TRUE)
series <- prepare_all_series(raw)

plot_full_series <- function(s, file, title) {
  png(file, width = 1400, height = 520, res = 140)
  par(mar = c(4, 4.2, 3.2, 1))
  plot(s$times, s$y, type = "l", col = "#1F3A5F", lwd = 0.7,
       xlab = "Time", ylab = s$pollutant, main = title)
  dev.off()
}

plot_full_series(series[["CPCB_PM2.5"]],
                 file.path(outdir, "series_cpcb_pm25.png"),
                 "CPCB PM2.5 (paper, Meghalaya) --- original series")
plot_full_series(series[["SHILLONG_PM2.5"]],
                 file.path(outdir, "series_shillong_pm25.png"),
                 "Shillong PM2.5 --- original series")

s <- series[["CPCB_PM2.5"]]
y <- s$y
t <- s$times
n <- length(y)
h <- 24L
val <- 14L * 24L
n_fit <- n - h
n_val <- min(val, floor(n_fit * 0.15))
n_train <- n_fit - n_val
ytr <- y[seq_len(n_train)]

png(file.path(outdir, "diag_2x2_cpcb_pm25.png"), width = 1600, height = 1400, res = 140)
par(mfrow = c(2, 2), mar = c(4.2, 4.2, 3.2, 1))
acf(ytr, lag.max = 72, main = "CPCB PM2.5 --- ACF (train)", na.action = na.pass)
pacf(ytr, lag.max = 72, main = "CPCB PM2.5 --- PACF (train)", na.action = na.pass)
k <- 1L
plot(ytr[1:(length(ytr) - k)], ytr[(k + 1):length(ytr)], pch = 16, cex = 0.35,
     col = rgb(0.12, 0.23, 0.37, 0.25), xlab = "Y(t-1)", ylab = "Y(t)",
     main = "CPCB PM2.5 --- Lag-1 scatter")
k <- 24L
plot(ytr[1:(length(ytr) - k)], ytr[(k + 1):length(ytr)], pch = 16, cex = 0.35,
     col = rgb(0.12, 0.23, 0.37, 0.25), xlab = "Y(t-24)", ylab = "Y(t)",
     main = "CPCB PM2.5 --- Lag-24 scatter")
dev.off()

# Individual panels for annotated Beamer slides.
png(file.path(outdir, "acf_cpcb_pm25.png"), width = 900, height = 700, res = 140)
par(mar = c(4.2, 4.2, 3.2, 1))
acf(ytr, lag.max = 72, main = "CPCB PM2.5 --- ACF (train)", na.action = na.pass)
dev.off()
png(file.path(outdir, "pacf_cpcb_pm25.png"), width = 900, height = 700, res = 140)
par(mar = c(4.2, 4.2, 3.2, 1))
pacf(ytr, lag.max = 72, main = "CPCB PM2.5 --- PACF (train)", na.action = na.pass)
dev.off()
png(file.path(outdir, "lag1_scatter_cpcb_pm25.png"), width = 900, height = 700, res = 140)
par(mar = c(4.2, 4.2, 3.2, 1))
k <- 1L
plot(ytr[1:(length(ytr) - k)], ytr[(k + 1):length(ytr)], pch = 16, cex = 0.4,
     col = rgb(0.12, 0.23, 0.37, 0.25), xlab = "Y(t-1)", ylab = "Y(t)",
     main = "CPCB PM2.5 --- Lag-1 scatter")
dev.off()
png(file.path(outdir, "lag24_scatter_cpcb_pm25.png"), width = 900, height = 700, res = 140)
par(mar = c(4.2, 4.2, 3.2, 1))
k <- 24L
plot(ytr[1:(length(ytr) - k)], ytr[(k + 1):length(ytr)], pch = 16, cex = 0.4,
     col = rgb(0.12, 0.23, 0.37, 0.25), xlab = "Y(t-24)", ylab = "Y(t)",
     main = "CPCB PM2.5 --- Lag-24 scatter")
dev.off()

png(file.path(outdir, "boxes_cpcb_pm25.png"), width = 1400, height = 550, res = 140)
par(mfrow = c(1, 2), mar = c(4.5, 4.2, 3.2, 1))
hod <- lubridate::hour(t[seq_len(n_train)])
dow <- lubridate::wday(t[seq_len(n_train)], label = TRUE, week_start = 1)
boxplot(ytr ~ hod, outline = FALSE, col = "#EEF1F5", xlab = "Hour of day",
        ylab = "PM2.5", main = "CPCB PM2.5 --- Hour-of-day")
boxplot(ytr ~ dow, outline = FALSE, col = "#EEF1F5", xlab = NULL,
        ylab = "PM2.5", main = "CPCB PM2.5 --- Day of week")
dev.off()

ttr <- t[seq_len(n_train)]
sumr <- eda_design_summary(ytr, ttr, J = 5L, filter = "haar")
dec  <- eda_design_decisions(sumr)
sn   <- eda_snaive_resid(ytr, season = SEASONALITY)

png(file.path(outdir, "snaive_resid_acf_cpcb_pm25.png"), width = 1400, height = 550, res = 140)
par(mfrow = c(1, 2), mar = c(4.5, 4.2, 3.2, 1))
plot(sn$resid, type = "l", col = "#1F3A5F", lwd = 0.7,
     xlab = "Train index", ylab = "Y(t) - Y(t-24)",
     main = "CPCB PM2.5 --- snaive residuals (train)")
abline(h = 0, col = "grey70")
acf(sn$resid, lag.max = 72, na.action = na.pass,
    main = "ACF of snaive residuals")
dev.off()

png(file.path(outdir, "eda_to_pipeline_cpcb_pm25.png"), width = 1600, height = 900, res = 140)
op <- par(mar = c(1, 1, 3.5, 1))
plot.new()
title(main = "From EDA (train) to pipeline --- CPCB PM2.5",
      col.main = "#1F3A5F", cex.main = 1.35)
n_row <- nrow(dec)
ys <- seq(0.92, 0.08, length.out = n_row)
for (i in seq_len(n_row)) {
  y0 <- ys[i]
  rect(0.02, y0 - 0.07, 0.48, y0 + 0.05, col = "#EEF1F5", border = "#9AA7B5")
  rect(0.52, y0 - 0.07, 0.98, y0 + 0.05, col = "#F7EDE6", border = "#C49A7A")
  text(0.03, y0 + 0.035, "EDA finding", adj = c(0, 0.5), cex = 0.7, col = "#5A6A7A")
  text(0.53, y0 + 0.035, "Pipeline choice", adj = c(0, 0.5), cex = 0.7, col = "#8A5A3A")
  text(0.03, y0 - 0.015, dec$EDA_finding[i], adj = c(0, 0.5), cex = 0.85, col = "#1F3A5F")
  text(0.53, y0 - 0.015, dec$Pipeline_choice[i], adj = c(0, 0.5), cex = 0.85, col = "#A64B2A")
}
par(op)
dev.off()

win <- min(14L * 24L, n_train)
starts <- seq(1L, n_train - win + 1L, by = 24L)
sds <- vapply(starts, function(i) stats::sd(ytr[i:(i + win - 1L)], na.rm = TRUE), numeric(1))
i0 <- starts[which.max(sds)]
ys <- ytr[i0:(i0 + win - 1L)]
ts <- t[i0:(i0 + win - 1L)]
mra <- haar_mra(ys, 4L)
png(file.path(outdir, "mra_d1d4_s4_cpcb_pm25.png"), width = 1200, height = 1400, res = 140)
par(mfrow = c(6, 1), mar = c(2.2, 4, 2.4, 1))
plot(ts, ys, type = "l", col = "#1F3A5F", ylab = "Y", xlab = "",
     main = "CPCB PM2.5 --- Haar MRA (K=4)")
for (k in 1:4) {
  plot(ts, mra$D[[k]], type = "l", col = "#A64B2A", ylab = paste0("D", k), xlab = "")
}
plot(ts, mra$S, type = "l", col = "#2E6B4F", ylab = "S4", xlab = "Time")
dev.off()

d4 <- waveslim::wave.filter("d4")
la8 <- waveslim::wave.filter("la8")
filters <- list(
  Haar = list(p = c(0.5, -0.5), q = c(0.5, 0.5)),
  D4 = list(p = as.numeric(d4$hpf), q = as.numeric(d4$lpf)),
  LA8 = list(p = as.numeric(la8$hpf), q = as.numeric(la8$lpf))
)
png(file.path(outdir, "filter_taps.png"), width = 1400, height = 900, res = 140)
par(mfrow = c(3, 2), mar = c(4, 4, 3.2, 1))
for (nm in names(filters)) {
  f <- filters[[nm]]
  p <- f$p[is.finite(f$p)]; q <- f$q[is.finite(f$q)]
  yr <- range(c(p, q))
  if (!all(is.finite(yr)) || diff(yr) == 0) yr <- c(-1, 1)
  yr <- yr + c(-0.1, 0.1) * max(abs(yr), 0.1)
  plot(seq_along(p) - 1L, p, type = "h", lwd = 3, col = "#A64B2A", ylim = yr,
       xlab = "tap index", ylab = "coef",
       main = paste0(nm, " wavelet p (detail)"))
  points(seq_along(p) - 1L, p, pch = 16, col = "#A64B2A")
  abline(h = 0, col = "grey70")
  plot(seq_along(q) - 1L, q, type = "h", lwd = 3, col = "#1F3A5F", ylim = yr,
       xlab = "tap index", ylab = "coef",
       main = paste0(nm, " scaling q (smooth)"))
  points(seq_along(q) - 1L, q, pch = 16, col = "#1F3A5F")
  abline(h = 0, col = "grey70")
}
dev.off()

message("Wrote figures under ", normalizePath(outdir))
