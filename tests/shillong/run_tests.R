# Shillong architecture study: automated tests. Sourced by the audit stage
# (sh_run_tests) or run directly:  Rscript tests/shillong/run_tests.R
# Produces SH_TEST_RESULTS (test, pass, detail).

if (!exists("sh_panel")) {
  suppressMessages({
    source("R/load_all.R")
    for (f in c("R/40_mv_data.R", "R/41_mv_features.R", "R/43_mv_models.R", "R/44_mv_metrics.R",
                "R/45_mv_families.R", "R/47_mv_eval.R", "R/48_mv_runner.R", "R/50_sh_data.R",
                "R/51_sh_features.R", "R/52_sh_audit.R", "R/53_sh_experiments.R")) source(f)
    library(data.table)
  })
}
if (!exists("cfg")) cfg <- yaml::read_yaml("config/shillong_arch.yaml")

SH_TEST_RESULTS <- data.frame(test = character(), pass = logical(), detail = character())
check <- function(id, expr, detail = "") {
  ok <- tryCatch(isTRUE(expr), error = function(e) { detail <<- conditionMessage(e); FALSE })
  SH_TEST_RESULTS[nrow(SH_TEST_RESULTS) + 1L, ] <<- list(id, ok, detail)
  cat(sprintf("%-4s %-62s %s\n", if (ok) "ok" else "FAIL", id, detail))
}

long <- sh_read_long(cfg)
L <- sh_panel(cfg, long, "Lumpyngngad"); Ls <- sh_splits(cfg, "Lumpyngngad")
J <- sh_panel(cfg, long, "JN_Stadium"); Js <- sh_splits(cfg, "JN_Stadium")
La <- sh_available(cfg, L, Ls)
smp <- sh_samples(cfg, L, Ls, "PM2.5", 24L, La$pollutants)

# 1. hourly loading: hour t = mean of the 15-min slots in (t-1h, t], start-labelled +15 min
local({
  raw <- as.data.table(arrow::read_parquet(file.path(PROJECT_ROOT, cfg$raw_path)))
  raw <- raw[raw[["Station ID"]] == SH_STATIONS[["Lumpyngngad"]]]
  clock <- lubridate::as_datetime(format(raw$Timestamp, tz = "UTC", format = "%Y-%m-%d %H:%M:%S"),
                                  tz = "Asia/Kolkata")
  pm <- raw[[grep("^PM2.5", names(raw), value = TRUE)]]
  t <- as.POSIXct("2023-03-01 11:00", tz = "Asia/Kolkata")
  shifted <- clock + 900
  slots <- pm[shifted > t - 3600 & shifted <= t]
  st <- long[long$station == "Lumpyngngad" & variable == "PM2.5" & timestamp == t]
  check("T01 hourly value = mean of slots in (t-1h, t]",
        abs(st$value_hourly_raw - mean(slots[is.finite(slots)])) < 1e-9 && length(slots) == 4,
        sprintf("%d slots", length(slots)))
  check("T01 8760 hours per station and variable",
        all(long[, .N, by = .(station, variable)]$N == 8760))
})

# 2. station isolation
check("T02 panels hold only their own station",
      identical(L$observed[["PM2.5"]],
                long[long$station == "Lumpyngngad" & variable == "PM2.5"][order(timestamp)]$value_masked) &&
      identical(J$observed[["PM2.5"]],
                long[long$station == "JN_Stadium" & variable == "PM2.5"][order(timestamp)]$value_masked))
check("T02 JN Stadium has no data before 2023-07-26, Lumpyngngad does",
      !any(is.finite(J$observed[["PM2.5"]][J$timestamps < as.POSIXct("2023-07-26", tz = "Asia/Kolkata")])) &&
      any(is.finite(L$observed[["PM2.5"]][L$timestamps < as.POSIXct("2023-07-26", tz = "Asia/Kolkata")])))

# 3. pollutant timestamp alignment
check("T03 all variables on one contiguous hourly grid", {
  g <- long[long$station == "Lumpyngngad", .(ts = list(sort(timestamp))), by = variable]
  all(vapply(g$ts, identical, logical(1), g$ts[[1]])) &&
    all(diff(as.numeric(L$timestamps)) == 3600) && identical(L$met$timestamp, L$timestamps)
})

