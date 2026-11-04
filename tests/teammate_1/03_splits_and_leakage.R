# Train/val/test boundaries match chrono_split_tvt. No future observations.

series_path <- file.path(PROC_DIR, "series.rds")
t1_ok("T1-03a", file.exists(series_path),
      "shared prepared series.rds exists")

if (file.exists(series_path)) {
  series_all <- t1_load_prepared_series()
  s <- series_all[["CPCB_PM2.5"]]
  t1_ok("T1-03b", !is.null(s), "CPCB_PM2.5 is in the shared series list")
  if (!is.null(s)) {
    h <- 24L
    sp <- t1_split_y(s, h)
    sp2 <- chrono_split_tvt(s$y, s$times, h, VAL_HOURS)
    t1_ok("T1-03c", identical(sp$n_train, sp2$n_train) &&
            identical(sp$n_val, sp2$n_val) && identical(sp$n_test, sp2$n_test),
          "T1 split lengths match chrono_split_tvt")
    t1_ok("T1-03d", identical(as.numeric(sp$y_test), as.numeric(sp2$y_test)),
          "T1 test slice matches shared helper")
    t1_ok("T1-03e", max(sp$t_train) < min(sp$t_val) &&
            max(sp$t_val) < min(sp$t_test),
          "train times < val times < test times")
    t1_ok("T1-03f", sp$n_test == h, "test length equals horizon")

    decomp <- t1_load_stored_components("CPCB", "PM2.5")
    aligned <- t1_align_components(s, decomp)
    cs <- t1_component_split(aligned, "D3", sp)
    t1_ok("T1-03g", length(cs$train) == sp$n_train &&
            length(cs$val) == sp$n_val && length(cs$test) == sp$n_test,
          "D3 split uses the same index boundaries as Y")
    t1_ok("T1-03h",
          max(as.numeric(cs$t_train), na.rm = TRUE) <
            min(as.numeric(cs$t_test), na.rm = TRUE),
          "component train origin is before component test")

    # Recursive lag row at the origin uses history ending at origin, not test.
    p <- 24L
    hist <- t1_drop_leading_na(cs$train)
    row <- last_lag_row(hist, p)
    t1_ok("T1-03i", isTRUE(all.equal(as.numeric(row[1, 1]), tail(hist, 1))),
          "lag1 at train origin is the last train value (no test leak)")
  }
}

X <- make_lags(1:10, 3)
t1_ok("T1-03j", is.na(X[1, 1]) && X[4, 1] == 3,
      "make_lags never copies a future y into row t")
