#!/usr/bin/env python3
import csv
from pathlib import Path

TREEFILE = Path("Eupsophus_concat.RENAMED.treefile")
MAP_TSV  = Path("Eupsophus_label_map.tsv")

OUT_SPECIES  = Path("colorstrip_species.txt")
OUT_LOCALITY = Path("colorstrip_locality.txt")

# Species: colores chillones planos (no se confunden con localidad)
SPECIES_COLORS = [
    "#FF0000", "#FFF700", "#1AFF00", "#001EFF", "#FF00FF",
    "#00FFFF", "#FF7A00", "#8A00FF", "#00FF7A", "#000000"
]

# Locality: paleta suave/brillante
LOCALITY_PALETTE = [
    "#4E79A7", "#F28E2B", "#E15759", "#76B7B2",
    "#59A14F", "#EDC948", "#B07AA1", "#FF9DA7",
    "#9C755F", "#BAB0AC", "#86BCB6", "#D37295",
    "#FABFD2", "#8CD17D", "#B6992D", "#499894",
]

def read_tree_tips(tree_path: Path) -> set[str]:
    """
    Extrae labels de tips desde Newick.
    Captura tokens antes de ':' y delimitadores ,() ;.
    """
    s = tree_path.read_text(encoding="utf-8", errors="replace").strip()
    tips = set()
    token = []
    reading = True

    for ch in s:
        if ch in "(),;":
            if token:
                t = "".join(token).strip()
                if t:
                    tips.add(t)
                token = []
            reading = True
            continue
        if ch == ":":
            # fin del label del tip / nodo
            if token:
                t = "".join(token).strip()
                if t:
                    tips.add(t)
                token = []
            reading = False
            continue
        if reading:
            token.append(ch)

    if token:
        t = "".join(token).strip()
        if t:
            tips.add(t)

    # Limpieza: a veces quedan cosas vacías o raras, pero tus tips son tipo "15_Eupsophus_..."
    tips = {t for t in tips if t and not t.replace(".", "", 1).isdigit()}
    return tips

def load_label_map(map_path: Path) -> dict[str, str]:
    # old_label -> new_label
    d = {}
    with map_path.open("r", encoding="utf-8") as f:
        r = csv.DictReader(f, delimiter="\t")
        if not r.fieldnames or "old_label" not in r.fieldnames or "new_label" not in r.fieldnames:
            raise SystemExit(f"{map_path} debe tener columnas: old_label, new_label. Tiene: {r.fieldnames}")
        for row in r:
            d[row["old_label"].strip()] = row["new_label"].strip()
    return d

def parse_species_and_locality(new_label: str):
    """
    Espera:
      {id}_{Genus}_{species}_{Codigo}_{Localidad...}_{Año}

    Localidad = todo lo entre Codigo y Año (puede ser 1 o más tokens: Cerro_Oncol / Colegual_II / etc)
    """
    parts = new_label.strip().split("_")
    if len(parts) < 6:
        return None, None

    year = parts[-1]
    # si el último token no es año, igual tratamos pero dejamos locality como lo que venga
    genus = parts[1]
    sp_ep = parts[2]
    species = f"{genus}_{sp_ep}"

    # code = parts[3]
    loc_tokens = parts[4:-1] if len(parts) >= 6 else []
    locality = " ".join(loc_tokens) if loc_tokens else "NA"
    return species, locality

def assign_colors_in_order(keys, palette):
    keys_sorted = sorted(keys)
    return {k: palette[i % len(palette)] for i, k in enumerate(keys_sorted)}

def write_itol_colorstrip(out_path: Path, dataset_label: str, rows, color_map, legend_order):
    # legend_order = lista de keys en orden consistente
    shapes = ["1"] * len(legend_order)
    colors = [color_map[k] for k in legend_order]
    labels = legend_order

    with out_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write("DATASET_COLORSTRIP\n")
        f.write("SEPARATOR TAB\n")
        f.write(f"DATASET_LABEL\t{dataset_label}\n")
        f.write("COLOR\t#000000\n\n")

        f.write(f"LEGEND_TITLE\t{dataset_label}\n")
        f.write("LEGEND_SHAPES\t" + "\t".join(shapes) + "\n")
        f.write("LEGEND_COLORS\t" + "\t".join(colors) + "\n")
        f.write("LEGEND_LABELS\t" + "\t".join(labels) + "\n\n")

        f.write("DATA\n")
        for leaf_label, k in rows:
            f.write(f"{leaf_label}\t{color_map[k]}\n")

def main():
    if not TREEFILE.exists():
        raise SystemExit(f"No encuentro el árbol: {TREEFILE}")
    if not MAP_TSV.exists():
        raise SystemExit(f"No encuentro el map: {MAP_TSV}")

    tips = read_tree_tips(TREEFILE)
    lm = load_label_map(MAP_TSV)

    # tips del árbol están en formato new_label (porque tu árbol es .RENAMED)
    # así que solo filtramos por tips directamente
    used_labels = sorted(tips)

    labels = []
    for new_label in used_labels:
        sp, loc = parse_species_and_locality(new_label)
        if not sp or not loc:
            continue
        labels.append((new_label, sp, loc))

    if not labels:
        raise SystemExit("No pude extraer species/locality desde los tips del árbol.")

    species_set = {sp for _, sp, _ in labels}
    loc_set     = {loc for _, _, loc in labels}

    sp_color  = assign_colors_in_order(species_set, SPECIES_COLORS)
    loc_color = assign_colors_in_order(loc_set, LOCALITY_PALETTE)

    # Orden de la leyenda:
    # Species: orden alfabético (estable)
    species_order = sorted(species_set)
    # Locality: orden alfabético (estable)
    loc_order = sorted(loc_set)

    rows_sp  = [(new, sp) for (new, sp, _) in labels]
    rows_loc = [(new, loc) for (new, _, loc) in labels]

    write_itol_colorstrip(OUT_SPECIES,  "Species",  rows_sp,  sp_color,  species_order)
    write_itol_colorstrip(OUT_LOCALITY, "Locality", rows_loc, loc_color, loc_order)

    print("[OK] Generados:")
    print(" -", OUT_SPECIES)
    print(" -", OUT_LOCALITY)
    print(f"[INFO] Tips en árbol: {len(tips)} | Species: {len(species_set)} | Localidades: {len(loc_set)}")

if __name__ == "__main__":
    main()
