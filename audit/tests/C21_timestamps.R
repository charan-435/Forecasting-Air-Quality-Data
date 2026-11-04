# C21: dmy_hm parsing, gaps, duplicates, last=first CPCB row.
source("audit/tests/_lib.R")

raw <- load_raw_datasets()
rows <- list()
for (nm in names(raw)) {
  dt <- raw[[nm]]$Datetime
  d <- as.numeric(diff(dt), units = "hours")
  rows[[nm]] <- tibble::tibble(
    sensor = nm,
    n = length(dt),
    tmin = as.character(min(dt, na.rm = TRUE)),
    tmax = as.character(max(dt, na.rm = TRUE)),
    n_na_time = sum(is.na(dt)),
    n_dup = sum(duplicated(dt)),
    min_gap_h = min(d, na.rm = TRUE),
    median_gap_h = stats::median(d, na.rm = TRUE),
    max_gap_h = max(d, na.rm = TRUE),
    n_gap_gt_1 = sum(d > 1.01, na.rm = TRUE),
    tz = paste(unique(lubridate::tz(dt)), collapse = ",")
  )
}
tab <- dplyr::bind_rows(rows)
write_tbl(tab, "C21_time_gaps.csv")
print(tab)

cpcb <- raw$CPCB
first_eq_last <- isTRUE(all.equal(
  as.numeric(cpcb[1, setdiff(names(cpcb), c("Datetime", "sensor"))]),
  as.numeric(cpcb[nrow(cpcb), setdiff(names(cpcb), c("Datetime", "sensor"))]),
  tolerance = 1e-8
))
audit_info("CPCB row1 == last row (values)? ", first_eq_last)

audit_ok("C21_no_gaps_or_dups",
         all(tab$n_dup == 0) && all(tab$n_gap_gt_1 == 0) && all(tab$n_na_time == 0),
         sprintf("dups=%s gaps>1h=%s na_time=%s",
                 paste(tab$n_dup, collapse = ","),
                 paste(tab$n_gap_gt_1, collapse = ","),
                 paste(tab$n_na_time, collapse = ",")))
audit_ok("C21_cpcb_last_row_not_a_copy_of_first",
         !first_eq_last,
         "CPCB last hour equals the first hour (01-07-2022 00:00 values repeated at 06-07-2023 00:00)")
audit_ok("C21_timezone_explicit",
         all(tab$tz %in% c("UTC", "Asia/Kolkata", "IST")),
         sprintf("lubridate::dmy_hm tz = %s (no tz passed; POSIXct default)",
                 paste(tab$tz, collapse = ",")))
