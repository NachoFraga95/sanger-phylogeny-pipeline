#!/usr/bin/env bash
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IN_DIR="$PROJ_DIR/work/02_consensus"
OUT_DIR="$PROJ_DIR/work/03_markers"

echo "Proyecto:    $PROJ_DIR"
echo "Input cons:  $IN_DIR"
echo "Output dir:  $OUT_DIR"
echo

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.fa

shopt -s nullglob
for f in "$IN_DIR"/*.fasta; do
    base="$(basename "$f" .fasta)"   # ej: 2024_19_CytB
    marker="${base##*_}"             # toma lo que está después del último "_": CytB, COI, etc.
    out="$OUT_DIR/${marker}.fa"

    # agregamos las secuencias tal cual, conservando el encabezado con año+ID
    cat "$f" >> "$out"
done
shopt -u nullglob

echo "Marcadores recopilados en:"
ls -1 "$OUT_DIR"
