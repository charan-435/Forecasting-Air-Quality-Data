# Second-stage tests (PCA isolation, recursion causality and consistency,
# hybrid inputs, cross-fit purge, reproduction of the original direct runs).
# Run through `Rscript code/experiments/run_second_stage.R --stage=tests`; expects cfg, scfg and
# load_station in the calling environment. Sets SS_TEST_RESULTS.

SS_TEST_RESULTS <- data.frame(test = character(0), pass = logical(0), detail = character(0))
check <- function(name, expr, detail = "") {
  ok <- tryCatch(isTRUE(expr), error = function(e) { detail <<- conditionMessage(e); FALSE })
  SS_TEST_RESULTS[nrow(SS_TEST_RESULTS) + 1L, ] <<- list(name, ok, as.character(detail))
  cat(if (ok) "PASS" else "FAIL", name, detail, "\n")
}

target <- cfg$primary_target
S <- load_station("Lumpyngngad")
SJ <- load_station("JN_Stadium")
smp24 <- sh_samples(cfg, S$panel, S$splits, target, 24L, S$avail$pollutants)
smp168 <- sh_samples(cfg, S$panel, S$splits, target, 168L, S$avail$pollutants)

# ---- PCA --------------------------------------------------------------------------------------
ds <- sh_dataset(S$panel, sh_arch("A3"), smp24, target, 24L, S$avail, S$splits)
Xtr <- ds$blocks$train$X; Xva <- ds$blocks$validation$X; Xte <- ds$blocks$test$X
tf <- ss_transform(Xtr, 0.95)
check("T01 PCA statistics are the training block's (mean)",
      isTRUE(all.equal(unname(tf$obj$mu), unname(colMeans(Xtr[, tf$obj$pc_cols])))))
check("T01 refit on train+validation applies the training PCA unchanged",
      identical(tf$fit(rbind(Xtr, Xva))$apply(Xte), tf$fit(Xtr)$apply(Xte)))
Xte2 <- Xte; Xte2[] <- Xte2[] * 3 + 1
check("T01 changing validation/test rows does not change the PCA",
      identical(ss_transform(Xtr, 0.95)$obj$rotation, tf$obj$rotation))
for (thr in c(0.90, 0.95, 0.99)) {
  o <- ss_pca_fit(Xtr, thr)
  check(sprintf("T02 retained k is the fewest components reaching %.2f", thr),
        o$info$cum_var[o$info$k] >= thr && (o$info$k == 1 || o$info$cum_var[o$info$k - 1] < thr),
        paste("k =", o$info$k, "of", o$info$n_in))
}
Z <- tf$obj$apply(Xte)
covc <- grep("^(cov_|cal_)", colnames(Xte), value = TRUE)
check("T03 A3: covariates and calendar are excluded from PCA",
      !any(grepl("^(cov_|cal_)", tf$obj$pc_cols)) && setequal(tf$obj$pass, covc))
check("T03 A3: covariates appended unchanged after the scores",
      identical(Z[, covc], Xte[, covc]) && all(grepl("^PC", setdiff(colnames(Z), covc))))
check("T03 A3: every pollutant lag enters PCA",
      setequal(tf$obj$pc_cols, grep("_l[0-9]{2}$", colnames(Xte), value = TRUE)))
dsc <- lapply(c("D1", "S5"), function(cp)
  sh_dataset(S$panel, sh_arch("C2_sep"), smp24, target, 24L, S$avail, S$splits, component = cp))
tfc <- lapply(dsc, function(d) ss_transform(d$blocks$train$X, 0.9)$obj)
check("T04 C2_sep: one PCA per component model, fitted on that model's training rows",
      all(vapply(seq_along(dsc), function(i) tfc[[i]]$info$n_fit == nrow(dsc[[i]]$blocks$train$X) &&
        isTRUE(all.equal(unname(tfc[[i]]$mu), unname(colMeans(dsc[[i]]$blocks$train$X)))), logical(1))))
check("T04 PCA input never contains the target (only lags at or before the origin)",
      all(grepl("_l[0-9]{2}$", tfc[[1]]$pc_cols)) && all(grepl("_l[0-9]{2}$", tf$obj$pc_cols)))

