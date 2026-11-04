# Shillong architecture study: audit, smoke, shortlist and sensitivity stages.

sh_md_table <- function(d, digits = 3) {
  d <- as.data.frame(d)
  for (k in names(d)) if (is.numeric(d[[k]])) d[[k]] <- ifelse(is.na(d[[k]]), "",
    formatC(d[[k]], digits = digits, format = "fg", big.mark = ","))
  c(paste0("| ", paste(names(d), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
    apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}

sh_sample_counts <- function(cfg, S, target, h) {
  pols <- S$avail$pollutants
  do.call(rbind, lapply(list(
    primary = list(TRUE, TRUE), no_origin_policy = list(TRUE, FALSE),
    unmasked_targets = list(FALSE, FALSE)), function(v) {
      s <- sh_samples(cfg, S$panel, S$splits, target, h, pols, v[[1]], v[[2]])
      tb <- table(factor(s$block, c("train", "validation", "test")))
      data.frame(train = tb[["train"]], validation = tb[["validation"]], test = tb[["test"]],
                 first_target = format(min(s$target_ts)), last_target = format(max(s$target_ts)))
    })) -> d
  cbind(station = S$panel$station, target = target, horizon_h = h, sample_rule = rownames(d), d,
        row.names = NULL)
}

sh_stage_audit <- function(cfg, out, say) {
  dir <- file.path(out, "audit")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(dir, "AUDIT_PASSED"))
  long <- sh_read_long(cfg)
  splits <- lapply(stats::setNames(cfg$stations, cfg$stations), function(st) sh_splits(cfg, st))
  raw <- sh_raw_15min_na(cfg)
  vars <- sh_audit_variables(cfg, long, splits)
  fills <- sh_audit_fill_methods(long)
  align <- sh_audit_alignment(long)
  mv_write_csv(raw, file.path(dir, "RAW_15MIN.csv"))
  mv_write_csv(vars, file.path(dir, "HOURLY_VARIABLES.csv"))
  mv_write_csv(fills, file.path(dir, "FILL_METHODS.csv"))
  mv_write_csv(align, file.path(dir, "ALIGNMENT.csv"))
  mv_write_csv(sh_audit_monthly_levels(long), file.path(dir, "MONTHLY_LEVELS.csv"))
  checks <- list()
  avail_rows <- list(); cov_rows <- list(); ov_rows <- list(); dec_rows <- list(); cnt <- list()
  split_rows <- list()
  for (st in cfg$stations) {
    S <- list(panel = sh_panel(cfg, long, st), splits = splits[[st]])
    S$avail <- sh_available(cfg, S$panel, S$splits)
    avail_rows[[st]] <- data.frame(station = st,
      pollutants_used = paste(S$avail$pollutants, collapse = ","),
      pollutants_dropped = paste(S$avail$dropped_pollutants, collapse = ","),
      covariates_used = paste(S$avail$covariates, collapse = ","),
      covariates_dropped = paste(S$avail$dropped_covariates, collapse = ","))
    cov_rows[[st]] <- sh_audit_covariates(S$panel, S$splits)
    ov_rows[[st]] <- sh_audit_overlap(S$panel, S$avail$pollutants, S$splits)
    dec_rows[[st]] <- sh_audit_decomp(S$panel, S$avail$pollutants, S$splits$train)
    for (b in names(S$splits)) split_rows[[paste(st, b)]] <- data.frame(
      station = st, block = b, from = format(S$splits[[b]][1]), to = format(S$splits[[b]][2]),
      hours = sum(S$panel$timestamps >= S$splits[[b]][1] & S$panel$timestamps <= S$splits[[b]][2]))
    for (v in S$avail$pollutants) for (h in cfg$horizons)
      cnt[[paste(st, v, h)]] <- sh_sample_counts(cfg, S, v, h)
    # checks on the station period (from the train start)
    w <- S$panel$timestamps >= S$splits$train[1]
    w_dec <- S$panel$timestamps >= S$splits$train[1] + 3600 * (2^S$panel$J - 1)
    for (v in S$avail$pollutants) {
      checks[[paste("finite after fill", st, v)]] <- all(is.finite(S$panel$fill[[v]][w]))
      M <- S$panel$comps[[v]]
      checks[[paste("components complete after warmup", st, v)]] <- all(is.finite(M[w_dec, ]))
      checks[[paste("additivity", st, v)]] <-
        isTRUE(max(abs(rowSums(M[w_dec, ]) - S$panel$fill[[v]][w_dec])) < 1e-8)
    }
    say("audit ", st, ": pollutants ", paste(S$avail$pollutants, collapse = ","),
        " | covariates ", paste(S$avail$covariates, collapse = ","))
  }
  cnt <- do.call(rbind, cnt)
  checks[["contiguous hourly grid"]] <- all(align$contiguous_hourly)
  checks[["no duplicate station-hours"]] <- all(align$duplicate_station_hours == 0)
  checks[["all variables every hour"]] <- all(align$all_variables_every_hour)
  checks[["every primary cell has samples in each block"]] <-
    all(cnt[cnt$sample_rule == "primary", c("train", "validation", "test")] > 0)
  mv_write_csv(do.call(rbind, avail_rows), file.path(dir, "AVAILABILITY.csv"))
  mv_write_csv(do.call(rbind, cov_rows), file.path(dir, "COVARIATES.csv"))
  mv_write_csv(do.call(rbind, ov_rows), file.path(dir, "OVERLAP.csv"))
  mv_write_csv(do.call(rbind, dec_rows), file.path(dir, "DECOMP_AUDIT.csv"))
  mv_write_csv(cnt, file.path(dir, "SAMPLE_COUNTS.csv"))
  mv_write_csv(do.call(rbind, split_rows), file.path(dir, "SPLITS.csv"))

  # automated tests (tests/shillong/run_tests.R) are part of the audit gate
  tres <- sh_run_tests(cfg)
  mv_write_csv(tres, file.path(dir, "TEST_SUMMARY.csv"))
  chk <- data.frame(check = names(checks), pass = unlist(checks))
  mv_write_csv(chk, file.path(dir, "CHECKS.csv"))
  say("audit checks: ", sum(chk$pass), "/", nrow(chk), " | tests: ", sum(tres$pass), "/", nrow(tres))
  if (all(chk$pass) && all(tres$pass)) writeLines(format(Sys.time()), file.path(dir, "AUDIT_PASSED"))
  else stop("audit failed: ", paste(c(chk$check[!chk$pass], tres$test[!tres$pass]), collapse = "; "))
}

sh_run_tests <- function(cfg) {
  env <- new.env(parent = globalenv())
  env$cfg <- cfg
  sys.source("tests/shillong/run_tests.R", envir = env)
  env$SH_TEST_RESULTS
}

# Phases 2-3: every architecture once on PM2.5 at h = 24 with a light LightGBM
# configuration and one seed; checks reconstruction and shared timestamps.
sh_stage_smoke <- function(cfg, out, say, load_station) {
  dir <- file.path(out, "smoke")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(dir, "SMOKE_PASSED"))
  sc <- cfg
  sc$families$lightgbm <- list(base = cfg$smoke$lightgbm$base)
  sc$seeds <- list(cfg$tune_seed)
  h <- as.integer(cfg$smoke$horizon); target <- cfg$primary_target
  rows <- list(); checks <- list(); schemas <- list()
  for (st in cfg$stations) {
    S <- load_station(st)
    smp <- sh_samples(sc, S$panel, S$splits, target, h, S$avail$pollutants)
    tgt_sets <- list()
    for (a in unlist(cfg$architectures)) {
      r <- sh_run_arch(sc, S$panel, S$avail, S$splits, smp, target, h, a, "lightgbm",
                       as.integer(cfg$tune_seed), as.integer(cfg$tune_seed))
      p <- r$pred
      lev <- p[component == "LEVEL"]
      tgt_sets[[a]] <- lev[order(block, target_idx), paste(block, target_idx)]
      if (sh_arch(a)$kind == "decomp") {
        comp <- p[component != "LEVEL"]
        sums <- comp[, .(ys = sum(y), yh = sum(yhat)), by = .(block, target_idx)]
        m <- merge(sums, lev[, .(block, target_idx, y, yhat)], by = c("block", "target_idx"))
        checks[[paste(st, a, "component truths sum to observed level")]] <- max(abs(m$ys - m$y)) < 1e-8
        checks[[paste(st, a, "reconstruction = sum of component forecasts")]] <- max(abs(m$yh - m$yhat)) < 1e-8
      }
      checks[[paste(st, a, "all forecasts finite")]] <- all(is.finite(p$yhat))
      m <- sh_metrics(lev, c(LEVEL = 1))
      rows[[paste(st, a)]] <- cbind(m[, .(station, target, horizon_h, arch, block, n, MAE, RMSE)],
                                    n_inputs = max(r$info$n_inputs), seconds = round(r$elapsed_s, 1))
      schemas[[paste(st, a)]] <- r$schema
      say(sprintf("smoke %s %s: val MAE %.3f test MAE %.3f (%d inputs, %.0f s)", st, a,
                  m[block == "validation", MAE], m[block == "test", MAE],
                  max(r$info$n_inputs), r$elapsed_s))
    }
    ref <- tgt_sets[[1]]
    checks[[paste(st, "identical target timestamps across architectures")]] <-
      all(vapply(tgt_sets, identical, logical(1), ref))
  }
  res <- data.table::rbindlist(rows)
  mv_write_csv(res, file.path(dir, "SMOKE_METRICS.csv"))
  mv_write_csv(data.table::rbindlist(schemas), file.path(dir, "FEATURE_SCHEMAS.csv"))
  chk <- data.frame(check = names(checks), pass = unlist(checks))
  mv_write_csv(chk, file.path(dir, "SMOKE_CHECKS.csv"))
  say("smoke checks: ", sum(chk$pass), "/", nrow(chk))
  if (all(chk$pass)) writeLines(format(Sys.time()), file.path(dir, "SMOKE_PASSED"))
  else stop("smoke failed: ", paste(chk$check[!chk$pass], collapse = "; "))
}

# Q12 diagnostics: retrain PM2.5 LightGBM models on looser sample rules.
#   no_origin_policy  - scorable targets, but origins inside long gaps or with
#                       > 25 % filled hours in the last day are kept;
#   unmasked_targets  - every target hour, imputed or masked ones included
#                       (truth = causal-filled value where not observed).
# The report scores every variant on the primary samples as well as its own.
sh_stage_sensitivity <- function(cfg, out, say, load_station, st, horizons) {
  S <- load_station(st)
  target <- cfg$primary_target
  archs <- unique(c("A0", "A2", "B0", sh_shortlist(cfg, out, st)))
  variants <- list(no_origin_policy = c(TRUE, FALSE), unmasked_targets = c(FALSE, FALSE))
  for (vn in names(variants)) for (h in horizons) {
    v <- variants[[vn]]
    smp <- sh_samples(cfg, S$panel, S$splits, target, h, S$avail$pollutants,
                      scorable_only = v[1], origin_policy = v[2])
    for (a in archs) {
      path <- file.path(out, "sensitivity", vn, "lightgbm", st, target, paste0("h", h), paste0(a, ".rds"))
      if (file.exists(path)) next
      r <- sh_run_arch(cfg, S$panel, S$avail, S$splits, smp, target, h, a, "lightgbm",
                       as.integer(unlist(cfg$seeds)), as.integer(cfg$tune_seed))
      r$pred[, variant := vn]
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      saveRDS(r, path)
      say(sprintf("sensitivity %s %s h=%d %s n_train=%d (%.0f s)", vn, st, h, a,
                  max(r$info$n_train), r$elapsed_s))
    }
  }
}

# Shortlist for stages 2 and 3 from LightGBM PM2.5 validation MAE (seed mean,
# averaged over horizons): best undecomposed and best decomposed architectures.
sh_shortlist <- function(cfg, out, st) {
  files <- list.files(file.path(out, "runs", "lightgbm", st, cfg$primary_target),
                      pattern = "\\.rds$", recursive = TRUE, full.names = TRUE)
  if (!length(files)) stop("no LightGBM PM2.5 runs for ", st)
  m <- data.table::rbindlist(lapply(files, function(f) {
    p <- readRDS(f)$pred[component == "LEVEL" & block == "validation"]
    sh_seed_mean(p)[, .(MAE = mean(abs(yhat - y))), by = .(arch, kind, horizon_h)]
  }))
  # relative to A0 within each horizon so horizons weigh equally
  a0 <- m[arch == "A0", .(horizon_h, a0 = MAE)]
  m <- merge(m, a0, by = "horizon_h")[, .(rel = mean(MAE / a0), n_h = .N), by = .(arch, kind)]
  m <- m[n_h == max(n_h)]
  k <- as.integer(cfg$stage2$per_kind)
  best <- c(head(m[kind == "level"][order(rel), arch], k),
            head(m[kind == "decomp"][order(rel), arch], k))
  unique(c("A0", "B0", best))
}
