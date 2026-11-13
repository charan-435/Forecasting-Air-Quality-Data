# Second-stage experiments: one cell = (station, architecture, PCA setting),
# all horizons and all three strategies. Every artefact is written as soon as it
# exists, so an interrupted cell resumes from the first missing file.

ss_cell_dir <- function(out, st, arch_id, pca) file.path(out, "runs", st, arch_id, ss_pca_label(pca))

ss_hybrid_cells <- function(horizons, switch_points) {
  g <- expand.grid(s = as.integer(switch_points), h = as.integer(horizons))
  g[g$s < g$h, ]
}

ss_meta <- function(d, meta) {
  if (is.null(d) || !nrow(d)) return(d)
  for (k in names(meta)) d[[k]] <- meta[[k]]
  d
}

# Recursive forecasts at horizon h on the direct samples of that horizon.
ss_recursive_pred <- function(S, target, h, smp, rec) {
  out <- list()
  for (b in c("validation", "test")) {
    sb <- data.table::as.data.table(smp[smp$block == b, c("origin_idx", "target_idx")])
    d <- rec[[b]][step == h]
    m <- merge(sb, d, by = "origin_idx", allow.cartesian = TRUE)
    if (nrow(m[component == "LEVEL"]) != nrow(sb)) stop("recursive: missing forecasts for ", b, " h=", h)
    m[, y := ifelse(component == "LEVEL", S$panel$observed[[target]][target_idx], NA_real_)]
    for (cp in setdiff(unique(m$component), "LEVEL"))
      m[component == cp, y := S$panel$comps[[target]][target_idx, cp]]
    m[, `:=`(block = b, seed = 0L, step = NULL)]
    out[[b]] <- m
  }
  data.table::rbindlist(out, use.names = TRUE)
}

