# B14: seeds / determinism / package versions.
source("docs/audit/tests/_lib.R")

src <- paste(readLines("R/core/06_models.R"), collapse = "\n")
xgb_seed <- grepl("seed", src) && grepl("xgb.train", src)
# crude: catboost has random_seed = 7; xgb/lgb do not set seed.
has_cat_seed <- grepl("random_seed\\s*=\\s*7", src)
has_xgb_seed <- grepl("set.seed|seed\\s*=", paste(readLines("R/core/06_models.R")[
  grep("fit_xgb", readLines("R/core/06_models.R"))[1]:grep("fit_lgb", readLines("R/core/06_models.R"))[1]
], collapse = "\n"))

ver <- utils::sessionInfo()
pkgs <- vapply(ver$otherPkgs, function(p) paste(p$Package, p$Version), character(1))
write_tbl(tibble::tibble(package = names(ver$otherPkgs),
                         version = vapply(ver$otherPkgs, `[[`, "", "Version")),
          "B14_session_packages.csv")
audit_info("R ", paste(ver$R.version$major, ver$R.version$minor, sep = "."))
audit_info("catboost random_seed=7 present? ", has_cat_seed)

audit_ok("B14_xgb_lgb_have_seed", FALSE,
         "fit_xgb / fit_lgb do not set a random seed (subsample=0.8 is stochastic)")
audit_ok("B14_catboost_has_seed", has_cat_seed,
         "fit_cat sets random_seed = 7")
