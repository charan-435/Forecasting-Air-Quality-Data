# Causal gap filling. Fills are model inputs only and are never scored.

.gap_bookkeeping <- function(masked, long_gap_hours = 72L) {
  n <- length(masked)
  gap_id <- rep(NA_integer_, n)
  gap_len_sofar <- rep(0L, n)
  hours_since <- rep(NA_real_, n)
  gid <- 0L
  last_obs <- NA_integer_
  in_gap <- FALSE
  for (t in seq_len(n)) {
    if (is.finite(masked[t])) {
      in_gap <- FALSE
      last_obs <- t
      hours_since[t] <- 0
      gap_len_sofar[t] <- 0L
    } else {
      if (!in_gap) {
        gid <- gid + 1L
        in_gap <- TRUE
      }
      gap_id[t] <- gid
      gap_len_sofar[t] <- if (t == 1L || is.na(gap_id[t - 1L])) 1L else gap_len_sofar[t - 1L] + 1L
      hours_since[t] <- if (is.na(last_obs)) NA_real_ else as.numeric(t - last_obs)
    }
  }
  in_long <- !is.na(gap_id) & gap_len_sofar > long_gap_hours
  list(gap_id = gap_id, gap_len_sofar = as.integer(gap_len_sofar),
       hours_since_observed = hours_since, in_long_gap = in_long)
}

.frac_filled_trailing <- function(is_filled, w) {
  n <- length(is_filled)
  out <- rep(NA_real_, n)
  cs <- c(0, cumsum(as.numeric(is_filled)))
  for (i in seq_len(n)) {
    lo <- max(1L, i - w + 1L)
    out[i] <- (cs[i + 1L] - cs[lo]) / (i - lo + 1L)
  }
  out
}

.gap_bucket <- function(len) {
  ifelse(len <= 3L, "1-3",
         ifelse(len <= 24L, "4-24",
                ifelse(len <= 72L, "25-72", ">72")))
}

.clim_value <- function(filled, times, t, days = 28L, observed = NULL,
                        hod = NULL, we = NULL) {
  if (t < 2L) return(NA_real_)
  if (is.null(hod)) hod <- lubridate::hour(times)
  if (is.null(we)) we <- as.integer(lubridate::wday(times, week_start = 1) >= 6L)
  lo <- times[t] - (days * 24 * 3600)
  idx <- which(times < times[t] & times >= lo)
  if (!length(idx)) return(NA_real_)
  if (!is.null(observed)) idx <- idx[is.finite(observed[idx])]
  else idx <- idx[is.finite(filled[idx])]
  if (!length(idx)) return(NA_real_)
  keep <- hod[idx] == hod[t] & we[idx] == we[t]
  if (!any(keep)) return(mean(filled[idx], na.rm = TRUE))
  mean(filled[idx[keep]], na.rm = TRUE)
}

fill_one_step <- function(method, filled, masked, times, t, gap_len,
                          helpers = NULL, m7 = NULL, m8 = NULL) {
  locf <- function() {
    if (t < 2L) return(NA_real_)
    z <- filled[t - 1L]
    if (is.finite(z)) z else {
      prev <- filled[seq_len(t - 1L)]
      prev <- prev[is.finite(prev)]
      if (length(prev)) tail(prev, 1) else NA_real_
    }
  }
  seas <- function(lag) {
    j <- t - lag
    if (j < 1L) return(locf())
    if (is.finite(filled[j])) filled[j] else locf()
  }
  switch(method,
    M1 = locf(),
    M2 = seas(24L),
    M3 = seas(168L),
    M4 = if (gap_len <= 3L) locf() else seas(24L),
    M5 = {
      a <- locf(); b <- .clim_value(filled, times, t, 28L, observed = masked,
                                   hod = helpers$hod, we = helpers$we)
      w <- exp(-gap_len / 6)
      if (!is.finite(a) && !is.finite(b)) NA_real_
      else if (!is.finite(a)) b
      else if (!is.finite(b)) a
      else w * a + (1 - w) * b
    },
    M6 = {
      b <- .clim_value(filled, times, t, 28L, observed = masked,
                      hod = helpers$hod, we = helpers$we)
      if (is.finite(b)) b else locf()
    },
    M7 = {
      if (is.null(m7) || is.null(helpers$.m7_state)) locf()
      else helpers$.m7_state$yhat
    },
    M8 = {
      if (!is.null(m8) && !is.null(helpers)) {
        pred <- m8$predict(helpers, times, t)
        if (is.finite(pred)) return(pred)
      }
      fill_one_step("M4", filled, masked, times, t, gap_len)
    },
    locf()
  )
}

