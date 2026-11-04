# Sampled causality / additivity / edge-fidelity checks of the repo's
# trailing-window Haar MRA (mra_haar_J5) on the real CPCB clean-store series.
# Uses the repo's own functions. Nothing is written to the repo and no full
# decomposition series is stored: only per-pollutant summary rows.
#
#   Rscript decomp_causality_check.R <repo_root> <wide_csv> <out_dir>

args <- commandArgs(trailingOnly = TRUE)
repo <- args[1]; wide_csv <- args[2]; out_dir <- args[3]
suppressPackageStartupMessages({ library(dplyr); library(yaml) })
`%||%` <- function(a, b) if (is.null(a)) b else a
PROJECT_ROOT <- repo
sys.source(file.path(repo, "R", "04_modwt.R"), envir = .GlobalEnv)
sys.source(file.path(repo, "R", "32_decomp_trailing.R"), envir = .GlobalEnv)
sys.source(file.path(repo, "R", "30_decomp_registry.R"), envir = .GlobalEnv)

cfg <- yaml::read_yaml(file.path(repo, "config", "decomp.yaml"))
.GlobalEnv$.DECOMP_CFG <- cfg
entry <- Filter(function(m) m$id == "mra_haar_J5", cfg$methods)[[1]]
W <- as.integer(cfg$window_h)
fn <- decomp_mra_haar
J <- as.integer(entry$params$J)
comps <- c(paste0("D", 1:J), paste0("S", J))

wide <- read.csv(wide_csv, check.names = FALSE, stringsAsFactors = FALSE)
pols <- c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO")
n <- nrow(wide)
set.seed(2026)
pool <- seq.int(W, n - 745L)
tsamp <- sort(sample(pool, 40L))
bump <- 50

at_t <- function(x, t) .decomp_at_t(x, t, entry, fn, W)

rows <- list(); reach <- list(); edge <- list()
for (p in pols) {
  x <- as.numeric(wide[[p]])
  worst_future <- 0; worst_add <- 0
  past_changes <- c(k0 = 0, k1 = 0, k31 = 0, kW_minus_1 = 0, kW = 0)
  for (t0 in tsamp) {
    base <- at_t(x, t0)
    worst_add <- max(worst_add, abs(sum(base) - x[t0]))
    for (k in c(1L, 24L, 168L, 336L, 744L)) {
      xp <- x; xp[t0 + k] <- xp[t0 + k] + bump
      worst_future <- max(worst_future, max(abs(at_t(xp, t0) - base)))
    }
    for (nm in names(past_changes)) {
      k <- switch(nm, k0 = 0L, k1 = 1L, k31 = 31L, kW_minus_1 = W - 1L, kW = W)
      xp <- x; xp[t0 - k] <- xp[t0 - k] + bump
      past_changes[[nm]] <- max(past_changes[[nm]], max(abs(at_t(xp, t0) - base)))
    }
  }
  rows[[p]] <- data.frame(
    variable = p, method = "mra_haar_J5__raw", window_h = W, J = J,
    components = paste(comps, collapse = ","),
    n_sampled_t = length(tsamp),
    max_change_from_future_bump = worst_future,
    causal_at_t = worst_future == 0,
    max_additivity_error = worst_add,
    change_from_bump_at_t = past_changes[["k0"]],
    change_from_bump_at_t_minus_1 = past_changes[["k1"]],
    change_from_bump_at_t_minus_31 = past_changes[["k31"]],
    change_from_bump_at_t_minus_W_plus_1 = past_changes[["kW_minus_1"]],
    change_from_bump_at_t_minus_W = past_changes[["kW"]]
  )

  # dependence profile of each component at the window end on x[t-k], k=0..W-1
  if (p == "PM2.5") {
    t0 <- tsamp[10]
    base <- at_t(x, t0)
    ks <- c(0:40, (W - 40L):(W - 1L))
    prof <- t(vapply(ks, function(k) {
      xp <- x; xp[t0 - k] <- xp[t0 - k] + 1
      at_t(xp, t0) - base
    }, numeric(length(comps))))
    colnames(prof) <- comps
    reach <- data.frame(k_hours_before_t = ks, prof, check.names = FALSE)
  }

  # D3-style edge fidelity: real-time endpoint value at t vs the value at t
  # recomputed from a window ending at t + H (two-sided, uses future data on
  # purpose; diagnostic only, never a feature).
  for (H in c(32L, 512L)) {
    pos <- W - H
    rt <- matrix(NA_real_, length(tsamp), length(comps))
    rv <- rt
    for (ii in seq_along(tsamp)) {
      t0 <- tsamp[ii]
      rt[ii, ] <- at_t(x, t0)
      win <- x[(t0 + H - W + 1L):(t0 + H)]
      rv[ii, ] <- fn(win, entry$params)[pos, ]
    }
    for (j in seq_along(comps)) {
      a <- rt[, j]; b <- rv[, j]
      edge[[length(edge) + 1L]] <- data.frame(
        variable = p, revised_with_future_hours = H, component = comps[j],
        cor_realtime_vs_revised = suppressWarnings(cor(a, b)),
        nrmse = sqrt(mean((a - b)^2)) / sd(b),
        sign_agreement = mean(sign(a) == sign(b))
      )
    }
  }
}

# engine equivalence: run_trailing_series row t == .decomp_at_t at t (short synthetic)
set.seed(1)
xs <- 20 + 5 * sin(2 * pi * seq_len(300) / 24) + rnorm(300)
Ws <- 128L
M <- run_trailing_series(xs, fn, entry$params, Ws, 0L)
eq <- max(abs(M[200, ] - .decomp_at_t(xs, 200L, entry, fn, Ws)))
na_rows <- sum(!complete.cases(M))

res <- do.call(rbind, rows)
write.csv(res, file.path(out_dir, "decomposition_causality_check_mra_haar_J5.csv"), row.names = FALSE)
write.csv(reach, file.path(out_dir, "decomposition_endpoint_dependence_profile_PM25.csv"), row.names = FALSE)
write.csv(do.call(rbind, edge), file.path(out_dir, "decomposition_edge_fidelity_mra_haar_J5.csv"), row.names = FALSE)
print(res)
cat("engine equivalence max diff:", eq, " warm-up NA rows in engine output (n=300, W=128):", na_rows, "\n")
cat("sampled t range:", min(tsamp), max(tsamp), "\n")
print(do.call(rbind, edge) %>% group_by(revised_with_future_hours, component) %>%
        summarise(cor = round(median(cor_realtime_vs_revised), 3),
                  nrmse = round(median(nrmse), 3), .groups = "drop"))
nz <- reach[rowSums(abs(reach[, -1])) > 0, ]
cat("PM2.5 endpoint: lags k with nonzero influence (first/last few):\n")
print(head(nz$k_hours_before_t, 40)); print(tail(nz$k_hours_before_t, 40))
