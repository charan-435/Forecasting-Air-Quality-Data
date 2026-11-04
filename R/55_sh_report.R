# Shillong architecture study: report tables, paired comparisons and plots.
# Reads results/shillong_arch/{runs,sensitivity}; writes results/shillong_arch/report.

SH_PAIRS <- list(
  # a = the richer architecture, b = its reference; ratio = MAE(a) / MAE(b)
  c("A1", "A0", "covariates, undecomposed"),
  c("A2", "A0", "multivariate lags, undecomposed"),
  c("A3", "A2", "covariates on multivariate lags"),
  c("A2", "A1", "multivariate lags vs covariates only"),
  c("B1", "B0", "shared vs separate components"),
  c("B2", "B0", "covariates, separate components"),
  c("B3", "B1", "covariates, shared component model"),
  c("C1_sep", "B0", "intercomponent lags (separate)"),
  c("C1_sh", "B0", "intercomponent lags (shared)"),
  c("C2_sep", "B0", "cross-pollutant components (separate)"),
  c("C2_sh", "B0", "cross-pollutant components (shared)"),
  c("C3_sep", "C2_sep", "covariates on C2 (separate)"),
  c("C3_sh", "C2_sh", "covariates on C2 (shared)"),
  c("C1_sh", "C1_sep", "shared vs separate (C1)"),
  c("C2_sh", "C2_sep", "shared vs separate (C2)"),
  c("C3_sh", "C3_sep", "shared vs separate (C3)"),
  c("C2_sep", "C1_sep", "cross-pollutant over intercomponent (separate)"),
  c("B0", "A0", "decomposition, univariate"),
  c("C2_sep", "A2", "decomposition, multivariate (separate)")
)

sh_palette <- c(level = "#2a78d6", decomp_sep = "#eb6834", decomp_sh = "#1baa7a",
                reference = "#7d8590")

sh_read_runs <- function(dir) {
  files <- list.files(dir, pattern = "\\.rds$", recursive = TRUE, full.names = TRUE)
  rs <- lapply(files, readRDS)
  pick <- function(k) data.table::rbindlist(lapply(rs, `[[`, k), fill = TRUE)
  list(pred = pick("pred"), info = pick("info"), tuning = pick("tuning"),
       importance = pick("importance"), schema = pick("schema"),
       elapsed = data.table::rbindlist(lapply(rs, function(r) r$pred[1, .(station, target, horizon_h,
                                                                       arch, family)][, s := r$elapsed_s])))
}

sh_arch_group <- function(arch) {
  ifelse(grepl("^A", arch), "level",
         ifelse(arch %in% c("B1", "B3") | grepl("_sh$", arch), "decomp_sh",
                ifelse(arch %in% c("persistence", "seasonal_naive", "climatology", "hour_climatology"),
                       "reference", "decomp_sep")))
}

# Seed-mean metrics with MASE for one or many (station, target) cells.
sh_metric_frame <- function(sm, scales) {
  m <- sm[, .(n = .N, MAE = mean(abs(yhat - y)), RMSE = sqrt(mean((yhat - y)^2))),
          by = .(station, target, horizon_h, arch, family, component, block)]
  m <- merge(m, scales, by = c("station", "target", "component"), all.x = TRUE)
  m[, MASE := MAE / scale][, scale := NULL]
  m[]
}

