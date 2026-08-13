source("analisis_bayesiano/00_funciones_bayes.R"); d <- leer_base_bayes()
f_principal <- bf(MUERTE_FETAL_BINARIA ~ EDAD_CAT + HIPERTENSIVOS_A + PAREJA_ESTABLE_A + INSTRUCCION_A + ACOMPANADA_BIN + CONTROLES_Z + SESIONES_Z + IVU_A)
pr_principal <- c(prior(normal(0,.7),class="b"),prior(normal(-4,1.5),class="Intercept"))
dp <- filas_modelo(formula(f_principal),d)
prior_file <- file.path(DIR_MODELOS,"BAYES_PRIOR_PREDICTIVO_PRINCIPAL.rds")
if(file.exists(prior_file)) priorfit <- readRDS(prior_file) else {
  priorfit <- brm(f_principal,data=dp,family=bernoulli("logit"),prior=pr_principal,sample_prior="only",
    chains=4,cores=min(4,parallel::detectCores()),iter=1250,warmup=1000,seed=20260810,
    backend="cmdstanr",control=list(adapt_delta=.99,max_treedepth=15),
    file=file.path(DIR_STAN,"BAYES_PRIOR_PREDICTIVO_PRINCIPAL"),file_refit="on_change",refresh=200)
  saveRDS(priorfit,prior_file)
}
yprior <- posterior_predict(priorfit,draws=1000); ev <- rowSums(yprior)
write_csv(tibble(Eventos=ev,Frecuencia=ev/nrow(dp)),file.path(DIR_TABLAS,"PRIOR_PREDICTIVE_PRINCIPAL.csv"))
png(file.path(DIR_PRIOR_PP,"PRIOR_PREDICTIVE_PRINCIPAL.png"),1800,1200,res=200)
hist(ev,breaks=40,col="#70A9A1",main="Distribución predictiva previa del número de eventos",xlab="Eventos esperados"); abline(v=sum(dp$MUERTE_FETAL_BINARIA),col="red",lwd=2); dev.off()
fit <- ajustar_modelo_bayes(f_principal,d,pr_principal,"BAYES_PRINCIPAL")
tab <- guardar_tabla_modelo(fit,"BAYES_PRINCIPAL","TABLA_BAYES_PRINCIPAL.csv")
guardar_forest(tab,"FOREST_BAYES_PRINCIPAL.png","Modelo bayesiano principal")
guardar_ppc(fit,"PRINCIPAL")
