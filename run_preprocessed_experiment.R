# CPCB parallel preprocessed experiment: architectures B0, A1, B1, B2, B3 at h = 24.
# Separate from every existing pipeline: reads shared data/config, writes only to
# store/preprocessed_experiment/ and results/preprocessed_experiment/.
#
#   Rscript run_preprocessed_experiment.R phase1   # guard snapshot, audit, cleaned dataset
#   Rscript run_preprocessed_experiment.R phase2   # decomposition + data tests
#   Rscript run_preprocessed_experiment.R phase3   # smoke run of B0, A1, B1, B2, B3 + model tests
#   Rscript run_preprocessed_experiment.R phase4   # full run (clean + unmasked control) + evaluation
#   Rscript run_preprocessed_experiment.R verify   # protected files unchanged?
# Single steps: guard | audit | preprocess | decompose | test-data | smoke | full | evaluate | verify

options(warn = 1)
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg)) setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
if (!file.exists("R/load_all.R")) stop("Run from the project root.")

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("Give a phase: phase1 | phase2 | verify | guard | audit | preprocess | decompose | test-data")

suppressMessages(source("R/load_all.R"))
for (f in sort(list.files("R/preprocessed_experiment", pattern = "\\.R$", full.names = TRUE))) source(f)
for (f in sort(list.files("tests/preprocessed_experiment", pattern = "\\.R$", full.names = TRUE))) source(f)

cfg <- pe_cfg()
pe_redirect_shared_logs(cfg)
set.seed(cfg$seed)

steps <- switch(args[1],
  phase1 = c("guard", "audit", "preprocess", "verify"),
  phase2 = c("decompose", "test-data", "verify"),
  phase3 = c("smoke", "verify"),
  phase4 = c("full", "evaluate", "verify"),
  args)

for (s in steps) {
  pe_log(cfg, "=== ", s)
  switch(s,
    guard = pe_guard_snapshot(cfg),
    audit = pe_audit(cfg),
    preprocess = {
      filled <- pe_preprocess(cfg)
      el <- pe_eligibility(cfg, filled, pe_decomp_entry(cfg)$params$window_h)
      av <- do.call(rbind, lapply(c("train", "val", "test"), function(b) {
        e <- el[el$block == b, ]
        data.frame(block = b, first_target = format(min(e$target)), last_target = format(max(e$target)),
                   target_hours = nrow(e), after_warmup = sum(e$warm),
                   target_valid = sum(e$warm & e$target_scorable), eligible_origins = sum(e$eligible))
      }))
      pe_write_csv(av, file.path(pe_dir(cfg, "results", "data_audit"), "split_availability.csv"))
      print(av)
    },
    decompose = print(pe_decompose(cfg)),
    `test-data` = {
      tr <- pe_test_data(cfg)
      print(tr, right = FALSE)
      if (!all(tr$pass)) stop("data tests failed: ", paste(tr$test[!tr$pass], collapse = "; "))
    },
    smoke = {
      sm <- pe_smoke(cfg)
      print(sm$table[, c("arch", "n_features", "n_fit_train", "n_eval_val", "n_eval_test", "val_MAE", "seconds")])
      tm <- pe_test_models(cfg, sm)
      print(tm[, c("rule", "test", "pass")], right = FALSE)
      if (!all(tm$pass)) stop("model tests failed: ", paste(tm$test[!tm$pass], collapse = "; "))
    },
    full = pe_full(cfg),
    evaluate = {
      ev <- pe_evaluate(cfg)
      print(ev$pol[ev$pol$block == "test", ], row.names = FALSE)
    },
    verify = pe_guard_verify(cfg, stage = paste(args, collapse = "_")),
    stop("unknown step ", s))
}
pe_log(cfg, "done: ", paste(steps, collapse = ", "))
