# Model-phase tests (leakage and alignment rules 1-13 of the task).
# Run through: Rscript code/experiments/run_preprocessed_experiment.R smoke

pe_test_models <- function(cfg, smoke) {
  res <- list()
  add <- function(rule, name, ok, detail = "") {
    res[[length(res) + 1L]] <<- data.frame(rule = rule, test = name, pass = isTRUE(ok), detail = detail)
  }
  md <- smoke$md
  h <- md$h
  tgt <- cfg$target
  S <- md$sets
  sc <- pe_scalers(md, max(md$train_hours))
  idx <- S$eval_val[c(1, 50, 200)]
  others <- pe_others(md)

  # Lag order and contents
  a1 <- pe_xy_single(md, "A1", idx, sc)
  add("lags", "A1 lag1 = PM2.5 at the origin, lag24 = 23 h earlier",
      isTRUE(all.equal(a1$X[, "lag1"], pe_z(md$input[idx, tgt], sc[[paste0(tgt, "|input")]]))) &&
        isTRUE(all.equal(a1$X[, "lag24"], pe_z(md$input[idx - 23, tgt], sc[[paste0(tgt, "|input")]]))))
  b0 <- pe_xy_single(md, "B0", idx, sc, comp = "D3")
  add("lags", "B0 lag1/lag24 = own component at t / t-23",
      isTRUE(all.equal(b0$X[, "lag1"], pe_z(md$comps[[tgt]][idx, "D3"], sc[[paste0(tgt, "|D3")]]))) &&
        isTRUE(all.equal(b0$X[, "lag24"], pe_z(md$comps[[tgt]][idx - 23, "D3"], sc[[paste0(tgt, "|D3")]]))))
  # Rule 4/5: covariates not lagged; lags only for the target component
  b2s <- pe_xy_single(md, "B2", idx, sc, comp = "D2", cov_set = "same_level")
  b2a <- pe_xy_single(md, "B2", idx, sc, comp = "D2", cov_set = "all_levels")
  add("4,5", "A1 = 24 PM2.5 lags + one value per covariate (no covariate lags)",
      identical(colnames(a1$X), c(paste0("lag", 1:24), paste0("cov_", others))))
  add("4,5", "B2 same_level = 24 own lags + 5 covariates at t",
      identical(colnames(b2s$X), c(paste0("lag", 1:24), paste0("cov_", others))) &&
        isTRUE(all.equal(unname(b2s$X[, "cov_PM10"]), pe_z(md$comps$PM10[idx, "D2"], sc[["PM10|D2"]]))))
  add("4,5", "B2 all_levels = 24 own lags + 30 covariates at t", ncol(b2a$X) == 54 &&
        sum(grepl("^lag", colnames(b2a$X))) == 24)
  sh <- pe_xy_shared(md, "B3", idx, sc, cov_set = "same_level")
  own_ok <- all(vapply(seq_along(PE_COMPS), function(k) {
    rows <- sh$comp == PE_COMPS[k]
    isTRUE(all.equal(unname(sh$X[rows, "lag1"]),
                     pe_z(md$comps[[tgt]][idx, PE_COMPS[k]], sc[[paste0(tgt, "|", PE_COMPS[k])]])))
  }, logical(1)))
  add("5", "B1/B3 rows carry only their own component's lags", own_ok)
  # Rule 6: component identity
  add("6", "component identity = fixed code 0..5 per component, no target information",
      all(tapply(sh$X[, "component"], sh$comp, function(z) length(unique(z)) == 1)) &&
        isTRUE(all.equal(sort(unique(unname(sh$X[, "component"]))), as.numeric(0:5))) &&
        all(vapply(seq_along(PE_COMPS), function(k)
          all(sh$X[sh$comp == PE_COMPS[k], "component"] == k - 1), logical(1))),
      "codes: D1=0 ... S5=5")
  # Rules 1-3: perturbation after the origin
  t0 <- S$eval_val[100]
  md2 <- md
  late <- (t0 + 1):md$n
  md2$input[late, ] <- md2$input[late, ] * 3 + 7
  for (v in md$P) md2$comps[[v]][late, ] <- md2$comps[[v]][late, ] * -2 + 5
  ii <- S$eval_val[S$eval_val <= t0]
  same <- TRUE
  for (a in c("A1", "B0", "B2")) for (cs in c("same_level", "all_levels")) {
    x1 <- pe_xy_single(md, a, ii, sc, comp = if (a == "A1") NULL else "D4", cov_set = cs)$X
    x2 <- pe_xy_single(md2, a, ii, sc, comp = if (a == "A1") NULL else "D4", cov_set = cs)$X
    same <- same && identical(x1, x2)
  }
  for (a in c("B1", "B3")) same <- same && identical(pe_xy_shared(md, a, ii, sc, "all_levels")$X,
                                                     pe_xy_shared(md2, a, ii, sc, "all_levels")$X)
  add("1,2,3", "perturbing every series after origin t leaves all features at <= t unchanged", same,
      sprintf("%d origins, all five architectures", length(ii)))
  # Rule 9: scaling fitted on training hours only
  md3 <- md
  after <- (max(md$train_hours) + 1):md$n
  md3$input[after, ] <- md3$input[after, ] + 100
  for (v in md$P) md3$comps[[v]][after, ] <- md3$comps[[v]][after, ] + 100
  add("9", "scalers unchanged when every value after the training block changes",
      identical(pe_scalers(md, max(md$train_hours)), pe_scalers(md3, max(md$train_hours))))
  # Rules 10, 11: targets inside their blocks
  te <- function(x) md$times[x + h]
  tr_end <- pe_time(cfg$split$train_end, cfg); va_end <- pe_time(cfg$split$val_end, cfg)
  add("10", "training targets within the training block", max(te(S$fit_train)) <= tr_end)
  add("11", "validation targets within the validation block",
      min(te(S$eval_val)) > tr_end && max(te(S$eval_val)) <= va_end &&
        min(te(S$fit_val)) > tr_end && max(te(S$fit_val)) <= va_end)
  add("11", "test targets after the validation block", min(te(S$eval_test)) > va_end)
  add("10,11", "evaluation targets are valid observations", all(is.finite(md$truth[c(S$eval_val, S$eval_test) + h])))
  # Rule 12: test labels cannot influence selection
  md4 <- md
  md4$truth[S$eval_test + h] <- md4$truth[S$eval_test + h] * 5 + 50
  md4$comps[[tgt]][S$eval_test + h, ] <- md4$comps[[tgt]][S$eval_test + h, ] * 5 + 50
  r1 <- smoke$res$B3
  r2 <- pe_run_arch(md4, "B3", smoke = TRUE)
  add("12", "selection and validation predictions unchanged when test labels change",
      identical(r1$selected, r2$selected) && identical(r1$val$predicted, r2$val$predicted))
  # Rule 13: identical targets across architectures
  tt <- lapply(smoke$res, function(r) r$test$target_time)
  vt <- lapply(smoke$res, function(r) r$val$target_time)
  add("13", "identical validation and test target timestamps across the five architectures",
      all(vapply(tt, identical, logical(1), tt[[1]])) && all(vapply(vt, identical, logical(1), vt[[1]])))
  # Reconstruction
  rb <- smoke$res$B0$test
  add("recon", "actual components at the target sum to actual PM2.5",
      max(abs(rowSums(rb[, paste0("actual_", PE_COMPS)]) - rb$actual)) < 1e-8)
  add("recon", "reconstructed forecast = sum of component forecasts",
      max(abs(rowSums(rb[, paste0("pred_", PE_COMPS)]) - rb$predicted)) < 1e-10)
  add("schema", "no NA in any feature matrix of the sample sets",
      all(vapply(c("A1", "B0", "B2"), function(a) all(is.finite(pe_xy_single(md, a, c(S$fit_train, S$fit_val, S$eval_test), sc,
                                                                             comp = if (a == "A1") NULL else "S5",
                                                                             cov_set = "all_levels")$X)), logical(1))))
  out <- dplyr::bind_rows(res)
  pe_write_csv(out, file.path(pe_dir(cfg, "results", "tests"), "model_tests.csv"))
  out
}
