#!/usr/bin/env python3
import csv
import re
from pathlib import Path

META = Path("meta_2024.tsv")
OUT  = Path("pattern_map_2024.tsv")

def norm(s: str) -> str:
    return s.strip()

def find_col(cols, candidates):
    cols_norm = {c.lower(): c for c in cols}
    # aceptar "Código" con tilde y variantes
    for cand in candidates:
        for c in cols:
            cl = c.lower().replace("ó", "o").replace(" ", "_")
            if cl == cand:
                return c
    raise RuntimeError(f"No se encontró ninguna columna {candidates} en {cols}")

def extra_aliases(code: str):
    """
    Genera posibles alias del 'Codigo' para matchear nombres de AB1 antiguos.
    """
    aliases = set()
    c = code.strip()
    if not c:
        return aliases

    aliases.add(c)

    # versiones sin espacios y sin puntos
    aliases.add(c.replace(" ", ""))
    aliases.add(c.replace(".", ""))

    # si trae guiones o underscores, agregar variantes
    aliases.add(c.replace("-", "_"))
    aliases.add(c.replace("_", "-"))

    # patrón corto tipo Ealt01 / Emicol01 / Erossj01h / Esep01 etc.
    m = re.search(r"(E[a-z]{2,5}\d{2}[a-z]?)", c, flags=re.IGNORECASE)
    if m:
        aliases.add(m.group(1))

    # patrón tipo Ealt_12 (muy común en tus nuevos AB1)
    # intentar capturar prefijo letras + separador + número
    m2 = re.search(r"([A-Za-z]+)[\-_]?(\d+)", c)
    if m2:
        aliases.add(f"{m2.group(1)}_{m2.group(2)}")
        aliases.add(f"{m2.group(1)}{m2.group(2)}")

    return {a for a in aliases if a and len(a) >= 4}

def main():
    patterns = []
    seen_pat = set()

    with META.open(encoding="latin-1") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        cols = reader.fieldnames

        col_id   = find_col(cols, ["id"])
        col_code = find_col(cols, ["codigo"])

        for row in reader:
            sid  = norm(row[col_id])
            code = norm(row[col_code])

            if not sid or not code:
                continue

            for pat in extra_aliases(code):
                if pat in seen_pat:
                    continue
                seen_pat.add(pat)
                patterns.append((pat, sid))

    # ordenar por ID numérico y luego por patrón
    patterns.sort(key=lambda x: (int(x[1]), x[0].lower()))

    with OUT.open("w", encoding="utf-8") as out:
        for pat, sid in patterns:
            out.write(f"{pat}\t{sid}\n")

    print(f"[OK] pattern_map_2024 generado con {len(patterns)} patrones (incluye alias)")
    print(f"     {OUT.resolve()}")

if __name__ == "__main__":
    main()
