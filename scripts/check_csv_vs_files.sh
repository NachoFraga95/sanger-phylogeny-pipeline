#!/usr/bin/env bash
# Usage:
#   MAP_CSV=meta/samples_2024_clean.csv MAP_LABEL_COL=2 bash check_csv_vs_files.sh
# Notes:
# - Preserves empty CSV fields; respects your MAP_LABEL_COL index.
# - Extracts labels from filenames like:
#     Econt.01, Esep01, Erossj01h, europu7, europu, etc.

set -euo pipefail
export LC_ALL=C

MAP_CSV="${MAP_CSV:?set MAP_CSV}"
LABEL_COL="${MAP_LABEL_COL:-2}"   # 1-based

normalize_line() {
  # preserve empty fields; do NOT collapse consecutive commas
  tr -d '\r' | sed -e 's/;/,/g'
}

trim() { sed 's/^[ \t]*//;s/[ \t]*$//'; }

# --- labels from CSV ---
readarray -t RAW_LINES < <(cat "$MAP_CSV" | normalize_line)
if ((${#RAW_LINES[@]}==0)); then
  echo "CSV appears empty"; exit 1
fi

csv_labels=()
for ((i=1;i<${#RAW_LINES[@]};i++)); do
  IFS=',' read -r -a row <<< "${RAW_LINES[$i]}"
  (( ${#row[@]} < LABEL_COL )) && continue
  lbl="$(echo "${row[$((LABEL_COL-1))]}" | tr -d '\"' | trim)"
  [[ -n "$lbl" ]] && csv_labels+=("$lbl")
done

# --- helper: extract label from filename ---
extract_label_from_fname() {
  local f="$1"
  local name="$(basename "$f")"
  name="${name%.ab1}"

  # 1) token.NN (e.g., Econt.01)
  if [[ "$name" =~ ([A-Za-z0-9]+)\.([0-9]{1,2}) ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"; return
  fi
  # 2) europuNN
  if [[ "$name" =~ (europu)([0-9]{1,2}) ]]; then
    echo "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"; return
  fi
  # 3) plain europu
  if [[ "$name" =~ (^|[^A-Za-z0-9])(europu)($|[^A-Za-z0-9]) ]]; then
    echo "europu"; return
  fi
  # 4) tokenNN[suffix] stuck to next token (e.g., Esep01-16S_..., Erossj01h-...)
  #    Take the first dash-separated token and pull trailing 2 digits + optional 1 letter
  local firsttok="${name%%-*}"
  if [[ "$firsttok" =~ ^([A-Za-z]+[A-Za-z0-9]*)([0-9]{2}[A-Za-z]?)$ ]]; then
    echo "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"; return
  fi
  # 5) fallback: token between first two dashes (legacy)
  if [[ "$name" =~ ^[^-]*-([A-Za-z0-9]+(\.[0-9]{1,2})?)- ]]; then
    echo "${BASH_REMATCH[1]}"; return
  fi
  # 6) nothing matched
  echo ""
}

# --- labels from filenames ---
file_labels=()
shopt -s nullglob
for f in *.ab1; do
  [[ -f "$f" ]] || continue
  tok="$(extract_label_from_fname "$f")"
  [[ -n "$tok" ]] && file_labels+=("$tok")
done

# --- compare ---
echo "=== CSV labels not seen in filenames ==="
comm -23 <(printf "%s\n" "${csv_labels[@]}" | sort -u) <(printf "%s\n" "${file_labels[@]}" | sort -u)

echo
echo "=== Filename labels not present in CSV ==="
comm -13 <(printf "%s\n" "${csv_labels[@]}" | sort -u) <(printf "%s\n" "${file_labels[@]}" | sort -u)