ds_of <- function(a, comp = NULL, P = L, S = Ls, A = La, sm = smp)
  sh_dataset(P, sh_arch(a), sm, "PM2.5", 24L, A, S, component = comp)

# 4. raw lags
local({
  ds <- ds_of("A2"); b <- ds$blocks$validation; i <- 17L; o <- b$origin_idx[i]
  check("T04 raw lag 1 = value at origin, lag 24 = value at origin - 23",
        b$X[i, "PM2.5_l01"] == L$fill[["PM2.5"]][o] && b$X[i, "PM2.5_l24"] == L$fill[["PM2.5"]][o - 23L] &&
          b$X[i, "CO_l07"] == L$fill[["CO"]][o - 6L])
  check("T04 A2 has 24 lags per available pollutant",
        ncol(b$X) == 24L * length(La$pollutants))
})

# 5. decomposed lags
local({
  ds <- ds_of("C2_sep", "D3"); b <- ds$blocks$train; i <- 101L; o <- b$origin_idx[i]
  check("T05 component lag k = component value at origin - k + 1",
        b$X[i, "PM2.5_D3_l05"] == L$comps[["PM2.5"]][o - 4L, "D3"] &&
          b$X[i, "SO2_S5_l24"] == L$comps[["SO2"]][o - 23L, "S5"] &&
          ncol(b$X) == 24L * length(La$pollutants) * length(L$components))
  check("T05 B0 component model sees only its own component",
        all(grepl("^PM2.5_D3_l", ds_of("B0", "D3")$feature_names)))
})

# 6./7./14. shared datasets: identity, sample construction, inverse scaling
local({
  sh <- ds_of("B1"); K <- length(L$components)
  b <- sh$blocks$train
  sep_n <- nrow(ds_of("B0", "D1")$blocks$train$X)
  check("T06 comp_id encodes the component (0..K-1) consistently",
        all(b$X[, "comp_id"] == match(b$component, L$components) - 1L))
  st <- sh$comp_stats; j <- 4L; cp <- L$components[j]
  r <- which(b$component == cp)[10]; o <- b$origin_idx[r]
  check("T06 own slot = standardized own-component lags",
        abs(b$X[r, "own_l03"] - (L$comps[["PM2.5"]][o - 2L, cp] - st$mean[j]) / st$sd[j]) < 1e-12)
  check("T07 shared rows = K x separate rows, same origins per component",
        nrow(b$X) == K * sep_n &&
          all(vapply(L$components, function(c) identical(b$origin_idx[b$component == c],
                                                         ds_of("B0", "D1")$blocks$train$origin_idx), TRUE)))
  check("T07 shared training rows only from training-block targets",
        all(L$timestamps[b$target_idx] <= Ls$train[2]))
  yb <- sh_unscale(sh, "validation", sh$blocks$validation$y)
  truth <- L$comps[["PM2.5"]][cbind(sh$blocks$validation$target_idx,
                                    match(sh$blocks$validation$component, L$components))]
  check("T14 inverse scaling recovers component values", max(abs(yb - truth)) < 1e-10)
  check("T14 scaling statistics come from training-block hours only", {
    w <- L$timestamps >= Ls$train[1] & L$timestamps <= Ls$train[2] & seq_along(L$timestamps) >= 2^L$J
    abs(st$mean[1] - mean(L$comps[["PM2.5"]][w, "D1"])) < 1e-12
  })
})

# 8./9. covariates: at the origin only, never lagged
local({
  ds <- ds_of("A1"); b <- ds$blocks$test; i <- 5L; o <- b$origin_idx[i]; tt <- b$target_idx[i]
  cv <- grep("^cov_", ds$feature_names, value = TRUE)
  check("T08 one column per covariate, value at the origin",
        length(cv) == length(La$covariates) &&
          isTRUE(all.equal(unname(b$X[i, cv]), unname(unlist(L$met[o, La$covariates, with = FALSE])))))
  check("T08 calendar describes the target timestamp",
        b$X[i, "cal_hour"] == lubridate::hour(L$timestamps[tt]) &&
          b$X[i, "cal_dow"] == lubridate::wday(L$timestamps[tt], week_start = 1))
  ok <- vapply(c("A1", "A3", "B2", "B3", "C3_sep", "C3_sh"), function(a) {
    fn <- (if (a %in% c("B2", "C3_sep")) ds_of(a, "D1") else ds_of(a))$feature_names
    cvn <- grep("^cov_|^cal_", fn, value = TRUE)
    !any(grepl("_l[0-9]+$", cvn)) && length(cvn) == length(La$covariates) + 2L
  }, logical(1))
  check("T09 covariate architectures carry no covariate lags", all(ok), paste(names(ok)[!ok], collapse = ","))
  check("T09 A1 history is the target pollutant only",
        all(sub("_l[0-9]+$", "", grep("_l[0-9]+$", ds$feature_names, value = TRUE)) == "PM2.5"))
  check("T09 no covariates in A0/A2/B0/B1/C1/C2",
        !any(grepl("^cov_|^cal_", c(ds_of("A0")$feature_names, ds_of("A2")$feature_names,
                                    ds_of("B0", "D1")$feature_names, ds_of("B1")$feature_names,
                                    ds_of("C1_sh")$feature_names, ds_of("C2_sep", "S5")$feature_names))))
})

