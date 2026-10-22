# Load and standardise the two GitHub datasets.

load_raw_datasets <- function() {
  cpcb_path <- file.path(RAW_DIR, "CPCB.csv")
  id1_path <- file.path(RAW_DIR, "ID1.csv")
  if (!file.exists(cpcb_path) || !file.exists(id1_path)) {
    stop("Raw CSVs not found in data/raw/. Download CPCB.csv and ID1.csv first.")
  }

  cpcb <- readr::read_csv(cpcb_path, show_col_types = FALSE)
  id1 <- readr::read_csv(id1_path, show_col_types = FALSE)

  cpcb <- cpcb %>%
    dplyr::mutate(Datetime = lubridate::dmy_hm(Datetime)) %>%
    dplyr::rename(O3 = Ozone) %>%
    dplyr::select(Datetime, dplyr::any_of(c(POLLUTANTS, "AT", "RH"))) %>%
    dplyr::mutate(sensor = "CPCB")

  # ID1: first column is a leftover index; O3 already named O3.
  id1 <- id1 %>%
    dplyr::mutate(Datetime = lubridate::dmy_hm(Datetime)) %>%
    dplyr::select(Datetime, dplyr::any_of(c(POLLUTANTS, "Temp", "RH"))) %>%
    dplyr::rename(AT = Temp) %>%
    dplyr::mutate(sensor = "ID1")

  list(CPCB = cpcb, ID1 = id1)
}

combine_long <- function(raw_list) {
  dplyr::bind_rows(raw_list) %>%
    tidyr::pivot_longer(
      cols = dplyr::any_of(POLLUTANTS),
      names_to = "pollutant",
      values_to = "value"
    )
}

sampling_hours <- function(dt) {
  d <- as.numeric(diff(dt), units = "hours")
  stats::median(d, na.rm = TRUE)
}
