#!/usr/bin/env python3
import os
import re

PROJ_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREES_DIR = os.path.join(PROJ_DIR, "work", "05_trees")

META_2024 = os.path.join(PROJ_DIR, "meta_2024.tsv")
META_2025 = os.path.join(PROJ_DIR, "meta_2025.tsv")

def load_meta(path):
    """
    Lee un TSV con columnas:
      ID (int)   especie   codigo_original
    y devuelve un dict {ID:int -> codigo_original:str}
    """
    mapping = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = re.split(r"\s+", line)
            if len(parts) < 3:
                continue
            try:
                idx = int(parts[0])
            except ValueError:
                continue
            code = parts[2]
            mapping[idx] = code
    return mapping

meta_2024 = load_meta(META_2024)
meta_2025 = load_meta(META_2025)

print(f"Loaded {len(meta_2024)} entries from meta_2024")
print(f"Loaded {len(meta_2025)} entries from meta_2025")

# Regex para capturar hojas tipo 2024_11_CYTB
pattern = re.compile(r"(\b)(20[0-9]{2})_([0-9]+)_([A-Za-z0-9]+)(\b)")

def replace_label(match):
    prefix, year, num_str, marker, suffix = match.groups()
    year_int = int(year)
    num = int(num_str)

    if year_int == 2024:
        code = meta_2024.get(num)
    elif year_int == 2025:
        code = meta_2025.get(num)
    else:
        code = None

    if code is None:
        print(f"[WARN] No mapping for {year}_{num}_{marker}")
        return match.group(0)

    # NUEVA ETIQUETA ÚNICA
    new_label = f"{year}_{num}_{code}_{marker}"

    return f"{prefix}{new_label}{suffix}"


def process_tree(path):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()

    new_text = pattern.sub(replace_label, text)

    backup = path + ".bak"
    if not os.path.exists(backup):
        with open(backup, "w", encoding="utf-8") as fh:
            fh.write(text)

    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new_text)

    print(f"[OK] Updated labels in {os.path.basename(path)}")

def main():
    for fname in os.listdir(TREES_DIR):
        if fname.endswith(".treefile"):
            process_tree(os.path.join(TREES_DIR, fname))

if __name__ == "__main__":
    main()
