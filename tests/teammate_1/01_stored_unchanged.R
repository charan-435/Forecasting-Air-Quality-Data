# Stored Haar J=5 components are loaded unchanged. T1 never recomputes MODWT.

path <- t1_decomp_parquet_path("CPCB", "PM2.5")
t1_ok("T1-01a", file.exists(path),
      paste("stored parquet exists:", path))

if (file.exists(path)) {
  fp0 <- t1_file_fingerprint(path)
  raw0 <- arrow::read_parquet(path)
  df <- t1_load_stored_components("CPCB", "PM2.5")
  fp1 <- t1_file_fingerprint(path)
  raw1 <- arrow::read_parquet(path)

  t1_ok("T1-01b", identical(fp0$md5, fp1$md5),
        "parquet md5 unchanged after get_decomp")
  t1_ok("T1-01c", identical(fp0$size, fp1$size),
        "parquet size unchanged")
  t1_ok("T1-01d", isTRUE(all.equal(as.data.frame(raw0), as.data.frame(raw1))),
        "parquet bytes/columns identical on re-read")
  t1_ok("T1-01e", all(T1_COMPONENTS %in% names(df)),
        "loaded columns include D1-D5 and S5")
  t1_ok("T1-01f", identical(attr(df, "t1_source_md5"), fp0$md5),
        "loader records the source md5")

  for (nm in T1_COMPONENTS) {
    a <- as.numeric(raw0[[nm]])
    b <- as.numeric(df[[nm]])
    n <- min(length(a), length(b))
    t1_ok(paste0("T1-01g-", nm),
          isTRUE(all.equal(a[seq_len(n)], b[seq_len(n)])),
          paste(nm, "values match the parquet"))
  }
}
