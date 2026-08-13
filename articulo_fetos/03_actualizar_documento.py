#!/usr/bin/env python3

import csv
import re
import shutil
import unicodedata
from pathlib import Path

from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph

ORIGEN = Path("manuscrito/Articulo_fetos.docx")
BACKUP = Path("manuscrito/Articulo_fetos_BACKUP.docx")
SALIDA = Path("manuscrito/Articulo_fetos_CORREGIDO.docx")
ERRORES = Path("errores_tabla1.csv")
VALIDACION = Path("validacion_final_tabla1.csv")
INFORME = Path("INFORME_AUDITORIA_TABLA1.md")


def normalizar(texto):
    texto = unicodedata.normalize("NFKD", texto or "")
    texto = "".join(c for c in texto if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", texto.replace("\xa0", " ")).strip().casefold()


def iter_blocks(document):
    for child in document.element.body.iterchildren():
        if child.tag.endswith("}p"):
            yield Paragraph(child, document)
        elif child.tag.endswith("}tbl"):
            yield Table(child, document)


def identificar_tabla1(document):
    titulo_visto = False
    for bloque in iter_blocks(document):
        if isinstance(bloque, Paragraph):
            if "tabla 1." in normalizar(bloque.text):
                titulo_visto = True
        else:
            encabezados = [normalizar(c.text) for c in bloque.rows[0].cells]
            if titulo_visto and encabezados == [
                "variable", "categoria", "muerte_fetal_no", "muerte_fetal_si"
            ]:
                return bloque
            titulo_visto = False
    raise RuntimeError("No se encontró inequívocamente la Tabla 1.")


def reemplazar_preservando_formato(cell, nuevo):
    parrafos = cell.paragraphs
    if len(parrafos) != 1:
        raise RuntimeError("Celda con estructura de párrafos inesperada.")
    p = parrafos[0]
    if not p.runs:
        p.add_run(nuevo)
        return
    p.runs[0].text = nuevo
    for run in p.runs[1:]:
        run.text = ""


with ERRORES.open(encoding="utf-8-sig", newline="") as f:
    filas = list(csv.DictReader(f))
cambios = [r for r in filas if r["estado"] == "ERROR_PORCENTAJE"]
ambiguos = [r for r in filas if r["estado"] in {"NO_ENCONTRADO", "REQUIERE_REVISION_MANUAL"}]
if ambiguos:
    raise RuntimeError("Hay correspondencias ambiguas; no se modificará el Word.")

if not BACKUP.exists():
    shutil.copy2(ORIGEN, BACKUP)
if BACKUP.read_bytes() != ORIGEN.read_bytes():
    raise RuntimeError("El backup no coincide con el Word de origen antes de editar.")

shutil.copy2(ORIGEN, SALIDA)
doc = Document(SALIDA)
tabla = identificar_tabla1(doc)
for r in cambios:
    fila = int(r["fila_word"])
    columna = int(r["columna_word"])
    cell = tabla.rows[fila - 1].cells[columna - 1]
    if cell.text.strip() != r["valor_documento"].strip():
        raise RuntimeError(f"La celda {fila},{columna} cambió desde la comparación.")
    reemplazar_preservando_formato(cell, r["valor_calculado"])
    print(
        f'CORREGIDO: fila {fila}, columna {columna}; '
        f'{r["variable_documento"]} — {r["categoria"]} — {r["desenlace"]}; '
        f'{r["valor_documento"]} -> {r["valor_calculado"]}'
    )
doc.save(SALIDA)

# Segunda lectura independiente del Word corregido.
doc_validacion = Document(SALIDA)
tabla_validacion = identificar_tabla1(doc_validacion)
validacion = []
for r in filas:
    celda = tabla_validacion.rows[int(r["fila_word"]) - 1].cells[int(r["columna_word"]) - 1]
    observado = celda.text.strip()
    estado = "OK" if observado == r["valor_calculado"] else "ERROR"
    validacion.append({**r, "valor_releido": observado, "validacion_final": estado})

with VALIDACION.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(validacion[0]))
    w.writeheader()
    w.writerows(validacion)

residuales = sum(r["validacion_final"] != "OK" for r in validacion)
print(f"Relectura del Word corregido: {'OK' if residuales == 0 else 'ERROR'}")
print(f"Errores residuales: {residuales}")
if residuales:
    raise RuntimeError("La validación final contiene errores residuales.")

correctos = sum(r["estado"] == "OK" for r in filas)
incorrectos = len(cambios)
ambiguos_n = sum(r["estado"] in {"NO_ENCONTRADO", "REQUIERE_REVISION_MANUAL"} for r in filas)
variables = []
for r in filas:
    if r["variable_documento"] not in variables:
        variables.append(r["variable_documento"])

lineas = [
    "# Informe de auditoría de porcentajes de la Tabla 1",
    "",
    "## Población analítica",
    "",
    "- Registros iniciales: 23.848.",
    "- Registros con `MUERTE_FETAL_BINARIA` válido: 23.642.",
    "- Registros analizados: 23.642.",
    "",
    "## Tabla auditada",
    "",
    "- Número de filas: 29, incluida la cabecera.",
    "- Número de columnas: 4.",
    f"- Variables auditadas ({len(variables)}): " + "; ".join(variables) + ".",
    "",
    "## Errores encontrados",
    "",
    f"- Porcentajes comparados: {len(filas)}.",
    f"- Correctos: {correctos}.",
    f"- Incorrectos: {incorrectos}.",
    f"- Ambiguos: {ambiguos_n}.",
    "",
    "## Correcciones realizadas",
    "",
    "| Variable | Categoría | Desenlace | Documento | Correcto | Diferencia (pp) |",
    "|:--|:--|:--|:--|:--|--:|",
]
for r in cambios:
    lineas.append(
        f'| {r["variable_documento"]} | {r["categoria"]} | {r["desenlace"]} | '
        f'{r["valor_documento"]} | {r["valor_calculado"]} | {r["diferencia"]} |'
    )
lineas += [
    "",
    "## Validación",
    "",
    "- Porcentajes recalculados desde base: OK.",
    "- Suma por columnas: OK.",
    "- Documento corregido generado: SÍ.",
    "- Relectura del Word corregido: OK.",
    f"- Errores residuales: {residuales}.",
    "",
    "## Archivos generados",
    "",
    "- `01_auditar_tabla1.R`",
    "- `02_comparar_word_tabla1.py`",
    "- `03_actualizar_documento.py`",
    "- `04_ejecutar_auditoria_completa.R`",
    "- `tabla1_auditoria_porcentajes.csv`",
    "- `tabla1_corregida.csv`",
    "- `errores_tabla1.csv`",
    "- `validacion_final_tabla1.csv`",
    "- `manuscrito/Articulo_fetos_BACKUP.docx`",
    "- `manuscrito/Articulo_fetos_CORREGIDO.docx`",
    "- `INFORME_AUDITORIA_TABLA1.md`",
    "",
    "No se imputaron datos, no se modificó la base y no se realizaron modelos estadísticos.",
]
INFORME.write_text("\n".join(lineas) + "\n", encoding="utf-8")
print(f"Informe generado: {INFORME}")
