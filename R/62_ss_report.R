# Second-stage report: metrics, validation-based selections, paired
# comparisons (moving-block bootstrap + Diebold-Mariano, as in R/55) and plots.
# Reads results/second_stage/runs and, read only, the original Shillong runs.

ss_read_runs <- function(out) {
  files <- list.files(file.path(out, "runs"), pattern = "[.]rds$", recursive = TRUE, full.names = TRUE)
  rr <- lapply(files, readRDS)
  kind <- sub("_.*$", "", sub("[.]rds$", "", basename(files)))
  list(files = files, runs = rr, kind = kind)
}

ss_seed_mean <- function(pred) {
  keys <- intersect(c("station", "target", "arch", "pca", "kind", "structure", "strategy", "switch_h",
                      "horizon_h", "component", "block", "origin_idx", "target_idx"), names(pred))
  pred[, .(y = y[1], yhat = mean(yhat), n_seeds = .N), by = keys]
}

# Paired comparisons a vs b on identical target hours (seed-mean forecasts).
# `pairs` is a data.table with key columns + id_a / id_b (strings of the form
# arch|pca|strategy|switch) and a question label.
ss_pair_rows <- function(sm, pairs, bcfg, blocks = c("validation", "test")) {
  sm <- sm[component == "LEVEL"]
  sm[, id := paste(arch, pca, strategy, switch_h, sep = "|")]
  data.table::setkey(sm, station, horizon_h, block, id)
  out <- vector("list", nrow(pairs) * length(blocks)); i <- 0L
  for (r in seq_len(nrow(pairs))) {
    p <- pairs[r]
    for (b in blocks) {
      a <- sm[list(p$station, p$horizon_h, b, p$id_a)]
      bb <- sm[list(p$station, p$horizon_h, b, p$id_b)]
      if (!nrow(a) || !nrow(bb) || anyNA(a$yhat) || anyNA(bb$yhat)) next
      m <- merge(a[, .(target_idx, origin_idx, y, ya = yhat)], bb[, .(target_idx, yb = yhat)], by = "target_idx")
      if (nrow(m) != nrow(a) || nrow(m) != nrow(bb)) stop("paired samples differ: ", p$id_a, " vs ", p$id_b)
      m <- m[order(origin_idx)]
      pc <- mv_paired_compare(m$y, m$ya, m$yb, p$horizon_h, reps = as.integer(bcfg$reps),
                              seed = as.integer(bcfg$seed), sensitivity = integer(0),
                              min_block = as.integer(bcfg$min_block_h), min_blocks = as.integer(bcfg$min_blocks))
      i <- i + 1L
      out[[i]] <- cbind(p, data.table::data.table(block = b, n = nrow(m), MAE_a = mean(abs(m$ya - m$y)),
                                                  MAE_b = mean(abs(m$yb - m$y))), pc)
    }
  }
  r <- data.table::rbindlist(out[seq_len(i)])
  if (!nrow(r)) return(r)
  r[, verdict := ifelse(mae_ratio_hi < 1, "a better", ifelse(mae_ratio_lo > 1, "a worse", "no clear difference"))]
  r[]
}

ss_theme <- function() ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = "bottom",
                 strip.text = ggplot2::element_text(face = "bold"))

ss_strategy_pal <- c(direct = "#2a78d6", recursive = "#d64545", hybrid = "#1f9e6e")
ss_pca_pal <- c(none = "#20242a", pca90 = "#e3a21a", pca95 = "#9a6fd1", pca99 = "#2a9fd6")

