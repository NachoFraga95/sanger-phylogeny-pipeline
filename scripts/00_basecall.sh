#!/usr/bin/env bash
set -euo pipefail
in_dir="${1:-unified_raw_ab1}"
out_dir="${2:-work/00_fastq}"
mkdir -p "$out_dir"
mapfile -t abis < <(find "$in_dir" -type f -iname '*.ab1' | sort)
[[ ${#abis[@]} -eq 0 ]] && { echo "No .ab1 in $in_dir"; exit 0; }
for ab1 in "${abis[@]}"; do
  bn="$(basename "$ab1" .ab1)"
  out="$out_dir/$bn.fastq"
  tracy basecall -f fastq -o "$out" "$ab1" >/dev/null 2>&1 || tracy basecall -o "$out" "$ab1"
  echo "[basecall] $ab1 -> $out"
done