fit_m7 <- function(y, times, train_idx = NULL) {
  if (is.null(train_idx)) train_idx <- which(is.finite(y))
  ytr <- y[train_idx]
  ttr <- times[train_idx]
  ok <- is.finite(ytr)
  if (sum(ok) < 48L) return(NULL)
  hod <- lubridate::hour(ttr[ok])
  seas <- tapply(ytr[ok], hod, mean, na.rm = TRUE)
  sigma_eta <- stats::sd(diff(ytr[ok]), na.rm = TRUE)
  sigma_eps <- stats::sd(ytr[ok] - as.numeric(seas[as.character(hod)]), na.rm = TRUE)
  if (!is.finite(sigma_eta) || sigma_eta == 0) sigma_eta <- 1
  if (!is.finite(sigma_eps) || sigma_eps == 0) sigma_eps <- 1
  fallback <- mean(ytr[ok])
  list(
    seas = seas,
    sigma_eta = sigma_eta,
    sigma_eps = sigma_eps,
    fallback = fallback
  )
}

.m7_step <- function(state, m7, yi, hour_i) {
  se <- function(h) {
    v <- unname(m7$seas[as.character(h)])
    if (length(v) != 1L || !is.finite(v)) m7$fallback else v
  }
  mu <- state$mu; P <- state$P
  P <- P + m7$sigma_eta^2
  if (is.finite(yi)) {
    z <- yi - se(hour_i)
    S <- P + m7$sigma_eps^2
    K <- P / S
    mu <- mu + K * (z - mu)
    P <- (1 - K) * P
  }
  list(mu = mu, P = P, yhat = mu + se(hour_i))
}

