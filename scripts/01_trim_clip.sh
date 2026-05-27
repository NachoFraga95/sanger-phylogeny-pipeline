#!/usr/bin/env bash
set -euo pipefail
fq_dir="${1:-work/00_fastq}"
out_dir="${2:-work/01_trimmed}"
primers="${3:-meta/primers.fa}"
mkdir -p "$out_dir"
declare -A MINLEN=( [CytB]=300 [COI]=300 [POMC]=250 [CRY]=180 [dLoop]=120 [12S]=200 [16S]=200 [RHOD]=250 )
declare -A QTRIM=( [CytB]="30,30" [COI]="30,30" [POMC]="30,30" [CRY]="22,22" [dLoop]="22,22" [12S]="30,30" [16S]="30,30" [RHOD]="30,30" )
mapfile -t fqs < <(find "$fq_dir" -type f -name '*_*.fastq' | sort)
[[ ${#fqs[@]} -eq 0 ]] && { echo "No FASTQ in $fq_dir"; exit 0; }
for fq in "${fqs[@]}"; do
  fn="$(basename "$fq")"
  base="${fn%.fastq}"
  num="${base%%_*}"
  rest="${base#*_}"
  marker="${rest%%_*}"
  dir="${rest##*_}"
  mlen="${MINLEN[$marker]:-200}"
  qpair="${QTRIM[$marker]:-30,30}"

  cutadapt \
   -g file:"$primers" -a file:"$primers" \
   -e 0.2 --overlap 10 \
   -q "$qpair" --minimum-length "$mlen" \
   -o "$out_dir/${base}.fastq" "$fq" \
   > "$out_dir/${base}.cutadapt.log" 2>&1 || true
  echo "[trim] $fq -> $out_dir/${base}.fastq"
done
