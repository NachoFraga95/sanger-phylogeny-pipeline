#!/usr/bin/env python3
from pathlib import Path
import csv
import re

MAP_TSV = Path("Eupsophus_label_map.tsv")   # old_label \t new_label
TREE_IN = Path("Eupsophus_concat.treefile") # ajusta al nombre real que te dejó IQ-TREE
TREE_OUT = Path("Eupsophus_concat.RENAMED.treefile")

def load_map(p: Path) -> dict:
    m = {}
    with p.open("r", encoding="utf-8") as f:
        r = csv.DictReader(f, delimiter="\t")
        for row in r:
            m[row["old_label"].strip()] = row["new_label"].strip()
    return m

def main():
    m = load_map(MAP_TSV)
    t = TREE_IN.read_text(encoding="utf-8")

    # Reemplaza solo labels “2024_123” o “2025_45” como tokens completos
    # (evita reemplazar dentro de otros strings)
    def repl(match):
        old = match.group(0)
        return m.get(old, old)

    t2 = re.sub(r"\b20(24|25)_[0-9]+\b", repl, t)
    TREE_OUT.write_text(t2, encoding="utf-8", newline="\n")

    print(f"[OK] Árbol renombrado -> {TREE_OUT}")

if __name__ == "__main__":
    main()