sh_pair_rows <- function(sm, pairs, by, bcfg, blocks = c("validation", "test"), sens = TRUE) {
  out <- list()
  cells <- unique(sm[, by, with = FALSE])
  for (i in seq_len(nrow(cells))) {
    key <- cells[i]
    d <- sm[key, on = by]
    for (p in pairs) for (b in blocks) {
      a <- d[arch == p[1] & block == b]; r <- d[arch == p[2] & block == b]
      if (!nrow(a) || !nrow(r)) next
      m <- merge(a[, .(target_idx, origin_idx, y, ya = yhat)], r[, .(target_idx, yb = yhat)],
                 by = "target_idx")
      if (nrow(m) != nrow(a) || nrow(m) != nrow(r)) stop("paired samples differ: ", paste(p, collapse = " vs "))
      m <- m[order(origin_idx)]
      pc <- mv_paired_compare(m$y, m$ya, m$yb, key$horizon_h, reps = as.integer(bcfg$reps),
                              seed = as.integer(bcfg$seed),
                              sensitivity = if (sens) as.integer(unlist(bcfg$sensitivity_blocks)) else integer(0),
                              min_block = as.integer(bcfg$min_block_h),
                              min_blocks = as.integer(bcfg$min_blocks))
      out[[length(out) + 1L]] <- cbind(key, data.table::data.table(
        a = p[1], b = p[2], question = p[3], block = b, n = nrow(m),
        MAE_a = mean(abs(m$ya - m$y)), MAE_b = mean(abs(m$yb - m$y))), pc)
    }
  }
  r <- data.table::rbindlist(out)
  if (!nrow(r)) return(r)
  r[, verdict := ifelse(mae_ratio_hi < 1, "a better", ifelse(mae_ratio_lo > 1, "a worse", "no clear difference"))]
  r[]
}

# Clean / imputed-input split: an origin is "clean" when no input pollutant has
# a filled hour in its lag window (lookback + decomposition warmup).
sh_input_fill_flag <- function(panel, pollutants, origin_idx) {
  back <- SH_LOOKBACK + (2L^panel$J - 1L)
  any_fill <- rep(FALSE, length(panel$timestamps))
  for (v in pollutants) any_fill <- any_fill | (panel$filled[[v]] %in% TRUE)
  cs <- cumsum(any_fill)
  (cs[origin_idx] - c(0L, cs)[origin_idx - back + 1L]) > 0L
}

