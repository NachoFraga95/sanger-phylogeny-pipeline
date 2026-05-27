#!/usr/bin/env python3
import csv
from pathlib import Path

BACKUP = Path("2024_raw_ab1/pattern_map_2024.tsv")   # ya copiado desde el respaldo
META   = Path("meta_2024.tsv")
OUT    = Path("2024_raw_ab1/pattern_map_2024.tsv")   # sobrescribe manteniendo todo

def read_map(path: Path):
    pairs = []
    seen = set()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        pat = parts[0].strip()
        sid = parts[1].strip()
        if not pat or not sid:
            continue
        if pat in seen:
            continue
        seen.add(pat)
        pairs.append((pat, sid))
    return pairs, seen

def main():
    pairs, seen = read_map(BACKUP)

    # leer metadata (viene como latin-1 / excel típico)
    meta_txt = META.read_text(encoding="latin-1", errors="replace")
    reader = csv.DictReader(meta_txt.splitlines(), delimiter="\t")

    # detectar columnas (con o sin tilde/espacios)
    cols = reader.fieldnames
    def pick(*cands):
        for c in cols:
            c2 = c.strip().lower().replace("ó","o")
            for cand in cands:
                if c2 == cand:
                    return c
        raise RuntimeError(f"No encontré columnas {cands} en {cols}")

    col_id   = pick("id")
    col_code = pick("codigo", "código")

    added_code = 0
    added_cris = 0

    for row in reader:
        sid = str(row[col_id]).strip()
        code = str(row[col_code]).strip()
        if not sid or not code:
            continue

        # 1) Asegurar patrón por Código exacto
        if code not in seen:
            pairs.append((code, sid))
            seen.add(code)
            added_code += 1

        # 2) Patrones para AB1 nuevos: Cristian-ID- / Cristian-IDS-
        #    Esto evita el problema de fechas, porque incluye "Cristian-" (no aparece en fecha)
        pats = [
            f"Cristian-{sid}-",
            f"CRISTIAN-{sid}-",
            f"Cristian-{sid}S-",
            f"CRISTIAN-{sid}S-",
        ]
        for p in pats:
            if p not in seen:
                pairs.append((p, sid))
                seen.add(p)
                added_cris += 1

    # escribir manteniendo todo lo anterior + lo nuevo
    OUT.write_text("\n".join([f"{p}\t{sid}" for p, sid in pairs]) + "\n", encoding="utf-8")

    print(f"[OK] pattern_map_2024 actualizado usando respaldo")
    print(f"     +{added_code} códigos nuevos desde meta_2024.tsv")
    print(f"     +{added_cris} patrones Cristian/CRISTIAN añadidos")
    print(f"     escrito en: {OUT.resolve()}")

if __name__ == "__main__":
    main()