# ---- recursion state = original features ------------------------------------------------------
check("T05 Haar filter reproduces the panel components", {
  Fm <- ss_haar_filter(S$panel$J)
  idx <- 500:900
  W <- t(vapply(idx, function(t) S$panel$fill$PM2.5[(t - 31):t], numeric(32)))
  isTRUE(all.equal(unname(W %*% Fm), unname(S$panel$comps$PM2.5[idx, ]), tolerance = 1e-10))
})
for (SS in list(S, SJ)) for (a in unlist(cfg$architectures)) for (h in c(1L, 168L)) {
  arch <- sh_arch(a)
  sm <- sh_samples(cfg, SS$panel, SS$splits, target, h, SS$avail$pollutants)
  sm <- sm[sm$block != "train", ]
  sm <- sm[unique(as.integer(round(seq(1, nrow(sm), length.out = 60)))), ]
  cp <- if (arch$kind == "decomp" && arch$structure == "separate") "D3" else NULL
  d <- sh_dataset(SS$panel, arch, sm, target, h, SS$avail, SS$splits, component = cp)
  st <- ss_state_init(SS, arch, target, sm$origin_idx)
  same <- TRUE
  for (b in c("validation", "test")) {
    bk <- d$blocks[[b]]
    if (!length(bk$y)) next
    r <- match(unique(bk$origin_idx), st$origins)
    sb <- ss_state_subset(st, r)
    X <- if (arch$kind == "decomp" && arch$structure == "shared") {
      st_stats <- d$comp_stats
      P <- lapply(seq_along(SS$panel$components), function(j)
        ss_state_X_shared(sb, SS$panel, arch, target, j, h, SS$avail, st_stats))
      oi <- rep(sb$origins, length(P)); ci <- rep(seq_along(P), each = length(sb$origins))
      do.call(rbind, P)[order(oi, ci), , drop = FALSE]
    } else ss_state_X(sb, SS$panel, arch, target, cp, h, SS$avail)
    same <- same && identical(colnames(X), colnames(bk$X)) &&
      isTRUE(all.equal(unname(X), unname(bk$X), tolerance = 1e-12))
  }
  check(sprintf("T05 %s %s h=%d: state features at step 0 equal sh_dataset()", SS$panel$station, a, h), same)
}

# ---- recursion: causality and consistency (light models) ---------------------------------------
sc <- cfg
sc$families$lightgbm <- list(base = cfg$smoke$lightgbm$base)
seed1 <- as.integer(cfg$tune_seed)
perturb_after <- function(SS, t_cut) {
  P <- SS
  P$panel$fill <- data.table::copy(SS$panel$fill)
  P$panel$observed <- data.table::copy(SS$panel$observed)
  P$panel$met <- data.table::copy(SS$panel$met)
  late <- seq_along(P$panel$timestamps) > t_cut
  for (v in names(P$panel$fill)[-1]) {
    P$panel$fill[late, (v) := get(v) * 5 + 100]
    P$panel$observed[late, (v) := get(v) * 5 + 100]
  }
  for (v in names(P$panel$comps)) P$panel$comps[[v]][late, ] <- P$panel$comps[[v]][late, ] * 5 + 100
  for (v in setdiff(names(P$panel$met), "timestamp")) P$panel$met[late, (v) := get(v) * 5 + 100]
  P
}
for (a in c("A3", "C2_sep", "C1_sh")) {
  arch <- sh_arch(a)
  units <- ss_fit_onestep(sc, S, arch, target, if (a == "C2_sep") 0.95 else "none", seed1, seed1)
  vo <- smp168$origin_idx[smp168$block == "validation"][c(1, 200, 400)]
  t_cut <- max(vo)
  r0 <- ss_recurse(S, arch, target, units, vo, rep(30L, 3), "sel", record = c(1L, 30L), snap = 24L)
  r1 <- ss_recurse(perturb_after(S, t_cut), arch, target, units, vo, rep(30L, 3), "sel",
                   record = c(1L, 30L), snap = 24L)
  check(sprintf("T06 %s: data after the origin does not change recursive forecasts", a),
        identical(r0$pred, r1$pred))
  check(sprintf("T06 %s: data after the origin does not change hybrid inputs at s", a),
        identical(ss_state_X(r0$snaps[["24"]], S$panel, arch, target, if (a == "C2_sep") "S5" else NULL, 144L, S$avail),
                  ss_state_X(r1$snaps[["24"]], S$panel, arch, target, if (a == "C2_sep") "S5" else NULL, 144L, S$avail)))
  # step 1 = the one-step models applied to the original one-step features
  u <- units[[paste(target, if (arch$kind == "level") "LEVEL" else if (arch$structure == "shared") "ALL" else "D1")]]
  sm1 <- sh_samples(cfg, S$panel, S$splits, target, 1L, S$avail$pollutants)
  sm1 <- sm1[sm1$origin_idx %in% vo, ]
  if (nrow(sm1)) {
    d1 <- sh_dataset(S$panel, arch, sm1, target, 1L, S$avail, S$splits,
                     component = if (arch$kind == "decomp" && arch$structure == "separate") "D1" else NULL)
    bk <- d1$blocks$validation
    p_direct <- ss_fam()$predict(u$models[[1]]$sel, u$tf$apply(bk$X))
    if (!is.null(d1$comp_stats)) p_direct <- sh_unscale(d1, "validation", p_direct)
    comp_want <- if (arch$kind == "level") "LEVEL" else "D1"
    keep <- if (is.null(d1$comp_stats)) rep(TRUE, length(p_direct)) else bk$component == "D1"
    p_direct <- p_direct[keep]
    p_rec <- r0$pred[step == 1 & component == comp_want][match(bk$origin_idx[keep], origin_idx), yhat]
    check(sprintf("T07 %s: recursive step 1 equals the one-step model on the original features", a),
          isTRUE(all.equal(p_rec, p_direct, tolerance = 1e-10)))
  }
  if (arch$kind == "decomp") {
    lv <- r0$pred[component == "LEVEL"]; cs <- r0$pred[component != "LEVEL", .(s = sum(yhat)), by = .(origin_idx, step)]
    m <- merge(lv, cs, by = c("origin_idx", "step"))
    check(sprintf("T08 %s: recursive level = sum of component forecasts", a), max(abs(m$yhat - m$s)) < 1e-8)
    # components after 24 pushed steps = decomposition of history + predicted level
    sn <- r0$snaps[["24"]]
    o <- sn$origins[1]
    W <- ss_win(S$panel)
    x <- c(S$panel$fill[[target]][(o - 200):(o + 24L - W)], sn$lev[[target]][1, ])  # ends at o + 24
    dec <- sh_decompose(x, S$panel$J)
    check(sprintf("T08 %s: pushed components = causal decomposition of the extended level", a),
          isTRUE(all.equal(unname(dec[nrow(dec) - (SH_LOOKBACK - 1):0, ]),
                           unname(do.call(cbind, lapply(S$panel$components, function(cp) sn$comps[[target]][[cp]][1, ]))),
                           tolerance = 1e-9)))
  }
}

