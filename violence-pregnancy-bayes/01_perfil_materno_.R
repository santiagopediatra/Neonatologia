############################################################
# ANALISIS ROBUSTO PARA VIOLENCIA GESTACIONAL SUBREGISTRADA
# Estimando: violencia gestacional REGISTRADA
# Subregistro: analisis de sensibilidad, no "verdad latente"
############################################################

rm(list = ls())

# ==========================================================
# 0. PAQUETES
# ==========================================================

pkgs <- c(
  "tidyverse", "readxl", "broom", "logistf", "car",
  "detectseparation", "brms", "posterior", "loo",
  "pROC", "PRROC", "ResourceSelection", "mice",
  "naniar", "boot", "EValue"
)

install.packages(setdiff(pkgs, rownames(installed.packages())))

invisible(lapply(pkgs, library, character.only = TRUE))

options(mc.cores = parallel::detectCores())

# ==========================================================
# 1. CARGA DE BASE
# ==========================================================

archivo <- "PERFIL_MADRE_VIOLENTADA_COMPLETO.xlsx"

df <- BASE_HASTA_2024

# ==========================================================
# 2. PREPARACION DE DATOS
# ==========================================================

datos0 <- df %>%
  transmute(
    violencia = as.numeric(VIOLENCIA.CODIGO),
    drogas = as.numeric(DROGAS),
    alcohol = as.numeric(Alcohol.CODIGO),
    tabaco_activo = as.numeric(TABACO.ACTIVO),
    tabaco_pasivo = as.numeric(TABACO.PASIVO),
    gestas = as.numeric(Numero.gestas.previas),
    controles = as.numeric(`Número.Consultas.prenatales`),
    pareja = as.numeric(PAREJA.ESTABLE.CODIGO),
    escolaridad_baja = ifelse(as.numeric(Estudios.CODIGO) <= 1, 1, 0),
    etnia_minoritaria = as.numeric(ETNIA.MINORITARIA),
    edad_materna = as.numeric(Edad.materna)
  )

datos <- datos0 %>%
  drop_na() %>%
  mutate(
    gestas_z = as.numeric(scale(gestas)),
    controles_z = as.numeric(scale(controles)),
    edad_z = as.numeric(scale(edad_materna))
  )

cat("\nPrevalencia registrada de violencia:\n")
print(mean(datos$violencia))
print(table(datos$violencia))

# ==========================================================
# 3. FORMULA
# ==========================================================

form <- violencia ~ drogas + alcohol + tabaco_activo + tabaco_pasivo +
  gestas_z + controles_z + pareja + escolaridad_baja +
  etnia_minoritaria + edad_z

vars <- c(
  "drogas", "alcohol", "tabaco_activo", "tabaco_pasivo",
  "gestas_z", "controles_z", "pareja",
  "escolaridad_baja", "etnia_minoritaria", "edad_z"
)

# ==========================================================
# 4. FALTANTES
# ==========================================================

missing_tab <- naniar::miss_var_summary(datos0)
write.csv(missing_tab, "00_patron_faltantes.csv", row.names = FALSE)

# ==========================================================
# 5. CELDAS 2x2 PARA VARIABLES BINARIAS
# ==========================================================

binarias <- c(
  "drogas", "alcohol", "tabaco_activo", "tabaco_pasivo",
  "pareja", "escolaridad_baja", "etnia_minoritaria"
)

celdas_2x2 <- map_df(binarias, function(v) {
  
  tab <- table(datos[[v]], datos$violencia)
  
  tibble(
    variable = v,
    n00 = ifelse("0" %in% rownames(tab) & "0" %in% colnames(tab), tab["0", "0"], NA),
    n01 = ifelse("0" %in% rownames(tab) & "1" %in% colnames(tab), tab["0", "1"], NA),
    n10 = ifelse("1" %in% rownames(tab) & "0" %in% colnames(tab), tab["1", "0"], NA),
    n11 = ifelse("1" %in% rownames(tab) & "1" %in% colnames(tab), tab["1", "1"], NA)
  )
})

write.csv(celdas_2x2, "01_celdas_2x2.csv", row.names = FALSE)

# ==========================================================
# 6. GLM CLASICO
# ==========================================================

glm_fit <- glm(form, data = datos, family = binomial())

