#!/usr/bin/env bash
# Verify uniqueness of (YY, NN, MARKER, DIR) keys in a folder of unified AB1 files.
# Env/Args:
#   DIR=/path/to/unified   # or pass as first arg

set -euo pipefail
export LC_ALL=C
DIR="${1:-${DIR:-/home/fraga/compartida_ubuntu/sanger-arboles/project/raw_ab1_24_25}}"

shopt -s nullglob
files=( "$DIR"/*.ab1 )

declare -A KEY2FILES
declare -A MARKER_COUNTS

parse_key() {
  local b="$1"
  # Accept 2- or 4-digit year prefix; capture DIR as F/R/?; ignore trailing tags before .ab1
  if [[ "$b" =~ ^([0-9]{2}|[0-9]{4})_([0-9]{2})_([A-Za-z0-9]+)_([FR\?]) ]]; then
    echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
  else
    echo ""
  fi
}

for f in "${files[@]}"; do
  base="$(basename "$f")"
  key="$(parse_key "$base")"
  if [[ -z "$key" ]]; then
    echo "[WARN] Unrecognized name: $base" >&2
    continue
  fi
  KEY2FILES["$key"]+="$base"$'\n'
  marker="$(echo "$key" | cut -d'|' -f3)"
  (( MARKER_COUNTS["$marker"]++ )) || true
done

echo "=== Per-marker counts ==="
for m in "${!MARKER_COUNTS[@]}"; do
  printf "%-6s %5d files\n" "$m" "${MARKER_COUNTS[$m]}"
done
echo

dup_count=0
echo "=== Duplicate keys (same YY|NN|MARKER|DIR) ==="
for k in "${!KEY2FILES[@]}"; do
  # Count lines
  c=$(echo -n "${KEY2FILES[$k]}" | grep -c . || true)
  if (( c > 1 )); then
    ((dup_count++))
    echo "KEY: $k"
    printf "%s" "${KEY2FILES[$k]}" | sed 's/^/  - /'
  fi
done

if (( dup_count == 0 )); then
  echo "OK: all keys are unique."
  exit 0
else
  echo
  echo "ERROR: $dup_count duplicate key group(s) detected."
  exit 2
fi