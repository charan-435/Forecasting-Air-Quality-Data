# Phase 2 stages that build on the model stage: featsel (Stage C), targets
# (six pollutants, separate vs shared) and report. Sourced by
# code/experiments/run_mv_experiments.R, which defines E, cfg, panel, fill, scales, OUT, L, SEEDS.

MV_COLORS <- c(B0 = "#2a78d6", B1 = "#eb6834", ref = "#8a8a85")   # categorical slots 1, 2; neutral
MV_FAMILY_ORDER <- c("lightgbm", "xgboost", "catboost", "ridge", "lasso", "elasticnet")

mv_theme <- function() {
  ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   panel.grid.major = ggplot2::element_line(colour = "#e6e5e0", linewidth = 0.3),
                   legend.position = "top", strip.text = ggplot2::element_text(face = "bold"))
}

mv_save_plot <- function(p, path, w = 9, h = 5.5) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, p, width = w, height = h, dpi = 150, bg = "white")
}

mv_load_preds <- function(dir) {
  fs <- list.files(dir, pattern = "^predictions\\.rds$", recursive = TRUE, full.names = TRUE)
  if (!length(fs)) return(NULL)
  pr <- do.call(rbind, lapply(fs, function(f) {
    x <- readRDS(f)
    if (is.null(x$variant)) x$variant <- "raw"
    x$seed <- as.character(x$seed)
    x[, c("stage", "family", "design", "variant", "target", "horizon_h", "seed", "block",
          "origin_idx", "target_idx", "y", "yhat")]
  }))
  pr
}

