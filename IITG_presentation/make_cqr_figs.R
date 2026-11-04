# CQR vs split-conformal figures for slides.
options(warn = 1)
setwd("c:/Users/chara/Desktop/atsa_project")
outdir <- file.path("IITG_presentation", "images", "results")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

co <- readRDS("results/conformal.rds")
ce <- readRDS("results/conformal_ext.rds")

# CPCB: split vs CQR side by side
png(file.path(outdir, "conformal_vs_cqr_cpcb.png"), width = 1600, height = 620, res = 140)
par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.4, 1))

z <- co$CPCB
t <- z$t_test; y <- z$y_test; yh <- z$yhat; lo <- z$lower; up <- z$upper
yr <- range(c(y, yh, lo, up, ce$cqr$CPCB$lower, ce$cqr$CPCB$upper), na.rm = TRUE)
plot(t, y, type = "n", ylim = yr, xlab = "Time", ylab = "PM2.5",
     main = sprintf("Split conformal  (cov=%.0f%%, w=%.1f)",
                    100 * z$coverage_test, z$width))
polygon(c(t, rev(t)), c(lo, rev(up)), col = rgb(0.55, 0.45, 0.70, 0.35), border = NA)
lines(t, y, col = "#1F3A5F", lwd = 1.3)
lines(t, yh, col = "#A64B2A", lwd = 1.2)

z <- ce$cqr$CPCB
t <- z$t_test; y <- z$y_test; yh <- z$yhat; lo <- z$lower; up <- z$upper
plot(t, y, type = "n", ylim = yr, xlab = "Time", ylab = "PM2.5",
     main = sprintf("CQR  (cov=%.0f%%, w=%.1f)",
                    100 * z$coverage_test, z$width))
polygon(c(t, rev(t)), c(lo, rev(up)), col = rgb(0.35, 0.55, 0.40, 0.35), border = NA)
lines(t, y, col = "#1F3A5F", lwd = 1.3)
lines(t, yh, col = "#2E6B4F", lwd = 1.2)
dev.off()

message("Wrote ", file.path(outdir, "conformal_vs_cqr_cpcb.png"))
