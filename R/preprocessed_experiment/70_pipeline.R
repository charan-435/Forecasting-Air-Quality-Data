# Smoke fits run in phase 3; full fitting and evaluation both run in phase 4.

pe_arch_doc <- function(cfg) {
  list(
    B0 = list(decomposition = TRUE, structure = "six separate models",
              inputs = "own PM2.5 component, 24 lags"),
    A1 = list(decomposition = FALSE, structure = "one PM2.5 model",
              inputs = "PM2.5 24 lags + PM10, NO2, SO2, O3, CO at the origin"),
    B1 = list(decomposition = TRUE, structure = "one shared model",
              inputs = "own component 24 lags + component identity (categorical)",
              weighting = cfg$architectures$shared_weighting),
    B2 = list(decomposition = TRUE, structure = "six separate models",
              inputs = "own component 24 lags + other pollutants' components at the origin",
              covariate_sets = cfg$architectures$covariate_sets),
    B3 = list(decomposition = TRUE, structure = "one shared model",
              inputs = "own component 24 lags + component identity + other pollutants' components at the origin",
              covariate_sets = cfg$architectures$covariate_sets,
              weighting = cfg$architectures$shared_weighting))
}

pe_arch_dir <- function(cfg, arch, dataset) {
  if (dataset == "clean") pe_dir(cfg, "results", arch) else pe_dir(cfg, "results", arch, "unmasked_control")
}

pe_save_arch <- function(cfg, md, res) {
  d <- pe_arch_dir(cfg, res$arch, md$dataset)
  saveRDS(res, file.path(d, "result.rds"))
  pe_write_csv(res$tuning, file.path(d, "tuning.csv"))
  pe_write_json(res$selected, file.path(d, "selected.json"))
  pe_write_csv(res$val, file.path(d, "predictions_val.csv"))
  pe_write_csv(res$test, file.path(d, "predictions_test.csv"))
  pe_write_json(c(pe_arch_doc(cfg)[[res$arch]],
                  list(dataset = md$dataset, horizon_h = md$h, n_lags = cfg$forecast$n_lags,
                       grid = cfg$lightgbm$grid, base_params = cfg$lightgbm,
                       n_fit_train = length(res$sets$fit_train), n_fit_val = length(res$sets$fit_val),
                       n_eval_val = length(res$sets$eval_val), n_eval_test = length(res$sets$eval_test))),
                file.path(d, "architecture.json"))
}

pe_smoke <- function(cfg) {
  md <- pe_model_data(cfg, "clean")
  out <- pe_dir(cfg, "results", "smoke")
  rows <- list(); res <- list()
  for (a in unlist(cfg$architectures$run)) {
    t0 <- proc.time()[3]
    r <- pe_run_arch(md, a, smoke = TRUE)
    res[[a]] <- r
    feat <- if (a %in% c("B1", "B3")) {
      x <- pe_xy_shared(md, a, utils::head(md$sets$fit_train, 3), pe_scalers(md, max(md$train_hours)),
                        cov_set = "same_level")
      colnames(x$X)
    } else {
      colnames(pe_xy_single(md, a, utils::head(md$sets$fit_train, 3), pe_scalers(md, max(md$train_hours)),
                            comp = if (a == "A1") NULL else "D1", cov_set = "same_level")$X)
    }
    rows[[a]] <- data.frame(arch = a, n_features = length(feat),
                            features = paste(feat, collapse = " "),
                            n_fit_train = length(r$sets$fit_train), n_eval_val = nrow(r$val),
                            n_eval_test = nrow(r$test), val_MAE = mean(abs(r$val$predicted - r$val$actual)),
                            first_test_target = format(min(r$test$target_time)),
                            seconds = round(proc.time()[3] - t0, 1))
  }
  tab <- dplyr::bind_rows(rows)
  pe_write_csv(tab, file.path(out, "smoke_summary.csv"))
  same_t <- all(vapply(res, function(r) identical(r$test$target_time, res[[1]]$test$target_time), logical(1)))
  pe_log(cfg, "smoke: identical test targets across architectures: ", same_t)
  list(table = tab, res = res, md = md)
}

pe_full <- function(cfg) {
  for (ds in unlist(cfg$architectures$datasets)) {
    md <- pe_model_data(cfg, ds)
    for (a in unlist(cfg$architectures$run)) {
      t0 <- proc.time()[3]
      res <- pe_run_arch(md, a)
      pe_save_arch(cfg, md, res)
      pe_log(cfg, sprintf("full %s %s: val MAE %.3f, test MAE %.3f, %.0f s", ds, a,
                          mean(abs(res$val$predicted - res$val$actual)),
                          mean(abs(res$test$predicted - res$test$actual)), proc.time()[3] - t0))
    }
  }
  invisible(TRUE)
}

pe_load_results <- function(cfg) {
  out <- list()
  for (ds in unlist(cfg$architectures$datasets)) for (a in unlist(cfg$architectures$run)) {
    out[[paste(ds, a)]] <- readRDS(file.path(pe_arch_dir(cfg, a, ds), "result.rds"))
  }
  out
}

