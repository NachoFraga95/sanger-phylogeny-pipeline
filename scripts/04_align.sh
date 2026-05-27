#!/usr/bin/env bash
set -euo pipefail
in_dir="${1:-work/03_markers}"
out_dir="${2:-work/04_align}"
mkdir -p "$out_dir"
for fa in "$in_dir"/*.fa; do
  m="$(basename "$fa" .fa)"
  out="$out_dir/${m}.aln.fa"
  mafft --adjustdirectionaccurately --localpair --maxiterate 1000 --thread -1 "$fa" > "$out"
  echo "[align] $fa -> $out"
done
