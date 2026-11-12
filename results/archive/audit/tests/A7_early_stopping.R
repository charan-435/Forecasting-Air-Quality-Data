# A7: early-stopping validation is the tail of the pre-test window, not the test set.
source("docs/audit/tests/_lib.R")

src <- paste(readLines("R/core/06_models.R"), collapse = "\n")
uses_split_val <- grepl("split_val\\(sup\\$X, sup\\$y, params\\$val_hours\\)", src)
xgb_watch <- grepl("watchlist = watch", src)
lgb_valid <- grepl("valids = list\\(eval = dva\\)", src)
cat_valid <- grepl("pool_va", src)

# split_val takes the last val_hours of the matrix built from y_train.
# For the bake-off, y_train = pre-test (chrono_split$y_train = y_fit).
packed <- readRDS(file.path(PROC_DIR, "series.rds"))
s <- packed$series$CPCB_PM2.5
n <- length(s$y)
rows <- list()
for (hn in names(HORIZONS)) {
  h <- HORIZONS[[hn]]
  sp <- chrono_split_tvt(s$y, s$times, h)
  # last val index vs first test index
  rows[[hn]] <- tibble::tibble(
    horizon = hn,
    n_train = sp$n_train, n_val = sp$n_val, n_test = sp$n_test,
    val_end = sp$n_train + sp$n_val,
    test_start = n - h + 1L,
    val_overlaps_test = (sp$n_train + sp$n_val) >= (n - h + 1L)
  )
}
tab <- dplyr::bind_rows(rows)
write_tbl(tab, "A7_early_stopping_windows.csv")
print(tab)

audit_ok("A7_trees_use_pretest_val_split", uses_split_val && xgb_watch && lgb_valid && cat_valid,
         "XGB/LGB/CatBoost early-stop on split_val of y_train")
audit_ok("A7_val_never_overlaps_that_jobs_test",
         all(!tab$val_overlaps_test),
         "for each horizon, the 14-day val tail is before that job's test start")
