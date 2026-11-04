m <- read.csv("results/b2/tables/component_metrics.csv")
te <- subset(
  m,
  stage == "test" & (
    setup == "B2.0_univariate_direct" |
      (setup == "B2.1_separate" & model_id == "lgb" & feature_mode == "full") |
      setup == "B2.2_shared"
  )
)
cat("=== Test MASE by horizon/setup/component ===\n")
print(aggregate(MASE ~ horizon_hours + setup + component, te, mean))
cat("\n=== Reconstructed ===\n")
print(read.csv("results/b2/tables/reconstructed_metrics.csv"))