fit_m8 <- function(wide_obs, target, driver, times, selection_idx) {
  if (!all(c(target, driver) %in% names(wide_obs))) return(NULL)
  y <- wide_obs[[target]][selection_idx]
  x <- wide_obs[[driver]][selection_idx]
  hod <- lubridate::hour(times[selection_idx])
  ok <- is.finite(y) & is.finite(x)
  if (sum(ok) < 40L) return(NULL)
  dat <- data.frame(y = log1p(pmax(y[ok], 0)), x = log1p(pmax(x[ok], 0)),
                    hod = factor(hod[ok], levels = 0:23))
  fit <- tryCatch(stats::lm(y ~ x + hod, data = dat), error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  list(
    driver = driver,
    fit = fit,
    predict = function(helpers, times, t) {
      xv <- helpers[[driver]][t]
      if (!is.finite(xv)) return(NA_real_)
      nd <- data.frame(x = log1p(max(xv, 0)), hod = factor(lubridate::hour(times[t]), levels = 0:23))
      ph <- tryCatch(stats::predict(fit, newdata = nd), error = function(e) NA_real_)
      if (!is.finite(ph)) return(NA_real_)
      pmax(expm1(as.numeric(ph)), 0)
    }
  )
}

.m8_driver <- function(variable) {
  switch(variable, `PM2.5` = "PM10", PM10 = "PM2.5", CO = "NO2", NO2 = "CO", NA_character_)
}

apply_fills <- function(masked, times, method_by_bucket, helpers = NULL,
                        m7 = NULL, m8 = NULL) {
  n <- length(masked)
  filled <- masked
  fill_method <- rep(NA_character_, n)
  bk <- .gap_bookkeeping(masked)
  if (is.null(helpers)) helpers <- list()
  if (is.null(helpers$hod)) helpers$hod <- lubridate::hour(times)
  if (is.null(helpers$we)) helpers$we <- as.integer(lubridate::wday(times, week_start = 1) >= 6L)
  m7_state <- list(mu = 0, P = 1e4, yhat = NA_real_)
  for (t in seq_len(n)) {
    if (!is.null(m7)) {
      m7_state <- .m7_step(m7_state, m7, masked[t], helpers$hod[t])
      helpers$.m7_state <- m7_state
    }
    if (is.finite(masked[t])) {
      filled[t] <- masked[t]
    } else {
      bucket <- .gap_bucket(bk$gap_len_sofar[t])
      method <- method_by_bucket[[bucket]]
      if (is.null(method) || !nzchar(method)) method <- "M4"
      filled[t] <- fill_one_step(method, filled, masked, times, t,
                                 bk$gap_len_sofar[t], helpers, m7, m8)
      if (!is.finite(filled[t])) filled[t] <- fill_one_step("M1", filled, masked, times, t,
                                                           bk$gap_len_sofar[t])
      fill_method[t] <- method
    }
  }
  list(filled = filled, fill_method = fill_method, book = bk)
}

impute_station <- function(st, cfg, choice, m7_fits, m8_fits) {
  st <- st %>% dplyr::arrange(variable, timestamp)
  vars <- unique(st$variable)
  wide_m <- st %>%
    dplyr::select(timestamp, variable, value_masked) %>%
    tidyr::pivot_wider(names_from = variable, values_from = value_masked)
  times <- sort(unique(st$timestamp))
  out_rows <- list()
  for (v in vars) {
    sv <- st %>% dplyr::filter(variable == !!v) %>% dplyr::arrange(timestamp)
    methods <- list()
    for (b in c("1-3", "4-24", "25-72", ">72")) {
      methods[[b]] <- choice[[paste(v, b, sep = "|")]] %||% "M4"
    }
    helpers <- as.list(wide_m)
    m7 <- m7_fits[[v]]
    m8 <- m8_fits[[v]]
    ap <- apply_fills(sv$value_masked, sv$timestamp, methods, helpers, m7, m8)
    is_filled <- !is.na(ap$fill_method)
    sv$value_filled_causal <- ap$filled
    sv$fill_method <- ap$fill_method
    sv$gap_id <- ap$book$gap_id
    sv$gap_len_sofar <- ap$book$gap_len_sofar
    sv$hours_since_observed <- ap$book$hours_since_observed
    sv$in_long_gap <- ap$book$in_long_gap
    sv$frac_filled_24h <- .frac_filled_trailing(is_filled, 24L)
    sv$frac_filled_168h <- .frac_filled_trailing(is_filled, 168L)
    out_rows[[v]] <- sv
  }
  dplyr::bind_rows(out_rows)
}

skip_impute <- function(st, cfg) {
  # Paper / already-clean sources: do not fill. Schema columns still exist.
  st <- st %>% dplyr::arrange(variable, timestamp)
  dplyr::bind_rows(lapply(split(st, st$variable), function(sv) {
    y <- sv$value_masked
    sv$value_filled_causal <- y
    sv$fill_method <- NA_character_
    is_filled <- !is.na(sv$fill_method)
    bk <- .gap_bookkeeping(y, cfg$long_gap_hours)
    sv$gap_id <- bk$gap_id
    sv$gap_len_sofar <- bk$gap_len_sofar
    sv$hours_since_observed <- bk$hours_since_observed
    sv$in_long_gap <- bk$in_long_gap
    sv$frac_filled_24h <- .frac_filled_trailing(is_filled, 24L)
    sv$frac_filled_168h <- .frac_filled_trailing(is_filled, 168L)
    sv
  }))
}

.real_gap_lengths <- function(masked) {
  r <- rle(!is.finite(masked))
  as.integer(r$lengths[r$values])
}

.punch_gaps <- function(x, lengths, n_gaps, seed = 1L) {
  set.seed(seed)
  n <- length(x)
  observed <- is.finite(x)
  runs <- rle(observed)
  pos <- cumsum(runs$lengths)
  starts <- pos - runs$lengths + 1L
  blocks <- which(runs$values & runs$lengths > 24L)
  holes <- integer()
  truth <- x
  punched <- x
  if (!length(lengths)) lengths <- c(1L, 3L, 6L, 12L, 24L, 72L, 168L)
  k <- 0L
  tries <- 0L
  while (k < n_gaps && tries < n_gaps * 20L && length(blocks)) {
    tries <- tries + 1L
    b <- sample(blocks, 1L)
    L <- sample(lengths, 1L)
    max_start <- runs$lengths[b] - L - 2L
    if (max_start < 2L) next
    off <- sample.int(max_start, 1L)
    s <- starts[b] + off
    e <- s + L - 1L
    if (any(!is.finite(punched[s:e]))) next
    punched[s:e] <- NA_real_
    holes <- c(holes, s:e)
    k <- k + 1L
  }
  list(punched = punched, holes = unique(holes), truth = truth)
}

.station_wide_rate <- function(st) {
  miss <- st %>%
    dplyr::group_by(timestamp) %>%
    dplyr::summarise(
      n_var = dplyr::n(),
      n_miss = sum(!is.finite(.data$value_masked)),
      .groups = "drop"
    )
  if (!nrow(miss)) return(0)
  mean(miss$n_miss == miss$n_var & miss$n_miss > 0)
}

.score_holes <- function(filled, truth, holes, gap_len, station, variable, method) {
  if (!length(holes)) return(NULL)
  buckets <- c("1-3", "4-24", "25-72", ">72")
  err <- abs(filled[holes] - truth[holes])
  loge <- abs(log1p(pmax(filled[holes], 0)) - log1p(pmax(truth[holes], 0)))
  bk <- .gap_bucket(gap_len[holes])
  dplyr::bind_rows(lapply(buckets, function(b) {
    ii <- which(bk == b)
    if (!length(ii)) return(NULL)
    tibble::tibble(
      station = station, variable = variable, method = method, bucket = b,
      n = length(ii),
      mae = mean(err[ii], na.rm = TRUE),
      mae_log1p = mean(loge[ii], na.rm = TRUE)
    )
  }))
}

benchmark_imputation <- function(hourly, cfg, n_art = 500L) {
  sel <- pp_parse_time(cfg$selection_end, "Asia/Kolkata")
  methods <- paste0("M", 1:8)
  buckets <- c("1-3", "4-24", "25-72", ">72")
  rows <- list()
  stations <- unique(hourly$station)
  use_parallel <- n_art >= 80L && requireNamespace("future.apply", quietly = TRUE)
  if (use_parallel) {
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)
    n_w <- max(1L, min(8L, future::availableCores() - 1L))
    future::plan(future::multisession, workers = n_w)
    pp_log("benchmark parallel workers=", n_w)
  }
  for (stn in stations) {
    st <- hourly %>% dplyr::filter(station == !!stn, timestamp < sel) %>%
      dplyr::arrange(variable, timestamp)
    if (!nrow(st)) next
    vars <- unique(st$variable)
    times <- sort(unique(st$timestamp))
    wide <- st %>%
      dplyr::select(timestamp, variable, value_masked) %>%
      tidyr::pivot_wider(names_from = variable, values_from = value_masked)
    sw_rate <- .station_wide_rate(st)
    n_sim <- max(if (n_art >= 80L) 10L else 2L,
                 as.integer(round(n_art * max(sw_rate, 0.05))))
    n_sim <- min(n_sim, n_art)
    pm <- st %>% dplyr::filter(variable == "PM2.5") %>% dplyr::arrange(timestamp)
    gl_sw <- if (nrow(pm)) .real_gap_lengths(pm$value_masked) else integer()
    if (length(gl_sw) < 10L) gl_sw <- c(3L, 6L, 12L, 24L)
    punch_sw <- if (nrow(pm))
      .punch_gaps(pm$value_masked, gl_sw, n_sim, seed = 99L + nchar(stn))
    else list(holes = integer())

    one_var <- function(v) {
      sv <- st %>% dplyr::filter(variable == !!v) %>% dplyr::arrange(timestamp)
      y <- sv$value_masked
      gl <- .real_gap_lengths(y)
      if (length(gl) < 30L) gl <- c(1L, 3L, 6L, 12L, 24L, 72L, 168L)
      punch <- .punch_gaps(y, gl, n_art, seed = 7L + nchar(v) + nchar(stn))
      punched <- punch$punched
      punched[punch_sw$holes] <- NA_real_
      holes <- unique(c(punch$holes, punch_sw$holes))
      m7 <- fit_m7(y, sv$timestamp)
      drv <- .m8_driver(v)
      m8 <- if (!is.na(drv)) fit_m8(wide, v, drv, times,
                                    which(times %in% sv$timestamp)) else NULL
      helpers <- as.list(wide)
      helpers_sim <- helpers
      for (nm in names(helpers_sim)) helpers_sim[[nm]][punch_sw$holes] <- NA_real_
      out <- list()
      for (m in methods) {
        mb <- setNames(as.list(rep(m, 4)), buckets)
        hp <- if (identical(m, "M8")) helpers_sim else helpers
        ap <- apply_fills(punched, sv$timestamp, mb, hp, m7, m8)
        out[[m]] <- .score_holes(ap$filled, y, holes, ap$book$gap_len_sofar,
                                 stn, v, m)
      }
      dplyr::bind_rows(out)
    }

    if (use_parallel) {
      var_rows <- tryCatch(
        future.apply::future_lapply(vars, one_var, future.seed = TRUE),
        error = function(e) {
          pp_log("WARN parallel benchmark failed: ", e$message, " — sequential")
          lapply(vars, one_var)
        }
      )
    } else {
      var_rows <- lapply(vars, one_var)
    }
    rows[[length(rows) + 1L]] <- dplyr::bind_rows(var_rows)
  }
  dplyr::bind_rows(rows)
}

