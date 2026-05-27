#!/usr/bin/env bash
set -Eeuo pipefail
file="${1:-$HOME/compartida_ubuntu/sanger-arboles/project/2024_raw_ab1/pattern_map_2024.tsv}"
while IFS=$'\t' read -r pat nn; do
  [[ -z "$pat" || "$pat" =~ ^[[:space:]]*# ]] && continue
  printf 'x' | grep -E -q "$pat" 2>/dev/null || echo "BAD REGEX:\t$pat\t-> NN=$nn"
done < "$file"
