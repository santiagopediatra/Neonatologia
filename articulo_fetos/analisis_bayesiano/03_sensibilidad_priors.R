source("analisis_bayesiano/00_funciones_bayes.R"); d<-leer_base_bayes()
f <- bf(MUERTE_FETAL_BINARIA ~ EDAD_CAT + HIPERTENSIVOS_A + PAREJA_ESTABLE_A + INSTRUCCION_A + ACOMPANADA_BIN + CONTROLES_Z + SESIONES_Z + IVU_A)
fitA <- readRDS(file.path(DIR_MODELOS,"BAYES_PRINCIPAL.rds"))
fitB <- ajustar_modelo_bayes(f,d,c(prior(normal(0,.5),class="b"),prior(normal(-4,1),class="Intercept")),"BAYES_PRIOR_ESCEPTICO")
fitC <- ajustar_modelo_bayes(f,d,c(prior(normal(0,1),class="b"),prior(normal(-4,2),class="Intercept")),"BAYES_PRIOR_AMPLIO")
tabs <- bind_rows(resumen_posterior(fitA,"Principal"),resumen_posterior(fitB,"Escéptico"),resumen_posterior(fitC,"Amplio"))
write_csv(tabs,file.path(DIR_TABLAS,"TABLA_SENSIBILIDAD_PRIORS.csv")); guardar_forest(tabs,"FOREST_SENSIBILIDAD_PRIORS.png","Sensibilidad a priors")
pri <- tribble(~Modelo,~Parametro,~Prior,~Media,~SD,~OR_2.5,~OR_97.5,~Uso,
 "Principal","Coeficientes","normal(0,0.7)",0,.7,exp(-1.96*.7),exp(1.96*.7),"Principal",
 "Principal","Intercepto","normal(-4,1.5)",-4,1.5,NA,NA,"Principal",
 "Sensible_esceptico","Coeficientes","normal(0,0.5)",0,.5,exp(-1.96*.5),exp(1.96*.5),"Sensibilidad",
 "Sensible_esceptico","Intercepto","normal(-4,1)",-4,1,NA,NA,"Sensibilidad",
 "Sensible_amplio","Coeficientes","normal(0,1)",0,1,exp(-1.96),exp(1.96),"Sensibilidad",
 "Sensible_amplio","Intercepto","normal(-4,2)",-4,2,NA,NA,"Sensibilidad")
write_csv(pri,file.path(DIR_TABLAS,"PRIORS_ESPECIFICADOS.csv"))
