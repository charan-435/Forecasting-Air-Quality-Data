source("tests/preprocessing/_lib.R")
path <- file.path(PROJECT_ROOT, "store", "clean", "series.parquet")
if (!file.exists(path)) run_preprocess(active = "paper", force = TRUE)
d <- tibble::as_tibble(arrow::read_parquet(path))
d$station <- as.character(d$station)
d$variable <- as.character(d$variable)
stns <- unique(d$station)
p1a_ok("schema_cols", all(CLEAN_COLS %in% names(d)),
       paste("missing", paste(setdiff(CLEAN_COLS, names(d)), collapse = ",")))
p1a_ok("schema_policy",
       file.exists(file.path(PROJECT_ROOT, "store", "clean", "policy.yaml")),
       "policy.yaml exists")
p1a_ok("schema_wide",
       all(file.exists(file.path(PROJECT_ROOT, "store", "clean",
                                 paste0("wide_", stns, ".parquet")))),
       "wide parquet per station")
p1a_ok("schema_daily",
       all(file.exists(file.path(PROJECT_ROOT, "store", "clean",
                                 paste0("daily_", stns, ".parquet")))),
       "daily parquet per station")
# Paper CPCB CO is stored as mg/m3 (source ug/m3 / 1000).
if ("CPCB" %in% d$station && "CO" %in% d$variable) {
  med <- stats::median(d$value_hourly_raw[d$station == "CPCB" & d$variable == "CO"], na.rm = TRUE)
  p1a_ok("schema_co_mg", is.finite(med) && med < 50,
         sprintf("CPCB CO median %s mg/m3 (canonical)", round(med, 4)))
}
