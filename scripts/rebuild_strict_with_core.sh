#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${1:-sanger_out}"
TRIM_OCC="${TRIM_OCC:-0.5}"   # column occupancy threshold
STRICT_THR="${STRICT_THR:-0.5}" # sequence gap fraction threshold

trim_py="$ROOT/_trim_by_occupancy.py"
filt_py="$ROOT/_filter_by_gaps.py"

do_set () {
  local kind="$1"  # align_reads or align_consensus
  local INP="$ROOT/$kind/permissive"
  local OUTP="$ROOT/$kind/trimmed_core"
  local OUTS="$ROOT/$kind/strict_core"
  mkdir -p "$OUTP" "$OUTS"

  shopt -s nullglob
  for aln in "$INP"/*.aln.fasta; do
    m=$(basename "$aln" .aln.fasta)
    t="$OUTP/${m}.aln.trim${TRIM_OCC//./}.fasta"
    s="$OUTS/${m}.aln.strict${STRICT_THR//./}_core.fasta"
    python3 "$trim_py" "$aln" "$t" "$TRIM_OCC"
    python3 "$filt_py" "$t" "$STRICT_THR" > "$s"
    echo "[ok] $kind $m"
  done
}

do_set align_reads
do_set align_consensus

echo "Done. New outputs:"
echo " - $ROOT/align_reads/trimmed_core/ and strict_core/"
echo " - $ROOT/align_consensus/trimmed_core/ and strict_core/"