# Reference forecasts (no fitting beyond block means): seasonal naive, overall
# climatology and hour-of-day climatology. Climatology uses train hours for
# train/validation and train + validation hours for test (mirrors the refit).
mv_reference_preds <- function(target = "PM2.5", horizons = H) {
  bl <- mv_blocks(cfg, panel$times)
  hod <- as.integer(format(panel$times, "%H", tz = panel$tz))
  span <- function(blocks) min(bl$start_idx[bl$block %in% blocks]):max(bl$end_idx[bl$block %in% blocks])
  out <- list()
  for (h in horizons) {
    ds <- mv_dataset(cfg, panel, "B0", h, target = target)
    for (b in c("train", "validation", "test")) {
      bk <- ds$blocks[[b]]
      fit_rows <- span(if (b == "test") c("train", "validation") else "train")
      y_fit <- panel$X[fit_rows, target]
      hod_mean <- tapply(y_fit, hod[fit_rows], mean)
      refs <- list(seasonal_naive = mv_seasonal_naive(panel, bk$origin_idx, h, target),
                   climatology = rep(mean(y_fit), length(bk$y)),
                   hour_of_day_climatology = as.numeric(hod_mean[as.character(hod[bk$target_idx])]))
      for (r in names(refs)) out[[paste(h, b, r)]] <- data.frame(
        stage = "reference", family = r, design = "reference", variant = "raw", target = target,
        horizon_h = h, seed = "none", block = b, origin_idx = bk$origin_idx,
        target_idx = bk$target_idx, y = bk$y, yhat = refs[[r]], stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, out)
}

# Paired comparison of two designs/variants on identical samples, for seed-mean predictions.
mv_pair_table <- function(pm, a_filter, b_filter, label, by = c("family", "target", "horizon_h", "block"),
                          blocks = c("validation", "test"),
                          groups_keep = c("all", "constant_fill_target", "non_fill_target"),
                          sensitivity = TRUE) {
  bs <- E$bootstrap
  A <- pm[a_filter(pm) & pm$block %in% blocks, ]; B <- pm[b_filter(pm) & pm$block %in% blocks, ]
  keyA <- split(A, A[by], drop = TRUE); keyB <- split(B, B[by], drop = TRUE)
  rows <- list()
  for (k in intersect(names(keyA), names(keyB))) {
    a <- keyA[[k]]; b <- keyB[[k]]
    a <- a[order(a$origin_idx), ]; b <- b[order(b$origin_idx), ]
    if (!identical(a$origin_idx, b$origin_idx) || !identical(a$y, b$y))
      stop("paired comparison on different samples: ", k)
    h <- a$horizon_h[1]
    groups <- c(list(all = rep(TRUE, nrow(a))),
                mv_fill_groups(fill, a$origin_idx, a$target_idx, L)[c("constant_fill_target", "non_fill_target")])
    for (g in intersect(names(groups), groups_keep)) {
      i <- groups[[g]]
      if (sum(i) < 50) next
      pc <- mv_paired_compare(a$y[i], a$yhat[i], b$yhat[i], h, bs$reps, bs$seed, bs$level,
                              if (sensitivity) unlist(bs$sensitivity_blocks) else integer(0),
                              bs$min_block_h, bs$min_blocks)
      rows[[paste(k, g)]] <- cbind(a[1, by, drop = FALSE],
                                   data.frame(comparison = label, group = g, n = sum(i),
                                              MAE_a = mean(abs(a$yhat[i] - a$y[i])),
                                              MAE_b = mean(abs(b$yhat[i] - b$y[i])),
                                              stringsAsFactors = FALSE), pc)
    }
  }
  out <- do.call(rbind, rows); rownames(out) <- NULL
  out
}

# Per-seed paired differences (stability of the sign across seeds).
mv_seed_pairs <- function(pr, by = c("family", "target", "horizon_h", "block")) {
  s <- pr[pr$seed != "mean" & pr$block %in% c("validation", "test"), ]
  agg <- stats::aggregate(list(MAE = abs(s$yhat - s$y)), s[c(by, "design", "seed")], mean)
  w <- stats::reshape(agg, idvar = c(by, "seed"), timevar = "design", direction = "wide")
  if (!all(c("MAE.B0", "MAE.B1") %in% names(w))) return(NULL)
  w$diff_B1_minus_B0 <- w$MAE.B1 - w$MAE.B0
  w
}

# ------------------------------------------------------------------------------------------
mv_stage_report <- function() {
  d <- file.path(OUT, "report"); dir.create(file.path(d, "plots"), recursive = TRUE, showWarnings = FALSE)
  pr <- mv_load_preds(file.path(OUT, "models"))
  if (is.null(pr)) stop("no model predictions under ", file.path(OUT, "models"))
  ref <- mv_reference_preds()
  pm_seed <- do.call(rbind, lapply(split(pr, pr$family), function(x) {
    m <- mv_seed_mean(x); m$seed <- "mean"; m[, names(pr)]
  }))
  all_pr <- rbind(pr, pm_seed, ref)
  mt <- mv_metric_table(all_pr, panel, fill, L, scales)
  mv_write_csv(mt, file.path(d, "MODEL_METRICS.csv"))
  log_line("report: metrics done")

  # seed summary: mean and sd of per-seed MAE, plus seed-mean-ensemble MAE
  ps <- mt[mt$seed != "mean" & mt$stage == "model", ]
  ss <- stats::aggregate(cbind(MAE, RMSE, MASE) ~ family + design + horizon_h + block + group, ps,
                         function(v) c(mean = mean(v), sd = if (length(v) > 1) stats::sd(v) else 0, n = length(v)))
  ss <- do.call(data.frame, ss)
  mv_write_csv(ss, file.path(d, "SEED_SUMMARY.csv"))

  # horizon-wise B0 vs B1 table (primary: unmasked "all"; seed-mean ensemble)
  em <- mt[mt$seed %in% c("mean", "none") & mt$group == "all", ]
  wide <- stats::reshape(em[em$stage == "model", c("family", "design", "horizon_h", "block", "MAE", "RMSE", "MASE")],
                         idvar = c("family", "horizon_h", "block"), timevar = "design", direction = "wide")
  wide$MAE_ratio_B1_B0 <- wide$MAE.B1 / wide$MAE.B0
  wide$RMSE_ratio_B1_B0 <- wide$RMSE.B1 / wide$RMSE.B0
  rf <- em[em$stage == "reference", c("family", "horizon_h", "block", "MAE")]
  for (r in unique(rf$family)) {
    x <- rf[rf$family == r, ]
    wide[[paste0("MAE.", r)]] <- x$MAE[match(paste(wide$horizon_h, wide$block), paste(x$horizon_h, x$block))]
  }
  wide <- wide[order(match(wide$family, MV_FAMILY_ORDER), wide$horizon_h,
                     match(wide$block, c("train", "validation", "test"))), ]
  mv_write_csv(wide, file.path(d, "HORIZON_COMPARISON_B0_B1.csv"))

  # paired B1 vs B0 (seed-mean predictions), with fill breakdown
  pt <- mv_pair_table(pm_seed, function(x) x$design == "B1", function(x) x$design == "B0", "B1 vs B0")
  mv_write_csv(pt, file.path(d, "PAIRED_B1_VS_B0.csv"))
  sp <- mv_seed_pairs(pr)
  mv_write_csv(sp, file.path(d, "PAIRED_B1_VS_B0_PER_SEED.csv"))
  log_line("report: B1 vs B0 paired done")
  # best model vs references on test (paired, B1 and B0 seed means vs seasonal naive / climatology)
  rp <- list()
  for (r in c("seasonal_naive", "climatology", "hour_of_day_climatology")) {
    for (dsn in c("B0", "B1")) {
      x <- pm_seed[pm_seed$design == dsn, ]
      rr <- ref[ref$family == r, ]
      for (fam in unique(x$family)) {
        z <- rbind(x[x$family == fam, ], transform(rr, family = fam, design = "REF"))
        rp[[paste(r, dsn, fam)]] <- mv_pair_table(z, function(q) q$design == dsn, function(q) q$design == "REF",
                                                 paste(dsn, "vs", r), groups_keep = "all", sensitivity = FALSE)
      }
    }
  }
  mv_write_csv(do.call(rbind, rp), file.path(d, "PAIRED_VS_REFERENCES.csv"))
  log_line("report: reference comparisons done")

  # overfitting: train (selection fit) vs validation vs test, per design
  of <- em[em$stage == "model", c("family", "design", "horizon_h", "block", "MAE")]
  of <- stats::reshape(of, idvar = c("family", "design", "horizon_h"), timevar = "block", direction = "wide")
  of$val_over_train <- of$MAE.validation / of$MAE.train
  of$test_over_val <- of$MAE.test / of$MAE.validation
  runs <- do.call(rbind, lapply(list.files(file.path(OUT, "models"), "^RUNS\\.csv$", recursive = TRUE, full.names = TRUE),
                                utils::read.csv, stringsAsFactors = FALSE))
  ri <- stats::aggregate(cbind(best_iter, n_inputs) ~ family + design + horizon_h, runs, mean)
  of <- merge(of, ri, by = c("family", "design", "horizon_h"), all.x = TRUE)
  mv_write_csv(of, file.path(d, "GENERALISATION_GAP.csv"))
  sel <- do.call(rbind, lapply(list.files(file.path(OUT, "models"), "^SELECTED\\.csv$", recursive = TRUE, full.names = TRUE),
                               utils::read.csv, stringsAsFactors = FALSE))
  mv_write_csv(sel, file.path(d, "SELECTED_CONFIGS.csv"))

  # importance by pollutant and by lag (B1, refit models, mean over seeds)
  imf <- list.files(file.path(OUT, "models"), "^IMPORTANCE\\.csv$", recursive = TRUE, full.names = TRUE)
  if (length(imf)) {
    im <- do.call(rbind, lapply(imf, utils::read.csv, stringsAsFactors = FALSE))
    im <- im[im$design == "B1", ]
    im$pollutant <- sub("__lag[0-9]+$", "", im$feature)
    im$lag <- as.integer(sub("^.*__lag", "", im$feature))
    tot <- stats::aggregate(importance ~ family + horizon_h + seed, im, sum)
    im$share <- im$importance / tot$importance[match(paste(im$family, im$horizon_h, im$seed),
                                                     paste(tot$family, tot$horizon_h, tot$seed))]
    byp <- stats::aggregate(share ~ family + horizon_h + pollutant, im, sum)
    nseed <- stats::aggregate(seed ~ family + horizon_h, unique(im[c("family", "horizon_h", "seed")]), length)
    byp$share <- byp$share / nseed$seed[match(paste(byp$family, byp$horizon_h), paste(nseed$family, nseed$horizon_h))]
    mv_write_csv(byp, file.path(d, "IMPORTANCE_BY_POLLUTANT.csv"))
    byl <- stats::aggregate(share ~ family + horizon_h + pollutant + lag, im, sum)
    byl$share <- byl$share / nseed$seed[match(paste(byl$family, byl$horizon_h), paste(nseed$family, nseed$horizon_h))]
    mv_write_csv(byl, file.path(d, "IMPORTANCE_BY_LAG.csv"))
    byp$pollutant <- factor(byp$pollutant, levels = panel$pollutants)
    p <- ggplot2::ggplot(byp, ggplot2::aes(x = pollutant, y = share)) +
      ggplot2::geom_col(fill = MV_COLORS[["B1"]], width = 0.6) +
      ggplot2::facet_grid(family ~ horizon_h, labeller = ggplot2::labeller(horizon_h = function(x) paste0("h = ", x))) +
      ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
      ggplot2::labs(x = NULL, y = "Share of importance (B1, refit, mean of seeds)",
                    title = "Which pollutants the B1 models use (PM2.5 target)",
                    subtitle = "Trees: gain (LightGBM, XGBoost) or PredictionValuesChange (CatBoost); linear: |standardized coef|") +
      mv_theme() + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
    mv_save_plot(p, file.path(d, "plots", "importance_by_pollutant.png"), 10, 9)
  }

  # ---- plots ----
  fam_lab <- function(x) factor(x, levels = intersect(MV_FAMILY_ORDER, unique(x)))
  vm <- em[em$stage == "model" & em$block %in% c("validation", "test"), ]
  vm$family <- fam_lab(vm$family); vm$block <- factor(vm$block, c("validation", "test"))
  rr <- em[em$stage == "reference" & em$block %in% c("validation", "test") & em$family == "seasonal_naive", ]
  rr$block <- factor(rr$block, c("validation", "test"))
  p <- ggplot2::ggplot(vm, ggplot2::aes(x = factor(horizon_h), y = MAE, colour = design, group = design)) +
    ggplot2::geom_hline(data = rr, ggplot2::aes(yintercept = MAE), inherit.aes = FALSE, colour = "transparent") +
    ggplot2::geom_point(data = transform(rr, design = "seasonal naive"), ggplot2::aes(x = factor(horizon_h), y = MAE),
                        inherit.aes = FALSE, shape = 4, size = 2.5, colour = MV_COLORS[["ref"]]) +
    ggplot2::geom_line(linewidth = 0.6) + ggplot2::geom_point(size = 2.2) +
    ggplot2::facet_grid(block ~ family) +
    ggplot2::scale_colour_manual(values = MV_COLORS[c("B0", "B1")]) +
    ggplot2::labs(x = "Horizon (h)", y = "MAE, PM2.5 (µg/m³), seed-mean forecast",
                  title = "B0 vs B1 by horizon: validation and test (UNMASKED)",
                  subtitle = "Grey crosses: seasonal-naive reference", colour = NULL) + mv_theme()
  mv_save_plot(p, file.path(d, "plots", "val_test_mae_by_horizon.png"), 12, 6)

  pa <- pt[pt$group == "all", ]
  pa$family <- fam_lab(pa$family); pa$block <- factor(pa$block, c("validation", "test"))
  p <- ggplot2::ggplot(pa, ggplot2::aes(x = factor(horizon_h), y = mae_ratio, colour = block)) +
    ggplot2::geom_hline(yintercept = 1, colour = "#4a4a46", linewidth = 0.4) +
    ggplot2::geom_pointrange(ggplot2::aes(ymin = mae_ratio_lo, ymax = mae_ratio_hi),
                             position = ggplot2::position_dodge(width = 0.5), size = 0.35) +
    ggplot2::facet_wrap(~family, nrow = 1) +
    ggplot2::scale_colour_manual(values = c(validation = "#1baf7a", test = "#2a78d6")) +
    ggplot2::labs(x = "Horizon (h)", y = "MAE ratio B1 / B0 (below 1: B1 better)",
                  title = "Paired B1 vs B0 on identical targets",
                  subtitle = "Seed-mean forecasts; 95% moving-block bootstrap, horizon-specific block length", colour = NULL) +
    mv_theme()
  mv_save_plot(p, file.path(d, "plots", "paired_ratio_b1_b0.png"), 12, 4.5)

  if (!is.null(sp)) {
    sp$family <- fam_lab(sp$family); sp$block <- factor(sp$block, c("validation", "test"))
    p <- ggplot2::ggplot(sp, ggplot2::aes(x = factor(horizon_h), y = diff_B1_minus_B0, colour = block)) +
      ggplot2::geom_hline(yintercept = 0, colour = "#4a4a46", linewidth = 0.4) +
      ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.5), size = 1.8, alpha = 0.85) +
      ggplot2::facet_wrap(~family, nrow = 1) +
      ggplot2::scale_colour_manual(values = c(validation = "#1baf7a", test = "#2a78d6")) +
      ggplot2::labs(x = "Horizon (h)", y = "MAE(B1) − MAE(B0), µg/m³", colour = NULL,
                    title = "Per-seed paired differences (one point per seed; linear models are deterministic)") +
      mv_theme()
    mv_save_plot(p, file.path(d, "plots", "paired_diff_per_seed.png"), 12, 4.5)
  }

  fg <- mt[mt$seed %in% c("mean") & mt$stage == "model" & mt$block == "test" &
             mt$group %in% c("all", "constant_fill_target", "non_fill_target"), ]
  fg$family <- fam_lab(fg$family)
  fg$group <- factor(fg$group, c("all", "constant_fill_target", "non_fill_target"),
                     c("all targets (primary)", "constant-fill targets", "non-fill targets"))
  p <- ggplot2::ggplot(fg, ggplot2::aes(x = factor(horizon_h), y = MAE, fill = design)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75), width = 0.7) +
    ggplot2::facet_grid(group ~ family, scales = "free_y") +
    ggplot2::scale_fill_manual(values = MV_COLORS[c("B0", "B1")]) +
    ggplot2::labs(x = "Horizon (h)", y = "Test MAE (µg/m³)", fill = NULL,
                  title = "Test MAE by constant-fill status (diagnostic breakdown of the same forecasts)") + mv_theme()
  mv_save_plot(p, file.path(d, "plots", "test_mae_by_fill_group.png"), 12, 7)

  if (dir.exists(file.path(OUT, "featsel"))) mv_report_featsel(d, pm_seed)
  if (dir.exists(file.path(OUT, "targets"))) mv_report_targets(d)
  stage_meta(d, list(note = "report over all model families present"))
  log_line("report written to ", d)
}

