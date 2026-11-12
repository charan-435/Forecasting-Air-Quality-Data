# Run from the project root: source("scripts/publish_analysis.R")
local({
  if (!file.exists("analysis.Rmd")) stop("Run from the repository root.")
  source("R/reporting/load_report.R", local = TRUE)
  # Include only report helpers: scanning training modules pulls in optional
  # packages and the locally installed Windows CatBoost binary.
  dirs <- c("config", "data", "results", "store")
  files <- sort(unique(c("analysis.Rmd", "R/reporting/load_report.R",
    "R/reporting/report.css", report_helper_files,
    unlist(lapply(dirs, function(p) {
      list.files(p, recursive = TRUE, full.names = TRUE)
    }), use.names = FALSE))))
  missing <- files[!file.exists(files)]
  if (length(missing)) stop("Missing report files: ", paste(missing, collapse = ", "))
  message(sprintf("Report bundle: %d files, %.1f MB", length(files),
                  sum(file.info(files)$size) / 1024^2))
  if (isTRUE(getOption("ats.publish.dry_run", FALSE))) {
    return(invisible(files))
  }
  if (!requireNamespace("rsconnect", quietly = TRUE)) {
    stop('Install rsconnect first: install.packages("rsconnect")')
  }
  # Fail locally before uploading if helper syntax or resource discovery breaks.
  message("Checking report syntax and external resources...")
  for (path in files[grepl("[.]R$", files, ignore.case = TRUE)]) {
    invisible(parse(path, encoding = "UTF-8"))
  }
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop('Install rmarkdown first: install.packages("rmarkdown")')
  }
  invisible(rmarkdown::find_external_resources("analysis.Rmd"))
  message("Report syntax and resource checks passed.")
  record <- "rsconnect/documents/analysis.Rmd/connect.posit.cloud/charan-435/analysis.dcf"
  # Saved records are local state. Fresh checkouts can use these defaults or
  # override them with options(ats.publish.account=..., ats.publish.app_id=...).
  deployment <- if (file.exists(record)) read.dcf(record) else matrix(
    c("01a1cea1-2101-b89f-ca18-d7dd27cfb83e", "charan-435", "connect.posit.cloud"),
    nrow = 1, dimnames = list(NULL, c("appId", "account", "server"))
  )
  rsconnect::deployApp(
    appDir = getwd(), appFiles = files,
    appPrimaryDoc = "analysis.Rmd", appMode = "rmd-shiny",
    appId = getOption("ats.publish.app_id", deployment[1, "appId"]),
    account = getOption("ats.publish.account", deployment[1, "account"]),
    server = deployment[1, "server"],
    launch.browser = FALSE
  )
})
