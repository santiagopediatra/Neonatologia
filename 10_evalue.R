# =============================================================================
# SCRIPT 10: E-VALUE FOR UNMEASURED CONFOUNDING
# VanderWeele & Ding (2017) — Epidemiology
# Estimated time: < 1 minute
# =============================================================================

library(tidyverse)

# E-value for OR (approximate, for rare outcomes or RR directly)
evalue_or <- function(or) {
  if (or < 1) or <- 1 / or  # flip for protective associations
  or + sqrt(or * (or - 1))
}

# Results for all 12 outcome × trimester combinations
resultados <- tribble(
  ~outcome,                ~trimester, ~OR_bayes, ~OR_lo, ~OR_hi, ~P_OR_gt1,
  "Preterm birth",         "T1",       0.88,      0.66,   1.17,   0.187,
  "Preterm birth",         "T2",       1.18,      0.86,   1.61,   0.841,
  "Preterm birth",         "T3",       1.36,      0.99,   1.89,   0.971,
  "SGA/IUGR",              "T1",       1.09,      0.81,   1.44,   0.726,
  "SGA/IUGR",              "T2",       1.22,      0.88,   1.67,   0.887,
  "SGA/IUGR",              "T3",       0.98,      0.68,   1.38,   0.447,
  "Apgar <7 at 1 min",     "T1",       1.15,      0.80,   1.61,   0.784,
  "Apgar <7 at 1 min",     "T2",       0.88,      0.56,   1.34,   0.279,
  "Apgar <7 at 1 min",     "T3",       1.10,      0.69,   1.66,   0.661,
  "Exclusive breastfeeding","T1",       1.07,      0.77,   1.54,   0.661,
  "Exclusive breastfeeding","T2",       1.28,      0.85,   1.97,   0.882,
  "Exclusive breastfeeding","T3",       1.36,      0.90,   2.16,   0.928
) |>
  mutate(
    E_value_point = map_dbl(OR_bayes, evalue_or),
    E_value_lo    = map_dbl(OR_lo,    evalue_or),
    interpretation = case_when(
      E_value_point >= 3   ~ "Strong — requires very strong confounder",
      E_value_point >= 2   ~ "Moderate — requires moderately strong confounder",
      E_value_point >= 1.5 ~ "Weak — modest confounder sufficient",
      TRUE                 ~ "Trivial"
    )
  )

cat("=== E-VALUES FOR ALL ASSOCIATIONS ===\n\n")
print(resultados |>
  select(outcome, trimester, OR_bayes, OR_lo, E_value_point, E_value_lo, interpretation),
  n = Inf)

write_csv(resultados, "tabla_evalue_todos.csv")

cat("\n=== PRIMARY FINDING: Preterm birth T3 ===\n")
prim <- resultados |> filter(outcome == "Preterm birth", trimester == "T3")
cat(sprintf("OR = %.2f (95%% CrI: %.2f–%.2f) | P(OR>1) = %.1f%%\n",
    prim$OR_bayes, prim$OR_lo, prim$OR_hi, prim$P_OR_gt1 * 100))
cat(sprintf("E-value (point estimate): %.2f\n", prim$E_value_point))
cat(sprintf("E-value (lower CrI):      %.2f\n", prim$E_value_lo))
cat("\nConclusion: An unmeasured confounder would need RR >= 2.06\n")
cat("with BOTH gestational violence AND preterm birth to fully\n")
cat("explain the observed association — controlling for 9 covariates.\n")

cat("\n=== Script 10 completed ===\n")