mv_read_all <- function(dir, file) {
  fs <- list.files(dir, paste0("^", gsub(".", "\\.", file, fixed = TRUE), "$"), recursive = TRUE, full.names = TRUE)
  if (!length(fs)) return(NULL)
  do.call(rbind, lapply(fs, function(f) if (grepl("\\.gz$", f)) as.data.frame(data.table::fread(f)) else
    utils::read.csv(f, stringsAsFactors = FALSE)))
}

# Stage C: every variant against B1 (all 144 lags) and B0, same learner family where possible.
mv_report_featsel <- function(d, pm_seed) {
  fp <- mv_load_preds(file.path(OUT, "featsel"))
  if (is.null(fp)) return(invisible())
  fs <- do.call(rbind, lapply(split(fp, list(fp$family, fp$variant), drop = TRUE), function(x) {
    m <- mv_seed_mean(x); m$seed <- "mean"; m[, names(fp)]
  }))
  fs$key <- paste(fs$variant, fs$family, sep = " | ")
  base <- pm_seed[pm_seed$family %in% c("lightgbm", "ridge", "elasticnet") & pm_seed$block != "train", ]
  base$key <- paste(base$design, "(all lags)", base$family, sep = " | ")
  runs <- mv_read_all(file.path(OUT, "featsel"), "RUNS.csv")
  ninp <- stats::aggregate(n_inputs ~ variant + family + horizon_h + group + chosen, runs, mean)
  allp <- rbind(fs[fs$block != "train", ], base)
  mt <- mv_metric_table(allp[, setdiff(names(allp), "key")], panel, fill, L, scales)
  mt$key <- ifelse(mt$stage == "featsel", paste(mt$variant, mt$family, sep = " | "),
                   paste(mt$design, "(all lags)", mt$family, sep = " | "))
  em <- mt[mt$group %in% c("all", "non_fill_target"), c("key", "horizon_h", "block", "group", "MAE")]
  em$col <- paste(em$block, em$group, sep = "_")
  w <- stats::reshape(em[, c("key", "horizon_h", "col", "MAE")], idvar = c("key", "horizon_h"),
                      timevar = "col", direction = "wide")
  names(w) <- sub("^MAE\\.", "MAE_", names(w))
  ref <- w[w$key == "B1 | (all lags) | lightgbm", ]
  r0 <- w[w$key == "B0 | (all lags) | lightgbm", ]
  w$val_ratio_vs_B1_lgb <- w$MAE_validation_all / ref$MAE_validation_all[match(w$horizon_h, ref$horizon_h)]
  w$test_ratio_vs_B1_lgb <- w$MAE_test_all / ref$MAE_test_all[match(w$horizon_h, ref$horizon_h)]
  w$test_ratio_vs_B0_lgb <- w$MAE_test_all / r0$MAE_test_all[match(w$horizon_h, r0$horizon_h)]
  w$variant <- sub(" \\|.*$", "", w$key)
  w$family <- sub("^.*\\| ", "", w$key)
  w <- merge(w, ninp, by = c("variant", "family", "horizon_h"), all.x = TRUE)
  w$n_inputs[is.na(w$n_inputs)] <- ifelse(grepl("^B0", w$key[is.na(w$n_inputs)]), 24, 144)

  # paired test comparison of each variant vs B1 (all lags, LightGBM)
  pr_rows <- list()
  b1 <- base[base$key == "B1 | (all lags) | lightgbm", ]
  for (k in unique(fs$key)) {
    z <- rbind(fs[fs$key == k & fs$block != "train", ], b1)
    z$design <- ifelse(z$key == k, "A", "B")
    pr_rows[[k]] <- cbind(key = k, mv_pair_table(z, function(q) q$design == "A", function(q) q$design == "B",
                                                 "variant vs B1 LightGBM", by = c("horizon_h", "block"),
                                                 groups_keep = "all", sensitivity = FALSE))
  }
  pt <- do.call(rbind, pr_rows)
  w <- merge(w, pt[pt$block == "test", c("key", "horizon_h", "mae_ratio_lo", "mae_ratio_hi", "block_h", "dm_p")],
             by = c("key", "horizon_h"), all.x = TRUE)
  names(w)[names(w) %in% c("mae_ratio_lo", "mae_ratio_hi", "dm_p")] <- c("test_ratio_vs_B1_lo", "test_ratio_vs_B1_hi", "test_dm_p_vs_B1")
  w <- w[order(w$horizon_h, w$MAE_validation_all), ]
  mv_write_csv(w, file.path(d, "FEATSEL_COMPARISON.csv"))
  mv_write_csv(pt, file.path(d, "FEATSEL_PAIRED_VS_B1.csv"))
  log_line("report: featsel paired done")
  for (f in c("SELECTED_FEATURES.csv", "RFE_PATH.csv", "PCA_VARIANCE.csv", "PCA_LOADINGS_BY_POLLUTANT.csv",
              "TRANSFORM_TUNING.csv", "RETUNE.csv")) {
    x <- mv_read_all(file.path(OUT, "featsel"), f)
    if (!is.null(x)) {
      if (f == "RFE_PATH.csv") x$horizon_h <- rep(sub("^h", "", basename(dirname(
        list.files(file.path(OUT, "featsel"), "^RFE_PATH\\.csv$", recursive = TRUE, full.names = TRUE)))),
        vapply(split(x$step, cumsum(x$step == 1)), length, 1L))
      mv_write_csv(x, file.path(d, paste0("FEATSEL_", f)))
    }
  }

  # plots
  pw <- w[!grepl("^B[01] \\|", w$key), ]
  pw <- rbind(transform(pw, block = "validation", ratio = val_ratio_vs_B1_lgb),
              transform(pw, block = "test", ratio = test_ratio_vs_B1_lgb))
  pw$block <- factor(pw$block, c("validation", "test"))
  pw$label <- paste0(pw$key)
  ord <- stats::aggregate(ratio ~ label, pw[pw$block == "validation", ], mean)
  pw$label <- factor(pw$label, ord$label[order(-ord$ratio)])
  p <- ggplot2::ggplot(pw, ggplot2::aes(x = ratio, y = label, colour = block)) +
    ggplot2::geom_vline(xintercept = 1, colour = "#4a4a46", linewidth = 0.4) +
    ggplot2::geom_point(size = 2) +
    ggplot2::facet_wrap(~horizon_h, nrow = 1, labeller = ggplot2::labeller(horizon_h = function(x) paste0("h = ", x))) +
    ggplot2::scale_colour_manual(values = c(validation = "#1baf7a", test = "#2a78d6")) +
    ggplot2::labs(x = "MAE ratio vs B1 (all 144 lags, LightGBM); below 1 is better", y = NULL, colour = NULL,
                  title = "Feature selection and dimensionality reduction (PM2.5, seed-mean forecasts, UNMASKED)") +
    mv_theme()
  mv_save_plot(p, file.path(d, "plots", "featsel_ratio_vs_b1.png"), 13, 7.5)
  rfe <- utils::read.csv(file.path(d, "FEATSEL_RFE_PATH.csv"))
  p <- ggplot2::ggplot(rfe, ggplot2::aes(x = n_inputs, y = val_MAE)) +
    ggplot2::geom_line(colour = MV_COLORS[["B1"]], linewidth = 0.6) + ggplot2::geom_point(colour = MV_COLORS[["B1"]], size = 1.8) +
    ggplot2::facet_wrap(~horizon_h, scales = "free_y", nrow = 1, labeller = ggplot2::labeller(horizon_h = function(x) paste0("h = ", x))) +
    ggplot2::scale_x_log10() +
    ggplot2::labs(x = "Number of inputs (log scale)", y = "Validation MAE (train-only fit)",
                  title = "Recursive feature elimination path (LightGBM gain, 20% dropped per step)") + mv_theme()
  mv_save_plot(p, file.path(d, "plots", "rfe_path.png"), 12, 3.8)
  pv <- utils::read.csv(file.path(d, "FEATSEL_PCA_VARIANCE.csv"))
  p <- ggplot2::ggplot(pv[pv$component <= 48, ], ggplot2::aes(x = component, y = cum_var, colour = factor(horizon_h))) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::scale_colour_manual(values = c("24" = "#2a78d6", "168" = "#eb6834", "336" = "#1baf7a", "744" = "#eda100")) +
    ggplot2::labs(x = "Principal component", y = "Cumulative variance explained (train rows)", colour = "h",
                  title = "PCA of the 144 standardized B1 lags") + mv_theme()
  mv_save_plot(p, file.path(d, "plots", "pca_cumulative_variance.png"), 7, 4.5)
}

