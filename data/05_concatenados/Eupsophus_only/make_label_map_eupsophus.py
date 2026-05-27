#!/usr/bin/env python3
import csv
import re
import unicodedata
from pathlib import Path

# Ajusta rutas si quieres
META_2024 = Path("meta_2024.tsv")
META_2025 = Path("meta_2025.tsv")

OUT_MAP = Path("Eupsophus_label_map.tsv")  # old_label \t new_label

def strip_accents(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    return "".join(ch for ch in s if not unicodedata.combining(ch))

def clean_token(s: str) -> str:
    s = s.strip()
    s = strip_accents(s)
    # reemplaza espacios y separadores raros por underscore
    s = re.sub(r"\s+", "_", s)
    s = re.sub(r"[^\w\.-]+", "_", s)  # deja letras/números/_/./-
    s = re.sub(r"_+", "_", s).strip("_")
    return s

def pick_col(fieldnames, candidates):
    lower = {c.lower(): c for c in fieldnames}
    for cand in candidates:
        if cand.lower() in lower:
            return lower[cand.lower()]
    # fallback: match por substring
    for fn in fieldnames:
        fnl = fn.lower()
        for cand in candidates:
            if cand.lower() in fnl:
                return fn
    raise KeyError(f"No encontré ninguna columna {candidates} en {fieldnames}")

def load_meta(meta_path: Path, year: int) -> dict:
    # Intenta utf-8-sig, luego latin1 (por si queda algún ó suelto)
    for enc in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            with meta_path.open("r", encoding=enc, newline="") as f:
                reader = csv.DictReader(f, delimiter="\t")
                if not reader.fieldnames:
                    raise RuntimeError(f"{meta_path} no tiene header")
                cols = reader.fieldnames

                c_id  = pick_col(cols, ["ID"])
                c_sp  = pick_col(cols, ["Especie", "Species"])
                c_cod = pick_col(cols, ["Codigo", "Código", "Cod", "Code"])
                c_loc = pick_col(cols, ["Localidad", "Locality", "Loc", "Lugar"])

                m = {}
                for row in reader:
                    sid = str(row[c_id]).strip()
                    sp  = clean_token(row[c_sp])
                    cod = clean_token(row[c_cod])
                    loc = clean_token(row[c_loc])

                    old = f"{year}_{sid}"           # así quedan en tus markers/supermatrix
                    # label final (ajusta el orden si quieres)
                    new = f"{sid}_{sp}_{cod}_{loc}_{year}"
                    m[old] = new
                return m
        except UnicodeDecodeError:
            continue
    raise RuntimeError(f"No pude leer {meta_path} por encoding (probé utf-8/latin1).")

def main():
    id2label = {}
    if META_2024.exists():
        id2label.update(load_meta(META_2024, 2024))
    if META_2025.exists():
        id2label.update(load_meta(META_2025, 2025))

    if not id2label:
        raise SystemExit("No cargué nada desde meta_2024/meta_2025")

    with OUT_MAP.open("w", encoding="utf-8", newline="\n") as out:
        out.write("old_label\tnew_label\n")
        for k in sorted(id2label.keys(), key=lambda x: (x.split("_")[0], int(x.split("_")[1]))):
            out.write(f"{k}\t{id2label[k]}\n")

    print(f"[OK] Escribí {OUT_MAP} con {len(id2label)} labels")

if __name__ == "__main__":
    main()
