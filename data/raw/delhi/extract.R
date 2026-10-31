# Pull two Delhi CAAQMS stations from the 600 MB vonter dump.
# Full-city Delhi is too large; ITO + R K Puram are the same CPCB 15-min
# sensor network as Shillong and stay around 1.4 MB.

root <- if (exists("PROJECT_ROOT")) PROJECT_ROOT else getwd()
src <- file.path(root, "data", "raw", "vonter", "cpcb-air-quality-2023.parquet")
out <- file.path(root, "data", "raw", "delhi", "cpcb_delhi_2023.parquet")
if (!file.exists(src)) stop("Missing vonter dump: ", src)

library(arrow)
library(dplyr)

ds <- arrow::open_dataset(src)
st <- ds %>%
  dplyr::filter(.data$City == "Delhi") %>%
  dplyr::distinct(`Station ID`, `Station Name`) %>%
  dplyr::collect()
cat("Delhi stations in dump:\n")
print(as.data.frame(st))

want_pat <- c("ITO", "R K Puram", "RK Puram", "R.K. Puram")
hit <- st[Reduce(`|`, lapply(want_pat, function(p) grepl(p, st$`Station Name`, ignore.case = TRUE))), ]
if (nrow(hit) < 2L) {
  counts <- ds %>%
    dplyr::filter(.data$City == "Delhi") %>%
    dplyr::count(`Station ID`, `Station Name`) %>%
    dplyr::arrange(dplyr::desc(n)) %>%
    dplyr::collect()
  hit <- counts[seq_len(min(2L, nrow(counts))), c("Station ID", "Station Name")]
}
ids <- unique(as.character(hit$`Station ID`))
cat("Extracting Station IDs: ", paste(ids, collapse = ", "), "\n", sep = "")

raw <- ds %>%
  dplyr::filter(.data$`Station ID` %in% ids) %>%
  dplyr::collect()
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
arrow::write_parquet(raw, out, compression = "zstd")
stopifnot(file.exists(out))
cat("Wrote ", out, " rows=", nrow(raw), " bytes=", file.info(out)$size, "\n", sep = "")
print(as.data.frame(dplyr::count(raw, `Station ID`, `Station Name`)))