# Six targets: separate (one model per target) vs shared (one pooled model).
mv_report_targets <- function(d) {
  tp <- mv_load_preds(file.path(OUT, "targets"))
  if (is.null(tp)) return(invisible())
  tp$key <- ifelse(tp$variant == "separate", paste0("separate_", tp$design), tp$design)
  tp$design <- tp$key
  sm <- do.call(rbind, lapply(split(tp, tp$key), function(x) { m <- mv_seed_mean(x); m$seed <- "mean"; m }))
  sm$key <- sm$design
  mt <- mv_metric_table(sm[, setdiff(names(sm), "key")], panel, fill, L, scales,
                        keys = c("design", "target", "horizon_h", "seed", "block"))
  mv_write_csv(mt, file.path(d, "TARGETS_METRICS.csv"))
  sumt <- stats::aggregate(cbind(MASE, MAE) ~ design + horizon_h + block + group, mt[mt$block != "train", ], mean)
  names(sumt)[names(sumt) == "MASE"] <- "mean_MASE_over_targets"
  names(sumt)[names(sumt) == "MAE"] <- "mean_MAE_over_targets_mixed_units"
  mv_write_csv(sumt, file.path(d, "TARGETS_SUMMARY.csv"))
  cmp <- list(c("separate_B1", "separate_B0", "B1 vs B0 (separate)"),
              c("pooled_B1_own", "separate_B1", "shared B1+own vs separate B1"),
              c("pooled_B1", "separate_B1", "shared B1 vs separate B1"),
              c("pooled_B0", "separate_B0", "shared B0 vs separate B0"),
              c("pooled_B1_own", "separate_B0", "shared B1+own vs separate B0"))
  sm$family <- "lightgbm"
  pt <- do.call(rbind, lapply(cmp, function(cc) {
    if (!all(cc[1:2] %in% sm$key)) return(NULL)
    mv_pair_table(sm, function(q) q$key == cc[1], function(q) q$key == cc[2], cc[3],
                  by = c("target", "horizon_h", "block"), sensitivity = FALSE)
  }))
  mv_write_csv(pt, file.path(d, "TARGETS_PAIRED.csv"))
  log_line("report: targets paired done")
  tm <- mt[mt$block == "test" & mt$group == "all", ]
  tm$target <- factor(tm$target, panel$pollutants)
  tm$design <- factor(tm$design, c("separate_B0", "separate_B1", "pooled_B0", "pooled_B1", "pooled_B1_own"))
  p <- ggplot2::ggplot(tm, ggplot2::aes(x = factor(horizon_h), y = MASE, fill = design)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.85), width = 0.8) +
    ggplot2::facet_wrap(~target, nrow = 2, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(separate_B0 = "#2a78d6", separate_B1 = "#eb6834", pooled_B0 = "#1baf7a",
                                          pooled_B1 = "#eda100", pooled_B1_own = "#e87ba4")) +
    ggplot2::labs(x = "Horizon (h)", y = "Test MASE (train-block seasonal-naive scale)", fill = NULL,
                  title = "Six targets: separate vs shared models (LightGBM, seed-mean, UNMASKED)") + mv_theme()
  mv_save_plot(p, file.path(d, "plots", "targets_test_mase.png"), 12, 6.5)
}

