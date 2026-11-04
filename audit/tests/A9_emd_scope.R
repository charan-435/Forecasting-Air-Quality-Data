# A9: EMD is an extension only — scored for CPCB/ID1 PM2.5, never in headline bake-off.
source("audit/tests/_lib.R")

ext <- paste(readLines("run_extensions.R"), collapse = "\n")
emd_keys_scoped <- grepl('EMD_KEYS <- c\\("CPCB_PM2\\.5", "ID1_PM2\\.5"\\)', ext)

rmd <- paste(readLines("analysis.Rmd"), collapse = "\n")
emd_on_train_prefix <- grepl("ys\\s*<-\\s*sp_emd\\$y_train\\[seq_len", rmd) ||
  grepl("ys\\s*<-\\s*sp\\$y_train\\[seq_len\\(n_emd\\)\\]", rmd)
emd_section <- grepl("## 10\\.2 EMD vs Haar MODWT", rmd)

scores <- readRDS(file.path(RES_DIR, "scores.rds"))
has_emd_method <- any(grepl("emd", scores$method, ignore.case = TRUE))
ext_scores <- if (file.exists(file.path(RES_DIR, "extension_scores.rds")))
  readRDS(file.path(RES_DIR, "extension_scores.rds")) else NULL
ext_has_emd <- !is.null(ext_scores) && any(grepl("emd", ext_scores$filter, ignore.case = TRUE))

if (ext_has_emd) {
  emd_rows <- ext_scores[grepl("emd", ext_scores$filter, ignore.case = TRUE), ]
  emd_pm25_only <- all(emd_rows$pollutant == "PM2.5") &&
    all(emd_rows$sensor %in% c("CPCB", "ID1"))
} else {
  emd_pm25_only <- FALSE
}

audit_info("EMD_KEYS scoped to CPCB/ID1 PM2.5? ", emd_keys_scoped)
audit_info("EMD section in analysis.Rmd? ", emd_section)
audit_info("EMD in scores.csv methods? ", has_emd_method)
audit_info("EMD rows in extension_scores? ", ext_has_emd)
audit_info("analysis.Rmd EMD plot uses train prefix? ", emd_on_train_prefix)

audit_ok("A9_emd_not_in_headline_scores", !has_emd_method,
         "EMD does not contribute rows to scores.csv (headline bake-off)")
audit_ok("A9_emd_in_extension_scores_scoped", ext_has_emd && emd_pm25_only && emd_keys_scoped,
         "EMD appears only in extension_scores for CPCB/ID1 PM2.5")
audit_ok("A9_emd_documented_and_demo_on_train", emd_section && emd_on_train_prefix,
         "Rmd §10.2 documents EMD; Shiny/demo uses a train prefix, not the test set")