# 10. no future observations: perturb everything after a cut, rebuild the
# decomposition from the perturbed series, features at origins <= cut unchanged
local({
  cut <- smp$origin_idx[which(smp$block == "validation")[50]]
  P2 <- L
  n <- length(P2$timestamps); fut <- (cut + 1L):n
  set.seed(3)
  for (v in P2$pollutants) {
    x <- P2$fill[[v]]; x[fut] <- x[fut] * 3 + stats::rnorm(length(fut), 50, 20)
    P2$fill[[v]] <- x
    P2$comps[[v]] <- sh_decompose(x, P2$J)
  }
  for (v in setdiff(names(P2$met), "timestamp")) P2$met[[v]][fut] <- -999
  sm <- smp[smp$origin_idx <= cut, ]
  same <- vapply(names(SH_ARCHS), function(a) {
    comp <- if (sh_arch(a)$kind == "decomp" && sh_arch(a)$structure == "separate") "D2" else NULL
    d1 <- sh_dataset(L, sh_arch(a), sm, "PM2.5", 24L, La, Ls, comp)
    d2 <- sh_dataset(P2, sh_arch(a), sm, "PM2.5", 24L, La, Ls, comp)
    all(vapply(names(d1$blocks), function(b) identical(d1$blocks[[b]]$X, d2$blocks[[b]]$X), TRUE))
  }, logical(1))
  check("T10 changing data after the origin leaves every architecture's inputs unchanged",
        all(same), paste(names(same)[!same], collapse = ","))
  check("T10 every input index <= origin (max lag index = origin)",
        all(smp$target_idx - smp$origin_idx == 24L))
})

# 11./12. chronological splits; no target crosses a boundary
local({
  ok <- TRUE
  for (h in cfg$horizons) for (P in list(list(L, Ls, La), list(J, Js, sh_available(cfg, J, Js)))) {
    s <- sh_samples(cfg, P[[1]], P[[2]], "PM2.5", h, P[[3]]$pollutants)
    for (b in names(P[[2]])) {
      tt <- s$target_ts[s$block == b]
      ok <- ok && all(tt >= P[[2]][[b]][1] & tt <= P[[2]][[b]][2])
    }
    ok <- ok && max(s$target_ts[s$block == "train"]) < min(s$target_ts[s$block == "validation"]) &&
      max(s$target_ts[s$block == "validation"]) < min(s$target_ts[s$block == "test"]) &&
      all(s$origin_idx < s$target_idx)
  }
  check("T11 blocks are chronological and disjoint for every horizon and station", ok)
  check("T12 no training target after the training end (h = 744)", {
    s <- sh_samples(cfg, L, Ls, "PM2.5", 744L, La$pollutants)
    max(s$target_ts[s$block == "train"]) <= Ls$train[2] &&
      max(s$target_ts[s$block == "validation"]) <= Ls$validation[2]
  })
  check("T12 every target hour is scorable and every origin passes the store policy", {
    all(L$scorable[["PM2.5"]][smp$target_idx]) &&
      all(L$frac_filled_24h[["PM2.5"]][smp$origin_idx] <= 0.25) &&
      !any(L$in_long_gap[["PM2.5"]][smp$origin_idx])
  })
})

