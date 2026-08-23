# =============================================================================
# SCRIPT 03: QUANTITATIVE BIAS ANALYSIS (QBA)
# Misclassification correction for underreported gestational violence
# Greenland (1996) — Monte Carlo n=10,000
# Estimated time: 5–10 minutes
# =============================================================================

library(tidyverse)
set.seed(2024)

# ── GREENLAND CORRECTION FUNCTION ────────────────────────────────────────────
# Non-differential misclassification of binary exposure
# a: exposed + outcome; b: exposed + no outcome
# M1: total with outcome; M0: total without outcome
# Se: sensitivity; Sp: specificity

corregir_OR <- function(a, b, M1, M0, Se, Sp) {
  denom <- Se + Sp - 1
  if (denom <= 0) return(NA_real_)
  A <- (a - (1 - Sp) * M1) / denom
  B <- (b - (1 - Sp) * M0) / denom
  if (A <= 0 || B <= 0) return(NA_real_)
  C <- M1 - A; D <- M0 - B
  if (C <= 0 || D <= 0) return(NA_real_)
  (A * D) / (B * C)
}

# ── DATA: 2x2 TABLES FOR MAIN ASSOCIATIONS ───────────────────────────────────
# Preterm birth × T3 (primary)
a_prem_t3 <- 72;  b_prem_t3 <- 83;  M1_prem <- 9487;  M0_prem <- 16753
# Exclusive breastfeeding × T3
a_lact_t3 <- 127; b_lact_t3 <- 28;  M1_lact <- 21561; M0_lact <- 4958

# ── MAIN QBA: Preterm birth T3 ───────────────────────────────────────────────
prev_obs_t3 <- 0.0058  # observed SIP prevalence T3

scenarios <- tibble(
  prev_real  = c(0.03, 0.05, 0.08, 0.10, 0.15),
  Se_central = prev_obs_t3 / c(0.03, 0.05, 0.08, 0.10, 0.15)
)

n_mc <- 10000

resultados_prem <- scenarios |>
  mutate(
    OR_central = map_dbl(Se_central, ~corregir_OR(
      a_prem_t3, b_prem_t3, M1_prem, M0_prem, Se=.x, Sp=1.0)),
    mc_results = map(Se_central, function(se_c) {
      se_sim <- pmin(pmax(rnorm(n_mc, se_c, 0.05), 0.01), 1.0)
      map_dbl(se_sim, ~corregir_OR(a_prem_t3, b_prem_t3, M1_prem, M0_prem, .x, 1.0))
    }),
    OR_mc_med  = map_dbl(mc_results, ~median(.x, na.rm=TRUE)),
    IC_lo      = map_dbl(mc_results, ~quantile(.x, 0.025, na.rm=TRUE)),
    IC_hi      = map_dbl(mc_results, ~quantile(.x, 0.975, na.rm=TRUE)),
    sens_impl  = paste0(round(Se_central * 100, 0), "%"),
    outcome    = "Preterm birth"
  ) |>
  select(outcome, prev_real, sens_impl, OR_central, OR_mc_med, IC_lo, IC_hi)

resultados_lact <- scenarios |>
  mutate(
    Se_central = prev_obs_t3 / prev_real,
    OR_central = map_dbl(Se_central, ~corregir_OR(
      a_lact_t3, b_lact_t3, M1_lact, M0_lact, Se=.x, Sp=1.0)),
    mc_results = map(Se_central, function(se_c) {
      se_sim <- pmin(pmax(rnorm(n_mc, se_c, 0.05), 0.01), 1.0)
      map_dbl(se_sim, ~corregir_OR(a_lact_t3, b_lact_t3, M1_lact, M0_lact, .x, 1.0))
    }),
    OR_mc_med  = map_dbl(mc_results, ~median(.x, na.rm=TRUE)),
    IC_lo      = map_dbl(mc_results, ~quantile(.x, 0.025, na.rm=TRUE)),
    IC_hi      = map_dbl(mc_results, ~quantile(.x, 0.975, na.rm=TRUE)),
    sens_impl  = paste0(round(Se_central * 100, 0), "%"),
    outcome    = "Exclusive breastfeeding"
  ) |>
  select(outcome, prev_real, sens_impl, OR_central, OR_mc_med, IC_lo, IC_hi)

tabla_qba <- bind_rows(resultados_prem, resultados_lact)
write_csv(tabla_qba, "tabla_qba_subregistro.csv")
print(tabla_qba)
cat("\n=== Script 03 completed ===\n")
