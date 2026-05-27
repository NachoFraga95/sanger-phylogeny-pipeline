#!/usr/bin/env bash
set -euo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && { APPLY=1; shift || true; }

AB1_DIR="${1:-.}"
PRIMERS_TMP="$(mktemp)"
JSON_TMP="$(mktemp)"
REPORT="primer_classify_$(date +%Y%m%d-%H%M%S).tsv"

# Minimal primer set (names must match below)
cat > "$PRIMERS_TMP" <<'FA'
>POMC_F
ATATGTCATGASCCAYTTYCGCTGGAA
>POMC_R
GGCRTTYTTGAAWAGAGTCATTAGWGG
>RHOD_F
ACCATGAACGGAACAGAAGGYCC
>RHOD_R
CCAAGGGTAGCGAAGAARCCTTC
FA

echo -e "file\tcall\tPOMC_hits\tRHOD_hits\taction" > "$REPORT"

shopt -s nullglob
mapfile -t AB1S < <(find "$AB1_DIR" -type f -iname '*.ab1' -o -iname '*.ab1.gz')

if (( ${#AB1S[@]} == 0 )); then
  echo "No .ab1 files found under: $AB1_DIR"
  exit 0
fi

# function: count matches for a primer pair with cutadapt (no trimming)
count_pair(){
  local fq="$1" pf="$2" pr="$3"
  cutadapt \
    -g "^${pf}" -a "${pr}$" \
    -e 0.2 --overlap 10 -n 2 --action=none \
    -j 0 \
    --json "$JSON_TMP" \
    -o /dev/null "$fq" >/dev/null 2>&1 || true
  # total matches for the two adapters (forward+reverse)
  awk '/"total_reads"/{tr=$2}
       /"adapters_trimmed"/{gsub(/[,]/,"",$2);at+=$2}
       END{print (at==""?0:at)}' "$JSON_TMP"
}

for ab1 in "${AB1S[@]}"; do
  base="$(basename "$ab1")"
  tmpfq="$(mktemp --suffix=.fastq)"
  # basecall
  tracy basecall "$ab1" "$tmpfq" >/dev/null 2>&1 || { echo -e "$base\tNA\t0\t0\tskip(basecall_failed)" >> "$REPORT"; rm -f "$tmpfq"; continue; }

  # count matches
  POMC_HITS=$(count_pair "$tmpfq" "POMC_F" "POMC_R")
  RHOD_HITS=$(count_pair "$tmpfq" "RHOD_F" "RHOD_R")

  # decide call
  call="undetermined"
  (( POMC_HITS >= 1 || RHOD_HITS >= 1 )) && {
    if (( POMC_HITS > RHOD_HITS )); then call="POMC"
    elif (( RHOD_HITS > POMC_HITS )); then call="Rhod1"
    else call="tie"  # same hits; keep name as-is
    fi
  }

  action="none"
  if (( APPLY )) && [[ "$call" == "POMC" || "$call" == "Rhod1" ]]; then
    # If filename contains the other marker string, rewrite it safely
    if [[ "$base" =~ Rhod1 ]] && [[ "$call" == "POMC" ]]; then
      new="${base/Rhod1/POMC}"
      mv -n -- "$ab1" "${ab1%/*}/$new" && action="rename:$new"
    elif [[ "$base" =~ POMC ]] && [[ "$call" == "Rhod1" ]]; then
      new="${base/POMC/Rhod1}"
      mv -n -- "$ab1" "${ab1%/*}/$new" && action="rename:$new"
    fi
  fi

  echo -e "$base\t$call\t$POMC_HITS\t$RHOD_HITS\t$action" >> "$REPORT"
  rm -f "$tmpfq"
done

rm -f "$PRIMERS_TMP" "$JSON_TMP"

echo "Done. Report: $REPORT"
echo "Columns: file, call, POMC_hits, RHOD_hits, action"