sh_stage_report <- function(cfg, out, say, load_station) {
  rdir <- file.path(out, "report"); pdir <- file.path(rdir, "plots")
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  bcfg <- cfg$bootstrap
  t0 <- Sys.time()
  R <- sh_read_runs(file.path(out, "runs"))
  if (!nrow(R$pred)) stop("no runs found")
  say("report: ", nrow(R$pred), " prediction rows from ", data.table::uniqueN(R$elapsed), " runs")
  sm <- sh_seed_mean(R$pred)

  # ---- references and MASE scales per (station, target, horizon) ----
  refs <- list(); scales <- list(); fillflag <- list()
  for (st in unique(sm$station)) {
    S <- load_station(st)
    for (tg in unique(sm[station == st, target])) {
      sc <- sh_mase_scales(S$panel, tg, S$splits)
      scales[[paste(st, tg)]] <- data.table::data.table(station = st, target = tg,
                                                        component = names(sc), scale = as.numeric(sc))
      for (h in unique(sm[station == st & target == tg, horizon_h])) {
        smp <- sh_samples(cfg, S$panel, S$splits, tg, h, S$avail$pollutants)
        rp <- sh_reference_preds(S$panel, smp, tg, S$splits)
        rp[, `:=`(station = st, target = tg, horizon_h = h)]
        refs[[paste(st, tg, h)]] <- rp
        fillflag[[paste(st, tg, h)]] <- data.table::data.table(
          station = st, target = tg, horizon_h = h, origin_idx = smp$origin_idx,
          inputs_imputed = sh_input_fill_flag(S$panel, S$avail$pollutants, smp$origin_idx),
          target_input_imputed = sh_input_fill_flag(S$panel, tg, smp$origin_idx))
      }
    }
  }
  scales <- data.table::rbindlist(scales)
  refs <- data.table::rbindlist(refs, fill = TRUE)
  fillflag <- unique(data.table::rbindlist(fillflag))
  mv_write_csv(scales, file.path(rdir, "MASE_SCALES.csv"))

  lev <- rbind(sm[component == "LEVEL"],
               refs[, .(station, target, horizon_h, arch, family, kind, structure, component, block,
                        origin_idx, target_idx, y, yhat, n_seeds = 0L)], fill = TRUE)
  met <- sh_metric_frame(lev, scales)
  met[, group := sh_arch_group(arch)]
  mv_write_csv(met[order(station, target, family, horizon_h, block, arch)],
               file.path(rdir, "LEVEL_METRICS.csv"))
  comp <- sh_metric_frame(sm[component != "LEVEL"], scales)
  comp[, group := sh_arch_group(arch)]
  mv_write_csv(comp[order(station, target, family, horizon_h, block, arch, component)],
               file.path(rdir, "COMPONENT_METRICS.csv"))
  seedm <- R$pred[component == "LEVEL", .(MAE = mean(abs(yhat - y))),
                  by = .(station, target, horizon_h, arch, family, block, seed)]
  mv_write_csv(seedm[, .(MAE_mean = mean(MAE), MAE_sd = stats::sd(MAE), n_seeds = .N),
                     by = .(station, target, horizon_h, arch, family, block)],
               file.path(rdir, "SEED_SUMMARY.csv"))
  sel <- unique(R$info[, .(station, target, horizon_h, arch, family, component, candidate, best_iter,
                           refit_rounds, n_inputs, n_train, n_validation, n_test, refit_params)],
                by = c("station", "target", "horizon_h", "arch", "family", "component"))
  mv_write_csv(sel, file.path(rdir, "SELECTED_CONFIGS.csv"))
  mv_write_csv(R$tuning, file.path(rdir, "TUNING_ALL.csv.gz"))
  mv_write_csv(unique(R$schema[, .(station, target, horizon_h = h, arch, family, component, feature, group)]),
               file.path(rdir, "FEATURE_SCHEMAS.csv.gz"))
  mv_write_csv(R$elapsed, file.path(rdir, "RUNTIME_BY_RUN.csv"))
  say("report: metrics written (", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " s)")

  # ---- validation-selected best per (station, target, horizon, family) ----
  lv <- met[component == "LEVEL" & group != "reference"]
  pick_best <- function(d) {
    v <- d[block == "validation"][order(MAE)]
    bu <- v[group == "level"][1]; bd <- v[group != "level"][1]
    data.table::data.table(best_overall = v$arch[1], best_undecomposed = bu$arch, best_decomposed = bd$arch,
                           val_MAE_best = v$MAE[1],
                           test_MAE_best = d[block == "test" & arch == v$arch[1], MAE],
                           test_MASE_best = d[block == "test" & arch == v$arch[1], MASE],
                           test_best_arch_oracle = d[block == "test"][order(MAE)]$arch[1])
  }
  best <- lv[, pick_best(.SD), by = .(station, target, horizon_h, family)]
  mv_write_csv(best, file.path(rdir, "BEST_BY_HORIZON.csv"))

  # ---- paired comparisons (LightGBM, primary target) ----
  pm <- sm[component == "LEVEL" & family == "lightgbm" & target == cfg$primary_target]
  pairs <- sh_pair_rows(pm, SH_PAIRS, c("station", "target", "horizon_h"), bcfg)
  bb <- best[family == "lightgbm" & target == cfg$primary_target]
  extra <- list()
  for (i in seq_len(nrow(bb))) {
    k <- bb[i]
    d <- pm[station == k$station & horizon_h == k$horizon_h]
    extra[[i]] <- sh_pair_rows(d, list(c(k$best_decomposed, k$best_undecomposed,
                                         "best decomposed vs best undecomposed (validation-selected)")),
                               c("station", "target", "horizon_h"), bcfg)
  }
  refpairs <- sh_pair_rows(rbind(pm, refs[target == cfg$primary_target], fill = TRUE),
                           lapply(unique(pm$arch), function(a) c(a, "climatology", "vs train-mean climatology")),
                           c("station", "target", "horizon_h"), bcfg, sens = FALSE)
  pairs <- rbind(pairs, data.table::rbindlist(extra), fill = TRUE)
  mv_write_csv(pairs, file.path(rdir, "PAIRED_COMPARISONS.csv"))
  mv_write_csv(refpairs, file.path(rdir, "PAIRED_VS_CLIMATOLOGY.csv"))
  say("report: paired comparisons written (", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " s)")

  # ---- stage 2: validation selection across (family, architecture), PM2.5 ----
  ps <- sm[component == "LEVEL" & target == cfg$primary_target]
  fam_cells <- unique(ps[family != "lightgbm", .(station, arch)])
  if (nrow(fam_cells)) {
    f2 <- merge(ps, fam_cells, by = c("station", "arch"))
    f2[, arch_family := paste(arch, family, sep = "@")]
    fm <- f2[, .(MAE = mean(abs(yhat - y))), by = .(station, horizon_h, arch, family, arch_family, block)]
    mv_write_csv(fm, file.path(rdir, "FAMILY_METRICS.csv"))
    pickf <- fm[block == "validation"][order(MAE), .SD[1], by = .(station, horizon_h)]
    rows <- list()
    for (i in seq_len(nrow(pickf))) {
      k <- pickf[i]
      d <- f2[station == k$station & horizon_h == k$horizon_h]
      d[, arch := arch_family]
      rows[[i]] <- sh_pair_rows(d, list(c(k$arch_family, "A0@lightgbm", "validation-selected (family, architecture) vs A0 LightGBM")),
                                c("station", "horizon_h"), bcfg, sens = FALSE)
    }
    fsel <- merge(pickf[, .(station, horizon_h, selected = arch_family, val_MAE = MAE)],
                  fm[block == "test", .(station, horizon_h, selected = arch_family, test_MAE = MAE)],
                  by = c("station", "horizon_h", "selected"))
    mv_write_csv(fsel, file.path(rdir, "FAMILY_SELECTED.csv"))
    mv_write_csv(data.table::rbindlist(rows), file.path(rdir, "FAMILY_PAIRED.csv"))
  }

  # ---- other targets: A2 / B0 / shortlisted decomposed vs A0 (LightGBM) ----
  ot <- sm[component == "LEVEL" & family == "lightgbm" & target != cfg$primary_target]
  if (nrow(ot)) {
    tp <- list(c("A2", "A0", "multivariate lags"), c("A3", "A0", "multivariate lags + covariates"),
               c("B0", "A0", "decomposition"), c("C3_sep", "B0", "cross-pollutant components + covariates"),
               c("C3_sep", "A0", "C3_sep vs raw univariate"),
               c("C3_sh", "B0", "shared cross-pollutant components + covariates"),
               c("C3_sh", "A0", "C3_sh vs raw univariate"))
    mv_write_csv(sh_pair_rows(ot, tp, c("station", "target", "horizon_h"), bcfg, sens = FALSE),
                 file.path(rdir, "TARGETS_PAIRED.csv"))
  }

  # ---- component-level: separate vs shared and own vs cross inputs, per component ----
  cm <- sm[component != "LEVEL" & family == "lightgbm" & target == cfg$primary_target]
  cpairs <- sh_pair_rows(cm, list(c("B1", "B0", "shared vs separate"), c("C1_sep", "B0", "intercomponent"),
                                  c("C2_sep", "B0", "cross-pollutant"), c("C2_sh", "C2_sep", "shared vs separate (C2)"),
                                  c("B2", "B0", "covariates")),
                         c("station", "target", "horizon_h", "component"), bcfg, blocks = "test", sens = FALSE)
  mv_write_csv(cpairs, file.path(rdir, "COMPONENT_PAIRED.csv"))

  # ---- input-imputation diagnostic (test, primary target, LightGBM) ----
  ff <- merge(pm[block == "test"], fillflag, by = c("station", "target", "horizon_h", "origin_idx"))
  fd <- ff[, .(n = .N, MAE = mean(abs(yhat - y))),
           by = .(station, horizon_h, arch, inputs = ifelse(inputs_imputed, "some input hour imputed",
                                                           "all input hours observed"))]
  mv_write_csv(fd, file.path(rdir, "TEST_MAE_BY_INPUT_IMPUTATION.csv"))

  # ---- importance groups ----
  if (nrow(R$importance)) {
    imp <- merge(R$importance, unique(R$schema[, .(station, target, horizon_h = h, arch, family, component,
                                                     feature, group)]),
                 by = c("station", "target", "horizon_h", "arch", "family", "component", "feature"),
                 all.x = TRUE)
    imp[, pollutant := ifelse(group %in% c("pollutant_lag", "component_lag"), sub("_.*$", "", feature),
                              ifelse(group == "own_component_slot", "own component", group))]
    imp[, comp := ifelse(group == "component_lag", sub("^[^_]+_([DS][0-9]+)_l.*$", "\\1", feature), NA)]
    agg <- imp[, .(gain = sum(importance)), by = .(station, target, horizon_h, arch, family, seed, component, pollutant)]
    agg[, share := gain / sum(gain), by = .(station, target, horizon_h, arch, family, seed, component)]
    agg <- agg[, .(share = mean(share)), by = .(station, target, horizon_h, arch, family, component, pollutant)]
    mv_write_csv(agg, file.path(rdir, "IMPORTANCE_BY_SOURCE.csv"))
    ac <- imp[group == "component_lag", .(gain = sum(importance)),
              by = .(station, target, horizon_h, arch, family, seed, component, comp)]
    ac[, share := gain / sum(gain), by = .(station, target, horizon_h, arch, family, seed, component)]
    mv_write_csv(ac[, .(share = mean(share)), by = .(station, target, horizon_h, arch, family, component, comp)],
                 file.path(rdir, "IMPORTANCE_BY_INPUT_COMPONENT.csv"))
  }

  # ---- sensitivity (Q12) ----
  sdir <- file.path(out, "sensitivity")
  if (dir.exists(sdir)) {
    SV <- sh_read_runs(sdir)
    sv <- sh_seed_mean(SV$pred[component == "LEVEL"])   # keeps `variant`
    prim <- pm[, .(station, horizon_h, arch, block, target_idx, y_primary = y)]
    own <- sv[, .(n = .N, MAE = mean(abs(yhat - y))), by = .(station, horizon_h, arch, variant, block)]
    on_prim <- merge(sv, prim, by = c("station", "horizon_h", "arch", "block", "target_idx"))
    onp <- on_prim[, .(n = .N, MAE = mean(abs(yhat - y_primary))), by = .(station, horizon_h, arch, variant, block)]
    base <- pm[, .(n = .N, MAE = mean(abs(yhat - y))), by = .(station, horizon_h, arch, block)][, variant := "primary"]
    sens <- rbind(base[, scored_on := "primary samples"],
                  onp[, scored_on := "primary samples"], own[, scored_on := "own samples"])
    mv_write_csv(sens[order(station, horizon_h, arch, block, scored_on, variant)],
                 file.path(rdir, "SENSITIVITY_MASKING.csv"))
  }

  sh_report_plots(cfg, met, comp, pairs, rdir, pdir)
  say("report done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " s")
}

sh_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   panel.grid.major = ggplot2::element_line(colour = "#e6e8eb", linewidth = 0.3),
                   strip.text = ggplot2::element_text(face = "bold"), legend.position = "top",
                   plot.title.position = "plot")
}