ss_stage_report <- function(cfg, scfg, out, say, load_station) {
  library(ggplot2)
  rdir <- file.path(out, "report"); pdir <- file.path(rdir, "plots")
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  target <- cfg$primary_target
  R <- ss_read_runs(out)
  say("report: ", length(R$files), " run files")
  pred <- data.table::rbindlist(lapply(R$runs, `[[`, "pred"), fill = TRUE)
  pred <- pred[block != "train"]
  sm <- ss_seed_mean(pred)

  # original study (read only): LightGBM PM2.5 direct runs and references
  Ss <- lapply(stats::setNames(cfg$stations, cfg$stations), load_station)
  scales <- do.call(rbind, lapply(names(Ss), function(st) {
    s <- sh_mase_scales(Ss[[st]]$panel, target, Ss[[st]]$splits)
    data.frame(station = st, component = names(s), scale = as.numeric(s))
  }))
  scale_mat <- function(st, cp) scales$scale[match(paste(st, cp), paste(scales$station, scales$component))]
  orig <- list()
  for (st in cfg$stations) for (h in cfg$horizons) {
    for (a in unique(c("A0", unique(sm$arch)))) {
      f <- file.path(scfg$original_output_dir, "runs", "lightgbm", st, target, paste0("h", h), paste0(a, ".rds"))
      if (!file.exists(f)) next
      p <- readRDS(f)$pred[block != "train"]
      p <- sh_seed_mean(p)
      orig[[paste(st, h, a)]] <- p[, .(station, target, arch, pca = "none", kind, structure,
                                       strategy = "original_direct", switch_h = NA_integer_, horizon_h,
                                       component, block, origin_idx, target_idx, y, yhat, n_seeds)]
    }
    S <- Ss[[st]]
    smp <- sh_samples(cfg, S$panel, S$splits, target, h, S$avail$pollutants)
    rp <- sh_reference_preds(S$panel, smp, target, S$splits)[block != "train"]
    orig[[paste(st, h, "ref")]] <- rp[arch %in% c("persistence", "hour_climatology"),
      .(station = st, target, arch, pca = "none", kind = "reference", structure = "none",
        strategy = "reference", switch_h = NA_integer_, horizon_h = as.integer(h), component, block,
        origin_idx, target_idx, y, yhat, n_seeds = 1L)]
  }
  orig <- data.table::rbindlist(orig)

  all_sm <- rbind(sm, orig, fill = TRUE)
  met <- all_sm[, .(n = .N, MAE = mean(abs(yhat - y)), RMSE = sqrt(mean((yhat - y)^2))),
                by = .(station, arch, pca, kind, strategy, switch_h, horizon_h, component, block)]
  met[, MASE := MAE / scale_mat(station, component)]

  # ---- original reproduction check
  chk <- merge(met[strategy == "direct" & pca == "none" & component == "LEVEL", .(station, arch, horizon_h, block, MAE_new = MAE)],
               met[strategy == "original_direct" & component == "LEVEL", .(station, arch, horizon_h, block, MAE_orig = MAE)],
               by = c("station", "arch", "horizon_h", "block"))
  chk[, identical := abs(MAE_new - MAE_orig) < 1e-9]
  mv_write_csv(chk, file.path(rdir, "ORIGINAL_REPRODUCTION.csv"))
  say("direct/none reproduces the original runs: ", sum(chk$identical), "/", nrow(chk))

  # ---- hybrid switch point chosen on validation
  hy <- met[strategy == "hybrid" & component == "LEVEL"]
  hsel <- hy[block == "validation", .SD[which.min(MAE)], by = .(station, arch, pca, horizon_h)][
    , .(station, arch, pca, horizon_h, switch_sel = switch_h)]
  mv_write_csv(merge(hy, hsel, by = c("station", "arch", "pca", "horizon_h"))[
    , selected := switch_h == switch_sel][order(station, arch, pca, horizon_h, block, switch_h)],
    file.path(rdir, "HYBRID_SWITCH_POINTS.csv"))
  hkey <- hsel[, paste(station, arch, pca, horizon_h, switch_sel)]
  sel_hyb <- function(d) d[strategy != "hybrid" | paste(station, arch, pca, horizon_h, switch_h) %in% hkey]
  main_sm <- sel_hyb(all_sm)
  main <- sel_hyb(met)

  # ---- runtime, sample counts, retained components
  rt <- list(); kk <- list(); nn <- list()
  for (i in seq_along(R$runs)) {
    r <- R$runs[[i]]; m <- r$meta
    if (R$kind[i] == "recursive") {
      rt[[i]] <- data.table::data.table(station = m$station, arch = m$arch, pca = m$pca, strategy = "recursive",
        switch_h = NA_integer_, horizon_h = NA_integer_, onestep_fit_s = r$elapsed$onestep_fit_s,
        recursion_s = r$elapsed$recursion_s, stage_fit_s = NA_real_, crossfit_s = NA_real_,
        n_units = r$elapsed$n_units)
      os <- r$onestep[seed == seed[1]]
      kk[[i]] <- os[, .(station = m$station, arch = m$arch, pca = m$pca, strategy = "recursive", switch_h = NA_integer_,
                        horizon_h = NA_integer_, unit = paste(pollutant, component),
                        n_in = as.numeric(ifelse(is.na(pca_k), n_inputs, pca_n_in + n_inputs - pca_k)),
                        k = as.numeric(pca_k))]
      nn[[i]] <- os[pollutant == target, .(station = m$station, arch = m$arch, pca = m$pca, strategy = "recursive",
                    switch_h = NA_integer_, horizon_h = NA_integer_, n_train = max(n_train))]
    } else {
      rt[[i]] <- data.table::data.table(station = m$station, arch = m$arch, pca = m$pca, strategy = m$strategy,
        switch_h = m$switch_h, horizon_h = m$horizon_h, onestep_fit_s = NA_real_, recursion_s = NA_real_,
        stage_fit_s = r$elapsed_s, crossfit_s = r$crossfit$elapsed_s %||% NA_real_,
        n_units = data.table::uniqueN(r$info$component))
      kk[[i]] <- r$pca[, .(station = m$station, arch = m$arch, pca = m$pca, strategy = m$strategy,
                           switch_h = m$switch_h, horizon_h = m$horizon_h, unit = component,
                           n_in = as.numeric(n_in), k = as.numeric(k))]
      nn[[i]] <- r$info[, .(station = m$station, arch = m$arch, pca = m$pca, strategy = m$strategy,
                            switch_h = m$switch_h, horizon_h = m$horizon_h, n_train = max(n_train))]
    }
  }
  rt <- data.table::rbindlist(rt); kk <- data.table::rbindlist(kk); nn <- unique(data.table::rbindlist(nn))
  mv_write_csv(rt, file.path(rdir, "RUNTIME_BY_RUN.csv"))
  mv_write_csv(kk, file.path(rdir, "PCA_RETAINED_BY_MODEL.csv"))
  # runtime attributed to one (strategy, horizon) row:
  #   direct    = that horizon's fit;
  #   recursive = one-step fits + recursion (one model set serves all horizons);
  #   hybrid    = one-step fits + recursion + cross-fit (shared) + this (s, h) direct stage.
  rec_cost <- rt[strategy == "recursive", .(station, arch, pca, rec_s = onestep_fit_s + recursion_s)]
  attr_rt <- function(d) {
    d <- merge(d, rec_cost, by = c("station", "arch", "pca"), all.x = TRUE)
    d <- merge(d, rt[strategy %in% c("direct", "hybrid"), .(station, arch, pca, strategy, switch_h, horizon_h,
                                                            stage_fit_s, crossfit_s)],
               by = c("station", "arch", "pca", "strategy", "switch_h", "horizon_h"), all.x = TRUE)
    d[, runtime_s := data.table::fcase(strategy == "direct", stage_fit_s, strategy == "recursive", rec_s,
                                       strategy == "hybrid", rec_s + crossfit_s + stage_fit_s, default = NA_real_)]
    d[, c("rec_s", "stage_fit_s", "crossfit_s") := NULL]
    d
  }
  ksum <- kk[, .(k_retained = if (all(is.na(k))) NA_character_ else
                   if (min(k) == max(k)) as.character(min(k)) else paste0(min(k), "-", max(k)),
                 n_inputs_before_pca = max(n_in)),
             by = .(station, arch, pca, strategy, switch_h, horizon_h)]

  # ---- main experiment table (LEVEL, wide by block)
  lv <- main[component == "LEVEL" & strategy %in% c("direct", "recursive", "hybrid")]
  w <- data.table::dcast(lv, station + arch + pca + strategy + switch_h + horizon_h ~ block,
                         value.var = c("n", "MAE", "RMSE", "MASE"))
  w <- merge(w, ksum[strategy != "recursive"], by = c("station", "arch", "pca", "strategy", "switch_h", "horizon_h"), all.x = TRUE)
  kr <- ksum[strategy == "recursive", .(station, arch, pca, k_rec = k_retained, n_rec = n_inputs_before_pca)]
  w <- merge(w, kr, by = c("station", "arch", "pca"), all.x = TRUE)
  w[strategy == "recursive", `:=`(k_retained = k_rec, n_inputs_before_pca = n_rec)]
  w[, c("k_rec", "n_rec") := NULL]
  w <- merge(w, nn[strategy != "recursive"], by = c("station", "arch", "pca", "strategy", "switch_h", "horizon_h"), all.x = TRUE)
  nr <- nn[strategy == "recursive", .(station, arch, pca, n_tr_rec = n_train)]
  w <- merge(w, nr, by = c("station", "arch", "pca"), all.x = TRUE)
  w[strategy == "recursive", n_train := n_tr_rec]; w[, n_tr_rec := NULL]
  w <- attr_rt(w)
  data.table::setnames(w, c("n_test"), c("n_test_predictions"))
  w[, n_validation := NULL]
  w[, strategy := factor(strategy, c("direct", "recursive", "hybrid"))]
  w <- w[order(station, horizon_h, arch, strategy, pca)]
  w[, strategy := as.character(strategy)]
  mv_write_csv(w, file.path(rdir, "EXPERIMENTS.csv"))
  arrow::write_parquet(w, file.path(rdir, "EXPERIMENTS.parquet"))
  mv_write_csv(met, file.path(rdir, "METRICS_ALL.csv"))
  arrow::write_parquet(met, file.path(rdir, "METRICS_ALL.parquet"))
  mv_write_csv(met[component != "LEVEL"], file.path(rdir, "COMPONENT_METRICS.csv"))
  arrow::write_parquet(sm, file.path(rdir, "PREDICTIONS_SEED_MEAN.parquet"))

  # ---- validation-selected PCA per (station, arch, strategy, h)
  ps <- w[, .SD[which.min(MAE_validation)], by = .(station, arch, strategy, horizon_h)][
    , .(station, arch, strategy, horizon_h, pca_sel = pca, val_MAE_sel = MAE_validation, test_MAE_sel = MAE_test)]
  pn <- w[pca == "none", .(station, arch, strategy, horizon_h, val_MAE_none = MAE_validation, test_MAE_none = MAE_test)]
  pb <- w[, .SD[which.min(MAE_test)], by = .(station, arch, strategy, horizon_h)][
    , .(station, arch, strategy, horizon_h, pca_test_best = pca)]
  pcs <- Reduce(function(a, b) merge(a, b, by = c("station", "arch", "strategy", "horizon_h")), list(ps, pn, pb))
  pcs[, test_ratio_sel_vs_none := test_MAE_sel / test_MAE_none]
  mv_write_csv(pcs, file.path(rdir, "PCA_SELECTED.csv"))

  # ---- best combination per horizon: validation-selected vs hindsight
  bb <- w[, {
    v <- .SD[which.min(MAE_validation)]; t <- .SD[which.min(MAE_test)]
    .(sel = paste(v$arch, v$strategy, v$pca, ifelse(is.na(v$switch_h), "", paste0("s", v$switch_h))),
      sel_val_MAE = v$MAE_validation, sel_test_MAE = v$MAE_test, sel_test_MASE = v$MASE_test,
      hindsight = paste(t$arch, t$strategy, t$pca, ifelse(is.na(t$switch_h), "", paste0("s", t$switch_h))),
      hindsight_test_MAE = t$MAE_test, hindsight_test_MASE = t$MASE_test)
  }, by = .(station, horizon_h)]
  ref <- met[component == "LEVEL" & block == "test" & (strategy == "reference" | (strategy == "original_direct" & arch %in% c("A0", "A2"))),
             .(station, horizon_h, ref = ifelse(strategy == "reference", arch, paste0("orig_", arch)), MAE)]
  bb <- merge(bb, data.table::dcast(ref, station + horizon_h ~ ref, value.var = "MAE"), by = c("station", "horizon_h"))
  mv_write_csv(bb, file.path(rdir, "BEST_BY_HORIZON.csv"))

  # ---- paired comparisons
  bcfg <- cfg$bootstrap
  cells <- unique(w[, .(station, arch, pca, strategy, switch_h, horizon_h)])
  idf <- function(a, p, s, sw) paste(a, p, s, sw, sep = "|")
  hy_id <- function(st, a, p, h) {
    s <- hsel[station == st & arch == a & pca == p & horizon_h == h, switch_sel]
    if (length(s)) idf(a, p, "hybrid", s) else NA_character_
  }
  pr <- list()
  # 1. PCA vs original features (same arch, strategy, horizon)
  for (i in seq_len(nrow(cells))) {
    c0 <- cells[i]
    if (c0$pca == "none") next
    base <- cells[station == c0$station & arch == c0$arch & pca == "none" & strategy == c0$strategy & horizon_h == c0$horizon_h]
    if (!nrow(base)) next
    pr[[length(pr) + 1]] <- data.table::data.table(comparison = "pca_vs_none", station = c0$station, horizon_h = c0$horizon_h,
      arch = c0$arch, strategy = c0$strategy, pca = c0$pca, id_a = idf(c0$arch, c0$pca, c0$strategy, c0$switch_h),
      id_b = idf(c0$arch, "none", c0$strategy, base$switch_h), question = paste(c0$pca, "vs none"))
  }
  # 2. strategies (same arch, PCA, horizon)
  ac <- unique(cells[, .(station, arch, pca, horizon_h)])
  for (i in seq_len(nrow(ac))) {
    c0 <- ac[i]
    d <- idf(c0$arch, c0$pca, "direct", NA); r <- idf(c0$arch, c0$pca, "recursive", NA)
    hb <- hy_id(c0$station, c0$arch, c0$pca, c0$horizon_h)
    add <- function(a, b, q) pr[[length(pr) + 1]] <<- data.table::data.table(comparison = "strategy",
      station = c0$station, horizon_h = c0$horizon_h, arch = c0$arch, strategy = q, pca = c0$pca,
      id_a = a, id_b = b, question = q)
    add(r, d, "recursive vs direct")
    if (!is.na(hb)) { add(hb, d, "hybrid vs direct"); add(hb, r, "hybrid vs recursive") }
  }
  # 3. architectures under each strategy (original features) and vs the original A0 direct
  archs <- unique(cells$arch)
  for (st in unique(cells$station)) for (h in unique(cells$horizon_h)) for (s in c("direct", "recursive", "hybrid")) {
    idx <- function(a) if (s == "hybrid") hy_id(st, a, "none", h) else idf(a, "none", s, NA)
    for (a in setdiff(archs, "A2")) if ("A2" %in% archs)
      pr[[length(pr) + 1]] <- data.table::data.table(comparison = "arch", station = st, horizon_h = h, arch = a,
        strategy = s, pca = "none", id_a = idx(a), id_b = idx("A2"), question = paste(a, "vs A2"))
    for (a in archs)
      pr[[length(pr) + 1]] <- data.table::data.table(comparison = "vs_original_A0", station = st, horizon_h = h,
        arch = a, strategy = s, pca = "none", id_a = idx(a), id_b = idf("A0", "none", "original_direct", NA),
        question = paste(a, s, "vs original A0 direct"))
  }
  # 4. validation-selected combination per horizon vs the original A2 direct and A0 direct
  for (i in seq_len(nrow(bb))) {
    v <- w[station == bb$station[i] & horizon_h == bb$horizon_h[i]][which.min(MAE_validation)]
    for (ref_a in c("A0", "A2"))
      pr[[length(pr) + 1]] <- data.table::data.table(comparison = "selected_vs_original", station = v$station,
        horizon_h = v$horizon_h, arch = v$arch, strategy = v$strategy, pca = v$pca,
        id_a = idf(v$arch, v$pca, v$strategy, v$switch_h), id_b = idf(ref_a, "none", "original_direct", NA),
        question = paste("validation-selected vs original", ref_a, "direct"))
  }
  pairs <- data.table::rbindlist(pr)
  pairs <- pairs[!is.na(id_a) & !is.na(id_b)]
  say("report: ", nrow(pairs), " paired comparisons x 2 blocks")
  pp <- ss_pair_rows(main_sm, pairs, bcfg)
  mv_write_csv(pp, file.path(rdir, "PAIRED_COMPARISONS.csv"))

  # ---- PCA diagnostics: explained-variance curves (direct, h = 24, one model per unit)
  curves <- list()
  for (i in seq_along(R$runs)) {
    r <- R$runs[[i]]; m <- r$meta
    if (R$kind[i] != "direct" || m$horizon_h != min(cfg$horizons) || m$pca != "pca99") next
    for (j in seq_len(nrow(r$pca))) {
      cv <- as.numeric(strsplit(r$pca$cum_var[j], ";")[[1]])
      curves[[length(curves) + 1]] <- data.table::data.table(station = m$station, arch = m$arch,
        unit = r$pca$component[j], n_components = seq_along(cv), cum_var = cv)
    }
  }
  curves <- data.table::rbindlist(curves)
  mv_write_csv(curves, file.path(rdir, "PCA_EXPLAINED_VARIANCE.csv"))

  # ---- recursive diagnostics: one-step accuracy and drift of the forecast mean
  os <- data.table::rbindlist(lapply(R$runs[R$kind == "recursive"], `[[`, "onestep_mae"))
  mv_write_csv(os, file.path(rdir, "ONESTEP_ACCURACY.csv"))
  drift <- main_sm[component == "LEVEL" & strategy %in% c("direct", "recursive", "hybrid"),
                   .(mean_y = mean(y), mean_yhat = mean(yhat), sd_y = stats::sd(y), sd_yhat = stats::sd(yhat)),
                   by = .(station, arch, pca, strategy, horizon_h, block)]
  mv_write_csv(drift, file.path(rdir, "FORECAST_SPREAD.csv"))

  # ---- completed / skipped / failed
  exp_cells <- data.table::CJ(station = cfg$stations, arch = c(unlist(scfg$primary_architectures),
                              unlist(scfg$extension_architectures)), pca = vapply(unlist(scfg$pca), function(p)
                              ss_pca_label(if (p == "none") "none" else as.numeric(p)), ""))
  hc <- ss_hybrid_cells(cfg$horizons, scfg$hybrid$switch_points)
  expected <- c(sprintf("direct_h%d.rds", cfg$horizons), "recursive.rds", sprintf("hybrid_s%d_h%d.rds", hc$s, hc$h))
  done <- exp_cells[, {
    d <- ss_cell_dir(out, station, arch, if (pca == "none") "none" else as.numeric(sub("pca", "", pca)) / 100)
    f <- file.exists(file.path(d, expected))
    .(files_done = sum(f), files_expected = length(expected),
      status = if (all(f)) "completed" else if (any(f)) "partial" else "not run")
  }, by = .(station, arch, pca)]
  mv_write_csv(done, file.path(rdir, "COMPLETION.csv"))
  skipped <- data.table::data.table(
    combination = c("hybrid, h = 24 (all switch points)", "hybrid, s >= h"),
    reason = c("A 24 h recursive block reaches the horizon: identical to recursive, not a distinct experiment",
               "The recursive block would reach or pass the horizon"))
  mv_write_csv(skipped, file.path(rdir, "SKIPPED.csv"))

  ss_report_plots(w, met, pp, curves, kk, rt, cfg, pdir)
  say("report written to ", rdir)
}