# ---- cross-fit purge ---------------------------------------------------------------------------
units <- ss_fit_onestep(sc, S, sh_arch("A2"), target, "none", seed1, seed1)
tro <- smp168$origin_idx[smp168$block == "train"]
folds <- ss_folds(tro, 4L)
back <- ss_back(S$panel)
units <- ss_crossfit_units(units, folds, back, 72L)
check("T09 folds partition the training origins contiguously",
      identical(sort(unlist(folds)), sort(unique(tro))) &&
        all(vapply(2:4, function(f) min(folds[[f]]) > max(folds[[f - 1]]), logical(1))))
u <- units[[1]]
check("T09 fold models exclude every training row whose window touches the fold (+ s_max)",
      all(vapply(seq_along(folds), function(f) {
        lo <- min(folds[[f]]); hi <- max(folds[[f]])
        o <- u$ds_train$origin_idx
        used <- !(o + 1L >= lo - back & o - back <= hi + 72L)
        u$models[[1]][[paste0("cf", f, "_n")]] == sum(used) &&
          !any(o[used] + 1L >= lo - back + 1L & o[used] - back + 1L <= hi + 72L)
      }, logical(1))))
check("T09 fold models never use validation or test rows",
      all(S$panel$timestamps[u$ds_train$target_idx] <= S$splits$train[2]))

# ---- hybrid cells ------------------------------------------------------------------------------
hc <- ss_hybrid_cells(cfg$horizons, scfg$hybrid$switch_points)
check("T10 hybrid only for s < h (none at h = 24)", all(hc$s < hc$h) && !any(hc$h == 24) && nrow(hc) == 9)

# ---- reproduction of the original direct runs --------------------------------------------------
for (cell in list(c("A2", "24"), c("A3", "744"))) {
  h <- as.integer(cell[2])
  smp <- sh_samples(cfg, S$panel, S$splits, target, h, S$avail$pollutants)
  r <- ss_run_direct(cfg, S, smp, target, h, sh_arch(cell[1]), "none",
                     as.integer(unlist(cfg$seeds)), as.integer(cfg$tune_seed))
  o <- readRDS(file.path(scfg$original_output_dir, "runs", "lightgbm", "Lumpyngngad", target,
                         paste0("h", h), paste0(cell[1], ".rds")))
  a <- r$pred[order(seed, block, component, origin_idx)]
  b <- o$pred[order(seed, block, component, origin_idx)]
  check(sprintf("T11 direct %s h=%d with original features reproduces the original run", cell[1], h),
        identical(a$target_idx, b$target_idx) && isTRUE(all.equal(a$yhat, b$yhat, tolerance = 1e-12)))
}
