# A5: hparam grid uses the 1-day train prefix, which contains longer-horizon tests.
source("docs/audit/tests/_lib.R")

hp <- readRDS(file.path(RES_DIR, "hparams.rds"))
packed <- readRDS(file.path(PROC_DIR, "series.rds"))
s <- packed$series$CPCB_PM2.5
n <- length(s$y)
h1 <- HORIZONS[["1d"]]
# choose_hparams: chrono_split(..., h=24) so train = 1:(n-24)
hp_train_end <- n - h1
rows <- list()
for (hn in names(HORIZONS)) {
  h <- HORIZONS[[hn]]
  test_lo <- n - h + 1L
  test_hi <- n
  overlap_lo <- max(1L, test_lo)
  overlap_hi <- min(hp_train_end, test_hi)
  n_ov <- max(0L, overlap_hi - overlap_lo + 1L)
  rows[[hn]] <- tibble::tibble(
    horizon = hn, h = h, test_start = test_lo, test_end = test_hi,
    hp_train_end = hp_train_end, overlap_hours = n_ov,
    overlap_frac_of_test = n_ov / h
  )
}
tab <- dplyr::bind_rows(rows)
write_tbl(tab, "A5_hparam_test_overlap.csv")
print(tab)
audit_info("hparams reason: ", hp$reason)
audit_info("Chosen p=", hp$params$p, " depth=", hp$params$max_depth,
           " eta=", hp$params$eta, " J=", hp$J)

ov31 <- tab$overlap_hours[tab$horizon == "31d"]
audit_ok("A5_hparams_disjoint_from_31d_test", ov31 == 0,
         sprintf("1-day hparam train overlaps 31-day test by %s hours (%.0f%% of that test)",
                 ov31, 100 * tab$overlap_frac_of_test[tab$horizon == "31d"]))
audit_ok("A5_hparams_disjoint_from_7d_test",
         tab$overlap_hours[tab$horizon == "7d"] == 0,
         sprintf("overlap with 7-day test = %s hours",
                 tab$overlap_hours[tab$horizon == "7d"]))
