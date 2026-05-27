#!/usr/bin/env python3
import os
from Bio import Phylo

# Rutas base
PROJ_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREE_DIR = os.path.join(PROJ_DIR, "work", "05_trees")
OUT_DIR  = os.path.join(PROJ_DIR, "work", "05_trees_renamed")

META_2024 = os.path.join(PROJ_DIR, "meta_2024.tsv")
META_2025 = os.path.join(PROJ_DIR, "meta_2025.tsv")

os.makedirs(OUT_DIR, exist_ok=True)

def load_meta(path, year):
    """
    Lee meta_20XX.tsv con columnas:
    ID<TAB>Especie<TAB>CodigoOriginal
    (puede o no tener header)
    Devuelve dict: { '1': 'Erossj012017', ... }
    """
    mapping = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            parts = line.split('\t')
            if not parts[0].isdigit():
                # Probable header
                continue
            num = parts[0]
            if len(parts) < 3:
                # Sin código original, usamos ID tal cual
                code = num
            else:
                code = parts[2].strip()
                if not code:
                    code = num
            mapping[num] = code
    print(f"[meta] {year}: cargados {len(mapping)} IDs desde {os.path.basename(path)}")
    return mapping

meta2024 = load_meta(META_2024, 2024)
meta2025 = load_meta(META_2025, 2025)

def rename_tip(name: str) -> str:
    """
    Espera algo tipo 2024_11_CYTB
    Devuelve 2024_11_CodigoOriginal_CYTB
    Si no se puede mapear, devuelve name sin cambios.
    """
    if not name:
        return name
    parts = name.split("_")
    if len(parts) != 3:
        # Por si hay algo raro tipo "outgroup" o similar
        return name

    year, nid, marker = parts

    if year == "2024":
        code = meta2024.get(nid)
    elif year == "2025":
        code = meta2025.get(nid)
    else:
        code = None

    if not code:
        # No encontramos en la tabla: lo dejamos como estaba
        return name

    return f"{year}_{nid}_{code}_{marker}"

def process_tree(path):
    fname = os.path.basename(path)
    out_path = os.path.join(OUT_DIR, fname)
    print(f"[tree] renombrando tips en {fname}")

    tree = Phylo.read(path, "newick")

    for clade in tree.get_terminals():
        old = clade.name
        new = rename_tip(old)
        clade.name = new

    Phylo.write(tree, out_path, "newick")
    print(f"  -> escrito {out_path}")

def main():
    treefiles = [f for f in os.listdir(TREE_DIR) if f.endswith(".treefile")]
    if not treefiles:
        print(f"No encontré .treefile en {TREE_DIR}")
        return
    for f in treefiles:
        process_tree(os.path.join(TREE_DIR, f))

if __name__ == "__main__":
    main()
