# Changes later observations and checks that fitted fill-model parameters stay the same.

source("code/tests/preprocessing/_lib.R")
tz <- "Asia/Kolkata"
n <- 2000L
times <- seq(as.POSIXct("2023-01-01 00:00:00", tz = tz), by = "hour", length.out = n)
sel <- as.POSIXct("2023-02-01 00:00:00", tz = tz)
y <- 15 + rnorm(n)
y[seq(40, 80)] <- NA_real_
train <- which(times < sel)
m7a <- fit_m7(y, times, train)
yp <- y
yp[times >= sel] <- yp[times >= sel] + 80
m7b <- fit_m7(yp, times, train)
p1a_ok("sel_m7_sigma",
       abs(m7a$sigma_eps - m7b$sigma_eps) < 1e-12 &&
         abs(m7a$sigma_eta - m7b$sigma_eta) < 1e-12,
       "M7 parameters ignore data after selection_end")

wide <- tibble::tibble(`PM2.5` = y, PM10 = y + 8)
wide2 <- wide
wide2$`PM2.5`[times >= sel] <- wide2$`PM2.5`[times >= sel] + 80
m8a <- fit_m8(wide, "PM2.5", "PM10", times, train)
m8b <- fit_m8(wide2, "PM2.5", "PM10", times, train)
ca <- stats::coef(m8a$fit)
cb <- stats::coef(m8b$fit)
p1a_ok("sel_m8_coef", max(abs(ca - cb), na.rm = TRUE) < 1e-12,
       "M8 coefficients ignore data after selection_end")

# Choice yaml is only written from data before selection_end (benchmark filters timestamp < sel).
hourly <- tibble::tibble(
  station = "S", variable = "PM2.5", timestamp = times,
  value_masked = y, value_hourly_raw = y, is_masked = !is.finite(y),
  is_scorable = is.finite(y)
)
cfg <- .p1a_cfg()
cfg$selection_end <- "2023-02-01 00:00"
b1 <- benchmark_imputation(hourly, cfg, n_art = 20L)
c1 <- choose_imputation(b1)
hourly2 <- hourly
hourly2$value_masked[times >= sel] <- hourly2$value_masked[times >= sel] + 80
hourly2$value_hourly_raw <- hourly2$value_masked
b2 <- benchmark_imputation(hourly2, cfg, n_art = 20L)
c2 <- choose_imputation(b2)
p1a_ok("sel_choice", identical(c1, c2),
       "imputation choice ignores data after selection_end")
