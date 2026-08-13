#!/usr/bin/env python3

import csv
import re
import unicodedata
from pathlib import Path

from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph

WORD = Path("manuscrito/Articulo_fetos.docx")
CALCULOS = Path("tabla1_corregida.csv")
ERRORES = Path("errores_tabla1.csv")


def iter_blocks(document):
    for child in document.element.body.iterchildren():
        if child.tag.endswith("}p"):
            yield Paragraph(child, document)
        elif child.tag.endswith("}tbl"):
            yield Table(child, document)


def normalizar(texto):
    texto = unicodedata.normalize("NFKD", texto or "")
    texto = "".join(c for c in texto if not unicodedata.combining(c))
    texto = texto.replace("\xa0", " ").replace("–", "-").replace("—", "-")
    return re.sub(r"\s+", " ", texto).strip().casefold()


def identificar_tabla1(document):
    titulo_visto = False
    numero = 0
    for bloque in iter_blocks(document):
        if isinstance(bloque, Paragraph):
            if "tabla 1." in normalizar(bloque.text):
                titulo_visto = True
        else:
            numero += 1
            encabezados = [normalizar(c.text) for c in bloque.rows[0].cells]
            estructura = encabezados == [
                "variable", "categoria", "muerte_fetal_no", "muerte_fetal_si"
            ]
            if titulo_visto and estructura:
                return numero, bloque
            titulo_visto = False
    raise RuntimeError("No se encontró inequívocamente la Tabla 1.")


def leer_calculos():
    with CALCULOS.open(encoding="utf-8-sig", newline="") as f:
        filas = list(csv.DictReader(f))
    return {
        (normalizar(r["etiqueta"]), normalizar(r["categoria"]), r["desenlace"]): r
        for r in filas
    }


def extraer_valor(texto):
    m = re.search(r"^\s*(\d+)\s*\(\s*([0-9]+(?:[.,][0-9]+)?)\s*%\s*\)\s*$", texto)
    if not m:
        return None
    return int(m.group(1)), float(m.group(2).replace(",", "."))


doc = Document(WORD)
numero, tabla = identificar_tabla1(doc)
encabezados = [c.text.strip() for c in tabla.rows[0].cells]
print(f"Tabla 1 identificada como tabla número {numero} del documento")
print(f"Filas: {len(tabla.rows)}; columnas: {len(tabla.columns)}")
print("Encabezados:", encabezados)
if len(tabla.rows) != 29 or len(tabla.columns) != 4:
    raise RuntimeError("La Tabla 1 no tiene la estructura esperada de 29 x 4.")

calculos = leer_calculos()
salida = []
variable_actual = ""
for fila_word, row in enumerate(tabla.rows[1:], start=2):
    variable_texto = row.cells[0].text.strip()
    if variable_texto:
        variable_actual = variable_texto
    categoria = row.cells[1].text.strip()
    for columna_word, desenlace in ((3, "NO"), (4, "SI")):
        valor_documento = row.cells[columna_word - 1].text.strip()
        clave = (normalizar(variable_actual), normalizar(categoria), desenlace)
        calculo = calculos.get(clave)
        publicado = extraer_valor(valor_documento)
        estado = "OK"
        diferencia = ""
        valor_calculado = ""
        variable_codigo = ""
        if calculo is None:
            estado = "NO_ENCONTRADO"
        elif publicado is None:
            estado = "REQUIERE_REVISION_MANUAL"
            variable_codigo = calculo["variable"]
            valor_calculado = calculo["valor_formateado"]
        else:
            variable_codigo = calculo["variable"]
            valor_calculado = calculo["valor_formateado"]
            diferencia_num = publicado[1] - float(calculo["porcentaje"])
            diferencia = f"{diferencia_num:.2f}"
            if publicado[0] != int(calculo["n"]):
                estado = "REQUIERE_REVISION_MANUAL"
            elif abs(diferencia_num) > 0.005:
                estado = "ERROR_PORCENTAJE"
        salida.append({
            "fila_word": fila_word,
            "columna_word": columna_word,
            "variable": variable_codigo,
            "variable_documento": variable_actual,
            "categoria": categoria,
            "desenlace": desenlace,
            "valor_documento": valor_documento,
            "valor_calculado": valor_calculado,
            "diferencia": diferencia,
            "estado": estado,
        })

campos = list(salida[0])
with ERRORES.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=campos)
    w.writeheader()
    w.writerows(salida)

errores = [r for r in salida if r["estado"] == "ERROR_PORCENTAJE"]
print("\nPLAN DE CAMBIOS (todavía no aplicado)")
print("Fila | Columna | Variable | Categoría | Desenlace | Valor actual | Valor nuevo")
for r in errores:
    print(
        f'{r["fila_word"]} | {r["columna_word"]} | {r["variable_documento"]} | '
        f'{r["categoria"]} | {r["desenlace"]} | {r["valor_documento"]} | {r["valor_calculado"]}'
    )
print(f"\nPorcentajes comparados: {len(salida)}")
print(f"Errores de porcentaje: {len(errores)}")
print(f"Revisión manual: {sum(r['estado'] == 'REQUIERE_REVISION_MANUAL' for r in salida)}")