pe_evaluate <- function(cfg) {
  # Every paired comparison below needs exactly the same ordered test targets.
  # Compare reconstructed pollutant forecasts, not a sum of component error scores.
  cmp <- pe_dir(cfg, "results", "comparisons")
  res <- pe_load_results(cfg)
  mds <- lapply(setNames(unlist(cfg$architectures$datasets), unlist(cfg$architectures$datasets)),
                function(ds) pe_model_data(cfg, ds))
  md <- mds$clean
  season <- as.integer(cfg$forecast$season)
  scale <- pe_mase_scale(md$truth, md$train_hours, season)
  tgt <- cfg$target
  ref_t <- res[["clean B0"]]$test$target_time
  stopifnot(all(vapply(res, function(r) identical(r$test$target_time, ref_t), logical(1))))

  # Pollutant level: architectures and baselines, validation and test
  pol <- list()
  for (k in names(res)) for (blk in c("val", "test")) {
    r <- res[[k]]
    pol[[length(pol) + 1L]] <- data.frame(dataset = r$dataset, model = r$arch, block = blk,
                                          pe_metrics(r[[blk]]$predicted, r[[blk]]$actual, scale))
  }
  for (ds in names(mds)) for (blk in c("val", "test")) {
    b <- pe_baselines(mds[[ds]], blk)
    for (m in c("persistence", "train_mean", "hour_of_day")) {
      pol[[length(pol) + 1L]] <- data.frame(dataset = ds, model = paste0("baseline:", m), block = blk,
                                            pe_metrics(b[[m]], b$actual, scale))
    }
    if (ds == "clean" && blk == "test") pe_write_csv(b, file.path(cmp, "baseline_predictions_test.csv"))
  }
  pol <- dplyr::bind_rows(pol)
  pol$MASE_scale <- scale
  pe_write_csv(pol, file.path(cmp, "metrics_pollutant_level.csv"))

  # Component level (decomposed architectures)
  comp <- list()
  for (k in names(res)) {
    r <- res[[k]]
    if (r$arch == "A1") next
    for (cc in PE_COMPS) {
      cs <- pe_mase_scale(mds[[r$dataset]]$comps[[tgt]][, cc], md$train_hours[mds[[r$dataset]]$warm[md$train_hours]], season)
      for (blk in c("val", "test")) {
        comp[[length(comp) + 1L]] <- data.frame(
          dataset = r$dataset, model = r$arch, block = blk, component = cc,
          pe_metrics(r[[blk]][[paste0("pred_", cc)]], r[[blk]][[paste0("actual_", cc)]], cs),
          MASE_scale = cs)
      }
    }
  }
  comp <- dplyr::bind_rows(comp)
  pe_write_csv(comp, file.path(cmp, "metrics_component_level.csv"))
  recon_ok <- vapply(res[grepl("^clean B", names(res))], function(r)
    max(abs(rowSums(r$test[, paste0("actual_", PE_COMPS)]) - r$test$actual)), numeric(1))

  # Paired comparisons on identical targets
  err <- function(k, blk) res[[k]][[blk]]$predicted - res[[k]][[blk]]$actual
  val_mae <- vapply(c("B0", "B1", "B2", "B3"), function(a)
    mean(abs(err(paste("clean", a), "val"))), numeric(1))
  best_dec <- names(which.min(val_mae))
  pairs <- list(c("A1", "B0"), c("B1", "B0"), c("B2", "B0"), c("B3", "B1"), c("B3", "B2"),
                c(best_dec, "A1"))
  pr <- list()
  for (blk in c("val", "test")) {
    for (p in pairs) {
      pr[[length(pr) + 1L]] <- pe_paired(err(paste("clean", p[1]), blk), err(paste("clean", p[2]), blk),
                                         scale, cfg, p[1], p[2], blk)
    }
    bl <- pe_baselines(md, blk)
    for (a in unlist(cfg$architectures$run)) {
      pr[[length(pr) + 1L]] <- pe_paired(err(paste("clean", a), blk), bl$persistence - bl$actual,
                                         scale, cfg, a, "persistence", blk)
    }
    if ("unmasked" %in% names(mds)) for (a in unlist(cfg$architectures$run)) {
      pr[[length(pr) + 1L]] <- pe_paired(err(paste("clean", a), blk), err(paste("unmasked", a), blk),
                                         scale, cfg, paste0(a, " clean"), paste0(a, " unmasked"), blk)
    }
  }
  pr <- dplyr::bind_rows(pr)
  pe_write_csv(pr, file.path(cmp, "paired_comparisons.csv"))
  pe_write_json(list(best_decomposed_by_validation = best_dec, validation_MAE = as.list(val_mae),
                     reconstruction_check_max_abs = as.list(recon_ok), MASE_scale_train = scale,
                     n_test = length(ref_t), n_val = nrow(res[["clean B0"]]$val)),
                file.path(cmp, "selection_and_checks.json"))

  # Existing kaisen CPCB PM2.5 1-day scores, context only (different protocol)
  sc_path <- file.path(PROJECT_ROOT, "results", "scores.csv")
  if (file.exists(sc_path)) {
    ks <- utils::read.csv(sc_path, check.names = FALSE)
    ks <- ks[ks$sensor == "CPCB" & ks$pollutant == tgt & ks$horizon == "1d", ]
    pe_write_csv(ks, file.path(cmp, "kaisen_existing_scores_context.csv"))
  }
  pe_plots(cfg, res, pol, comp, pr)
  pe_write_json(c(pe_provenance(cfg, "full+evaluate"),
                  list(datasets = cfg$architectures$datasets, architectures = cfg$architectures$run,
                       lightgbm = cfg$lightgbm, comparison = cfg$comparison,
                       clean_store_sha256 = digest::digest(file = file.path(pe_dir(cfg, "store", "clean"),
                                                                            "series.parquet"), algo = "sha256"))),
                file.path(pe_dir(cfg, "results"), "provenance_models.json"))
  invisible(list(pol = pol, comp = comp, pairs = pr, best = best_dec))
}

