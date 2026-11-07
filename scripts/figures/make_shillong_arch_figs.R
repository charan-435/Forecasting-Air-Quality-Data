# Presentation figures for Shillong A0--C3 (numbers from package REPORT §5).
options(warn = 1)
args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg))) else getwd()
proj <- if (length(file_arg)) normalizePath(file.path(script_dir, "..", "..")) else getwd()
setwd(proj)

outdir <- file.path("presentation", "images", "shillong_arch")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

NAVY <- "#1F3A5F"
RUST <- "#A64B2A"
GREEN <- "#2E6B4F"
BLUE <- "#3D6B9A"
GREY <- "#7A8B9A"

# Lumpyngngad PM2.5 test MAE (ug/m3), LightGBM seed mean — REPORT.md §5.
mae <- data.frame(
  arch = rep(c("A0", "A1", "A2", "A3", "B0", "C2_sep", "Persist."), each = 4L),
  h = rep(c(24L, 168L, 336L, 744L), times = 7L),
  MAE = c(
    9.84, 15.64, 16.82, 13.10,   # A0
    9.72, 16.42, 18.71, 16.55,   # A1
    9.11, 10.94, 12.29, 11.42,   # A2
    9.04, 10.82, 12.51, 12.31,   # A3
    10.38, 14.21, 16.09, 15.69,  # B0
    9.54, 10.45, 13.90, 13.06,   # C2_sep
    10.03, 13.28, 15.70, 14.65   # Persistence
  ),
  stringsAsFactors = FALSE
)
mae$kind <- ifelse(mae$arch %in% c("A0", "A1", "A2", "A3"), "level",
              ifelse(mae$arch %in% c("B0", "C2_sep"), "decomp", "reference"))
mae$h_lab <- factor(paste0("h = ", mae$h, " h"),
                    levels = paste0("h = ", c(24, 168, 336, 744), " h"))
mae$arch <- factor(mae$arch,
                   levels = c("A0", "A1", "A2", "A3", "B0", "C2_sep", "Persist."))

png(file.path(outdir, "lump_test_mae_bars.png"), width = 1600, height = 620, res = 140)
op <- par(mfrow = c(1, 4), mar = c(6.2, 4.2, 3.5, 0.8), oma = c(0, 0, 2.2, 0))
cols <- c(A0 = BLUE, A1 = BLUE, A2 = GREEN, A3 = GREEN,
          B0 = RUST, C2_sep = RUST, Persist. = GREY)
for (hh in c(24L, 168L, 336L, 744L)) {
  d <- mae[mae$h == hh, ]
  d <- d[order(d$arch), ]
  yl <- c(0, max(mae$MAE) * 1.08)
  bp <- barplot(d$MAE, names.arg = as.character(d$arch), las = 2, col = cols[as.character(d$arch)],
                border = NA, ylim = yl, ylab = if (hh == 24L) expression(MAE~(mu*g/m^3)) else "",
                main = paste0("h = ", hh, " h"), cex.names = 0.85, cex.main = 1.05)
  abline(h = d$MAE[d$arch == "A0"], col = NAVY, lty = 3, lwd = 1.2)
}
mtext("Lumpyngngad PM2.5 --- test MAE by architecture (LightGBM seed mean)",
      outer = TRUE, cex = 1.05, font = 2, col = NAVY, line = 0.4)
par(op)
dev.off()

a0 <- mae$MAE[mae$arch == "A0"]
a2 <- mae$MAE[mae$arch == "A2"]
ratio <- a2 / a0
hs <- c(24L, 168L, 336L, 744L)
png(file.path(outdir, "lump_a2_vs_a0_ratio.png"), width = 1000, height = 560, res = 140)
par(mar = c(4.5, 4.5, 3.8, 1.2))
bp <- barplot(ratio, names.arg = paste0("h=", hs), col = GREEN, border = NA,
              ylim = c(0, 1.15), ylab = "MAE(A2) / MAE(A0)",
              main = "A2 vs A0 on test --- Lumpyngngad PM2.5")
abline(h = 1, lty = 2, col = "grey40")
text(bp, ratio + 0.04, sprintf("%.2f", ratio), col = NAVY, cex = 1.05, font = 2)
mtext("Ratio < 1: multivariate lags beat univariate", side = 3, line = 0.15, cex = 0.85, col = GREY)
dev.off()

png(file.path(outdir, "lump_test_mae_table.png"), width = 1200, height = 560, res = 140)
par(mar = c(1, 1, 3.5, 1))
plot.new()
title(main = "Lumpyngngad PM2.5 --- test MAE (\u00b5g/m\u00b3)", col.main = NAVY, cex.main = 1.25)
hdr <- c("Arch", "h=24", "h=168", "h=336", "h=744", "vs A0 @168")
xs <- seq(0.06, 0.94, length.out = length(hdr))
text(xs, 0.90, hdr, font = 2, cex = 0.95, col = NAVY)
rows <- c("A0", "A1", "A2", "A3", "B0", "C2_sep", "Persist.")
for (i in seq_along(rows)) {
  a <- rows[i]
  y <- 0.78 - (i - 1) * 0.10
  vals <- mae$MAE[mae$arch == a]
  vs <- vals[2] / mae$MAE[mae$arch == "A0"][2]
  lab <- c(a, sprintf("%.2f", vals), sprintf("%.2f", vs))
  if (a %in% c("A2", "A3")) rect(0.02, y - 0.04, 0.98, y + 0.04, col = "#F7EDE6", border = NA)
  text(xs, y, lab, cex = 0.95,
       col = if (a %in% c("A2", "A3")) RUST else NAVY,
       font = if (a %in% c("A2", "A3")) 2 else 1)
}
dev.off()

png(file.path(outdir, "arch_family_map.png"), width = 1400, height = 720, res = 140)
par(mar = c(1, 1, 3.2, 1))
plot.new()
title(main = "Shillong A0--C3 --- design axes", col.main = NAVY, cex.main = 1.3)
# three columns
boxes <- list(
  list(x = 0.17, title = "A --- raw level",
       lines = c("A0  own PM2.5 lags (24)",
                 "A1  A0 + weather @ origin",
                 "A2  lags of all pollutants",
                 "A3  A2 + weather"),
       col = "#E8EEF5"),
  list(x = 0.50, title = "B --- Haar bands",
       lines = c("B0  one model / band (own lags)",
                 "B1  shared model + band id",
                 "B2  B0 + weather",
                 "B3  B1 + weather"),
       col = "#F7EDE6"),
  list(x = 0.83, title = "C --- cross inputs",
       lines = c("C1  all own bands as features",
                 "C2  all bands × pollutants",
                 "C3  C2 + weather",
                 "(_sep / _sh = separate / shared)"),
       col = "#EAF3EC")
)
for (b in boxes) {
  rect(b$x - 0.15, 0.12, b$x + 0.15, 0.82, col = b$col, border = "#9AA7B5")
  text(b$x, 0.76, b$title, font = 2, cex = 1.05, col = NAVY)
  for (j in seq_along(b$lines)) {
    text(b$x - 0.13, 0.66 - (j - 1) * 0.11, b$lines[j], adj = c(0, 0.5), cex = 0.78, col = NAVY)
  }
}
text(0.5, 0.05,
     "Protocol: direct \u0177(t+h)=f_h(X_t), h\u2208{24,168,336,744}, LightGBM stage-1, paired bootstrap on test",
     cex = 0.78, col = GREY)
dev.off()

message("Wrote figures under ", normalizePath(outdir))
