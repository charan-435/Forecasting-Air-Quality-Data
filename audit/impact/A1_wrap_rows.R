# How many origin-adjacent training rows are circular-wrap contaminated
# at the J actually used in the bake-off (J=5) and in the paper protocol (J=ln N).
source("audit/tests/_lib.R")

hp <- readRDS(file.path(RES_DIR, "hparams.rds"))
J_use <- min(as.integer(hp$J), 5L)
packed <- readRDS(file.path(PROC_DIR, "series.rds"))
p <- 24L

rows <- list()
for (key in c("CPCB_PM2.5", "ID1_PM2.5")) {
  s <- packed$series[[key]]
  n <- length(s$y)
  J_paper <- max(1L, min(9L, as.integer(floor(log(n)))))
  for (hn in names(HORIZONS)) {
    h <- HORIZONS[[hn]]
    ntr <- n - h
    for (J in unique(c(J_use, J_paper))) {
      # last L = 2^J - 1 points of a length-ntr circular MRA depend on Y[1].
      L <- 2^J - 1L
      rows[[length(rows) + 1L]] <- tibble::tibble(
        series = key, horizon = hn, n_train = ntr, J = J,
        wrap_len = L,
        origin_lags_all_wrapped = L >= p,
        n_train_rows_wrapped = min(L, ntr)
      )
    }
  }
}
tab <- dplyr::bind_rows(rows)
readr::write_csv(tab, file.path(AUDIT_OUT, "A1_wrap_rows_by_split.csv"))
print(tab)
