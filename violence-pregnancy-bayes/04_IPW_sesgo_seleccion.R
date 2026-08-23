# =============================================================================
# SCRIPT 04: IPW — SELECTION BIAS SENSITIVITY ANALYSIS
# Inverse probability weighting for missing violence data
# Estimated time: 30–40 minutes
# =============================================================================

library(tidyverse)
library(WeightIt)
library(cobalt)

set.seed(2024)

df_full <- read_csv("BASE_HASTA_2024.csv", show_col_types = FALSE) |>
  mutate(
    incluida  = !is.na(`Violencia.1er.`) & !is.na(`Violencia.2do.`) & !is.na(`Violencia.3er.`),
    prematuro = as.numeric(PREMATURO.CODIGO),
    peg       = as.numeric(RCIU),
    apgar1    = as.numeric(CODIGO.Apgar.1.minuto..7),
    lactancia = as.numeric(LACTANCIA_EXCLUSIVA_SI_NO),
    edad_mat  = as.numeric(Edad.materna),
    escol     = as.numeric(ESCOLARIDAD.BAJA == "SI" | ESCOLARIDAD.BAJA == 1),
    etnia     = as.numeric(ETNIA.MINORITARIA),
    pareja    = as.numeric(PAREJA.ESTABLE.CODIGO),
    tabaco    = as.numeric(TABACO.PASIVO),
    alcohol   = as.numeric(Alcohol.CODIGO),
    drogas    = as.numeric(DROGAS),
    gestas    = as.numeric(Numero.gestas.previas),
    cpn       = as.numeric(`Número.Consultas.prenatales`),
    viol_t1   = as.integer(`Violencia.1er.`),
    viol_t2   = as.integer(`Violencia.2do.`),
    viol_t3   = as.integer(`Violencia.3er.`)
  )

cat(sprintf("Total: %d | Included: %d | Excluded: %d\n",
    nrow(df_full), sum(df_full$incluida), sum(!df_full$incluida)))

# Selection model
w_out <- weightit(
  incluida ~ edad_mat + escol + etnia + pareja + tabaco + alcohol +
             drogas + gestas + cpn + prematuro + lactancia,
  data = df_full, method = "glm", estimand = "ATE"
)

# Balance diagnostics
bal <- bal.tab(w_out, stats = c("m", "ks"), thresholds = c(m = 0.1))
print(bal)

# Apply weights to included sample
di <- df_full |>
  filter(incluida) |>
  mutate(
    ipw      = w_out$weights[df_full$incluida],
    ipw_trim = pmin(pmax(ipw, quantile(ipw, 0.01)), quantile(ipw, 0.99))
  )

cat(sprintf("IPW weights — median: %.3f | max: %.3f\n",
    median(di$ipw_trim), max(di$ipw_trim)))

# Save
saveRDS(list(di = di, w_out = w_out, bal = bal), "ipw_objects.rds")
cat("IPW objects saved to ipw_objects.rds\n")
cat("=== Script 04 completed ===\n")
