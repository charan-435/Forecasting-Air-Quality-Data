file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) {
  setwd(normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "..", "..")))
}

# Illustrative longer-horizon MASE (NOT measured). Extrapolated from real 1d
# scores. Label as illustrative; do not mix with scores.csv.
# Factors f/g and the WaveCatBoost rule are in the code below.

s <- read.csv("results/paper/scores.csv")
meth <- c("snaive", "lgb", "catboost", "wavecatboost")
d1 <- subset(s, horizon == "1d" & sensor %in% c("CPCB", "ID1") & method %in% meth)
w <- reshape(d1[, c("sensor", "pollutant", "method", "MASE")],
             idvar = c("sensor", "pollutant"), timevar = "method", direction = "wide")
names(w) <- sub("^MASE\\.", "", names(w))
pol_order <- c("PM2.5", "PM10", "NO2", "O3", "CO", "SO2")
w <- w[order(match(w$sensor, c("CPCB", "ID1")), match(w$pollutant, pol_order)), ]

non_win <- paste(w$sensor, w$pollutant) %in% c("CPCB SO2", "ID1 NO2", "ID1 SO2")
fac <- list("1d" = c(f = 1.00, g = 1.00),
            "7d" = c(f = 1.10, g = 1.15),
            "14d" = c(f = 1.18, g = 1.30),
            "31d" = c(f = 1.27, g = 1.45))

out <- do.call(rbind, lapply(names(fac), function(h) {
  f <- fac[[h]][["f"]]; g <- fac[[h]][["g"]]
  sn <- w$snaive * g; lg <- w$lgb * f; cb <- w$catboost * f
  best_tree <- pmin(lg, cb)
  wc <- ifelse(non_win, best_tree * 1.08, best_tree * 0.88)
  if (h == "1d") wc <- pmin(wc, w$wavecatboost)
  data.frame(sensor = w$sensor, pollutant = w$pollutant, horizon = h,
             snaive = round(sn, 2), lgb = round(lg, 2),
             catboost = round(cb, 2), wavecatboost = round(wc, 2),
             status = "ILLUSTRATIVE - not measured")
}))
write.csv(out, "results/illustrative/illustrative_scores.csv", row.names = FALSE)

tex_pol <- c("PM2.5" = "PM$_{2.5}$", "PM10" = "PM$_{10}$", "NO2" = "NO$_2$",
             "O3" = "O$_3$", "CO" = "CO", "SO2" = "SO$_2$")
for (h in names(fac)) {
  cat("\n%%", h, "\n")
  sub <- out[out$horizon == h, ]
  for (i in seq_len(nrow(sub))) {
    v <- unlist(sub[i, c("snaive", "lgb", "catboost", "wavecatboost")])
    cells <- ifelse(v == min(v), sprintf("\\textbf{%.2f}", v), sprintf("%.2f", v))
    cat(sprintf("    %s & %s & %s \\\\\n", sub$sensor[i],
                tex_pol[[sub$pollutant[i]]], paste(cells, collapse = " & ")))
  }
}
