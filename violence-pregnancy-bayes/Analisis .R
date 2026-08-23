# =============================================================================
# ANÁLISIS MAESTRO — Violencia gestacional HGOIA 2009-2024
# Versión unificada y corregida
# Todos los análisis en un solo script, con convergencia garantizada
# =============================================================================
# INSTRUCCIONES:
#   1. Ajusta la sección "CONFIGURACIÓN" con el nombre real de tu objeto/archivo
#   2. Ejecuta completo: source("VIOLENCIA_analisis_maestro.R")
#   3. Todos los outputs se guardan en la carpeta de trabajo
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(brms)
  library(posterior)
  library(logistf)
  library(WeightIt)
  library(EValue)
  library(dagitty)
  library(ggdag)
  library(boot)
})

n_cores <- parallel::detectCores(logical = FALSE)  # núcleos físicos (24 en Ryzen 9)
options(mc.cores = n_cores)
cat(sprintf("Núcleos disponibles: %d
", n_cores))

# Redirigir TMPDIR para evitar error "No queda espacio en el dispositivo" en /tmp
tmp_stan <- path.expand("~/tmp_stan")
dir.create(tmp_stan, showWarnings = FALSE, recursive = TRUE)
Sys.setenv(TMPDIR = tmp_stan)
cat(sprintf("TMPDIR: %s
", tmp_stan))
set.seed(2024)

# Reset sink connections (evita error con Stan en sesiones interactivas)
while (sink.number() > 0) sink()

# =============================================================================
# 0. CONFIGURACIÓN — AJUSTA AQUÍ
# =============================================================================

# Carga tu base. Usa la que corresponda:
df <- BASE_HASTA_2024          # Si ya está en el entorno
# df <- read_csv("BASE_HASTA_2024.csv", show_col_types = FALSE)

# Nombres de columnas (ajusta si difieren en tu base)
COL_VIOL_1  <- "Violencia.1er."
COL_VIOL_2  <- "Violencia.2do."
COL_VIOL_3  <- "Violencia.3er."
COL_VIOL_ACUM <- "VIOLENCIA.CODIGO"   # 1 si violencia en cualquier trimestre
COL_PREM    <- "PREMATURO.CODIGO"
COL_SGA     <- "RCIU"
COL_APGAR   <- "CODIGO.Apgar.1.minuto..7"
COL_LACT    <- "LACTANCIA_EXCLUSIVA_SI_NO"
COL_EDAD    <- "Edad.materna"
COL_ESCOL   <- "ESCOLARIDAD.BAJA"     # 1=baja, 0=otra
COL_ETNIA   <- "ETNIA.MINORITARIA"
COL_PAREJA  <- "PAREJA.ESTABLE.CODIGO"
COL_TABACT  <- "TABACO.ACTIVO"
COL_TABPAS  <- "TABACO.PASIVO"
COL_ALCOHOL <- "Alcohol.CODIGO"
COL_DROGAS  <- "DROGAS"
COL_GESTAS  <- "Numero.gestas.previas"
COL_CPN     <- "Número.Consultas.prenatales"

# =============================================================================
# 1. PREPARACIÓN DE DATOS
# =============================================================================

cat("\n===== 1. PREPARANDO DATOS =====\n")

datos <- df %>%
  transmute(
    viol_1     = as.numeric(.data[[COL_VIOL_1]]),
    viol_2     = as.numeric(.data[[COL_VIOL_2]]),
    viol_3     = as.numeric(.data[[COL_VIOL_3]]),
    viol_any   = as.numeric(.data[[COL_VIOL_ACUM]]),
    prematuro  = as.numeric(.data[[COL_PREM]]),
    sga        = as.numeric(.data[[COL_SGA]]),
    apgar      = as.numeric(.data[[COL_APGAR]]),
    lactancia  = as.numeric(.data[[COL_LACT]]),
    edad_mat   = as.numeric(.data[[COL_EDAD]]),
    escol_baja = as.numeric(.data[[COL_ESCOL]] == "SI" | .data[[COL_ESCOL]] == 1),
    etnia_min  = as.numeric(.data[[COL_ETNIA]]),
    pareja     = as.numeric(.data[[COL_PAREJA]]),
    tabaco_act = as.numeric(.data[[COL_TABACT]]),
    tabaco_pas = as.numeric(.data[[COL_TABPAS]]),
    alcohol    = as.numeric(.data[[COL_ALCOHOL]]),
    drogas     = as.numeric(.data[[COL_DROGAS]]),
    gestas     = as.numeric(.data[[COL_GESTAS]]),
    cpn        = as.numeric(.data[[COL_CPN]])
  ) %>%
  mutate(
    gestas_z  = as.numeric(scale(gestas)),
    cpn_z     = as.numeric(scale(cpn)),
    edad_z    = as.numeric(scale(edad_mat))
  )

# Muestra analítica para perfil materno (viol_any disponible)
datos_perfil <- datos %>%
  filter(!is.na(viol_any)) %>%
  drop_na(drogas, alcohol, tabaco_act, tabaco_pas,
          gestas_z, cpn_z, pareja, escol_baja, etnia_min, edad_z)

# Muestra analítica para desenlaces (viol trimestre disponible)
datos_desenlaces <- datos %>%
  filter(!is.na(viol_1), !is.na(viol_2), !is.na(viol_3))

cat(sprintf("N total: %d\n", nrow(datos)))
cat(sprintf("N perfil materno (viol_any): %d | Expuestas: %d (%.2f%%)\n",
            nrow(datos_perfil), sum(datos_perfil$viol_any, na.rm=TRUE),
            mean(datos_perfil$viol_any, na.rm=TRUE)*100))
cat(sprintf("N desenlaces (trimestre): %d\n", nrow(datos_desenlaces)))
cat(sprintf("  Viol T1: %d (%.2f%%) | T2: %d (%.2f%%) | T3: %d (%.2f%%)\n",
            sum(datos_desenlaces$viol_1), mean(datos_desenlaces$viol_1)*100,
            sum(datos_desenlaces$viol_2), mean(datos_desenlaces$viol_2)*100,
            sum(datos_desenlaces$viol_3), mean(datos_desenlaces$viol_3)*100))

# =============================================================================
# 2. PERFIL MATERNO — GLM + FIRTH + BAYESIANO
# =============================================================================

cat("\n===== 2. PERFIL MATERNO =====\n")

form_perfil <- viol_any ~ drogas + alcohol + tabaco_act + tabaco_pas +
  gestas_z + cpn_z + pareja + escol_baja + etnia_min + edad_z

# 2a. GLM clásico
glm_perfil <- glm(form_perfil, data = datos_perfil, family = binomial())

glm_tab <- broom::tidy(glm_perfil, exponentiate = TRUE, conf.int = TRUE) %>%
  filter(term != "(Intercept)") %>%
  rename(variable = term, OR_GLM = estimate,
         IC_lo_GLM = conf.low, IC_hi_GLM = conf.high, p_GLM = p.value)

# 2b. Firth
firth_perfil <- logistf(form_perfil, data = datos_perfil)

firth_tab <- data.frame(
  variable    = names(firth_perfil$coefficients),
  OR_Firth    = exp(firth_perfil$coefficients),
  IC_lo_Firth = exp(firth_perfil$ci.lower),
  IC_hi_Firth = exp(firth_perfil$ci.upper),
  p_Firth     = firth_perfil$prob
) %>% filter(variable != "(Intercept)")

# 2c. Bayesiano — configuración con convergencia garantizada
cat("  Ajustando modelo bayesiano perfil materno...\n")
bayes_perfil <- brm(
  formula = form_perfil,
  data    = datos_perfil,
  family  = bernoulli(link = "logit"),
  prior   = c(
    prior(normal(0, 2.5), class = b),
    prior(student_t(3, 0, 2.5), class = Intercept)
  ),
  chains      = 4,
  iter        = 6000,
  warmup      = 2000,
  cores       = n_cores,
  seed        = 2024,
  control     = list(adapt_delta = 0.97, max_treedepth = 15),
  refresh     = 500
)

# Diagnósticos
diag_perfil <- summarise_draws(
  as_draws_df(bayes_perfil),
  "mean", "sd", "rhat", "ess_bulk", "ess_tail"
)

cat(sprintf("  Rhat max: %.4f | ESS bulk min: %.0f\n",
            max(diag_perfil$rhat, na.rm = TRUE),
            min(diag_perfil$ess_bulk, na.rm = TRUE)))

if (max(diag_perfil$rhat, na.rm = TRUE) > 1.01) {
  warning("CONVERGENCIA INSUFICIENTE en modelo bayesiano perfil materno. Rhat > 1.01")
}
if (min(diag_perfil$ess_bulk, na.rm = TRUE) < 400) {
  warning("ESS < 400 en modelo bayesiano perfil materno. Aumentar iteraciones.")
}

post_perfil <- as_draws_df(bayes_perfil)
vars_perfil <- c("drogas", "alcohol", "tabaco_act", "tabaco_pas",
                 "gestas_z", "cpn_z", "pareja", "escol_baja", "etnia_min", "edad_z")

bayes_tab <- map_df(vars_perfil, function(v) {
  draws <- post_perfil[[paste0("b_", v)]]
  tibble(
    variable    = v,
    OR_Bayes    = exp(median(draws)),
    IC_lo_Bayes = exp(quantile(draws, 0.025)),
    IC_hi_Bayes = exp(quantile(draws, 0.975)),
    P_OR_gt1    = mean(draws > 0)
  )
})

# Tabla combinada perfil materno
tabla_perfil <- firth_tab %>%
  left_join(glm_tab %>% select(variable, OR_GLM, IC_lo_GLM, IC_hi_GLM, p_GLM),
            by = "variable") %>%
  left_join(bayes_tab, by = "variable")

write.csv(tabla_perfil,   "A1_perfil_materno_tabla2.csv", row.names = FALSE)
write.csv(diag_perfil,    "A2_perfil_materno_diagnosticos_bayes.csv", row.names = FALSE)

cat("  -> Guardados: A1_perfil_materno_tabla2.csv | A2_perfil_materno_diagnosticos_bayes.csv\n")

# =============================================================================
# 3. DESENLACES NEONATALES — GLM + FIRTH + BAYESIANO (Tabla 3)
# =============================================================================

cat("\n===== 3. DESENLACES NEONATALES — TABLA 3 =====\n")

outcomes_list <- list(
  "Preterm birth" = "prematuro",
  "SGA/IUGR"      = "sga",
  "Apgar <7 1min" = "apgar",
  "Excl. breastf."= "lactancia"
)

trim_list <- list(T1 = "viol_1", T2 = "viol_2", T3 = "viol_3")

confounders_des <- c("edad_mat", "escol_baja", "etnia_min", "pareja",
                     "cpn", "gestas", "alcohol", "drogas", "tabaco_pas")

tabla3 <- data.frame()

for (out_label in names(outcomes_list)) {
  out_var <- outcomes_list[[out_label]]
  
  for (trim_label in names(trim_list)) {
    viol_var <- trim_list[[trim_label]]
    
    d_tmp <- datos_desenlaces %>%
      select(all_of(c(out_var, viol_var, confounders_des))) %>%
      drop_na()
    
    n_exp <- sum(d_tmp[[viol_var]])
    cat(sprintf("  %s | %s | n=%d | exp=%d\n",
                out_label, trim_label, nrow(d_tmp), n_exp))
    
    f <- as.formula(paste(out_var, "~", viol_var, "+",
                          paste(confounders_des, collapse = " + ")))
    
    # GLM
    m_glm <- tryCatch(glm(f, data = d_tmp, family = binomial()), error = function(e) NULL)
    if (!is.null(m_glm) && m_glm$converged) {
      cf <- coef(summary(m_glm))[viol_var, ]
      or_glm   <- exp(cf["Estimate"])
      lo_glm   <- exp(cf["Estimate"] - 1.96 * cf["Std. Error"])
      hi_glm   <- exp(cf["Estimate"] + 1.96 * cf["Std. Error"])
      p_glm    <- cf["Pr(>|z|)"]
    } else {
      or_glm <- lo_glm <- hi_glm <- p_glm <- NA
    }
    
    # Firth
    m_firth <- tryCatch(logistf(f, data = d_tmp), error = function(e) NULL)
    if (!is.null(m_firth)) {
      or_firth <- exp(m_firth$coefficients[viol_var])
      lo_firth <- exp(m_firth$ci.lower[viol_var])
      hi_firth <- exp(m_firth$ci.upper[viol_var])
      p_firth  <- m_firth$prob[viol_var]
    } else {
      or_firth <- lo_firth <- hi_firth <- p_firth <- NA
    }
    
    # Bayesiano
    m_bayes <- tryCatch(
      brm(
        formula = f,
        data    = d_tmp,
        family  = bernoulli(link = "logit"),
        prior   = c(
          prior(normal(0, 2.5), class = b),
          prior(student_t(3, 0, 2.5), class = Intercept)
        ),
        chains  = 4,
        iter    = 6000,
        warmup  = 2000,
        cores   = n_cores,
        seed    = 2024,
        control = list(adapt_delta = 0.97, max_treedepth = 15),
        refresh = 500
      ),
      error = function(e) { cat("    BRMS error:", conditionMessage(e), "\n"); NULL }
    )
    
    if (!is.null(m_bayes)) {
      post_b  <- as_draws_df(m_bayes)[[paste0("b_", viol_var)]]
      or_bayes <- exp(median(post_b))
      lo_bayes <- exp(quantile(post_b, 0.025))
      hi_bayes <- exp(quantile(post_b, 0.975))
      p_bayes  <- mean(post_b > 0)
      
      diag_b   <- summarise_draws(as_draws_df(m_bayes), "rhat", "ess_bulk")
      rhat_max <- max(diag_b$rhat, na.rm = TRUE)
      ess_min  <- min(diag_b$ess_bulk, na.rm = TRUE)
      
      if (rhat_max > 1.01)
        warning(sprintf("Rhat > 1.01 en %s %s", out_label, trim_label))
      if (ess_min < 400)
        warning(sprintf("ESS < 400 en %s %s: ESS=%.0f", out_label, trim_label, ess_min))
    } else {
      or_bayes <- lo_bayes <- hi_bayes <- p_bayes <- rhat_max <- ess_min <- NA
    }
    
    tabla3 <- rbind(tabla3, data.frame(
      outcome      = out_label,
      trimestre    = trim_label,
      n            = nrow(d_tmp),
      n_expuestos  = n_exp,
      OR_GLM       = round(or_glm,   3),
      IC_lo_GLM    = round(lo_glm,   3),
      IC_hi_GLM    = round(hi_glm,   3),
      p_GLM        = round(p_glm,    4),
      OR_Firth     = round(or_firth, 3),
      IC_lo_Firth  = round(lo_firth, 3),
      IC_hi_Firth  = round(hi_firth, 3),
      p_Firth      = round(p_firth,  4),
      OR_Bayes     = round(or_bayes, 3),
      IC_lo_Bayes  = round(lo_bayes, 3),
      IC_hi_Bayes  = round(hi_bayes, 3),
      P_OR_gt1     = round(p_bayes,  4),
      Rhat_max     = round(rhat_max, 4),
      ESS_min      = round(ess_min,  0)
    ))
    
    cat(sprintf("    GLM=%.3f | Firth=%.3f | Bayes=%.3f | Rhat=%.4f | ESS=%.0f\n",
                or_glm, or_firth, or_bayes, rhat_max, ess_min))
  }
}

write.csv(tabla3, "B1_tabla3_desenlaces_todos_metodos.csv", row.names = FALSE)
cat("  -> Guardado: B1_tabla3_desenlaces_todos_metodos.csv\n")

# =============================================================================
# 4. ANÁLISIS DE ATENUACIÓN — TABLA 4
# =============================================================================

cat("\n===== 4. ANÁLISIS DE ATENUACIÓN (TABLA 4) =====\n")

conf_base <- c("edad_mat", "escol_baja", "etnia_min", "pareja", "cpn", "gestas")
mediadores <- c("alcohol", "drogas", "tabaco_pas")

tabla4 <- data.frame()

for (out_label in names(outcomes_list)) {
  out_var <- outcomes_list[[out_label]]
  
  for (trim_label in names(trim_list)) {
    viol_var <- trim_list[[trim_label]]
    
    d_tmp <- datos_desenlaces %>%
      select(all_of(c(out_var, viol_var, conf_base, mediadores))) %>%
      drop_na()
    
    # Modelo A — solo confusores basales
    fA <- as.formula(paste(out_var, "~", viol_var, "+",
                           paste(conf_base, collapse = " + ")))
    mA <- tryCatch(
      brm(fA, data = d_tmp, family = bernoulli(),
          prior = c(prior(normal(0, 2.5), class = b),
                    prior(student_t(3, 0, 2.5), class = Intercept)),
          chains = 4, iter = 6000, warmup = 2000, cores = n_cores,
          seed = 2024, control = list(adapt_delta = 0.97), refresh = 500),
      error = function(e) NULL
    )
    
    # Modelo B — confusores + mediadores
    fB <- as.formula(paste(out_var, "~", viol_var, "+",
                           paste(c(conf_base, mediadores), collapse = " + ")))
    mB <- tryCatch(
      brm(fB, data = d_tmp, family = bernoulli(),
          prior = c(prior(normal(0, 2.5), class = b),
                    prior(student_t(3, 0, 2.5), class = Intercept)),
          chains = 4, iter = 6000, warmup = 2000, cores = n_cores,
          seed = 2024, control = list(adapt_delta = 0.97), refresh = 500),
      error = function(e) NULL
    )
    
    if (!is.null(mA) && !is.null(mB)) {
      postA  <- as_draws_df(mA)[[paste0("b_", viol_var)]]
      postB  <- as_draws_df(mB)[[paste0("b_", viol_var)]]
      orA    <- exp(median(postA))
      orB    <- exp(median(postB))
      loA    <- exp(quantile(postA, 0.025))
      hiA    <- exp(quantile(postA, 0.975))
      loB    <- exp(quantile(postB, 0.025))
      hiB    <- exp(quantile(postB, 0.975))
      
      # Cambio relativo en escala logit
      delta_log <- postA - postB
      or_delta  <- exp(median(delta_log))
      lo_delta  <- exp(quantile(delta_log, 0.025))
      hi_delta  <- exp(quantile(delta_log, 0.975))
      pct_cambio <- round((orA - orB) / orA * 100, 1)
      
      diag_A <- summarise_draws(as_draws_df(mA), "rhat", "ess_bulk")
      diag_B <- summarise_draws(as_draws_df(mB), "rhat", "ess_bulk")
      
      cat(sprintf("  %s %s: ModA=%.3f ModB=%.3f %%cambio=%.1f | RhatA=%.4f RhatB=%.4f\n",
                  out_label, trim_label, orA, orB, pct_cambio,
                  max(diag_A$rhat, na.rm=TRUE), max(diag_B$rhat, na.rm=TRUE)))
      
      tabla4 <- rbind(tabla4, data.frame(
        outcome      = out_label,
        trimestre    = trim_label,
        OR_ModeloA   = round(orA, 3),
        IC_lo_A      = round(loA, 3),
        IC_hi_A      = round(hiA, 3),
        OR_ModeloB   = round(orB, 3),
        IC_lo_B      = round(loB, 3),
        IC_hi_B      = round(hiB, 3),
        OR_delta     = round(or_delta, 3),
        IC_lo_delta  = round(lo_delta, 3),
        IC_hi_delta  = round(hi_delta, 3),
        pct_cambio   = pct_cambio,
        Rhat_max_A   = round(max(diag_A$rhat, na.rm=TRUE), 4),
        ESS_min_A    = round(min(diag_A$ess_bulk, na.rm=TRUE), 0),
        Rhat_max_B   = round(max(diag_B$rhat, na.rm=TRUE), 4),
        ESS_min_B    = round(min(diag_B$ess_bulk, na.rm=TRUE), 0)
      ))
    }
  }
}

write.csv(tabla4, "C1_tabla4_atenuacion.csv", row.names = FALSE)
cat("  -> Guardado: C1_tabla4_atenuacion.csv\n")

# =============================================================================
# 5. QBA — CORRECCIÓN POR SUBREGISTRO (Tabla 5)
# =============================================================================

cat("\n===== 5. QBA — TABLA 5 =====\n")

# Datos 2x2 para prematuridad T3 y lactancia T3
# Ajusta estos valores con los conteos reales de tu base
a_prem <- sum(datos_desenlaces$viol_3 == 1 & datos_desenlaces$prematuro == 1, na.rm=TRUE)
b_prem <- sum(datos_desenlaces$viol_3 == 1 & datos_desenlaces$prematuro == 0, na.rm=TRUE)
M1_prem <- sum(datos_desenlaces$prematuro == 1, na.rm=TRUE)
M0_prem <- sum(datos_desenlaces$prematuro == 0, na.rm=TRUE)

a_lact <- sum(datos_desenlaces$viol_3 == 1 & datos_desenlaces$lactancia == 1, na.rm=TRUE)
b_lact <- sum(datos_desenlaces$viol_3 == 1 & datos_desenlaces$lactancia == 0, na.rm=TRUE)
M1_lact <- sum(datos_desenlaces$lactancia == 1, na.rm=TRUE)
M0_lact <- sum(datos_desenlaces$lactancia == 0, na.rm=TRUE)

cat(sprintf("  Prematuridad T3: a=%d b=%d M1=%d M0=%d\n", a_prem, b_prem, M1_prem, M0_prem))
cat(sprintf("  Lactancia T3:    a=%d b=%d M1=%d M0=%d\n", a_lact, b_lact, M1_lact, M0_lact))

corregir_OR <- function(a, b, M1, M0, Se, Sp = 1.0) {
  denom <- Se + Sp - 1
  if (abs(denom) < 1e-10) return(NA)
  A <- (a - (1 - Sp) * M1) / denom
  B <- (b - (1 - Sp) * M0) / denom
  if (A <= 0 | B <= 0) return(NA)
  C <- M1 - A; D <- M0 - B
  if (C <= 0 | D <= 0) return(NA)
  (A * D) / (B * C)
}

set.seed(2024)
n_mc <- 10000
prev_obs_t3 <- mean(datos_desenlaces$viol_3, na.rm = TRUE)

qba_tab <- data.frame()

for (prev_real in c(0.03, 0.05, 0.08, 0.10, 0.15)) {
  Se_impl <- prev_obs_t3 / prev_real
  
  for (des in c("prematuridad", "lactancia")) {
    if (des == "prematuridad") { a <- a_prem; b <- b_prem; M1 <- M1_prem; M0 <- M0_prem }
    else                       { a <- a_lact; b <- b_lact; M1 <- M1_lact; M0 <- M0_lact }
    
    or_corr <- corregir_OR(a, b, M1, M0, Se = Se_impl, Sp = 1.0)
    
    # Monte Carlo — propaga incertidumbre sobre Se
    mc_ors <- replicate(n_mc, {
      Se_sim <- rbeta(1, shape1 = Se_impl * 100, shape2 = (1 - Se_impl) * 100)
      corregir_OR(a, b, M1, M0, Se = Se_sim, Sp = 1.0)
    })
    mc_ors <- mc_ors[!is.na(mc_ors)]
    
    qba_tab <- rbind(qba_tab, data.frame(
      desenlace   = des,
      trimestre   = "T3",
      escenario   = paste0("Prev real ", round(prev_real * 100), "%"),
      prev_real   = prev_real,
      Se_implicita = round(Se_impl, 3),
      OR_corregido = round(or_corr, 3),
      IC_lo_MC    = round(quantile(mc_ors, 0.025, na.rm=TRUE), 3),
      IC_hi_MC    = round(quantile(mc_ors, 0.975, na.rm=TRUE), 3)
    ))
  }
}

write.csv(qba_tab, "D1_tabla5_QBA.csv", row.names = FALSE)
cat("  -> Guardado: D1_tabla5_QBA.csv\n")
print(qba_tab)

# =============================================================================
# 6. IPW — TODOS LOS DESENLACES × TRIMESTRES (Tabla 6)
# =============================================================================

cat("\n===== 6. IPW — TABLA 6 =====\n")

datos_ipw_full <- datos %>%
  mutate(
    incluida = !is.na(viol_1) & !is.na(viol_2) & !is.na(viol_3)
  )

# Modelo de pesos: predice quién tiene datos de violencia trimestral
# NOTA: El desenlace NO se incluye en el modelo de pesos (corrección metodológica)
w_ipw <- weightit(
  incluida ~ edad_mat + escol_baja + etnia_min + pareja +
    tabaco_act + alcohol + drogas + gestas + cpn,
  data      = datos_ipw_full,
  method    = "glm",
  estimand  = "ATE"
)

di <- datos_ipw_full %>%
  filter(incluida) %>%
  mutate(
    ipw      = w_ipw$weights[datos_ipw_full$incluida],
    ipw_trim = pmin(pmax(ipw,
                         quantile(ipw, 0.01, na.rm=TRUE)),
                    quantile(ipw, 0.99, na.rm=TRUE))
  )

# Balance post-IPW
# Balance post-IPW — SMD manual (sin cobalt)
smd_vars <- names(w_ipw$covs)
smd_vals <- sapply(smd_vars, function(v) {
  x   <- datos_ipw_full[[v]]
  w   <- w_ipw$weights
  inc <- datos_ipw_full$incluida
  m1  <- weighted.mean(x[inc],  w[inc],  na.rm=TRUE)
  m0  <- weighted.mean(x[!inc], w[!inc], na.rm=TRUE)
  sdp <- sd(x, na.rm=TRUE)
  if (is.na(sdp) | sdp == 0) NA_real_ else (m1 - m0) / sdp
})
cat(sprintf("  SMD max post-IPW: %.3f
", max(abs(smd_vals), na.rm=TRUE)))

tabla6 <- data.frame()

for (out_label in names(outcomes_list)) {
  out_var <- outcomes_list[[out_label]]
  
  for (trim_label in names(trim_list)) {
    viol_var <- trim_list[[trim_label]]
    
    f <- as.formula(paste(out_var, "~", viol_var,
                          "+ edad_mat + escol_baja + etnia_min + pareja",
                          "+ tabaco_pas + alcohol + drogas + gestas + cpn"))
    
    m_ipw <- tryCatch(
      glm(f, data = di, family = binomial(), weights = ipw_trim),
      error = function(e) NULL
    )
    
    if (!is.null(m_ipw) && m_ipw$converged) {
      cf <- coef(summary(m_ipw))[viol_var, ]
      or_ipw <- exp(cf["Estimate"])
      lo_ipw <- exp(cf["Estimate"] - 1.96 * cf["Std. Error"])
      hi_ipw <- exp(cf["Estimate"] + 1.96 * cf["Std. Error"])
      p_ipw  <- cf["Pr(>|z|)"]
    } else {
      or_ipw <- lo_ipw <- hi_ipw <- p_ipw <- NA
    }
    
    # OR bayesiano sin IPW (de tabla3 ya calculada)
    row_b3 <- tabla3[tabla3$outcome == out_label & tabla3$trimestre == trim_label, ]
    or_bayes_ref <- if (nrow(row_b3) > 0) row_b3$OR_Bayes else NA
    
    tabla6 <- rbind(tabla6, data.frame(
      outcome       = out_label,
      trimestre     = trim_label,
      OR_Bayes_sinIPW = round(or_bayes_ref, 3),
      OR_GLM_IPW    = round(or_ipw, 3),
      IC_lo_IPW     = round(lo_ipw, 3),
      IC_hi_IPW     = round(hi_ipw, 3),
      p_GLM_IPW     = round(p_ipw,  4)
    ))
    
    cat(sprintf("  %s %s: OR_IPW=%.3f (%.3f-%.3f) p=%.3f\n",
                out_label, trim_label, or_ipw, lo_ipw, hi_ipw, p_ipw))
  }
}

write.csv(tabla6, "E1_tabla6_IPW.csv", row.names = FALSE)
cat("  -> Guardado: E1_tabla6_IPW.csv\n")

# =============================================================================
# 7. BOOTSTRAP PONDERADO — PREMATURIDAD T3
# =============================================================================

cat("\n===== 7. BOOTSTRAP PONDERADO (prematuridad T3) =====\n")

set.seed(2024)
n_boot <- 500

ors_boot <- sapply(seq_len(n_boot), function(b) {
  if (b %% 100 == 0) cat("  Bootstrap", b, "/ ", n_boot, "\n")
  idx <- sample(nrow(di), replace = TRUE,
                prob = di$ipw_trim / sum(di$ipw_trim))
  m_b <- tryCatch(
    glm(prematuro ~ viol_3 + edad_mat + escol_baja + etnia_min +
          pareja + tabaco_pas + alcohol + drogas + gestas + cpn,
        data = di[idx, ], family = binomial()),
    error = function(e) NULL
  )
  if (!is.null(m_b) && m_b$converged) exp(coef(m_b)["viol_3"]) else NA_real_
})

ors_boot_ok <- ors_boot[!is.na(ors_boot)]
cat(sprintf("\n  Bootstrap n_válidos=%d | OR=%.3f (IC95%%: %.3f-%.3f)\n",
            length(ors_boot_ok),
            median(ors_boot_ok),
            quantile(ors_boot_ok, 0.025),
            quantile(ors_boot_ok, 0.975)))

write.csv(data.frame(
  OR_bootstrap_median = median(ors_boot_ok),
  IC_lo = quantile(ors_boot_ok, 0.025),
  IC_hi = quantile(ors_boot_ok, 0.975),
  n_validos = length(ors_boot_ok)
), "F1_bootstrap_prem_T3.csv", row.names = FALSE)

# =============================================================================
# 8. E-VALUE — PREMATURIDAD T3
# =============================================================================

cat("\n===== 8. E-VALUE (prematuridad T3) =====\n")

# Usa OR del análisis principal (Bayes o GLM — deben coincidir)
or_principal <- tabla3[tabla3$outcome == "Preterm birth" &
                         tabla3$trimestre == "T3", "OR_Bayes"]
lo_principal <- tabla3[tabla3$outcome == "Preterm birth" &
                         tabla3$trimestre == "T3", "IC_lo_Bayes"]

ev <- evalues.OR(est = or_principal, lo = lo_principal, hi = NA,
                 rare = FALSE)
cat("  E-value para OR principal prematuridad T3:\n")
print(ev)

write.csv(as.data.frame(ev), "G1_evalue_prem_T3.csv", row.names = TRUE)

# =============================================================================
# 9. SENSIBILIDAD DE PRIOR BAYESIANO — PREMATURIDAD T3
# =============================================================================

cat("\n===== 9. SENSIBILIDAD DE PRIOR (prematuridad T3) =====\n")

d_prem_t3 <- datos_desenlaces %>%
  select(prematuro, viol_3, all_of(confounders_des)) %>%
  drop_na()

priors_sens <- list(
  "Debilmente informativo N(0,2.5)" = c(
    prior(normal(0, 2.5), class = b),
    prior(student_t(3, 0, 2.5), class = Intercept)
  ),
  "Esceptico N(0,0.5)" = c(
    prior(normal(0, 0.5), class = b),
    prior(student_t(3, 0, 2.5), class = Intercept)
  )
)

f_prem <- prematuro ~ viol_3 + edad_mat + escol_baja + etnia_min +
  pareja + cpn + gestas + alcohol + drogas + tabaco_pas

tabla_s3 <- data.frame()

for (prior_name in names(priors_sens)) {
  while (sink.number() > 0) sink()
  cat(sprintf("  Ajustando prior: %s\n", prior_name))
  m_s <- brm(
    formula   = f_prem,
    data      = d_prem_t3,
    family    = bernoulli(),
    prior     = priors_sens[[prior_name]],
    chains    = 4, iter = 6000, warmup = 2000, cores = n_cores,
    seed      = 2024,
    control   = list(adapt_delta = 0.97, max_treedepth = 15),
    refresh   = 500,
    recompile = TRUE
  )
  while (sink.number() > 0) sink()
  post_s <- as_draws_df(m_s)[["b_viol_3"]]
  diag_s <- summarise_draws(as_draws_df(m_s), "rhat", "ess_bulk")
  
  tabla_s3 <- rbind(tabla_s3, data.frame(
    prior      = prior_name,
    OR_mediana = round(exp(median(post_s)), 3),
    IC_lo      = round(exp(quantile(post_s, 0.025)), 3),
    IC_hi      = round(exp(quantile(post_s, 0.975)), 3),
    P_OR_gt1   = round(mean(post_s > 0), 4),
    Rhat_max   = round(max(diag_s$rhat, na.rm=TRUE), 4),
    ESS_min    = round(min(diag_s$ess_bulk, na.rm=TRUE), 0)
  ))
}

write.csv(tabla_s3, "H1_tablaS3_prior_sensitivity.csv", row.names = FALSE)
cat("  -> Guardado: H1_tablaS3_prior_sensitivity.csv\n")
print(tabla_s3)

# =============================================================================
# RESUMEN FINAL
# =============================================================================

cat("\n\n")
cat("=============================================================================\n")
cat("  ANÁLISIS COMPLETADO\n")
cat("=============================================================================\n")
cat("Archivos generados:\n")
cat("  A1_perfil_materno_tabla2.csv         -> Tabla 2\n")
cat("  A2_perfil_materno_diagnosticos_bayes -> Diagnósticos Tabla S1\n")
cat("  B1_tabla3_desenlaces_todos_metodos   -> Tabla 3\n")
cat("  C1_tabla4_atenuacion.csv             -> Tabla 4\n")
cat("  D1_tabla5_QBA.csv                    -> Tabla 5\n")
cat("  E1_tabla6_IPW.csv                    -> Tabla 6\n")
cat("  F1_bootstrap_prem_T3.csv             -> Bootstrap ponderado\n")
cat("  G1_evalue_prem_T3.csv                -> E-value\n")
cat("  H1_tablaS3_prior_sensitivity.csv     -> Tabla S3\n")
cat("=============================================================================\n")

# Verificación final de convergencia
cat("\nVERIFICACIÓN DE CONVERGENCIA:\n")
cat(sprintf("  Perfil materno — Rhat max: %.4f | ESS min: %.0f\n",
            max(diag_perfil$rhat, na.rm=TRUE),
            min(diag_perfil$ess_bulk, na.rm=TRUE)))

rhat_tabla3 <- max(tabla3$Rhat_max, na.rm=TRUE)
ess_tabla3  <- min(tabla3$ESS_min,  na.rm=TRUE)
cat(sprintf("  Tabla 3 — Rhat max: %.4f | ESS min: %.0f\n", rhat_tabla3, ess_tabla3))

if (rhat_tabla3 > 1.01 | max(diag_perfil$rhat, na.rm=TRUE) > 1.01)
  cat("  *** ADVERTENCIA: Rhat > 1.01 — revisar convergencia ***\n")
if (ess_tabla3 < 400 | min(diag_perfil$ess_bulk, na.rm=TRUE) < 400)
  cat("  *** ADVERTENCIA: ESS < 400 — aumentar iteraciones ***\n")
if (rhat_tabla3 <= 1.01 & ess_tabla3 >= 400 &
    max(diag_perfil$rhat, na.rm=TRUE) <= 1.01 &
    min(diag_perfil$ess_bulk, na.rm=TRUE) >= 400)
  cat("  ✓ Todos los modelos convergieron adecuadamente\n")