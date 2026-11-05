# Presentation of saved Shillong metrics. This file does not fit forecasting models.
make_shillong_extension_plots <- function(directory = "results/shillong/architecture") {
  metrics <- read.csv(file.path(directory, "LEVEL_METRICS.csv")) %>%
    dplyr::filter(station == "Lumpyngngad", target == "PM2.5", component == "LEVEL")
  paired <- read.csv(file.path(directory, "PAIRED_COMPARISONS.csv")) %>%
    dplyr::filter(station == "Lumpyngngad", target == "PM2.5", block == "test")
  horizons <- c(24L, 168L, 336L, 744L)
  horizon_labels <- paste(horizons, "h")
  families <- c(catboost = "CatBoost", lightgbm = "LightGBM", xgboost = "XGBoost")
  common_designs <- c("A0", "A3", "B0", "C3_sh")
  test_metrics <- metrics %>% dplyr::filter(block == "test")
  selected <- metrics %>%
    dplyr::filter(block == "validation", family %in% names(families), arch %in% common_designs) %>%
    dplyr::group_by(family, horizon_h) %>%
    dplyr::arrange(MAE, arch, .by_group = TRUE) %>%
    dplyr::slice_head(n = 1L) %>%
    dplyr::ungroup() %>%
    dplyr::select(family, horizon_h, arch) %>%
    dplyr::left_join(test_metrics %>% dplyr::select(family, horizon_h, arch, MAE),
                     by = c("family", "horizon_h", "arch")) %>%
    dplyr::mutate(horizon = factor(horizon_h, levels = horizons, labels = horizon_labels),
                  model = factor(family, levels = names(families), labels = unname(families)))

  dodge <- ggplot2::position_dodge(width = 0.84)
  boosting <- ggplot2::ggplot(selected, ggplot2::aes(horizon, MAE, fill = model)) +
    ggplot2::geom_col(position = dodge, width = 0.78) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", MAE)),
                       position = dodge, vjust = -0.4, size = 3.5) +
    ggplot2::geom_text(ggplot2::aes(y = 0.6, label = arch), position = dodge,
                       colour = "white", size = 3.2) +
    ggplot2::scale_fill_manual(values = c(CatBoost = "#2D7DD2", LightGBM = "#ED6A32",
                                          XGBoost = "#1AAD7A")) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.12))) +
    ggplot2::labs(title = "Inter-boosting model comparison",
                   subtitle = "Design selected on validation, then scored on test. Same four candidate designs for each model.",
                   x = "Forecast horizon", y = "Test MAE (ug/m3)", fill = NULL) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "top", panel.grid.major.x = ggplot2::element_blank())

  architecture_order <- c("A0", "A1", "A2", "A3", "B0", "B1", "B2", "B3",
                          "C1_sep", "C1_sh", "C2_sep", "C2_sh", "C3_sep", "C3_sh")
  architecture <- test_metrics %>%
    dplyr::filter(family == "lightgbm", arch %in% architecture_order) %>%
    dplyr::select(arch, horizon_h, MAE)
  persistence <- test_metrics %>%
    dplyr::filter(family == "reference", arch == "persistence") %>%
    dplyr::select(arch, horizon_h, MAE)
  descriptions <- c(A0 = "PM2.5 lags", A1 = "+ weather", A2 = "+ SO2 and CO lags",
                    A3 = "+ SO2, CO and weather", B0 = "own bands, separate",
                    B1 = "own bands, shared", B2 = "+ weather, separate", B3 = "+ weather, shared",
                    C1_sep = "all PM2.5 bands, separate", C1_sh = "all PM2.5 bands, shared",
                    C2_sep = "bands of three pollutants, separate", C2_sh = "bands of three pollutants, shared",
                    C3_sep = "C2 + weather, separate", C3_sh = "C2 + weather, shared",
                    persistence = "Persistence (reference)")

  ratio_plot <- function(designs, reference, title, show_mae = TRUE, group_rows = FALSE) {
    reference_values <- architecture %>%
      dplyr::filter(arch == reference) %>%
      dplyr::select(horizon_h, reference_MAE = MAE)
    # A reverse paired comparison has the same significance decision.
    significance <- paired %>%
      dplyr::filter(a == reference | b == reference) %>%
      dplyr::mutate(arch = ifelse(b == reference, a, b),
                    significant = mae_ratio_hi < 1 | mae_ratio_lo > 1) %>%
      dplyr::group_by(arch, horizon_h) %>%
      dplyr::summarise(significant = any(significant), .groups = "drop")
    cells <- dplyr::bind_rows(architecture, persistence) %>%
      dplyr::filter(arch %in% designs) %>%
      dplyr::left_join(reference_values, by = "horizon_h") %>%
      dplyr::left_join(significance, by = c("arch", "horizon_h")) %>%
      dplyr::mutate(ratio = MAE / reference_MAE,
                    horizon = factor(horizon_h, levels = horizons, labels = horizon_labels),
                    design = factor(arch, levels = rev(designs)),
                    label = ifelse(arch == reference, "reference",
                                   paste0(sprintf("%.2f", ratio),
                                          ifelse(!is.na(significant) & significant, "*", ""))))
    if (show_mae) cells$label <- paste0(cells$label, "\nMAE ", sprintf("%.2f", cells$MAE))
    cells <- cells %>%
      dplyr::group_by(horizon_h) %>%
      dplyr::mutate(fontface = ifelse(abs(ratio - min(ratio)) < 1e-10, "bold", "plain")) %>%
      dplyr::ungroup()
    labels <- stats::setNames(ifelse(designs == "persistence", "Persistence (reference)",
                                      paste0(designs, "  ", unname(descriptions[designs]))), designs)
    plot <- ggplot2::ggplot(cells, ggplot2::aes(horizon, design, fill = ratio)) +
      ggplot2::geom_tile(colour = "white", linewidth = 1.2, width = 0.96, height = 0.94) +
      ggplot2::geom_text(ggplot2::aes(label = label, fontface = fontface), size = 3.6, lineheight = 1.15) +
      ggplot2::scale_fill_gradient2(low = "#64A1D8", mid = "#F0F0ED", high = "#E57878",
                                     midpoint = 1, limits = c(0.63, 1.6), oob = scales::squish,
                                     name = paste0("MAE / ", reference)) +
      ggplot2::scale_y_discrete(labels = labels) +
      ggplot2::scale_x_discrete(position = "top", drop = FALSE) +
      ggplot2::labs(title = title,
                     subtitle = paste0("LightGBM, PM2.5 test, Lumpyngngad. Below 1 means lower error than ", reference, "."),
                     x = NULL, y = NULL,
                     caption = "* Saved paired-bootstrap comparison excludes 1 at 95%. Unmarked cells may have no saved comparison.") +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(panel.grid = ggplot2::element_blank(), legend.position = "bottom",
                      axis.text.y = ggplot2::element_text(colour = "#333333"),
                      plot.caption = ggplot2::element_text(hjust = 0, size = 9))
    if (group_rows) {
      cells$group <- factor(ifelse(grepl("^A", cells$arch), "Raw lags",
                                    ifelse(grepl("^B", cells$arch), "Own bands", "Cross-band inputs")),
                              levels = c("Raw lags", "Own bands", "Cross-band inputs"))
      plot$data <- cells
      plot <- plot + ggplot2::facet_grid(group ~ ., scales = "free_y", space = "free_y")
    }
    plot
  }

  means <- architecture %>%
    dplyr::group_by(arch) %>%
    dplyr::summarise(MAE = mean(MAE), .groups = "drop") %>%
    dplyr::arrange(MAE) %>%
    dplyr::mutate(arch = factor(arch, levels = arch))
  architecture_bars <- ggplot2::ggplot(means, ggplot2::aes(arch, MAE)) +
    ggplot2::geom_col(fill = "#2D5A96", width = 0.72) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", MAE)), vjust = -0.4, size = 3) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.12))) +
    ggplot2::labs(title = "Architecture comparison",
                   subtitle = "LightGBM mean test MAE across 24, 168, 336 and 744 hours. Lower is better.",
                   x = "Architecture", y = "Mean test MAE (ug/m3)") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
                    panel.grid.major.x = ggplot2::element_blank())

  list(boosting = boosting,
       all_architectures = ratio_plot(architecture_order, "A0", "Architecture errors relative to A0",
                                       show_mae = FALSE, group_rows = TRUE),
       band_models = ratio_plot(c("B0", "B1", "B2", "B3", "persistence"), "B0",
                                  "Decomposed PM2.5 designs relative to B0"),
       cross_band = ratio_plot(c("C1_sh", "C1_sep", "C2_sep", "C2_sh", "C3_sep", "C3_sh", "persistence"),
                                "C1_sh", "Cross-band designs relative to C1_sh"),
       architecture = architecture_bars)
}
