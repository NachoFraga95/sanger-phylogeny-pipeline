#!/usr/bin/env bash
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IN_DIR="$PROJ_DIR/work/03_markers"
OUT_DIR="$PROJ_DIR/work/03_markers_raw"

echo "Proyecto:      $PROJ_DIR"
echo "Input:         $IN_DIR"
echo "Output (raw):  $OUT_DIR"
echo

mkdir -p "$OUT_DIR"

shopt -s nullglob
fa_files=("$IN_DIR"/*.fa)

if [ "${#fa_files[@]}" -eq 0 ]; then
    echo "ERROR: no se encontraron .fa en $IN_DIR"
    exit 1
fi

for fa in "${fa_files[@]}"; do
    marker="$(basename "$fa" .fa)"
    out="$OUT_DIR/${marker}.fa"

    echo "[concat] $marker -> $out"

    # Por ahora, simplemente copiamos lo que hay en 03_markers.
    # Si en el futuro quieres añadir referencias externas, se puede
    # hacer algo como:
    #   refs_dir="$PROJ_DIR/refs"
    #   if [ -s "$refs_dir/${marker}_refs.fa" ]; then
    #       cat "$fa" "$refs_dir/${marker}_refs.fa" > "$out"
    #   else
    #       cp -f "$fa" "$out"
    #   fi

    cp -f "$fa" "$out"
done

echo
echo "Listo: archivos concatenados en $OUT_DIR"
