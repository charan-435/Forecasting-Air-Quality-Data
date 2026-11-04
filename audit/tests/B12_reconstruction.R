# B12: Haar / D4 / LA8 MRA sums back to Y on training-length series.
source("audit/tests/_lib.R")

set.seed(3)
y <- as.numeric(stats::arima.sim(list(ar = 0.4), n = 512))
J <- 5L
rows <- list()
for (f in c("haar", "d4", "la8")) {
  mra <- generic_mra(y, J, f)
  rec <- mra_reconstruct(mra)
  err <- max(abs(rec - y))
  rows[[f]] <- tibble::tibble(filter = f, max_abs_recon_err = err)
  audit_info(f, " max |sum(D)+S - Y| = ", signif(err, 4))
}
tab <- dplyr::bind_rows(rows)
write_tbl(tab, "B12_reconstruction_error.csv")

# waveslim periodic MRA should still be additive; Haar is claimed ~1e-14.
audit_ok("B12_haar_recon_lt_1e_12",
         tab$max_abs_recon_err[tab$filter == "haar"] < 1e-12,
         sprintf("Haar recon err = %g", tab$max_abs_recon_err[tab$filter == "haar"]))
audit_ok("B12_d4_recon_lt_1e_8",
         tab$max_abs_recon_err[tab$filter == "d4"] < 1e-8,
         sprintf("D4 recon err = %g", tab$max_abs_recon_err[tab$filter == "d4"]))
audit_ok("B12_la8_recon_lt_1e_8",
         tab$max_abs_recon_err[tab$filter == "la8"] < 1e-8,
         sprintf("LA8 recon err = %g", tab$max_abs_recon_err[tab$filter == "la8"]))