# ---- shared helpers for Stage C / targets -------------------------------------------------

mv_selected_params <- function(family, design, h) {
  s <- utils::read.csv(file.path(OUT, "models", family, "SELECTED.csv"), stringsAsFactors = FALSE)
  s <- s[s$design == design & s$horizon_h == h, ]
  if (nrow(s) != 1L) stop("no Stage A/B selection for ", family, " ", design, " h=", h)
  jsonlite::fromJSON(s$params, simplifyVector = TRUE)
}

mv_retune_candidates <- function(params, grid) {
  mv_candidates(list(base = params, grid = grid))
}

# Validation MAE of the train-only fit for each transform candidate (fixed params).
mv_tune_transforms <- function(family, ds, tfs, params, seed) {
  fam <- mv_family(family)
  tr <- ds$blocks$train; va <- ds$blocks$validation
  do.call(rbind, lapply(names(tfs), function(k) {
    tf <- tfs[[k]]$fit(tr$X, tr$y)
    Xtr <- tf$apply(tr$X); Xva <- tf$apply(va$X)
    f <- fam$fit(Xtr, tr$y, Xva, va$y, params, seed, nrounds = params$num_iterations %||% 1L,
                 early_stopping = TRUE)
    pv <- fam$predict(f, Xva)
    data.frame(candidate = k, n_inputs = ncol(Xtr), val_MAE = mean(abs(pv - va$y)),
               train_MAE = mean(abs(fam$predict(f, Xtr) - tr$y)), best_iter = f$best_iter,
               stringsAsFactors = FALSE)
  }))
}