ss_run_cell <- function(cfg, scfg, S, arch_id, pca, out, say, horizons,
                        seeds = as.integer(unlist(cfg$seeds)), tune_seed = as.integer(cfg$tune_seed)) {
  arch <- sh_arch(arch_id)
  target <- cfg$primary_target
  st <- S$panel$station
  dir <- ss_cell_dir(out, st, arch_id, pca)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  base_meta <- list(station = st, target = target, arch = arch_id, pca = ss_pca_label(pca),
                    kind = arch$kind, structure = arch$structure %||% "separate")
  smp <- lapply(stats::setNames(horizons, horizons), function(h)
    sh_samples(cfg, S$panel, S$splits, target, h, S$avail$pollutants))

  # ---- direct
  for (h in horizons) {
    path <- file.path(dir, sprintf("direct_h%d.rds", h))
    if (file.exists(path)) next
    r <- ss_run_direct(cfg, S, smp[[as.character(h)]], target, h, arch, pca, seeds, tune_seed)
    meta <- c(base_meta, list(strategy = "direct", horizon_h = as.integer(h), switch_h = NA_integer_))
    for (k in c("pred", "info", "tuning", "pca")) r[[k]] <- ss_meta(r[[k]], meta)
    r$meta <- meta
    saveRDS(r, path)
    say(sprintf("%s %s %s direct h=%d: %.0f s", st, arch_id, ss_pca_label(pca), h, r$elapsed_s))
  }

  # ---- recursive and hybrid
  sw <- as.integer(unlist(scfg$hybrid$switch_points))
  hc <- ss_hybrid_cells(horizons, sw)
  rec_path <- file.path(dir, "recursive.rds")
  hyb_paths <- file.path(dir, sprintf("hybrid_s%d_h%d.rds", hc$s, hc$h))
  if (file.exists(rec_path) && all(file.exists(hyb_paths))) return(invisible(NULL))

  t0 <- proc.time()[["elapsed"]]
  units <- ss_fit_onestep(cfg, S, arch, target, pca, seeds, tune_seed, say)
  t_fit <- proc.time()[["elapsed"]] - t0
  need_for <- function(b) {
    d <- data.table::rbindlist(lapply(names(smp), function(h)
      data.table::data.table(origin_idx = smp[[h]]$origin_idx[smp[[h]]$block == b], h = as.integer(h))))
    d[, .(need = max(h)), by = origin_idx][order(origin_idx)]
  }
  rec <- list(); snaps <- list(); t_rec <- c()
  for (b in c("validation", "test")) {
    nb <- need_for(b)
    t1 <- proc.time()[["elapsed"]]
    r <- ss_recurse(S, arch, target, units, nb$origin_idx, nb$need,
                    version = if (b == "validation") "sel" else "ref", record = horizons,
                    snap = if (nrow(hc)) sw else integer(0))
    t_rec[b] <- proc.time()[["elapsed"]] - t1
    rec[[b]] <- r$pred; snaps[[b]] <- r$snaps
  }
  say(sprintf("%s %s %s recursive: one-step fits %.0f s, recursion %.0f s", st, arch_id,
              ss_pca_label(pca), t_fit, sum(t_rec)))
  if (!file.exists(rec_path)) {
    pred <- data.table::rbindlist(lapply(horizons, function(h)
      ss_meta(ss_recursive_pred(S, target, h, smp[[as.character(h)]], rec),
              c(base_meta, list(strategy = "recursive", horizon_h = as.integer(h), switch_h = NA_integer_)))))
    saveRDS(list(pred = pred, meta = base_meta,
                 onestep = ss_meta(data.table::rbindlist(lapply(units, `[[`, "summary")), base_meta),
                 onestep_mae = ss_meta(data.table::rbindlist(lapply(units, `[[`, "onestep_mae")), base_meta),
                 elapsed = list(onestep_fit_s = t_fit, recursion_s = sum(t_rec),
                                recursion_by_block_s = as.list(t_rec), n_units = length(units))),
            rec_path)
  }

  if (!nrow(hc) || all(file.exists(hyb_paths))) return(invisible(NULL))
  # cross-fitted one-step models -> recursive inputs for the training origins
  t2 <- proc.time()[["elapsed"]]
  tr_orig <- unique(unlist(lapply(unique(hc$h), function(h) {
    s <- smp[[as.character(h)]]; s$origin_idx[s$block == "train"] })))
  folds <- ss_folds(tr_orig, as.integer(scfg$hybrid$crossfit_folds))
  units <- ss_crossfit_units(units, folds, ss_back(S$panel), max(sw))
  tr_snaps <- NULL
  for (f in seq_along(folds)) {
    r <- ss_recurse(S, arch, target, units, folds[[f]], rep(max(sw), length(folds[[f]])),
                    version = paste0("cf", f), record = integer(0), snap = sw)
    tr_snaps <- if (is.null(tr_snaps)) r$snaps else
      lapply(stats::setNames(names(r$snaps), names(r$snaps)), function(s) ss_state_rbind(tr_snaps[[s]], r$snaps[[s]]))
  }
  t_cf <- proc.time()[["elapsed"]] - t2
  cf_n <- data.table::rbindlist(lapply(units, function(u) data.table::data.table(
    pollutant = u$v, component = u$component, fold = seq_along(folds),
    n_fold_origins = lengths(folds),
    n_train_rows = vapply(seq_along(folds), function(f) u$models[[1]][[paste0("cf", f, "_n")]], 1L),
    n_train_all = length(u$ds_train$y))))
  say(sprintf("%s %s %s cross-fit (%d folds): %.0f s", st, arch_id, ss_pca_label(pca), length(folds), t_cf))
  for (i in seq_len(nrow(hc))) {
    s <- hc$s[i]; h <- hc$h[i]
    if (file.exists(hyb_paths[i])) next
    sn <- list(train = tr_snaps[[as.character(s)]], validation = snaps$validation[[as.character(s)]],
               test = snaps$test[[as.character(s)]])
    ds_list <- lapply(ss_units(S$panel, arch), function(cp)
      ss_hybrid_ds(S, arch, target, h, s, smp[[as.character(h)]], sn, component = cp))
    r <- ss_run_units(cfg, S$panel, arch, target, ds_list, pca, seeds, tune_seed)
    meta <- c(base_meta, list(strategy = "hybrid", horizon_h = as.integer(h), switch_h = as.integer(s)))
    for (k in c("pred", "info", "tuning", "pca")) r[[k]] <- ss_meta(r[[k]], meta)
    r$meta <- meta
    r$crossfit <- list(elapsed_s = t_cf, folds = ss_meta(cf_n, base_meta))
    saveRDS(r, hyb_paths[i])
    say(sprintf("%s %s %s hybrid s=%d h=%d: %.0f s", st, arch_id, ss_pca_label(pca), s, h, r$elapsed_s))
  }
  invisible(NULL)
}