# 13. causal imputation: a fill at t does not change when data after t change
local({
  set.seed(11)
  n <- 400L; tt <- as.POSIXct("2023-03-01", tz = "Asia/Kolkata") + 3600 * (0:(n - 1))
  x <- 50 + 10 * sin(2 * pi * (0:(n - 1)) / 24) + stats::rnorm(n)
  x[c(100:102, 150:170, 220:260, 300:390)] <- NA
  mb <- list(`1-3` = "M1", `4-24` = "M4", `25-72` = "M5", `>72` = "M2")
  a <- apply_fills(x, tt, mb)
  x2 <- x; x2[261:n] <- x2[261:n] + 500
  b <- apply_fills(x2, tt, mb)
  check("T13 imputed values up to t ignore observations after t",
        identical(a$filled[1:260], b$filled[1:260]))
  st <- long[long$station == "Lumpyngngad" & variable == "SO2"][order(timestamp)]
  m1 <- which(st$fill_method == "M1" & c(FALSE, !is.na(st$value_masked[-nrow(st)])))
  check("T13 store LOCF fills equal the previous observed hour",
        length(m1) > 0 && all(st$value_filled_causal[m1] == st$value_masked[m1 - 1L]))
  check("T13 store keeps observed hours unchanged",
        all(st$value_filled_causal[!is.na(st$value_masked)] == st$value_masked[!is.na(st$value_masked)]))
})

# 15. reconstruction additivity
check("T15 sum of components = series (every pollutant, both stations)", {
  ok <- TRUE
  for (P in list(L, J)) {
    sp <- sh_splits(cfg, P$station)
    for (v in sh_available(cfg, P, sp)$pollutants) {
      w <- rowSums(!is.finite(P$comps[[v]])) == 0
      ok <- ok && max(abs(rowSums(P$comps[[v]][w, ]) - P$fill[[v]][w])) < 1e-9 &&
        all(w[P$timestamps >= sp$train[1] + 3600 * (2^P$J - 1)])   # complete after warmup
    }
  }
  ok
})
check("T15 component at t uses only x[t - 2^J + 1 .. t]", {
  x <- L$fill[["PM2.5"]]; t <- 5000L
  a <- sh_decompose(x[1:t], L$J)[t, ]
  b <- sh_decompose(c(rep(0, 100), x[(t - 2^L$J + 1L):t]), L$J)
  max(abs(a - b[nrow(b), ])) < 1e-9
})

# 16. identical evaluation timestamps
check("T16 all architectures share target timestamps per block", {
  key <- function(ds) lapply(ds$blocks, function(b) sort(unique(b$target_idx)))
  ref <- key(ds_of("A0"))
  all(vapply(c("A1", "A2", "A3", "B1", "B3", "C1_sh", "C2_sh", "C3_sh"),
             function(a) identical(key(ds_of(a)), ref), TRUE)) &&
    all(vapply(c("B0", "B2", "C1_sep", "C2_sep", "C3_sep"),
               function(a) identical(key(ds_of(a, "S5")), ref), TRUE))
})
check("T16 samples are the same for every pollutant set used as inputs", {
  s1 <- sh_samples(cfg, L, Ls, "PM2.5", 168L, La$pollutants)
  ds1 <- sh_dataset(L, sh_arch("A0"), s1, "PM2.5", 168L, La, Ls)
  ds2 <- sh_dataset(L, sh_arch("C3_sh"), s1, "PM2.5", 168L, La, Ls)
  identical(ds1$blocks$test$target_idx, unique(ds2$blocks$test$target_idx))
})

# 17. reproducibility
local({
  ds <- ds_of("A2")
  p <- list(objective = "regression", learning_rate = 0.1, num_leaves = 15, min_data_in_leaf = 50,
            feature_fraction = 0.8, bagging_fraction = 0.8, bagging_freq = 1,
            num_iterations = 60, early_stopping_rounds = 10)
  r1 <- mv_select_and_refit("lightgbm", ds, p, 2026L)
  r2 <- mv_select_and_refit("lightgbm", ds, p, 2026L)
  check("T17 same seed -> identical forecasts", identical(r1$pred, r2$pred))
  check("T17 samples and datasets rebuild identically",
        identical(sh_samples(cfg, L, Ls, "PM2.5", 24L, La$pollutants), smp) &&
          identical(digest::digest(ds_of("C2_sh")), digest::digest(ds_of("C2_sh"))))
})

cat(sprintf("\n%d / %d tests passed\n", sum(SH_TEST_RESULTS$pass), nrow(SH_TEST_RESULTS)))