# Recursive feature elimination with train-only fits: drop the lowest-gain
# drop_frac of the remaining columns each step; validation MAE scores each step.
mv_rfe <- function(family, ds, params, seed, drop_frac, min_features) {
  fam <- mv_family(family)
  tr <- ds$blocks$train; va <- ds$blocks$validation
  cols <- colnames(tr$X); path <- list(); sets <- list(); step <- 0L
  repeat {
    step <- step + 1L
    f <- fam$fit(tr$X[, cols, drop = FALSE], tr$y, va$X[, cols, drop = FALSE], va$y, params, seed,
                 nrounds = params$num_iterations, early_stopping = TRUE)
    pv <- fam$predict(f, va$X[, cols, drop = FALSE])
    path[[step]] <- data.frame(step = step, n_inputs = length(cols), val_MAE = mean(abs(pv - va$y)),
                               best_iter = f$best_iter)
    sets[[step]] <- cols
    if (length(cols) <= min_features) break
    imp <- fam$importance(f)
    g <- stats::setNames(rep(0, length(cols)), cols)
    g[intersect(names(imp), cols)] <- imp[intersect(names(imp), cols)]
    n_drop <- max(1L, floor(drop_frac * length(cols)))
    n_keep <- max(min_features, length(cols) - n_drop)
    keep <- names(sort(g, decreasing = TRUE))[seq_len(n_keep)]
    cols <- cols[cols %in% keep]
  }
  path <- do.call(rbind, path)
  best <- which.min(path$val_MAE)
  list(path = path, best_step = best, cols = sets[[best]])
}

