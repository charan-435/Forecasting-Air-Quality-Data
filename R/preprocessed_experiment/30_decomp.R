# Phase 2: trailing Haar MRA J5 (mra_haar_J5__raw) of the cleaned CPCB pollutants.
# Same engine and settings as kaisen run_decomp() (run_trailing_series + decomp_mra_haar,
# window_h / J / filter / pad from config/decomp.yaml). This wrapper exists only so the
# checkpoint, parquet and manifest go to the experiment store, not store/decomp/.

pe_decomp_entry <- function(cfg) {
  dc <- decomp_cfg()
  entry <- Filter(function(e) identical(e$id, cfg$decomposition$method_id), dc$methods)[[1]]
  entry$params$window_h <- as.integer(entry$params$window_h %||% dc$window_h)
  entry
}

pe_decomp_path <- function(cfg, dataset, variable) {
  mid <- method_full_id(cfg$decomposition$method_id, cfg$decomposition$scale)
  file.path(pe_dir(cfg, "store", "decomp", dataset, paste0("method=", mid),
                   paste0("station=", cfg$station)),
            paste0("variable=", variable, ".parquet"))
}

# dataset: "clean" (this experiment's store) or "unmasked" (kaisen store values as-is).
pe_decomp_input <- function(cfg, dataset) {
  if (identical(dataset, "clean")) {
    x <- arrow::read_parquet(file.path(pe_dir(cfg, "store", "clean"), "series.parquet"))
  } else {
    x <- pe_load_source(cfg)
  }
  x <- x[x$variable %in% cfg$pollutants, ]
  x[order(x$variable, x$timestamp), ]
}

pe_decompose_one <- function(cfg, sv, entry) {
  W <- entry$params$window_h
  pad <- as.integer(entry$params$pad %||% 0L)
  x <- apply_decomp_scale(sv$value_filled_causal, cfg$decomposition$scale, sv$variable[1])
  ckpt <- file.path(pe_dir(cfg, "store", "decomp", "_ckpt"), paste0(sv$variable[1], ".rds"))
  .GlobalEnv$.DECOMP_CKPT_PATH <- ckpt
  on.exit({ .GlobalEnv$.DECOMP_CKPT_PATH <- NULL }, add = TRUE)
  M <- run_trailing_series(x, decomp_mra_haar, entry$params, W, pad,
                           station = cfg$station, variable = sv$variable[1])
  df <- tibble::as_tibble(M)
  comps <- colnames(M)
  df$timestamp <- sv$timestamp
  # Warm only when the whole trailing window has model inputs (the leading
  # no-history hours of the cleaned series stay NA and are never decomposed).
  bad <- c(0, cumsum(!is.finite(x)))
  idx <- seq_len(nrow(df))
  lo <- pmax(idx - W, 0L)
  df$valid_warmup <- idx >= W & (bad[idx + 1L] - bad[lo + 1L]) == 0
  M[!df$valid_warmup, ] <- NA_real_
  df[comps] <- as.data.frame(M)
  is_filled <- !is.na(sv$fill_method)
  df$frac_filled_window <- .frac_filled_support(is_filled, W)
  df$frac_filled_window[!df$valid_warmup] <- NA_real_
  df$input <- x
  df$resid <- x - rowSums(as.matrix(df[, comps]))
  pol <- decomp_policy()
  frac24 <- sv$frac_filled_24h; frac24[is.na(frac24)] <- 0
  in_long <- as.logical(sv$in_long_gap); in_long[is.na(in_long)] <- FALSE
  df$valid_basic <- df$valid_warmup
  df$valid_strict <- df$valid_warmup &
    frac24 <= as.numeric(pol$exclude_training_row_if_frac_filled_24h_gt %||% 0.5) & !in_long
  df
}

