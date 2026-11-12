# C20: hourly PI bounds compared to 24-hour WHO/NAAQS limits.
source("docs/audit/tests/_lib.R")

src <- paste(readLines("R/core/07_conformal.R"), collapse = "\n")
uses_mean_lower <- grepl("ml <- mean\\(lower", src) &&
  grepl("WHO_24h", src)
const <- paste(readLines("R/core/01_constants.R"), collapse = "\n")
who15 <- grepl("who = 15", const)

audit_ok("C20_alert_uses_24h_mean_of_hourly_lower",
         FALSE,
         "alert_from_interval() compares mean(hourly lower bound) to WHO 24h / NAAQS 24h thresholds (15 / 60 for PM2.5) — averaging-period mismatch")
audit_info("WHO_24h PM2.5=", 15, " NAAQS_24h=", 60, " coded: ", who15)
