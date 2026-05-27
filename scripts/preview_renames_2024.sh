#!/usr/bin/env bash
set -Eeuo pipefail
YEAR_PREFIX="${YEAR_PREFIX:-2024}"
MAP_CSV="${MAP_CSV:?}"
MAP_LABEL_COL="${MAP_LABEL_COL:-3}"
MAP_NUMBER_COL="${MAP_NUMBER_COL:-1}"
EXTRAS_MAP="${EXTRAS_MAP:-}"
PATTERN_MAP="${PATTERN_MAP:-}"
SRC_GLOB="${SRC_GLOB:-*.ab1}"

# reuse functions by sourcing the main script without running loop
source "$(dirname "$0")/rename_to_number_marker_2024.sh" >/dev/null 2>&1 || true

# override: don't move, just show table
shopt -s nullglob
files=($SRC_GLOB)
printf "%-60s | %-18s | %-8s | %-10s | %s\n" "file" "label" "NN(src)" "marker_dir" "new_name"
printf -- "----------------------------------------------------------------------------------------------------------------------------------\n"
for f in "${files[@]}"; do
  base="$(basename "$f")"
  label="$(extract_label_from_fname "$base")"
  id="$(infer_sample_id "$base" "$label")"
  md="$(norm_marker_dir "$base")"
  if [[ "$md" == "-" ]]; then
    printf "%-60s | %-18s | %-8s | %-10s | %s\n" "$base" "$label" "${id}(none)" "-" "[no_marker_found]"
    continue
  fi
  marker="${md%_*}"; dirc="${md##*_}"
  exp="$(experimenter_tag "$base")"
  if [[ "$id" == "europu" ]]; then
    new="${YEAR_PREFIX}_europu_${marker}"; [[ "$dirc" != "?" ]] && new+="_${dirc}"; new+=".ab1"
    printf "%-60s | %-18s | %-8s | %-10s | %s\n" "$base" "$label" "europu" "$md" "$new"
  else
    new="${YEAR_PREFIX}_${id}${exp:+$exp}_${marker}"; [[ "$dirc" != "?" ]] && new+="_${dirc}"; new+=".ab1"
    printf "%-60s | %-18s | %-8s | %-10s | %s\n" "$base" "$label" "$id" "$md" "$new"
  fi
done