# ---- smoke -----------------------------------------------------------------------------------
# Every primary architecture on one station with the light LightGBM config and
# one seed: all three strategies, PCA none and one threshold. Checks shared
# target timestamps, finiteness, reconstruction, valid switch points and a
# sanity bound against persistence.
ss_stage_smoke <- function(cfg, scfg, out, say, load_station) {
  dir <- file.path(out, "smoke")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(dir, "SMOKE_PASSED"))
  sc <- cfg
  sc$families$lightgbm <- list(base = cfg$smoke$lightgbm$base)
  ssc <- scfg
  ssc$hybrid$switch_points <- scfg$smoke$switch_points
  S <- load_station(scfg$smoke$station)
  hs <- as.integer(unlist(scfg$smoke$horizons))
  pcas <- lapply(unlist(scfg$smoke$pca), function(p) if (p == "none") "none" else as.numeric(p))
  tseed <- as.integer(cfg$tune_seed)
  target <- cfg$primary_target
  checks <- list(); rows <- list()
  for (a in unlist(scfg$smoke$architectures)) for (p in pcas) {
    t0 <- proc.time()[["elapsed"]]
    ss_run_cell(sc, ssc, S, a, p, dir, say, hs, seeds = tseed, tune_seed = tseed)
    cdir <- ss_cell_dir(dir, S$panel$station, a, p)
    files <- list.files(cdir, pattern = "[.]rds$", full.names = TRUE)
    pred <- data.table::rbindlist(lapply(files, function(f) readRDS(f)$pred), fill = TRUE)
    key <- paste(a, ss_pca_label(p))
    hc <- ss_hybrid_cells(hs, ssc$hybrid$switch_points)
    checks[[paste(key, "hybrid files exactly for s < h")]] <-
      setequal(basename(files[grepl("hybrid", files)]), sprintf("hybrid_s%d_h%d.rds", hc$s, hc$h))
    checks[[paste(key, "all forecasts finite")]] <- all(is.finite(pred$yhat))
    for (h in hs) {
      smp <- sh_samples(cfg, S$panel, S$splits, target, h, S$avail$pollutants)
      ref <- sort(smp$target_idx[smp$block != "train"])
      lev <- pred[component == "LEVEL" & horizon_h == h & block != "train"]
      sets <- split(lev$target_idx, paste(lev$strategy, lev$switch_h, lev$seed))
      checks[[paste(key, "h", h, "same target hours in every strategy")]] <-
        all(vapply(sets, function(x) identical(sort(x), ref), logical(1)))
      if (sh_arch(a)$kind == "decomp") {
        d <- pred[horizon_h == h, .(lev = sum(yhat[component == "LEVEL"]), cs = sum(yhat[component != "LEVEL"])),
                  by = .(strategy, switch_h, seed, block, origin_idx)]
        checks[[paste(key, "h", h, "level = sum of components")]] <- max(abs(d$lev - d$cs)) < 1e-8
      }
      pers <- S$panel$fill[[target]][smp$origin_idx[smp$block == "test"]]
      mae_p <- mean(abs(pers - S$panel$observed[[target]][smp$target_idx[smp$block == "test"]]))
      m <- lev[block == "test", .(MAE = mean(abs(yhat - y))), by = .(strategy, switch_h)]
      checks[[paste(key, "h", h, "test MAE < 3 x persistence")]] <- all(m$MAE < 3 * mae_p)
      rows[[paste(key, h)]] <- cbind(arch = a, pca = ss_pca_label(p), horizon_h = h, m, persistence_MAE = mae_p)
    }
    say(sprintf("smoke %s %s: %.0f s", a, ss_pca_label(p), proc.time()[["elapsed"]] - t0))
  }
  mv_write_csv(data.table::rbindlist(rows), file.path(dir, "SMOKE_METRICS.csv"))
  chk <- data.frame(check = names(checks), pass = unlist(checks))
  mv_write_csv(chk, file.path(dir, "SMOKE_CHECKS.csv"))
  say("smoke checks: ", sum(chk$pass), "/", nrow(chk))
  if (all(chk$pass)) writeLines(format(Sys.time()), file.path(dir, "SMOKE_PASSED"))
  else stop("smoke failed: ", paste(chk$check[!chk$pass], collapse = "; "))
}