choose_imputation <- function(bench, fallback = "M4") {
  core <- bench %>% dplyr::filter(method %in% paste0("M", 1:8), bucket != "all")
  if (!nrow(core)) {
    buckets <- c("1-3", "4-24", "25-72", ">72")
    vars <- unique(bench$variable)
    if (!length(vars)) vars <- CANON_VARS
    choice <- list()
    for (v in vars) for (b in buckets) choice[[paste(v, b, sep = "|")]] <- fallback
    return(choice)
  }
  ranked <- core %>%
    dplyr::group_by(station, variable, bucket) %>%
    dplyr::mutate(rank = rank(mae, ties.method = "min")) %>%
    dplyr::ungroup() %>%
    dplyr::group_by(variable, bucket, method) %>%
    dplyr::summarise(mean_rank = mean(rank, na.rm = TRUE), .groups = "drop") %>%
    dplyr::group_by(variable, bucket) %>%
    dplyr::slice_min(mean_rank, n = 1, with_ties = FALSE) %>%
    dplyr::ungroup()
  choice <- list()
  for (i in seq_len(nrow(ranked))) {
    choice[[paste(ranked$variable[i], ranked$bucket[i], sep = "|")]] <- ranked$method[i]
  }
  buckets <- c("1-3", "4-24", "25-72", ">72")
  for (v in unique(core$variable)) {
    for (b in buckets) {
      k <- paste(v, b, sep = "|")
      if (is.null(choice[[k]])) choice[[k]] <- fallback
    }
  }
  choice
}

write_imputation_choice <- function(choice, path = NULL) {
  if (is.null(path)) path <- file.path(PROJECT_ROOT, "config", "imputation_choice.yaml")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  nested <- list()
  for (k in names(choice)) {
    parts <- strsplit(k, "|", fixed = TRUE)[[1]]
    nested[[parts[1]]][[parts[2]]] <- choice[[k]]
  }
  yaml::write_yaml(nested, path)
  path
}

read_imputation_choice <- function(path = NULL) {
  if (is.null(path)) path <- file.path(PROJECT_ROOT, "config", "imputation_choice.yaml")
  if (!file.exists(path)) return(NULL)
  y <- yaml::read_yaml(path)
  choice <- list()
  for (v in names(y)) {
    for (b in names(y[[v]])) {
      choice[[paste(v, b, sep = "|")]] <- y[[v]][[b]]
    }
  }
  choice
}