pe_plots <- function(cfg, res, pol, comp, pr) {
  pdir <- pe_dir(cfg, "results", "plots")
  archs <- unlist(cfg$architectures$run)
  d <- pol[pol$block == "test", ]
  d$model <- factor(d$model, levels = c(archs, paste0("baseline:", c("persistence", "hour_of_day", "train_mean"))))
  g <- ggplot2::ggplot(d, ggplot2::aes(model, MAE, fill = dataset)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(0.8), width = 0.75) +
    ggplot2::labs(title = "Test PM2.5 MAE by architecture (h = 24 h)",
                  subtitle = "clean = cleaned data; unmasked = same code trained on the original series; same test targets",
                  x = NULL, y = "MAE (PM2.5 units)") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
  ggplot2::ggsave(file.path(pdir, "test_mae_by_architecture.png"), g, width = 9, height = 4.5, dpi = 120)

  cd <- comp[comp$dataset == "clean" & comp$block == "test", ]
  cd$component <- factor(cd$component, levels = PE_COMPS)
  g2 <- ggplot2::ggplot(cd, ggplot2::aes(component, MAE, fill = model)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(0.8), width = 0.75) +
    ggplot2::labs(title = "Test component MAE (cleaned data)", x = NULL, y = "MAE") +
    ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(pdir, "test_component_mae.png"), g2, width = 8, height = 4, dpi = 120)

  p <- pr[pr$block == "test" & !grepl("persistence", pr$B), ]
  p$pair <- factor(paste(p$A, "vs", p$B), levels = rev(unique(paste(p$A, "vs", p$B))))
  g3 <- ggplot2::ggplot(p, ggplot2::aes(MAE_diff, pair)) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey50") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = MAE_diff_lo, xmax = MAE_diff_hi), width = 0.25,
                           orientation = "y") +
    ggplot2::geom_point(size = 2) +
    ggplot2::labs(title = "Paired test MAE difference (A - B), 95% moving-block bootstrap CI",
                  subtitle = "left of 0 = A better", x = "MAE difference (PM2.5 units)", y = NULL) +
    ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(pdir, "paired_differences_test.png"), g3, width = 8, height = 4.5, dpi = 120)

  ts <- res[["clean B0"]]$test[, c("target_time", "actual")]
  for (a in archs) ts[[a]] <- res[[paste("clean", a)]]$test$predicted
  ts <- ts[ts$target_time < min(ts$target_time) + 14 * 86400, ]
  tl <- tidyr::pivot_longer(ts, -target_time, names_to = "series", values_to = "value")
  g4 <- ggplot2::ggplot(tl, ggplot2::aes(target_time, value, colour = series)) +
    ggplot2::geom_point(size = 0.5) + ggplot2::geom_line(linewidth = 0.3, alpha = 0.7) +
    ggplot2::labs(title = "Test forecasts (first 14 days of test targets; gaps = unscored hours)",
                  x = NULL, y = "PM2.5") + ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(pdir, "test_forecasts_window.png"), g4, width = 11, height = 4.5, dpi = 120)

  vt <- tidyr::pivot_wider(pol[pol$dataset == "clean", c("model", "block", "MAE")],
                           names_from = "block", values_from = "MAE")
  g5 <- ggplot2::ggplot(vt, ggplot2::aes(val, test, label = model)) + ggplot2::geom_point() +
    ggplot2::geom_text(nudge_y = 0.08, size = 3) +
    ggplot2::labs(title = "Validation vs test MAE (cleaned data)", x = "validation MAE", y = "test MAE") +
    ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(pdir, "validation_vs_test.png"), g5, width = 6, height = 5, dpi = 120)
  invisible(TRUE)
}