ss_report_plots <- function(w, met, pp, curves, kk, rt, cfg, pdir) {
  library(ggplot2)
  save <- function(p, f, wd = 11, ht = 7) ggsave(file.path(pdir, f), p, width = wd, height = ht, dpi = 150, bg = "white")
  w <- data.table::copy(w)
  w[, strategy := factor(strategy, c("direct", "recursive", "hybrid"))]
  w[, pca := factor(pca, c("none", "pca90", "pca95", "pca99"))]
  w[, row := paste(arch, strategy)]
  for (b in c("test", "validation")) {
    d <- w[, .(row, station, pca, horizon_h, MASE = get(paste0("MASE_", b)))]
    p <- ggplot(d, aes(factor(horizon_h), row, fill = MASE)) + geom_tile(colour = "white", linewidth = 0.5) +
      geom_text(aes(label = sprintf("%.2f", MASE)), size = 2.6) +
      facet_grid(station ~ pca) + scale_fill_gradient(low = "#eef4fb", high = "#1d5fae", name = "MASE") +
      ss_theme() + labs(title = sprintf("PM2.5 %s MASE by architecture, strategy and PCA setting", b),
                        subtitle = "Hybrid = switch point chosen on validation; MASE = MAE / train seasonal-naive (24 h) MAE",
                        x = "horizon (h)", y = NULL)
    save(p, sprintf("mase_heatmap_%s.png", b), 13, 9)
  }
  if (nrow(curves)) {
    p <- ggplot(curves[n_components <= 60], aes(n_components, cum_var, group = paste(arch, unit), colour = arch)) +
      geom_hline(yintercept = c(0.9, 0.95, 0.99), linetype = 2, colour = "#9aa1a9") +
      geom_line(linewidth = 0.5, alpha = 0.8) + facet_wrap(~station) + ss_theme() +
      labs(title = "Cumulative explained variance of the train-only PCA (direct models, h = 24)",
           subtitle = "One curve per model; dashed lines = the 90 / 95 / 99 % thresholds",
           x = "principal components", y = "cumulative variance share", colour = NULL)
    save(p, "pca_explained_variance.png", 11, 5.5)
  }
  kd <- kk[strategy != "recursive" & !is.na(k)]
  if (nrow(kd)) {
    p <- ggplot(kd, aes(factor(horizon_h), k, colour = pca)) +
      geom_point(position = position_jitterdodge(jitter.width = 0.1, dodge.width = 0.6), size = 1.3, alpha = 0.8) +
      facet_grid(station ~ arch + strategy) + scale_colour_manual(values = ss_pca_pal) + scale_y_log10() + ss_theme() +
      labs(title = "Retained principal components per model", subtitle = "Inputs before PCA: A2/A3 24 x pollutants, C2_sep 144 x pollutants",
           x = "horizon (h)", y = "components kept (log scale)", colour = NULL)
    save(p, "pca_retained_components.png", 14, 7)
  }
  sp <- pp[comparison == "strategy" & block == "test"]
  if (nrow(sp)) {
    sp[, pca := factor(pca, c("none", "pca90", "pca95", "pca99"))]
    p <- ggplot(sp, aes(factor(horizon_h), mae_ratio, colour = pca)) +
      geom_hline(yintercept = 1, linetype = 2, colour = "#7d8590") +
      geom_pointrange(aes(ymin = mae_ratio_lo, ymax = mae_ratio_hi), position = position_dodge(width = 0.6), size = 0.2) +
      facet_grid(station + question ~ arch, scales = "free_y") + scale_colour_manual(values = ss_pca_pal) + ss_theme() +
      labs(title = "Test MAE ratio between strategies (95% moving-block bootstrap interval)",
           subtitle = "Below 1 = the first strategy is better", x = "horizon (h)", y = "MAE ratio", colour = "features")
    save(p, "strategy_comparison.png", 13, 11)
  }
  pc <- pp[comparison == "pca_vs_none" & block == "test"]
  if (nrow(pc)) {
    p <- ggplot(pc, aes(factor(horizon_h), mae_ratio, colour = pca)) +
      geom_hline(yintercept = 1, linetype = 2, colour = "#7d8590") +
      geom_pointrange(aes(ymin = mae_ratio_lo, ymax = mae_ratio_hi), position = position_dodge(width = 0.6), size = 0.2) +
      facet_grid(station + strategy ~ arch, scales = "free_y") + scale_colour_manual(values = ss_pca_pal) + ss_theme() +
      labs(title = "Test MAE ratio PCA / original features (95% moving-block bootstrap interval)",
           subtitle = "Below 1 = PCA better", x = "horizon (h)", y = "MAE ratio", colour = NULL)
    save(p, "pca_vs_none.png", 13, 11)
  }
  hd <- w[pca == "none"]
  ref <- met[component == "LEVEL" & block %in% c("validation", "test") & strategy %in% c("reference", "original_direct") &
               arch %in% c("persistence", "A0"), .(station, horizon_h, block, ref = arch, MASE)]
  hl <- data.table::melt(hd, id.vars = c("station", "arch", "strategy", "horizon_h"),
                         measure.vars = c("MASE_validation", "MASE_test"), variable.name = "block", value.name = "MASE")
  hl[, block := sub("MASE_", "", block)]
  p <- ggplot(hl, aes(horizon_h, MASE, colour = strategy)) + geom_line(linewidth = 0.6) + geom_point(size = 1.5) +
    geom_line(data = ref, aes(horizon_h, MASE, linetype = ref), colour = "#7d8590", inherit.aes = FALSE) +
    facet_grid(station + block ~ arch, scales = "free_y") + scale_x_continuous(breaks = cfg$horizons, trans = "log2") +
    scale_colour_manual(values = ss_strategy_pal) + ss_theme() +
    labs(title = "PM2.5 MASE by horizon (original features)", subtitle = "Grey: persistence and the original A0 direct model",
         x = "horizon (h, log scale)", y = "MASE", colour = NULL, linetype = NULL)
  save(p, "horizon_performance.png", 13, 9)
  rr <- w[, .(runtime_min = runtime_s / 60), by = .(station, arch, strategy, pca, horizon_h)]
  p <- ggplot(rr[horizon_h == max(horizon_h)], aes(pca, runtime_min, fill = strategy)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.75) + facet_grid(station ~ arch) +
    scale_fill_manual(values = ss_strategy_pal) + scale_y_log10() + ss_theme() +
    labs(title = sprintf("Wall-clock cost per forecast setup at h = %d (single thread)", max(rr$horizon_h)),
         subtitle = "Recursive = one-step fits + recursion (shared by all horizons); hybrid adds cross-fitting and its direct stage",
         x = NULL, y = "minutes (log scale)", fill = NULL)
  save(p, "runtime.png", 12, 6.5)
  hs <- met[strategy == "hybrid" & component == "LEVEL" & pca == "none"]
  if (nrow(hs)) {
    p <- ggplot(hs, aes(switch_h, MAE, colour = block)) + geom_line() + geom_point(size = 1.5) +
      facet_grid(station + arch ~ horizon_h, scales = "free_y") + scale_x_continuous(breaks = c(24, 48, 72)) +
      scale_colour_manual(values = c(validation = "#7d8590", test = "#eb6834")) + ss_theme() +
      labs(title = "Hybrid MAE by switch point (original features)", x = "recursive block s (h)", y = "MAE (ug/m3)", colour = NULL)
    save(p, "hybrid_switch_points.png", 11, 10)
  }
}
