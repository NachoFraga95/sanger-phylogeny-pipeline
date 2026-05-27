#!/usr/bin/env python3
import os
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FA_DIR = os.path.join(ROOT, "work", "04_align_filtered")

meta_2024 = os.path.join(ROOT, "meta_2024.tsv")
meta_2025 = os.path.join(ROOT, "meta_2025.tsv")

# --------------------------------------------------------------------
# 1) Cargar metadata: (year, ID) -> especie
# --------------------------------------------------------------------
id2species = {}  # (year, num) -> species

def load_meta(path, year):
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            num_str, species = parts[0], parts[1]
            try:
                num = int(num_str)
            except ValueError:
                continue
            id2species[(year, num)] = species

load_meta(meta_2024, 2024)
load_meta(meta_2025, 2025)

# --------------------------------------------------------------------
# 2) Definir colores por especie (ajusta / agrega si hace falta)
# --------------------------------------------------------------------
species_colors = {
    "E. roseus":       "#e41a1c",
    "E. altor":        "#377eb8",
    "E. vertebralis":  "#4daf4a",
    "E. migueli":      "#984ea3",
    "E. insularis":    "#ff7f00",
    "E. contulmoensis":"#a65628",
    "E. septentrionalis":"#f781bf",
    "P. thaul":       "#999999",
    "P. bufonina":    "#ffff33",
    "A. hugoi":          "#66c2a5",
}

# --------------------------------------------------------------------
# 3) Leer todos los IDs de work/04_align_filtered/*.filtered.fa
# --------------------------------------------------------------------
labels = set()

for fname in os.listdir(FA_DIR):
    if not fname.endswith(".filtered.fa"):
        continue
    path = os.path.join(FA_DIR, fname)
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith(">"):
                label = line[1:].strip()
                labels.add(label)

# --------------------------------------------------------------------
# 4) Para cada ID del árbol, deducir (año, numero) y especie
#    Formatos esperados:
#       2024_19_CYTB
#       2024_19_1_CYTB   (con índice de copia)
# --------------------------------------------------------------------
def parse_label(label):
    # 2024_19_CYTB  OR  2025_19_1_COI
    m = re.match(r"^(20\d{2})_(\d+)(?:_\d+)?_[A-Za-z0-9]+$", label)
    if not m:
        return None
    year = int(m.group(1))
    num  = int(m.group(2))
    return year, num

rows = []          # (label, color)
species_in_tree = set()

for lab in sorted(labels):
    parsed = parse_label(lab)
    if not parsed:
        # por si hay algo raro como "outgroup" con otro formato
        continue
    year, num = parsed
    sp = id2species.get((year, num))
    if not sp:
        # No tenemos especie para este ID (p.ej. un outgroup externo)
        continue
    color = species_colors.get(sp, "#000000")  # negro si no está mapeada
    rows.append((lab, color, sp))
    species_in_tree.add(sp)

# --------------------------------------------------------------------
# 5) Imprimir archivo DATASET_COLORSTRIP para iTOL
# --------------------------------------------------------------------
print("DATASET_COLORSTRIP")
print("SEPARATOR\tTAB")
print("DATASET_LABEL\tEspecies")
print("COLOR\t#000000")  # color por defecto (no muy relevante aquí)
print("STRIP_WIDTH\t25")
print("BORDER_WIDTH\t0")
print("BORDER_COLOR\t#000000")
print("SHOW_INTERNAL\t0")
print()

# Leyenda: solo incluimos las especies que efectivamente aparecen en los árboles
legend_species = sorted(species_in_tree)
legend_colors = [species_colors.get(sp, "#000000") for sp in legend_species]

print("LEGEND_TITLE\tEspecies")
print("LEGEND_SHAPES\t" + "\t".join(["1"] * len(legend_species)))
print("LEGEND_COLORS\t" + "\t".join(legend_colors))
print("LEGEND_LABELS\t" + "\t".join(legend_species))
print()

print("DATA")
for lab, color, sp in rows:
    print(f"{lab}\t{color}")
