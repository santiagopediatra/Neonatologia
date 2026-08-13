import pandas as pd
from pathlib import Path


# ============================================================
# CARGAR BASE ORIGINAL
# ============================================================

archivo = Path(
    "datos/originales/CALDERON_obito_04_agosto_2026.csv"
)

df = pd.read_csv(
    archivo,
    sep=";",
    encoding="latin1",
    dtype=str
)


# ============================================================
# MOSTRAR ENCABEZADOS NUMERADOS
# ============================================================

print()
print("========================================")
print("ENCABEZADO COMPLETO DE LA BASE")
print("========================================")
print()

for numero, columna in enumerate(df.columns, start=1):
    print(f"{numero:02d}. {columna}")


print()
print("========================================")
print(f"TOTAL DE COLUMNAS: {len(df.columns)}")
print("========================================")