# Pick a transform on validation, retune the tree grid at that choice, run all seeds.
mv_featsel_variant <- function(name, group, family, ds, tfs, params, retune_grid, seeds) {
  tun <- mv_tune_transforms(family, ds, tfs, params, as.integer(E$tuning_seed))
  k <- tun$candidate[which.min(tun$val_MAE)]
  tf <- tfs[[k]]
  if (length(retune_grid) && family %in% mv_stochastic_families()) {
    rt <- mv_tune(family, ds, mv_retune_candidates(params, retune_grid), as.integer(E$tuning_seed), tf)
    params <- rt$params
    rtab <- cbind(variant = name, rt$table)
  } else rtab <- NULL
  fr <- mv_final_runs(family, ds, params, seeds, tf, "featsel", list(variant = name))
  ti <- fr$last_run$transform_info
  sel <- list(selection = ti$selection$selected, refit = ti$refit$selected)
  list(pred = fr$pred, info = cbind(fr$info, group = group, chosen = k),
       tuning = cbind(variant = name, group = group, family = family, horizon_h = ds$h, tun),
       retune = rtab, importance = fr$importance,
       selected = if (length(sel$selection)) data.frame(
         variant = name, horizon_h = ds$h, chosen = k, n_selection = length(sel$selection),
         n_refit = length(sel$refit), jaccard_selection_vs_refit = mv_jaccard(sel$selection, sel$refit),
         features_selection = paste(sel$selection, collapse = " "),
         features_refit = paste(sel$refit, collapse = " "), stringsAsFactors = FALSE) else NULL)
}

mv_stage_featsel <- function() {
  require_check()
  FS <- E$featsel; fam <- FS$tree_family
  seeds_tree <- SEEDS; seed_lin <- SEEDS[1]
  en_sel <- utils::read.csv(file.path(OUT, "models", "elasticnet", "SELECTED.csv"), stringsAsFactors = FALSE)
  en_runs <- utils::read.csv(file.path(OUT, "models", "elasticnet", "RUNS.csv"), stringsAsFactors = FALSE)
  for (h in H) {
    d <- file.path(OUT, "featsel", paste0("h", h)); dir.create(d, recursive = TRUE, showWarnings = FALSE)
    ds <- mv_dataset(cfg, panel, "B1", h)
    fn <- ds$feature_names
    p0 <- mv_selected_params(fam, "B1", h)
    rg <- FS$retune_grid
    res <- list()
    add <- function(r) { res[[length(res) + 1L]] <<- r; log_line(sprintf("featsel h=%d %s done", h, r$info$variant[1])) }

    if (isTRUE(FS$ablation)) {
      for (p in setdiff(panel$pollutants, "PM2.5"))
        add(mv_featsel_variant(paste0("B0+", p), "ablation_add", fam, ds,
                               list(all = mv_transform_columns(mv_pollutant_columns(fn, c("PM2.5", p)))), p0, rg, seeds_tree))
      for (p in panel$pollutants)
        add(mv_featsel_variant(paste0("B1-", p), "ablation_drop", fam, ds,
                               list(all = mv_transform_columns(mv_pollutant_columns(fn, setdiff(panel$pollutants, p)))),
                               p0, rg, seeds_tree))
    }
    ks <- function(v, mk) stats::setNames(lapply(v, mk), paste0("k", v))
    add(mv_featsel_variant("corr_topk", "filter", fam, ds, ks(unlist(FS$corr_k), mv_transform_corr_topk), p0, rg, seeds_tree))
    add(mv_featsel_variant("mi_topk", "filter", fam, ds,
                           ks(unlist(FS$mi_k), function(k) mv_transform_mi_topk(k, FS$mi_bins)), p0, rg, seeds_tree))
    if (isTRUE(FS$enet_select)) {
      a <- jsonlite::fromJSON(en_sel$params[en_sel$design == "B1" & en_sel$horizon_h == h])$alpha
      lam <- jsonlite::fromJSON(en_runs$refit_params[en_runs$design == "B1" & en_runs$horizon_h == h][1])$lambda
      add(mv_featsel_variant("enet_select", "embedded", fam, ds,
                             list(en = mv_transform_enet_select(a, lam)), p0, rg, seeds_tree))
    }
    rfe <- mv_rfe(fam, ds, p0, as.integer(E$tuning_seed), FS$rfe$drop_frac, FS$rfe$min_features)
    mv_write_csv(rfe$path, file.path(d, "RFE_PATH.csv"))
    add(mv_featsel_variant("rfe", "wrapper", fam, ds,
                           stats::setNames(list(mv_transform_columns(rfe$cols, "rfe")), paste0("k", length(rfe$cols))),
                           p0, rg, seeds_tree))
    pk <- unlist(FS$pca_k)
    add(mv_featsel_variant("pca+lightgbm", "projection", fam, ds, ks(pk, mv_transform_pca), p0, rg, seeds_tree))
    add(mv_featsel_variant("pca+ols (PCR)", "projection", "ols", ds, ks(pk, mv_transform_pca), list(), NULL, seed_lin))
    add(mv_featsel_variant("plsscores+lightgbm", "projection", fam, ds, ks(unlist(FS$pls_scores_k), mv_transform_pls),
                           p0, rg, seeds_tree))
    add(mv_featsel_variant("pls regression", "projection", "pls", ds, list(std = mv_transform_standardize()),
                           list(max_ncomp = FS$pls_max_ncomp), NULL, seed_lin))

    # PCA diagnostics on the training rows
    pc <- stats::prcomp(mv_transform_standardize()$fit(ds$blocks$train$X)$apply(ds$blocks$train$X),
                        center = FALSE, scale. = FALSE)
    ve <- pc$sdev^2 / sum(pc$sdev^2)
    pol <- sub("__lag[0-9]+$", "", rownames(pc$rotation))
    load <- do.call(rbind, lapply(1:4, function(j) {
      s <- tapply(pc$rotation[, j]^2, pol, sum)
      data.frame(horizon_h = h, component = j, pollutant = names(s), loading_share = as.numeric(s))
    }))
    mv_write_csv(data.frame(horizon_h = h, component = seq_along(ve), var_explained = ve, cum_var = cumsum(ve)),
                 file.path(d, "PCA_VARIANCE.csv"))
    mv_write_csv(load, file.path(d, "PCA_LOADINGS_BY_POLLUTANT.csv"))

    saveRDS(do.call(rbind, lapply(res, `[[`, "pred")), file.path(d, "predictions.rds"))
    mv_write_csv(do.call(rbind, lapply(res, `[[`, "info")), file.path(d, "RUNS.csv"))
    mv_write_csv(do.call(rbind, lapply(res, `[[`, "tuning")), file.path(d, "TRANSFORM_TUNING.csv"))
    rt <- do.call(rbind, lapply(res, `[[`, "retune")); if (length(rt)) mv_write_csv(rt, file.path(d, "RETUNE.csv"))
    sf <- do.call(rbind, lapply(res, `[[`, "selected")); if (length(sf)) mv_write_csv(sf, file.path(d, "SELECTED_FEATURES.csv"))
    im <- do.call(rbind, lapply(res, `[[`, "importance")); if (length(im)) mv_write_csv(im, file.path(d, "IMPORTANCE.csv.gz"))
    stage_meta(d, list(horizon_h = h, base_params = p0))
  }
}