glm_tab <- broom::tidy(glm_fit, exponentiate = TRUE, conf.int = TRUE) %>%
  filter(term != "(Intercept)") %>%
  transmute(
    variable = term,
    OR_GLM = estimate,
    IC95_inf_GLM = conf.low,
    IC95_sup_GLM = conf.high,
    p_GLM = p.value
  )

write.csv(glm_tab, "02_GLM_comparador.csv", row.names = FALSE)

# ==========================================================
# 7. SEPARACION
# ==========================================================

sep <- detectseparation::detect_separation(
  form,
  data = datos,
  family = binomial()
)

capture.output(sep, file = "03_deteccion_separacion.txt")

# ==========================================================
# 8. MODELO PRINCIPAL: FIRTH
# ==========================================================

firth_fit <- logistf::logistf(form, data = datos)

firth_tab <- data.frame(
  variable = names(firth_fit$coefficients),
  beta_Firth = firth_fit$coefficients,
  OR_Firth = exp(firth_fit$coefficients),
  IC95_inf_Firth = exp(firth_fit$ci.lower),
  IC95_sup_Firth = exp(firth_fit$ci.upper),
  p_Firth = firth_fit$prob
) %>%
  filter(variable != "(Intercept)")

write.csv(firth_tab, "04_Firth_modelo_principal.csv", row.names = FALSE)

# ==========================================================
# 9. COLINEALIDAD
# ==========================================================

vif_tab <- data.frame(
  variable = names(car::vif(glm_fit)),
  VIF = as.numeric(car::vif(glm_fit))
)

write.csv(vif_tab, "05_VIF.csv", row.names = FALSE)

# ==========================================================
# 10. BAYESIANO REGISTRADO ROBUSTO
# ==========================================================

priors_robustos <- c(
  set_prior("student_t(3, 0, 1)", class = "b"),
  set_prior("student_t(3, 0, 2.5)", class = "Intercept")
)

bayes_fit <- brm(
  formula = form,
  data = datos,
  family = bernoulli(link = "logit"),
  prior = priors_robustos,
  chains = 4,
  iter = 4000,
  warmup = 2000,
  seed = 2026,
  control = list(adapt_delta = 0.99, max_treedepth = 15)
)

saveRDS(bayes_fit, "06_bayes_registrado_robusto.rds")

post <- posterior::as_draws_df(bayes_fit)

bayes_tab <- map_df(vars, function(v) {
  
  beta <- post[[paste0("b_", v)]]
  OR <- exp(beta)
  
  tibble(
    variable = v,
    OR_Bayes = median(OR),
    ICr95_inf_Bayes = quantile(OR, 0.025),
    ICr95_sup_Bayes = quantile(OR, 0.975),
    P_OR_mayor_1 = mean(OR > 1),
    P_OR_menor_1 = mean(OR < 1)
  )
})

write.csv(bayes_tab, "07_Bayes_registrado_robusto.csv", row.names = FALSE)

diag_bayes <- posterior::summarise_draws(
  post,
  "mean", "sd", "rhat", "ess_bulk", "ess_tail"
)

write.csv(diag_bayes, "08_diagnosticos_bayes.csv", row.names = FALSE)

# ==========================================================
# 11. CALIBRACION, DISCRIMINACION, PR CURVE
# ==========================================================

prob_glm <- fitted(glm_fit)

roc_glm <- pROC::roc(datos$violencia, prob_glm)
auc_glm <- pROC::auc(roc_glm)

png("09_ROC_GLM.png", width = 1800, height = 1400, res = 300)
plot(roc_glm, main = paste("AUC GLM =", round(auc_glm, 3)))
dev.off()

pr <- PRROC::pr.curve(
  scores.class0 = prob_glm[datos$violencia == 1],
  scores.class1 = prob_glm[datos$violencia == 0],
  curve = TRUE
)

png("10_PR_curve_GLM.png", width = 1800, height = 1400, res = 300)
plot(pr)
dev.off()

brier_glm <- mean((datos$violencia - prob_glm)^2)

calib <- tibble(
  y = datos$violencia,
  p = prob_glm
) %>%
  mutate(decil = ntile(p, 10)) %>%
  group_by(decil) %>%
  summarise(
    n = n(),
    predicho = mean(p),
    observado = mean(y),
    .groups = "drop"
  )

