#!/usr/bin/env Rscript

ejecutar <- function(comando, args) {
  estado <- system2(comando, args = args)
  if (estado != 0) stop("Falló: ", comando, " ", paste(args, collapse = " "))
}

ejecutar("Rscript", "01_auditar_tabla1.R")
ejecutar(".venv/bin/python", "02_comparar_word_tabla1.py")
ejecutar(".venv/bin/python", "03_actualizar_documento.py")