# ---- six targets: separate vs shared -------------------------------------------------------

mv_stage_targets <- function() {
  require_check()
  TG <- E$targets; fam <- TG$family
  tg <- unlist(TG$pollutants)
  cands <- mv_candidates(list(base = TG$base, grid = TG$grid))
  for (h in H) {
    d <- file.path(OUT, "targets", paste0("h", h)); dir.create(d, recursive = TRUE, showWarnings = FALSE)
    preds <- list(); info <- list(); tun <- list()
    for (t in tg) for (dsn in c("B0", "B1")) {
      ds <- mv_dataset(cfg, panel, dsn, h, target = t)
      tu <- mv_tune(fam, ds, cands, as.integer(E$tuning_seed), mv_transform_identity())
      fr <- mv_final_runs(fam, ds, tu$params, SEEDS, mv_transform_identity(), "targets", list(variant = "separate"))
      preds[[paste(t, dsn)]] <- fr$pred
      info[[paste(t, dsn)]] <- fr$info
      tun[[paste(t, dsn)]] <- cbind(design = dsn, target = t, horizon_h = h, tu$table, chosen = tu$table$candidate == tu$best)
      log_line(sprintf("targets h=%d separate %s %s best=%s", h, dsn, t, tu$best))
    }
    st <- mv_pooled_stats(cfg, panel)
    for (pv in unlist(TG$pooled_variants)) {
      pds <- mv_pooled_dataset(cfg, panel, h, tg, st, own_slot = pv != "pooled_B1",
                               include_all = pv != "pooled_B0")
      pc <- lapply(cands, function(p) utils::modifyList(p, list(categorical_feature = "target_id")))
      tu <- mv_tune(fam, pds, pc, as.integer(E$tuning_seed), mv_transform_identity())
      fr <- mv_final_runs(fam, pds, tu$params, SEEDS, mv_transform_identity(), "targets", list(variant = "shared"))
      fr$pred$yhat <- fr$pred$yhat * st$sd[fr$pred$target] + st$mu[fr$pred$target]   # back to original units
      preds[[pv]] <- fr$pred; info[[pv]] <- fr$info
      tun[[pv]] <- cbind(design = pv, target = "all", horizon_h = h, tu$table, chosen = tu$table$candidate == tu$best)
      log_line(sprintf("targets h=%d shared %s best=%s", h, pv, tu$best))
    }
    saveRDS(do.call(rbind, preds), file.path(d, "predictions.rds"))
    mv_write_csv(do.call(rbind, info), file.path(d, "RUNS.csv"))
    mv_write_csv(do.call(rbind, tun), file.path(d, "TUNING.csv"))
    stage_meta(d, list(horizon_h = h, pooled_scaling = "per-pollutant mean/sd of the train block hours",
                       pooled_selection = "validation MAE in standardized units (equal weight per target)"))
  }
}

mv_run_stage <- function(stage) {
  switch(stage,
         report = mv_stage_report(),
         featsel = mv_stage_featsel(),
         targets = mv_stage_targets(),
         stop("unknown stage ", stage))
}
