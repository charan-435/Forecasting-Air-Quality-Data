# Regenerate architecture comparisons from the saved validation/test tables.
# Run from the repository root: Rscript code/figures/make_shillong_figures.R
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))
source("code/figures/shillong_plots.R")
plots <- make_shillong_extension_plots("results/shillong/architecture")
output_dir <- file.path(Sys.getenv("ATS_FIGURE_DIR", "results/figures"), "shillong_arch")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
for (name in names(plots)) {
  height <- if (name == "all_architectures") 8 else 5
  ggsave(file.path(output_dir, paste0(name, ".png")), plots[[name]],
         width = 11, height = height, dpi = 150)
}
message("Wrote ", length(plots), " architecture plots to ", output_dir)
