# Conformal interval figures for slides.
options(warn = 1)
args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg))) else getwd()
proj <- if (basename(script_dir) == "IITG_presentation") dirname(script_dir) else script_dir
setwd(proj)

outdir <- file.path("IITG_presentation", "images", "results")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

conf_path <- file.path("results", "conformal.rds")
if (!file.exists(conf_path)) stop("Missing results/conformal.rds — run run_conformal.R first.")
conf <- readRDS(conf_path)

plot_one <- function(z, file, title) {
  t <- z$t_test
  y <- z$y_test
  yh <- z$yhat
  lo <- z$lower
  up <- z$upper
  png(file, width = 1400, height = 520, res = 140)
  par(mar = c(4.2, 4.2, 3.2, 1))
  yr <- range(c(y, yh, lo, up), na.rm = TRUE)
  plot(t, y, type = "n", ylim = yr, xlab = "Time", ylab = z$pollutant, main = title)
  polygon(c(t, rev(t)), c(lo, rev(up)), col = rgb(0.55, 0.45, 0.70, 0.35), border = NA)
  lines(t, y, col = "#1F3A5F", lwd = 1.4)
  lines(t, yh, col = "#A64B2A", lwd = 1.3)
  legend("topleft",
         c("actual", "WaveCatBoost", "95% conformal PI"),
         col = c("#1F3A5F", "#A64B2A", rgb(0.55, 0.45, 0.70, 0.7)),
         lty = c(1, 1, NA), lwd = c(1.4, 1.3, NA),
         pch = c(NA, NA, 15), pt.cex = 1.6, bty = "n", cex = 0.8)
  mtext(sprintf("cov_test=%.1f%%  kappa=%s  mean width=%.2f",
                100 * z$coverage_test, z$kappa, z$width),
        side = 3, line = 0.15, cex = 0.75, col = "grey30")
  dev.off()
}

for (nm in c("CPCB", "ID1", "SHILLONG")) {
  if (is.null(conf[[nm]])) next
  z <- conf[[nm]]
  plot_one(z,
           file.path(outdir, paste0("conformal_", tolower(nm), "_pm25.png")),
           sprintf("%s PM2.5 --- 7-day split conformal (1-step)", nm))
}

# Side-by-side CPCB + ID1 for one slide
png(file.path(outdir, "conformal_cpcb_id1.png"), width = 1600, height = 620, res = 140)
par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.4, 1))
for (nm in c("CPCB", "ID1")) {
  z <- conf[[nm]]
  t <- z$t_test; y <- z$y_test; yh <- z$yhat; lo <- z$lower; up <- z$upper
  yr <- range(c(y, yh, lo, up), na.rm = TRUE)
  plot(t, y, type = "n", ylim = yr, xlab = "Time", ylab = "PM2.5",
       main = sprintf("%s  (cov=%.0f%%)", nm, 100 * z$coverage_test))
  polygon(c(t, rev(t)), c(lo, rev(up)), col = rgb(0.55, 0.45, 0.70, 0.35), border = NA)
  lines(t, y, col = "#1F3A5F", lwd = 1.3)
  lines(t, yh, col = "#A64B2A", lwd = 1.2)
}
dev.off()

message("Wrote conformal figs under ", normalizePath(outdir))
