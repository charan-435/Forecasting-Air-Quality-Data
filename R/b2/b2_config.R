# B2 configuration — CPCB UNMASKED decomposed multivariate forecasting.
# Does not modify T1, stored decomps, or B1.

B2_SENSOR <- "CPCB"
B2_TARGET_POLLUTANT <- "PM2.5"
B2_POLLUTANTS <- c("PM2.5", "PM10", "NO2", "SO2", "O3", "CO")
B2_COMPONENTS <- c("D1", "D2", "D3", "D4", "D5", "S5")
B2_METHOD_ID <- "mra_haar_J5"
B2_SCALE <- "raw"
B2_DECOMP_ID <- "mra_haar_J5__raw"
B2_VALIDITY <- "basic"
B2_LABEL <- "UNMASKED"
B2_P <- 24L
B2_N_FEATURES <- length(B2_POLLUTANTS) * length(B2_COMPONENTS) * B2_P  # 864
B2_SEED <- 7L
B2_SPLIT_ID <- "chrono_split_tvt"
B2_FORECAST_STRATEGY <- "direct_fixed_horizon"

# T1 architecture map used only as univariate reference family labels.
B2_T1_MAP <- c(
  D1 = "lgb", D2 = "lgb", D3 = "dlinear",
  D4 = "catboost", D5 = "sarima", S5 = "dlinear"
)

b2_out_dir <- function() file.path(RES_DIR, "b2")
b2_plot_dir <- function() file.path(b2_out_dir(), "plots")
b2_table_dir <- function() file.path(b2_out_dir(), "tables")
b2_cache_dir <- function() file.path(b2_out_dir(), "_cache")

b2_dir_create <- function() {
  for (d in c(b2_out_dir(), b2_plot_dir(), b2_table_dir(), b2_cache_dir())) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
  b2_out_dir()
}

b2_assert <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  allowed <- normalizePath(b2_out_dir(), winslash = "/", mustWork = FALSE)
  if (!startsWith(tolower(path), tolower(allowed))) {
    stop("B2 may only write under results/b2/. Refused: ", path)
  }
  invisible(path)
}

b2_feature_names <- function(p = B2_P) {
  as.character(unlist(lapply(B2_POLLUTANTS, function(pol) {
    lapply(B2_COMPONENTS, function(comp) {
      paste0(pol, "__", comp, "__lag", seq_len(p))
    })
  })))
}

b2_default_lgb_params <- function() {
  hp <- if (exists("t1_load_tree_params")) t1_load_tree_params()$params else default_tree_params()
  list(
    p = B2_P,
    nrounds = as.integer(hp$nrounds %||% 160L),
    max_depth = as.integer(hp$max_depth %||% 6L),
    eta = as.numeric(hp$eta %||% 0.05),
    early_stopping = as.integer(hp$early_stopping %||% 30L),
    val_hours = as.integer(hp$val_hours %||% VAL_HOURS),
    lgb_leaves = as.integer(hp$lgb_leaves %||% 31L),
    feature_fraction = 0.8,
    bagging_fraction = 0.8,
    min_data_in_leaf = 20L
  )
}
