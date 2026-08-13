#!/usr/bin/env python3

"""Genera el Word intermedio con únicamente la Tabla 1 corregida."""

import runpy
import shutil
from pathlib import Path

runpy.run_path("03_actualizar_documento.py", run_name="__main__")

origen_corregido = Path("manuscrito/Articulo_fetos_CORREGIDO.docx")
salida = Path("manuscrito/Articulo_fetos_TABLA1_CORREGIDA.docx")
if not origen_corregido.exists():
    raise RuntimeError("No se generó la copia con Tabla 1 corregida.")
shutil.copy2(origen_corregido, salida)
print(f"Word intermedio generado: {salida}")