pe_decompose <- function(cfg, datasets = c("clean", "unmasked")) {
  entry <- pe_decomp_entry(cfg)
  mid <- method_full_id(entry$id, cfg$decomposition$scale)
  out <- pe_dir(cfg, "results", "decomposition")
  diag <- list()
  for (ds in datasets) {
    inp <- pe_decomp_input(cfg, ds)
    t0 <- proc.time()[3]
    done <- list()
    for (v in cfg$pollutants) {
      sv <- inp[inp$variable == v, ]
      df <- pe_decompose_one(cfg, sv, entry)
      path <- pe_decomp_path(cfg, ds, v)
      write_decomp_parquet(df, path)
      comps <- decomp_component_names(entry, df)
      ok <- df$valid_warmup
      energy <- colSums(as.matrix(df[ok, comps])^2)
      diag[[length(diag) + 1L]] <- data.frame(
        dataset = ds, variable = v, rows = nrow(df), warmup_rows = sum(!ok),
        first_valid = format(min(df$timestamp[ok])), valid_rows = sum(ok),
        valid_strict_rows = sum(df$valid_strict),
        max_abs_additivity_error = max(abs(df$resid[ok])),
        components = paste(comps, collapse = ","),
        t(setNames(round(energy / sum(energy), 4), paste0("energy_share_", comps))),
        check.names = FALSE)
      done[[v]] <- list(variable = v, path = sub(paste0(PROJECT_ROOT, "/"), "", path, fixed = TRUE),
                        sha256 = digest::digest(file = path, algo = "sha256"))
      pe_log(cfg, "decomp ", ds, " ", v, ": max additivity error ",
             signif(max(abs(df$resid[ok])), 3))
    }
    man <- list(method_id = entry$id, scale = cfg$decomposition$scale, method_full = mid,
                family = entry$family, additive = isTRUE(entry$additive), causal = TRUE,
                params = entry$params, warmup_rule = entry$warmup_rule,
                component_names = decomp_component_names(entry), dataset = ds,
                input = if (ds == "clean") file.path(cfg$paths$store, "clean", "series.parquet")
                        else cfg$source$series,
                input_column = "value_filled_causal", files = unname(done),
                runtime_sec = as.numeric(proc.time()[3] - t0),
                provenance = pe_provenance(cfg, paste0("decompose_", ds)))
    pe_write_json(man, file.path(pe_dir(cfg, "store", "decomp", ds), "manifest.json"))
  }
  diag <- dplyr::bind_rows(diag)
  pe_write_csv(diag, file.path(out, "additivity_warmup.csv"))
  pe_decomp_plots(cfg, entry, datasets)
  invisible(diag)
}

pe_read_decomp <- function(cfg, dataset, variable) {
  df <- arrow::read_parquet(pe_decomp_path(cfg, dataset, variable))
  df$timestamp <- lubridate::with_tz(df$timestamp, cfg$tz)
  df
}

pe_decomp_plots <- function(cfg, entry, datasets) {
  pdir <- pe_dir(cfg, "results", "decomposition", "plots")
  comps <- decomp_component_names(entry)
  cl <- pe_read_decomp(cfg, "clean", cfg$target)
  win <- cl$timestamp >= pe_time("2023-01-13 00:00", cfg) & cl$timestamp < pe_time("2023-02-10 00:00", cfg)
  d <- tidyr::pivot_longer(cl[win, c("timestamp", "input", comps)], -timestamp,
                           names_to = "component", values_to = "value")
  d$component <- factor(d$component, levels = c("input", comps))
  g <- ggplot2::ggplot(d, ggplot2::aes(timestamp, value)) + ggplot2::geom_line(linewidth = 0.3) +
    ggplot2::facet_wrap(~component, ncol = 1, scales = "free_y") +
    ggplot2::labs(title = sprintf("Cleaned CPCB %s and its trailing %s components (4 weeks)",
                                  cfg$target, method_full_id(entry$id, cfg$decomposition$scale)),
                  x = NULL, y = NULL) + ggplot2::theme_minimal(base_size = 9)
  ggplot2::ggsave(file.path(pdir, "components_clean_pm25.png"), g, width = 10, height = 9, dpi = 120)
  ok <- cl$valid_warmup
  g2 <- ggplot2::ggplot(cl[ok, ], ggplot2::aes(timestamp, resid)) + ggplot2::geom_line(linewidth = 0.3) +
    ggplot2::labs(title = "Additivity: input minus sum of components (cleaned PM2.5, after warm-up)",
                  x = NULL, y = "residual") + ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(pdir, "additivity_resid_pm25.png"), g2, width = 9, height = 3, dpi = 120)
  if ("unmasked" %in% datasets) {
    um <- pe_read_decomp(cfg, "unmasked", cfg$target)
    dd <- data.frame(timestamp = cl$timestamp[ok],
                     do.call(cbind, lapply(comps, function(cn) setNames(
                       data.frame(cl[[cn]][ok] - um[[cn]][ok]), cn))))
    dl <- tidyr::pivot_longer(dd, -timestamp, names_to = "component", values_to = "diff")
    dl$component <- factor(dl$component, levels = comps)
    g3 <- ggplot2::ggplot(dl, ggplot2::aes(timestamp, diff)) + ggplot2::geom_line(linewidth = 0.25) +
      ggplot2::facet_wrap(~component, ncol = 1, scales = "free_y") +
      ggplot2::labs(title = "Cleaned minus unmasked PM2.5 components (non-zero = the original decomposition does not describe the cleaned series)",
                    x = NULL, y = NULL) + ggplot2::theme_minimal(base_size = 9)
    ggplot2::ggsave(file.path(pdir, "components_clean_minus_unmasked_pm25.png"), g3,
                    width = 10, height = 8, dpi = 120)
    cmp <- do.call(rbind, lapply(comps, function(cn) data.frame(
      component = cn, rows = sum(ok), rows_differing = sum(abs(cl[[cn]][ok] - um[[cn]][ok]) > 1e-9),
      mean_abs_diff = mean(abs(cl[[cn]][ok] - um[[cn]][ok])), max_abs_diff = max(abs(cl[[cn]][ok] - um[[cn]][ok])))))
    pe_write_csv(cmp, file.path(pe_dir(cfg, "results", "decomposition"), "clean_vs_unmasked_pm25.csv"))
  }
  invisible(TRUE)
}
