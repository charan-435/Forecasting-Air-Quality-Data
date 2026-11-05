# C17: Friedman/Nemenyi block count and q for k=9.
source("docs/audit/tests/_lib.R")

scores <- readRDS(file.path(RES_DIR, "scores.rds"))
n_cases <- scores %>%
  dplyr::distinct(sensor, pollutant, horizon) %>%
  nrow()
n_methods <- length(unique(scores$method))
n_rows <- nrow(scores)
audit_info("score rows=", n_rows, " methods=", n_methods, " cases=", n_cases,
           " complete=", n_cases * n_methods)

mcb <- mcb_from_table(dplyr::filter(scores, is.finite(MASE)))
write_tbl(mcb, "C17_mcb_recomputed.csv")
print(mcb)

saved <- if (file.exists(file.path(RES_DIR, "mcb.csv")))
  readr::read_csv(file.path(RES_DIR, "mcb.csv"), show_col_types = FALSE) else NULL
if (!is.null(saved)) {
  audit_info("saved mcb.csv CD=", unique(saved$critical_distance),
             " recomputed CD=", unique(mcb$critical_distance))
}

k <- n_methods
n <- n_cases
q <- nemenyi_q(k)
cd_theory <- q * sqrt(k * (k + 1) / (6 * n))
audit_info("k=", k, " n_blocks=", n, " q_0.05=", q, " CD=", signif(cd_theory, 4))

# Wrong n=10 reproduces 3.799
cd_n10 <- q * sqrt(k * (k + 1) / (6 * 10))
audit_info("CD if n=10: ", signif(cd_n10, 4), " (matches results/paper/mcb.csv ~3.799)")

audit_ok("C17_block_count_is_48", n_cases == 48L,
         sprintf("distinct (sensor, pollutant, horizon) = %s (want 48)", n_cases))
audit_ok("C17_saved_cd_uses_48_blocks",
         is.null(saved) || abs(unique(saved$critical_distance)[1] - cd_theory) < 0.01,
         sprintf("saved CD=%s vs theory with n=%s: %s",
                 if (is.null(saved)) NA else unique(saved$critical_distance)[1],
                 n, signif(cd_theory, 4)))
audit_ok("C17_q_for_k9_is_3.102", abs(q - 3.102) < 1e-6,
         sprintf("nemenyi_q(%s)=%s", k, q))
