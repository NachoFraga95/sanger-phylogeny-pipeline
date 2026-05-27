#!/usr/bin/env bash
set -euo pipefail

# Directorio del proyecto (raíz)
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IN_DIR="$PROJ_DIR/work/04_align_filtered"
OUT_DIR="$PROJ_DIR/work/05_trees"

echo "Proyecto:        $PROJ_DIR"
echo "Alineos in:      $IN_DIR"
echo "Árboles out:     $OUT_DIR"
echo

mkdir -p "$OUT_DIR"

# Buscar todos los alineamientos filtrados (*.filtered.fa)
shopt -s nullglob
aln_files=("$IN_DIR"/*.filtered.fa)

if [ "${#aln_files[@]}" -eq 0 ]; then
    echo "ERROR: no se encontraron *.filtered.fa en $IN_DIR"
    exit 1
fi

for aln in "${aln_files[@]}"; do
    base="$(basename "$aln")"          # p.ej. COI.filtered.fa
    marker="${base%.filtered.fa}"      # -> COI

    prefix="$OUT_DIR/${marker}"
    echo "[iqtree] $aln -> ${prefix}.treefile"

    iqtree -s "$aln" \
           -st DNA \
           -m MFP \
           -bb 1000 \
           -alrt 1000 \
           -nt 2 \
           -pre "$prefix" \
           -redo

    echo
done

echo "Listo: árboles en $OUT_DIR"
