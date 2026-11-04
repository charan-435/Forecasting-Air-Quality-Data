# Data-phase tests (Phases 1-2). Run through: Rscript run_preprocessed_experiment.R test-data

pe_test_data <- function(cfg) {
  res <- list()
  add <- function(name, ok, detail = "") {
    res[[length(res) + 1L]] <<- data.frame(test = name, pass = isTRUE(ok), detail = detail)
  }
  P <- cfg$pollutants
  src <- pe_load_source(cfg)
  cl <- arrow::read_parquet(file.path(pe_dir(cfg, "store", "clean"), "series.parquet"))
  cl <- cl[order(cl$variable, cl$timestamp), ]
  src <- src[order(src$variable, src$timestamp), ]

  # 1. Same grid as the source; source values untouched in value_hourly_raw
  add("clean store has the source grid", nrow(cl) == nrow(src) &&
        identical(as.numeric(cl$timestamp), as.numeric(src$timestamp)) &&
        identical(cl$variable, src$variable), sprintf("%d rows", nrow(cl)))
  add("raw values carried unchanged", isTRUE(all.equal(cl$value_hourly_raw, src$value_hourly_raw)))
  # 2. Invalid -> NA, valid unchanged, filled only where masked, nothing clipped
  add("masked hours are NA in value_masked", all(is.na(cl$value_masked[cl$is_masked])))
  add("valid hours unchanged", isTRUE(all.equal(cl$value_masked[!cl$is_masked],
                                                cl$value_hourly_raw[!cl$is_masked])) &&
        isTRUE(all.equal(cl$value_filled_causal[!cl$is_masked], cl$value_hourly_raw[!cl$is_masked])))
  add("fill_method set exactly on masked hours", identical(!is.na(cl$fill_method), cl$is_masked))
  lead_ok <- all(vapply(split(cl, cl$variable), function(f) {
    f <- f[order(f$timestamp), ]
    na <- which(!is.finite(f$value_filled_causal))
    !length(na) || (identical(na, seq_along(na)) && na[length(na)] < min(which(f$is_scorable)))
  }, logical(1)))
  add("model-input NA only before each pollutant's first valid observation", lead_ok,
      sprintf("%d no-history hours", sum(!is.finite(cl$value_filled_causal))))
  add("no negative model inputs", all(cl$value_filled_causal >= 0, na.rm = TRUE))
  add("only parameter-free past-only fill methods used",
      all(na.omit(cl$fill_method) %in% unlist(cfg$imputation$methods)),
      paste(sort(unique(na.omit(cl$fill_method))), collapse = ","))
  add("scorable == not masked", identical(cl$is_scorable, !cl$is_masked))
  add("no value clipped to a bound", all(cl$value_masked[!cl$is_masked] == cl$value_hourly_raw[!cl$is_masked]))

  # 3. Fill codes depend only on the training block
  w <- pe_wide(src)
  tr <- w$timestamp <= pe_time(cfg$split$train_end, cfg)
  a <- pe_fill_codes(w, P, tr, cfg$validity$fill_code_min_hours)
  w2 <- w
  for (v in P) w2[[v]][!tr] <- w2[[v]][!tr] * 1.37 + 0.11
  b <- pe_fill_codes(w2, P, tr, cfg$validity$fill_code_min_hours)
  add("fill codes unchanged when non-training values are perturbed", identical(a$codes, b$codes),
      sprintf("%d codes", length(a$codes)))

  # 4. Causal imputation: perturbing hours after a cut leaves fills up to the cut unchanged
  choice <- yaml::read_yaml(file.path(pe_dir(cfg, "store", "clean"), "imputation_choice.yaml"))
  cut <- pe_time("2023-01-10 12:00", cfg)
  pp <- pp_cfg()
  run_fill <- function(hourly) {
    out <- impute_station(hourly, pp, choice, m7_fits = list(), m8_fits = list())
    out[order(out$variable, out$timestamp), ]
  }
  base_in <- cl[, c("station", "variable", "timestamp", "value_masked")]
  late <- base_in$timestamp > cut
  pert_in <- base_in
  pert_in$value_masked[late] <- pert_in$value_masked[late] * 3 + 50
  pert_in$value_masked[late & seq_len(nrow(pert_in)) %% 7 == 0] <- NA
  f1 <- run_fill(base_in); f2 <- run_fill(pert_in)
  early <- f1$timestamp <= cut
  add("imputation is causal (perturbing later hours leaves earlier fills unchanged)",
      isTRUE(all.equal(f1$value_filled_causal[early], f2$value_filled_causal[early])))
  add("experiment fill reproduces the stored fill", isTRUE(all.equal(f1$value_filled_causal,
                                                                      cl$value_filled_causal)))

  # 5. Decomposition: causal, additive, warm-up
  entry <- pe_decomp_entry(cfg)
  W <- entry$params$window_h
  d <- pe_read_decomp(cfg, "clean", cfg$target)
  comps <- decomp_component_names(entry)
  add("components are D1..D5 and S5", identical(comps, c(paste0("D", 1:5), "S5")),
      paste(comps, collapse = ","))
  ok <- d$valid_warmup
  add("additivity: |input - sum(components)| < 1e-8 after warm-up", max(abs(d$resid[ok])) < 1e-8,
      sprintf("max %.2e", max(abs(d$resid[ok]))))
  x <- cl$value_filled_causal[cl$variable == cfg$target]
  s0 <- min(which(is.finite(x)))
  add("warm-up = first full window of model inputs; no components before it",
      all(!is.finite(as.matrix(d[!ok, comps]))) && sum(!ok) == s0 + W - 2L,
      sprintf("%d warm-up rows (first input row %d, W = %d)", sum(!ok), s0, W))
  t0 <- W + 300L
  xp <- x
  xp[(t0 + 1):length(xp)] <- xp[(t0 + 1):length(xp)] * 2 + 40
  m_a <- run_trailing_series(x[seq_len(t0 + 50L)], decomp_mra_haar, entry$params, W, 0L)
  m_b <- run_trailing_series(xp[seq_len(t0 + 50L)], decomp_mra_haar, entry$params, W, 0L)
  add("decomposition is causal (perturbing hours after t leaves components at <= t unchanged)",
      isTRUE(all.equal(m_a[W:t0, ], m_b[W:t0, ])) && !isTRUE(all.equal(m_a[(t0 + 1):(t0 + 50), ],
                                                                         m_b[(t0 + 1):(t0 + 50), ])))
  add("stored components equal a fresh computation", isTRUE(all.equal(
    unname(as.matrix(d[W:(t0 + 50L), comps])), unname(m_a[W:(t0 + 50L), ]))))

  out <- dplyr::bind_rows(res)
  pe_write_csv(out, file.path(pe_dir(cfg, "results", "tests"), "data_tests.csv"))
  out
}