write.csv(calib, "11_calibracion_GLM.csv", row.names = FALSE)

png("12_calibracion_GLM.png", width = 1800, height = 1400, res = 300)
plot(
  calib$predicho,
  calib$observado,
  xlab = "Riesgo predicho",
  ylab = "Riesgo observado",
  pch = 19,
  main = "Calibracion del modelo registrado"
)
abline(0, 1, lty = 2)
dev.off()

# ==========================================================
# 12. VALIDACION INTERNA BOOTSTRAP AUC
# ==========================================================

boot_auc <- function(data, indices) {
  
  d <- data[indices, ]
  
  m <- glm(form, data = d, family = binomial())
  p <- predict(m, type = "response")
  
  roc_obj <- pROC::roc(d$violencia, p, quiet = TRUE)
  
  as.numeric(pROC::auc(roc_obj))
}

set.seed(2026)

boot_res <- boot::boot(
  data = datos,
  statistic = boot_auc,
  R = 500
)

boot_ci <- boot::boot.ci(boot_res, type = "perc")

capture.output(boot_res, boot_ci, file = "13_bootstrap_AUC.txt")

# ==========================================================
# 13. SENSIBILIDAD POR SUBREGISTRO NO DIFERENCIAL
# ==========================================================

escenarios <- tibble(
  escenario = c(
    "subregistro_leve",
    "subregistro_moderado",
    "subregistro_severo",
    "subregistro_extremo"
  ),
  Se = c(0.80, 0.60, 0.40, 0.25),
  Sp = c(0.99, 0.99, 0.995, 0.995)
)

