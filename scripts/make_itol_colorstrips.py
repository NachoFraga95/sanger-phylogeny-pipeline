#!/usr/bin/env python3
import os
import re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

META_2024 = os.path.join(ROOT, "meta_2024.tsv")
META_2025 = os.path.join(ROOT, "meta_2025.tsv")

TREES_DIR = os.path.join(ROOT, "work", "05_trees_renamed")

# Marcadores que tienes en los árboles
MARKERS = ["12S", "16S", "COI", "CRY", "CYTB", "DLOOP", "POMC", "RHOD"]

# Paleta de colores por especie (bastante sobria)
SPECIES_COLORS = {
    "E. roseus":           "#d73027",
    "E. contulmoensis":    "#b35806",
    "E. insularis":        "#984ea3",
    "E. migueli":          "#e78ac3",
    "E. septentrionalis":  "#377eb8",
    "E. altor":            "#4daf4a",
    "P. bufonina":         "#ffb74d",  # naranja suave
    "A. hugoi":            "#66c2a5",
    "E. vertebralis":      "#1f78b4",
    "P. thaul":            "#555555",
}

def load_meta(path, year):
    """
    Lee meta_YYYY.tsv -> dict[int_id] = (especie, codigo)
    """
    meta = {}
    if not os.path.exists(path):
        print(f"[WARN] meta {year} no encontrada: {path}")
        return meta

    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            try:
                idx = int(parts[0])
            except ValueError:
                continue
            species = parts[1].strip()
            code = parts[2].strip()
            meta[idx] = (species, code)
    print(f"[meta] {year}: cargadas {len(meta)} entradas desde {os.path.basename(path)}")
    return meta

def parse_tips(tree_text, marker):
    """
    Devuelve lista de (full_id, year, idx) para un marcador dado.
    full_id es exactamente como aparece en el treefile.
    """
    # Ejemplo de tip: 2024_11_Erossj012017_CYTB
    pat = re.compile(r"(\d{4})_(\d+)_([^:,()]+)_" + re.escape(marker))
    tips = {}
    for m in pat.finditer(tree_text):
        year = int(m.group(1))
        idx = int(m.group(2))
        # reconstruimos el ID exactamente como está en el árbol:
        full_id = f"{m.group(1)}_{m.group(2)}_{m.group(3)}_{marker}"
        tips[full_id] = (year, idx)
    return tips

def write_species_colorstrip(marker, tips, meta_by_year):
    out_path = os.path.join(ROOT, f"itol_colorstrip_species_{marker}.txt")

    # recolectar qué especies aparecen en este árbol
    used_species = []
    rows = []

    for full_id, (year, idx) in tips.items():
        meta = meta_by_year.get(year, {})
        if idx not in meta:
            # muestra que no está en meta (puede pasar con outgroups raros)
            continue
        species, code = meta[idx]
        color = SPECIES_COLORS.get(species, "#000000")
        if species not in used_species:
            used_species.append(species)
        label = species  # lo que quieres mostrar en el strip
        rows.append((full_id, color, label, species))

    if not rows:
        print(f"[species] {marker}: sin filas, no se escribe archivo.")
        return

    # ordenar filas por especie para que quede prolijo
    rows.sort(key=lambda x: x[3])

    # construir leyenda según especies efectivamente presentes
    legend_colors = []
    legend_labels = []
    legend_shapes = []
    for sp in used_species:
        legend_colors.append(SPECIES_COLORS.get(sp, "#000000"))
        legend_labels.append(sp)
        legend_shapes.append("1")

    with open(out_path, "w", encoding="utf-8") as out:
        out.write("DATASET_COLORSTRIP\n")
        out.write("SEPARATOR TAB\n")
        out.write("DATASET_LABEL\tSpecies\n")
        out.write("COLOR\t#000000\n\n")

        out.write("LEGEND_TITLE\tSpecies\n")
        out.write("LEGEND_SHAPES\t" + "\t".join(legend_shapes) + "\n")
        out.write("LEGEND_COLORS\t" + "\t".join(legend_colors) + "\n")
        out.write("LEGEND_LABELS\t" + "\t".join(legend_labels) + "\n\n")

        out.write("DATA\n")
        for full_id, color, label, _ in rows:
            out.write(f"{full_id}\t{color}\t{label}\n")

    print(f"[OK] escrito {out_path} ({len(rows)} filas).")

def write_year_colorstrip(marker, tips):
    out_path = os.path.join(ROOT, f"itol_colorstrip_year_{marker}.txt")

    if not tips:
        print(f"[year] {marker}: sin filas, no se escribe archivo.")
        return

    rows = []
    for full_id, (year, idx) in tips.items():
        if year == 2024:
            color = "#000000"   # negro
            label = "2024"
        elif year == 2025:
            color = "#777777"   # gris medio
            label = "2025"
        else:
            # por si a futuro hay otros años
            color = "#bbbbbb"
            label = str(year)
        rows.append((full_id, color, label, year))

    rows.sort(key=lambda x: x[3])

    with open(out_path, "w", encoding="utf-8") as out:
        out.write("DATASET_COLORSTRIP\n")
        out.write("SEPARATOR TAB\n")
        out.write("DATASET_LABEL\tYear\n")
        out.write("COLOR\t#000000\n\n")

        out.write("LEGEND_TITLE\tSampling year\n")
        out.write("LEGEND_SHAPES\t1\t1\n")
        out.write("LEGEND_COLORS\t#000000\t#777777\n")
        out.write("LEGEND_LABELS\t2024\t2025\n\n")

        out.write("DATA\n")
        for full_id, color, label, _ in rows:
            out.write(f"{full_id}\t{color}\t{label}\n")

    print(f"[OK] escrito {out_path} ({len(rows)} filas).")

def main():
    meta2024 = load_meta(META_2024, 2024)
    meta2025 = load_meta(META_2025, 2025)
    meta_by_year = {2024: meta2024, 2025: meta2025}

    for marker in MARKERS:
        tree_path = os.path.join(TREES_DIR, f"{marker}.treefile")
        if not os.path.exists(tree_path):
            print(f"[WARN] no se encontró árbol para {marker}: {tree_path}")
            continue

        with open(tree_path, encoding="utf-8") as fh:
            txt = fh.read()

        tips = parse_tips(txt, marker)
        if not tips:
            print(f"[WARN] No se detectaron tips para {marker} en {tree_path}")
            continue

        print(f"[INFO] {marker}: {len(tips)} tips detectados.")
        write_species_colorstrip(marker, tips, meta_by_year)
        write_year_colorstrip(marker, tips)

if __name__ == "__main__":
    main()
