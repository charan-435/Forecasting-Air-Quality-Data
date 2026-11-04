# A9: EMD is computed where, and does it enter scores?
source("audit/tests/_lib.R")

ext <- paste(readLines("run_extensions.R"), collapse = "\n")
emd_keys_empty <- grepl("EMD_KEYS <- character\\(0\\)", ext)

rmd <- paste(readLines("analysis.Rmd"), collapse = "\n")
emd_on_train_prefix <- grepl("ys    <- sp\\$y_train\\[seq_len\\(n_emd\\)\\]", rmd)

scores <- readRDS(file.path(RES_DIR, "scores.rds"))
has_emd_method <- any(grepl("emd", scores$method, ignore.case = TRUE))
ext_scores <- if (file.exists(file.path(RES_DIR, "extension_scores.rds")))
  readRDS(file.path(RES_DIR, "extension_scores.rds")) else NULL
ext_has_emd <- !is.null(ext_scores) && any(grepl("emd", ext_scores$filter, ignore.case = TRUE))

audit_info("EMD_KEYS empty in run_extensions.R? ", emd_keys_empty)
audit_info("EMD in scores.csv methods? ", has_emd_method)
audit_info("EMD rows in extension_scores? ", ext_has_emd)
audit_info("analysis.Rmd EMD plot uses first 500h of y_train? ", emd_on_train_prefix)

audit_ok("A9_emd_not_in_headline_scores", !has_emd_method && !ext_has_emd,
         "EMD does not contribute rows to scores.csv / extension_scores")
audit_ok("A9_emd_plot_on_train_prefix", emd_on_train_prefix,
         "Shiny EMD demo uses the first 500 hours of y_train, not the test set")
