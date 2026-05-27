#!/usr/bin/env python3
import os
import csv
import glob
from collections import defaultdict
from Bio import Phylo

# Ajusta rutas si tus meta están en otro lado
META_2024 = "meta_2024.tsv"
META_2025 = "meta_2025.tsv"

TREES_DIR = "work/05_trees_renamed"
OUT_DIR = "itol_datasets"
os.makedirs(OUT_DIR, exist_ok=True)


def load_meta(path, year_tag):
    """
    Lee meta_20XX.tsv con formato:
        ID \t especie \t codigo_original
    y devuelve dict: f"{year}_{codigo_original}" -> especie
    """
    mapping = {}
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.reader(fh, delimiter="\t")
        for row in reader:
            if not row or row[0].startswith("#"):
                continue
            if len(row) < 3:
                continue
            _id_raw = row[0].strip()
            species = row[1].strip()
            code = row[2].strip()
            if not code:
                continue
            key = f"{year_tag}_{code}"
            mapping[key] = species
    return mapping


# Cargar meta de ambos años
code2species = {}
code2species.update(load_meta(META_2024, "2024"))
code2species.update(load_meta(META_2025, "2025"))

# Paleta fija por especie (ajústala a gusto)
species_colors = {
    "E. roseus":        "#e41a1c",
    "E. altor":         "#377eb8",
    "E. migueli":       "#4daf4a",
    "E. insularis":     "#984ea3",
    "E. contulmoensis": "#ff7f00",
    "E. septentrionalis": "#a65628",
    "E. vertebralis":   "#f781bf",
    "P. thaul":         "#999999",
    "P. bufonina":      "#ffff33",
    "Alsodes hugoi":    "#a6cee3",
}

DEFAULT_COLOR = "#000000"


def make_dataset_for_tree(tree_path):
    tree_name = os.path.splitext(os.path.basename(tree_path))[0]  # p.ej. CYTB
    out_path = os.path.join(OUT_DIR, f"treecolors_{tree_name}.txt")

    tree = Phylo.read(tree_path, "newick")

    with open(out_path, "w", encoding="utf-8") as out:
        out.write("TREE_COLORS\n")
        out.write("SEPARATOR TAB\n")
        out.write(f"DATASET_LABEL\tSpecies_{tree_name}\n")
        out.write("COLOR\t#000000\n")
        out.write("DATA\n")

        for clade in tree.get_terminals():
            tip = clade.name
            if not tip:
                continue

            # Esperamos formato: YYYY_ID_codigoOriginal_MARCADOR
            parts = tip.split("_")
            if len(parts) < 4:
                # Por si hay algo raro
                print(f"[WARN] tip raro, lo dejo sin color especial: {tip}")
                continue

            year = parts[0]          # "2024" o "2025"
            code = parts[-2]         # penúltimo token = código original (Erossj012017, etc.)
            key = f"{year}_{code}"

            species = code2species.get(key)
            if species is None:
                print(f"[WARN] no se encontró especie para {tip} (key={key}), usando color por defecto.")
                color = DEFAULT_COLOR
            else:
                color = species_colors.get(species, DEFAULT_COLOR)

            # Formato TREE_COLORS:
            # NODE_ID  type    color   style   width
            # type puede ser 'label' o 'branch'
            out.write(f"{tip}\tlabel\t{color}\tnormal\t1\n")

    print(f"[OK] dataset generado: {out_path}")


def main():
    treefiles = sorted(glob.glob(os.path.join(TREES_DIR, "*.treefile")))
    if not treefiles:
        print(f"ERROR: no se encontraron .treefile en {TREES_DIR}")
        return

    for tf in treefiles:
        make_dataset_for_tree(tf)


if __name__ == "__main__":
    main()