writeLines('
data {
  int<lower=1> N;
  int<lower=1> K;
  matrix[N, K] X;
  array[N] int<lower=0, upper=1> y;
  real<lower=0, upper=1> Se;
  real<lower=0, upper=1> Sp;
}

parameters {
  vector[K] beta;
}

model {
  vector[N] p_true;
  vector[N] p_obs;

  beta ~ student_t(3, 0, 1);

  p_true = inv_logit(X * beta);

  for (i in 1:N) {
    p_obs[i] = Se * p_true[i] + (1 - Sp) * (1 - p_true[i]);
    y[i] ~ bernoulli(p_obs[i]);
  }
}

generated quantities {
  vector[K] OR;

  for (k in 1:K) {
    OR[k] = exp(beta[k]);
  }
}
', "modelo_subregistro_fijo.stan")

X <- model.matrix(form, data = datos)
nombres_x <- colnames(X)

stan_data_base <- list(
  N = nrow(datos),
  K = ncol(X),
  X = X,
  y = as.integer(datos$violencia)
)

sens_list <- list()

for (j in seq_len(nrow(escenarios))) {
  
  data_j <- stan_data_base
  data_j$Se <- escenarios$Se[j]
  data_j$Sp <- escenarios$Sp[j]
  
  fit_j <- rstan::stan(
    file = "modelo_subregistro_fijo.stan",
    data = data_j,
    chains = 4,
    iter = 3000,
    warmup = 1500,
    seed = 3000 + j,
    control = list(adapt_delta = 0.99, max_treedepth = 15)
  )
  
  post_j <- posterior::as_draws_df(fit_j)
  
  tab_j <- map_df(seq_along(nombres_x), function(k) {
    
    OR <- post_j[[paste0("OR[", k, "]")]]
    
    tibble(
      escenario = escenarios$escenario[j],
      Se = escenarios$Se[j],
      Sp = escenarios$Sp[j],
      variable = nombres_x[k],
      OR_mediana = median(OR),
      ICr95_inf = quantile(OR, 0.025),
      ICr95_sup = quantile(OR, 0.975),
      P_OR_mayor_1 = mean(OR > 1),
      P_OR_menor_1 = mean(OR < 1)
    )
  }) %>%
    filter(variable != "(Intercept)")
  
  sens_list[[j]] <- tab_j
}

sens_subregistro <- bind_rows(sens_list)

write.csv(
  sens_subregistro,
  "14_sensibilidad_subregistro_SeSp.csv",
  row.names = FALSE
)

# ==========================================================
# 14. SENSIBILIDAD CRUDA POR PREVALENCIAS CORREGIDAS
# ==========================================================

corr_prev <- function(p_obs, Se, Sp) {
  p <- (p_obs + Sp - 1) / (Se + Sp - 1)
  pmin(pmax(p, 1e-6), 1 - 1e-6)
}

sens_cruda <- crossing(
  variable = binarias,
  escenarios
) %>%
  mutate(resultado = pmap(
    list(variable, Se, Sp),
    function(variable, Se, Sp) {
      
      d <- datos %>% filter(!is.na(.data[[variable]]))
      
      p1_obs <- mean(d$violencia[d[[variable]] == 1])
      p0_obs <- mean(d$violencia[d[[variable]] == 0])
      
      p1_corr <- corr_prev(p1_obs, Se, Sp)
      p0_corr <- corr_prev(p0_obs, Se, Sp)
      
      OR_corr <- (p1_corr / (1 - p1_corr)) /
        (p0_corr / (1 - p0_corr))
      
      tibble(
        p1_obs = p1_obs,
        p0_obs = p0_obs,
        p1_corr = p1_corr,
        p0_corr = p0_corr,
        OR_crudo_corregido = OR_corr
      )
    }
  )) %>%
  unnest(resultado)

write.csv(
  sens_cruda,
  "15_sensibilidad_cruda_prevalencias_corregidas.csv",
  row.names = FALSE
)

# ==========================================================
# 15. IMPUTACION MULTIPLE MAR
# ==========================================================

imp_data <- datos0 %>%
  mutate(
    gestas_z = as.numeric(scale(gestas)),
    controles_z = as.numeric(scale(controles)),
    edad_z = as.numeric(scale(edad_materna))
  ) %>%
  select(
    violencia, drogas, alcohol, tabaco_activo, tabaco_pasivo,
    gestas_z, controles_z, pareja, escolaridad_baja,
    etnia_minoritaria, edad_z
  )

ini <- mice::mice(imp_data, maxit = 0, printFlag = FALSE)

meth <- ini$method
pred <- ini$predictorMatrix

meth["violencia"] <- "logreg"

imp <- mice::mice(
  imp_data,
  m = 20,
  method = meth,
  predictorMatrix = pred,
  seed = 2026,
  printFlag = FALSE
)

fit_imp <- with(
  imp,
  glm(
    violencia ~ drogas + alcohol + tabaco_activo + tabaco_pasivo +
      gestas_z + controles_z + pareja + escolaridad_baja +
      etnia_minoritaria + edad_z,
    family = binomial()
  )
)

pool_imp <- pool(fit_imp)

mi_tab <- summary(pool_imp, conf.int = TRUE, exponentiate = TRUE) %>%
  filter(term != "(Intercept)")

write.csv(mi_tab, "16_imputacion_multiple_MAR.csv", row.names = FALSE)

# ==========================================================
# 16. SENSIBILIDAD MNAR TIPO DELTA
# ==========================================================

mnar_base <- datos0 %>%
  mutate(
    r_violencia = ifelse(is.na(violencia), 0, 1),
    violencia_obs0 = ifelse(is.na(violencia), 0, violencia),
    gestas_z = as.numeric(scale(gestas)),
    controles_z = as.numeric(scale(controles)),
    edad_z = as.numeric(scale(edad_materna))
  ) %>%
  drop_na(
    drogas, alcohol, tabaco_activo, tabaco_pasivo,
    gestas_z, controles_z, pareja, escolaridad_baja,
    etnia_minoritaria, edad_z
  )

delta_grid <- c(0, 0.5, 1.0, 1.5, 2.0)
B <- 100

mnar_resultados <- list()

for (delta in delta_grid) {
  
  for (b in seq_len(B)) {
    
    set.seed(5000 + b + round(delta * 100))
    
    d_b <- mnar_base
    
    p_base <- mean(datos$violencia)
    p_mnar <- plogis(qlogis(p_base) + delta)
    
    d_b$violencia_delta <- ifelse(
      d_b$r_violencia == 1,
      d_b$violencia_obs0,
      rbinom(nrow(d_b), 1, p_mnar)
    )
    
    m_b <- logistf::logistf(
      violencia_delta ~ drogas + alcohol + tabaco_activo + tabaco_pasivo +
        gestas_z + controles_z + pareja + escolaridad_baja +
        etnia_minoritaria + edad_z,
      data = d_b
    )
    
    tab_b <- data.frame(
      variable = names(m_b$coefficients),
      OR = exp(m_b$coefficients)
    ) %>%
      filter(variable != "(Intercept)") %>%
      mutate(delta = delta, simulacion = b)
    
    mnar_resultados[[length(mnar_resultados) + 1]] <- tab_b
  }
}

mnar_tab <- bind_rows(mnar_resultados)

mnar_resumen <- mnar_tab %>%
  group_by(delta, variable) %>%
  summarise(
    OR_mediana = median(OR),
    OR_p025 = quantile(OR, 0.025),
    OR_p975 = quantile(OR, 0.975),
    .groups = "drop"
  )

write.csv(mnar_tab, "17_MNAR_delta_simulaciones.csv", row.names = FALSE)
write.csv(mnar_resumen, "18_MNAR_delta_resumen.csv", row.names = FALSE)

# ==========================================================
# 17. E-VALUES PARA FIRTH
# ==========================================================

evalue_tab <- firth_tab %>%
  mutate(
    Evalue_OR = purrr::map_dbl(
      OR_Firth,
      ~ as.numeric(EValue::evalues.OR(est = .x, lo = NA, hi = NA)$Evalues[1])
    )
  )

write.csv(evalue_tab, "19_Evalues_Firth.csv", row.names = FALSE)

# ==========================================================
# 18. TABLA FINAL
# ==========================================================

tabla_final <- firth_tab %>%
  select(variable, OR_Firth, IC95_inf_Firth, IC95_sup_Firth, p_Firth) %>%
  left_join(glm_tab, by = "variable") %>%
  left_join(bayes_tab, by = "variable") %>%
  left_join(vif_tab, by = "variable") %>%
  left_join(evalue_tab %>% select(variable, Evalue_OR), by = "variable")

write.csv(tabla_final, "20_tabla_final_modelos.csv", row.names = FALSE)

# ==========================================================
# 19. CRITERIOS DE ROBUSTEZ
# ==========================================================

robustez <- tabla_final %>%
  mutate(
    direccion_Firth = case_when(
      OR_Firth > 1 ~ "positiva",
      OR_Firth < 1 ~ "inversa",
      TRUE ~ "nula"
    ),
    direccion_Bayes = case_when(
      OR_Bayes > 1 ~ "positiva",
      OR_Bayes < 1 ~ "inversa",
      TRUE ~ "nula"
    ),
    evidencia_bayes = case_when(
      P_OR_mayor_1 >= 0.975 ~ "positiva fuerte",
      P_OR_menor_1 >= 0.975 ~ "inversa fuerte",
      P_OR_mayor_1 >= 0.90 ~ "positiva moderada",
      P_OR_menor_1 >= 0.90 ~ "inversa moderada",
      TRUE ~ "incierta"
    ),
    robusta_modelos = direccion_Firth == direccion_Bayes,
    VIF_alto = ifelse(!is.na(VIF) & VIF >= 3, TRUE, FALSE)
  )

write.csv(robustez, "21_criterios_robustez.csv", row.names = FALSE)

# ==========================================================
# 20. RESUMEN
# ==========================================================

cat("\n====================================================\n")
cat("ANALISIS COMPLETADO\n")
cat("====================================================\n")

cat("\nEstimando primario:\n")
cat("Asociacion con violencia gestacional registrada.\n")

cat("\nSubregistro:\n")
cat("Evaluado mediante sensibilidad Se/Sp y MNAR; no estimado como verdad observada.\n")

cat("\nArchivos principales:\n")
cat("\n04_Firth_modelo_principal.csv")
cat("\n07_Bayes_registrado_robusto.csv")
cat("\n14_sensibilidad_subregistro_SeSp.csv")
cat("\n18_MNAR_delta_resumen.csv")
cat("\n19_Evalues_Firth.csv")
cat("\n20_tabla_final_modelos.csv")
cat("\n21_criterios_robustez.csv\n")

cat("\nAUC GLM:\n")
print(auc_glm)

cat("\nBrier score GLM:\n")
print(brier_glm)

cat("\nPrevalencia registrada:\n")
print(mean(datos$violencia))