sh_report_plots <- function(cfg, met, comp, pairs, rdir, pdir) {
  library(ggplot2)
  save <- function(p, f, w = 10, h = 6) ggsave(file.path(pdir, f), p, width = w, height = h, dpi = 150, bg = "white")
  arch_order <- c(unlist(cfg$architectures), "persistence", "climatology", "hour_climatology")
  d <- met[family %in% c("lightgbm", "reference") & target == cfg$primary_target & component == "LEVEL" &
             arch != "seasonal_naive" & block != "train"]
  d[, arch := factor(arch, arch_order)]
  d[, block := factor(block, c("validation", "test"))]
  p <- ggplot(d, aes(arch, MASE, fill = group)) +
    geom_col(width = 0.7) + facet_grid(station + block ~ horizon_h, labeller = label_both) +
    scale_fill_manual(values = sh_palette) + coord_flip() + sh_theme() +
    labs(title = "PM2.5 MASE by architecture (LightGBM, seed mean)", x = NULL, y = "MASE (train seasonal-naive scale)",
         fill = NULL)
  save(p, "level_mase_by_arch.png", 13, 11)

  a0 <- d[arch == "A0", .(station, horizon_h, block, MAE0 = MAE)]
  r <- merge(d, a0, by = c("station", "horizon_h", "block"))[, ratio := MAE / MAE0]
  p <- ggplot(r[group != "reference"], aes(factor(horizon_h), arch, fill = log2(ratio))) +
    geom_tile(colour = "white", linewidth = 0.6) +
    geom_text(aes(label = sprintf("%.2f", ratio)), size = 3) +
    facet_grid(block ~ station) +
    scale_fill_gradient2(low = "#2a78d6", mid = "#f2f3f5", high = "#d64545", midpoint = 0,
                         limits = c(-0.6, 0.6), oob = scales::squish, name = "log2 MAE / A0") +
    sh_theme() + labs(title = "PM2.5 MAE relative to A0 (below 1 = better than raw univariate)",
                      x = "horizon (h)", y = NULL)
  save(p, "ratio_vs_A0_heatmap.png", 11, 8)

  pp <- pairs[block == "test" | block == "validation"]
  pp[, label := paste0(a, " vs ", b)]
  p <- ggplot(pp, aes(mae_ratio, label, colour = block)) +
    geom_vline(xintercept = 1, colour = "#7d8590", linetype = 2) +
    geom_pointrange(aes(xmin = mae_ratio_lo, xmax = mae_ratio_hi), position = position_dodge(width = 0.6),
                    size = 0.25) +
    facet_grid(station ~ horizon_h, labeller = label_both) +
    scale_colour_manual(values = c(validation = "#7d8590", test = "#eb6834")) +
    sh_theme() + labs(title = "Paired MAE ratios a / b with 95% block-bootstrap intervals (PM2.5, LightGBM)",
                      x = "MAE ratio (below 1 = a better)", y = NULL, colour = NULL)
  save(p, "paired_ratios.png", 14, 11)

  cd <- comp[family == "lightgbm" & target == cfg$primary_target & block == "test" &
               arch %in% c("B0", "B1", "C1_sep", "C1_sh", "C2_sep", "C2_sh")]
  p <- ggplot(cd, aes(component, MASE, colour = arch, group = arch)) +
    geom_line(linewidth = 0.6) + geom_point(size = 1.6) +
    facet_grid(station ~ horizon_h, labeller = label_both, scales = "free_y") +
    sh_theme() + labs(title = "Component-level test MASE (component's own train seasonal-naive scale)",
                      x = NULL, y = "MASE", colour = NULL)
  save(p, "component_mase.png", 13, 7)

  bh <- d[group != "reference"][, .(MAE = min(MAE)), by = .(station, block, horizon_h, group)]
  rf <- d[arch %in% c("persistence", "climatology"), .(station, block, horizon_h, group = as.character(arch), MAE)]
  p <- ggplot(rbind(bh, rf), aes(horizon_h, MAE, colour = group)) +
    geom_line(linewidth = 0.7) + geom_point(size = 2) + facet_grid(block ~ station, scales = "free_y") +
    scale_x_continuous(breaks = c(24, 168, 336, 744), trans = "log2") +
    scale_colour_manual(values = c(sh_palette, persistence = "#9a6fd1", climatology = "#7d8590")) +
    sh_theme() + labs(title = "Best architecture of each kind by horizon (PM2.5, LightGBM)",
                      subtitle = "Lowest MAE within each kind on that block; references for scale",
                      x = "horizon (h)", y = "MAE (ug/m3)", colour = NULL)
  save(p, "best_by_horizon.png", 11, 7)
}
