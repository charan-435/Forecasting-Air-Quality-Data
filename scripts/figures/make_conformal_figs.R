# Conformal interval figures for slides — paper residual PI (letter Fig. 2 style).
options(warn = 1)
args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg))) else getwd()
proj <- if (length(file_arg)) normalizePath(file.path(script_dir, "..", "..")) else getwd()
setwd(proj)

outdir <- file.path("presentation", "images", "results")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

pp_path <- file.path("results", "paper", "paper_protocol.rds")
if (!file.exists(pp_path)) stop("Missing results/paper/paper_protocol.rds — run scripts/experiments/run_paper_protocol.R first.")
pp <- readRDS(pp_path)

get_z <- function(nm) {
  w <- pp[[nm]]$methods$wavecatboost
  if (is.null(w) || isTRUE(w$error) || is.null(w$yhat)) return(NULL)
  list(
    t_test = pp[[nm]]$t_test,
    y_test = pp[[nm]]$y_test,
    yhat = w$yhat,
    lower = w$lower,
    upper = w$upper,
    coverage_test = w$coverage_test,
    width = w$width,
    pollutant = "PM2.5"
  )
}

plot_one <- function(z, file, title) {
  t <- z$t_test; y <- z$y_test; yh <- z$yhat; lo <- z$lower; up <- z$upper
  png(file, width = 1400, height = 520, res = 140)
  par(mar = c(4.2, 4.2, 3.2, 1))
  yr <- range(c(y, yh, lo, up), na.rm = TRUE)
  plot(t, y, type = "n", ylim = yr, xlab = "Time", ylab = z$pollutant, main = title)
  # Match analysis.Rmd §8.2: black actual, rust WaveCatBoost, rust-tint band
  polygon(c(t, rev(t)), c(lo, rev(up)), col = rgb(166 / 255, 75 / 255, 42 / 255, 0.22), border = NA)
  lines(t, y, col = "black", lwd = 1.4)
  lines(t, yh, col = "#A64B2A", lwd = 1.3)
  legend("topleft",
         c("actual", "WaveCatBoost", "95% residual PI"),
         col = c("black", "#A64B2A", rgb(166 / 255, 75 / 255, 42 / 255, 0.55)),
         lty = c(1, 1, NA), lwd = c(1.4, 1.3, NA),
         pch = c(NA, NA, 15), pt.cex = 1.6, bty = "n", cex = 0.8)
  mtext(sprintf("cov=%.0f%%  mean width=%.2f",
                100 * z$coverage_test, z$width),
        side = 3, line = 0.15, cex = 0.75, col = "grey30")
  dev.off()
}

for (nm in c("CPCB", "ID1", "SHILLONG")) {
  z <- get_z(nm)
  if (is.null(z)) next
  plot_one(z,
           file.path(outdir, paste0("conformal_", tolower(nm), "_pm25.png")),
           sprintf("%s PM2.5 --- 7-day paper residual PI", nm))
}

png(file.path(outdir, "conformal_cpcb_id1.png"), width = 1600, height = 620, res = 140)
par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.4, 1))
for (nm in c("CPCB", "ID1")) {
  z <- get_z(nm)
  t <- z$t_test; y <- z$y_test; yh <- z$yhat; lo <- z$lower; up <- z$upper
  yr <- range(c(y, yh, lo, up), na.rm = TRUE)
  plot(t, y, type = "n", ylim = yr, xlab = "Time", ylab = "PM2.5",
       main = sprintf("%s  (cov=%.0f%%)", nm, 100 * z$coverage_test))
  polygon(c(t, rev(t)), c(lo, rev(up)), col = rgb(166 / 255, 75 / 255, 42 / 255, 0.22), border = NA)
  lines(t, y, col = "black", lwd = 1.3)
  lines(t, yh, col = "#A64B2A", lwd = 1.2)
}
dev.off()

message("Wrote paper residual PI figs under ", normalizePath(outdir))
