#!/usr/bin/env bash
# Normalize 2024 .ab1 filenames → 2024_NN[-Op]_MARKER_[F|R].ab1
# Special: europu → 2024_europu_MARKER_[F|R].ab1
# Dry-run by default; use --apply to move.
set -Eeuo pipefail

# Inputs (env)
YEAR_PREFIX="${YEAR_PREFIX:-2024}"
SRC_GLOB="${SRC_GLOB:-*.ab1}"
MAP_CSV="${MAP_CSV:-$HOME/compartida_ubuntu/sanger-arboles/project/meta/samples_2024_clean.csv}"
MAP_LABEL_COL="${MAP_LABEL_COL:-3}"   # 'Código'
MAP_NUMBER_COL="${MAP_NUMBER_COL:-1}" # 'N muestra'
EXTRAS_MAP="${EXTRAS_MAP:-}"          # optional TSV (label \t NN)
PATTERN_MAP="${PATTERN_MAP:-}"        # optional TSV (regex \t NN)

apply=0; [[ "${1:-}" == "--apply" ]] && apply=1

# --- helpers ---
trim(){ sed 's/^[ \t]*//;s/[ \t]*$//'; }

unique_name(){ # dir name -> new_unique_name
  local dir="$1" name="$2" stem ext cand i=2
  stem="${name%.*}" ; ext=".${name##*.}"
  [[ "$name" == *.* ]] || { stem="$name"; ext=""; }
  cand="$name"
  while [[ -e "$dir/$cand" ]]; do cand="${stem}_$i$ext"; ((i++)); done
  printf '%s\n' "$cand"
}

# read CSV → mapping SAMPLE2NUM via derived aliases from Código
declare -A SAMPLE2NUM
declare -A seen_numbers

load_csv(){
  mapfile -t L < <(tr -d '\r' < "$MAP_CSV" | sed -e $'s/\t/,/g' -e 's/;/,/g')
  local i row code num_raw nd nn alias
  for ((i=1;i<${#L[@]};i++)); do
    IFS=, read -r -a row <<< "${L[$i]}"
    code="$(echo "${row[MAP_LABEL_COL-1]:-}" | tr -d '"' | tr -d '[:space:]')"
    num_raw="${row[MAP_NUMBER_COL-1]:-}"
    nd="$(echo "$num_raw" | tr -cd 0-9)"
    [[ -z "$code" || -z "$nd" ]] && continue
    printf -v nn "%02d" "$nd"
    seen_numbers["$nn"]=1
    # derive aliases from Código, e.g., Econtct012017 → Econt.01 / Econt01 / Econt.01c etc.
    while IFS= read -r alias; do
      [[ -n "$alias" ]] && SAMPLE2NUM["$alias"]="$nn"
    done < <(derive_aliases "$code")
  done
}

derive_aliases(){ # from raw code to multiple label aliases
  local raw="$1"
  local code pre core nn let base
  code="$(echo "$raw" | tr -d '"' | tr -d '[:space:]')"
  pre="$(echo "$code" | sed -E 's/[0-9]{2,}$//')"   # drop trailing year digits
  if [[ "$pre" =~ ^(.+[^0-9])([0-9]{2})([A-Za-z]?)$ ]]; then
    core="${BASH_REMATCH[1]}"; nn="${BASH_REMATCH[2]}"; let="${BASH_REMATCH[3]}"
    base="$core"; [[ "$base" =~ ^(.+)[a-z]{2}$ ]] && base="${BASH_REMATCH[1]}"
    printf '%s\n' \
      "${core}${nn}" "${core}.${nn}" \
      "${base}${nn}" "${base}.${nn}"
    if [[ -n "$let" ]]; then
      printf '%s\n' \
        "${core}${nn}${let}" "${core}.${nn}${let}" \
        "${base}${nn}${let}" "${base}.${nn}${let}"
    fi
  fi
}

# optional extras label→NN map (bridge for Econt.01 etc.)
declare -A EXTRAS2NUM
[[ -n "${EXTRAS_MAP:-}" && -f "$EXTRAS_MAP" ]] && {
  while IFS=$'\t' read -r lab nn; do
    [[ -z "$lab" || -z "$nn" || "$lab" =~ ^[[:space:]]*# ]] && continue
    EXTRAS2NUM["$lab"]="$nn"
    seen_numbers["$nn"]=1
  done < "$EXTRAS_MAP"
}

# optional pattern map (regex→NN)
declare -a PM_PAT PM_NN
if [[ -n "${PATTERN_MAP:-}" && -f "$PATTERN_MAP" ]]; then
  while IFS=$'\t' read -r pat nn; do
    [[ -z "$pat" || -z "$nn" || "$pat" =~ ^[[:space:]]*# ]] && continue
    PM_PAT+=("$pat"); PM_NN+=("$nn")
  done < "$PATTERN_MAP"
fi

# label extraction from filename (Econt.01, Esep03, H01, etc.)
extract_label_from_fname(){
  local n="${1%.ab1}"
  if [[ "$n" =~ ([Ee][A-Za-z0-9]*)\.([0-9]{2}[A-Za-z]?) ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"; return
  fi
  # H01 etc.
  if [[ "$n" =~ ([Hh][0-9]{2}) ]]; then echo "${BASH_REMATCH[1]}"; return; fi
  # fallback: tokens containing europu or 1h/2h tags get handled elsewhere
  echo ""
}

# marker + direction from filename (robust to variants)
norm_marker_dir(){
  local S="$(echo "$1" | tr '[:lower:]' '[:upper:]')"
  # COI
  [[ "$S" =~ (LCO-?1490|FISHF1) ]] && { echo "COI_F"; return; }
  [[ "$S" =~ (HCO-?2198|FISHR1) ]] && { echo "COI_R"; return; }
  # 16S
  [[ "$S" =~ 16SAR ]] && { echo "16S_F"; return; }
  [[ "$S" =~ 16SBR ]] && { echo "16S_R"; return; }
  # 12S (note 12Sb/12br = reverse)
  [[ "$S" =~ 12SA ]] && { echo "12S_F"; return; }
  [[ "$S" =~ (12SB|12BR) ]] && { echo "12S_R"; return; }
  # CYTB
  [[ "$S" =~ (GLUDG-?L|MVZ15) ]] && { echo "CYTB_F"; return; }
  [[ "$S" =~ (CB3-?H|EUPCB180) ]] && { echo "CYTB_R"; return; }
  # RHO
  [[ "$S" =~ (RHODF|RHOD1A) ]] && { echo "RHO_F"; return; }
  [[ "$S" =~ (RHODR|RHOD1C) ]] && { echo "RHO_R"; return; }
  # CRY (clock CRYB1Ls=F, CRYB2Ls=R)
  [[ "$S" =~ CRYB1L ]] && { echo "CRY_F"; return; }
  [[ "$S" =~ CRYB2L ]] && { echo "CRY_R"; return; }
  # POMC
  [[ "$S" =~ POMC.*_F1 ]] && { echo "POMC_F"; return; }
  [[ "$S" =~ POMC.*_R1 ]] && { echo "POMC_R"; return; }
  # D-loop (ControlIJ2-L = F, ControlIP-H = R; also fallback -L/-H)
  [[ "$S" =~ DLOOP|D-?LOOP|CONTROL ]] && {
    if [[ "$S" =~ (IJ2-?L|[^A-Z]L[^A-Z]) ]]; then echo "DLOOP_F"; return; fi
    if [[ "$S" =~ (IP-?H|[^A-Z]H[^A-Z]) ]]; then echo "DLOOP_R"; return; fi
    echo "DLOOP_?"; return;
  }
  echo "-"
}

# operator tag -C / -J if present in 2nd token (CRISTIAN|JORGE)
experimenter_tag(){
  local n="${1%.ab1}" tok1 tok2
  IFS=- read -r tok1 tok2 _ <<< "$n"
  [[ -z "$tok2" ]] && { echo ""; return; }
  case "${tok2^^}" in
    CRISTIAN) echo "-C" ;;
    JORGE)    echo "-J" ;;
    *)        echo ""   ;;
  esac
}

# sample ID from label or patterns (returns NN or 'europu' or 'XX')
infer_sample_id(){
  local base="$1"
  local label="$2"

  # europu detection
  if [[ "$base" =~ [Ee]uropu[ _-]?([0-9]{1,2})? ]]; then
    echo "europu"; return
  fi

  # pattern map
  if [[ -n "${PM_PAT[*]:-}" ]]; then
    local i
    for ((i=0; i<${#PM_PAT[@]}; i++)); do
      if grep -E -q "${PM_PAT[$i]}" <<< "$base"; then
        printf "%02d\n" "${PM_NN[$i]}"
        return
      fi
    done
  fi

  # label to number via EXTRAS then CSV aliases
  if [[ -n "$label" ]]; then
    [[ -n "${EXTRAS2NUM[$label]:-}" ]] && { echo "${EXTRAS2NUM[$label]}"; return; }
    if [[ "$label" =~ ^([Ee][A-Za-z0-9]*)\.?([0-9]{2}[A-Za-z]?)$ ]]; then
      local stem="${BASH_REMATCH[1]}" nnpart="${BASH_REMATCH[2]}"
      [[ -n "${SAMPLE2NUM[$stem.$nnpart]:-}" ]] && { echo "${SAMPLE2NUM[$stem.$nnpart]}"; return; }
      [[ -n "${SAMPLE2NUM[$stem$nnpart]:-}"  ]] && { echo "${SAMPLE2NUM[$stem$nnpart]}"; return; }
      local base2="$stem"; [[ "$base2" =~ ^(.+)[a-z]{2}$ ]] && base2="${BASH_REMATCH[1]}"
      [[ -n "${SAMPLE2NUM[$base2.$nnpart]:-}" ]] && { echo "${SAMPLE2NUM[$base2.$nnpart]}"; return; }
      [[ -n "${SAMPLE2NUM[$base2$nnpart]:-}"  ]] && { echo "${SAMPLE2NUM[$base2$nnpart]}"; return; }
    fi
  fi

  echo "XX"
}

# --- main ---
load_csv

shopt -s nullglob
files=($SRC_GLOB)
echo "Scanning ${#files[@]} candidate files."

ts="$(date +%Y%m%d-%H%M%S)"
report="rename_report_${ts}.tsv"
undo="undo_renames_${ts}.sh"
echo -e "old_path\tnew_name\tstatus\treason" > "$report"
echo -e "#!/usr/bin/env bash\nset -Eeuo pipefail" > "$undo"
chmod +x "$undo"

count_total=0; count_renamed=0; count_skipped=0; count_failed=0

for f in "${files[@]}"; do
  ((count_total++))
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"; dirn="$(dirname "$f")"

  # skip already-normalized names
  if [[ "$base" =~ ^(${YEAR_PREFIX}|${YEAR_PREFIX:2})_[0-9]{2}(-[A-Z])?_[A-Za-z0-9]+_([FR]|\?)\.ab1$ ]]; then
    echo -e "$f\t\tskip\talready_normalized" >> "$report"; ((count_skipped++)); continue
  fi
  if [[ "$base" =~ ^${YEAR_PREFIX}_europu_[A-Za-z0-9]+_([FR]|\?)\.ab1$ ]]; then
    echo -e "$f\t\tskip\talready_europu" >> "$report"; ((count_skipped++)); continue
  fi

  label="$(extract_label_from_fname "$base")"
  id="$(infer_sample_id "$base" "$label")"
  md="$(norm_marker_dir "$base")"

  if [[ "$md" == "-" ]]; then
    echo "[fail]  $f (no_marker_found)"
    echo -e "$f\t\tfail\tno_marker_found" >> "$report"
    ((count_failed++))
    continue
  fi

  marker="${md%_*}"
  dirc="${md##*_}"
  # operator tag (only for 2024 IDs, not europu)
  exp="$(experimenter_tag "$base")"

  # target name
  if [[ "$id" == "europu" ]]; then
    new="${YEAR_PREFIX}_europu_${marker}"
    [[ "$dirc" != "?" ]] && new+="_${dirc}"
    new+=".ab1"
  else
    [[ "$id" == "XX" ]] && exp=""   # no id → don't add operator
    new="${YEAR_PREFIX}_${id}${exp:+$exp}_${marker}"
    [[ "$dirc" != "?" ]] && new+="_${dirc}"
    new+=".ab1"
  fi

  # ensure uniqueness in dir
  new="$(unique_name "$dirn" "$new")"

  if [[ $apply -eq 1 ]]; then
    mv -n -- "$f" "$dirn/$new"
    echo "mv -n -- \"$dirn/$new\" \"$f\"" >> "$undo"
    echo -e "$f\t$new\trenamed\t" >> "$report"
    ((count_renamed++))
  else
    echo "[dry]   $f -> $new"
    echo -e "$f\t$new\tdry-run\t" >> "$report"
  fi
done

echo
if [[ $apply -eq 0 ]]; then
  echo "Dry-run only. Re-run with:  $(realpath "$0") --apply"
else
  echo "Done."
fi
echo "Report: $report"
echo "Undo script: $undo"
echo "Summary: renamed=$count_renamed, skipped=$count_skipped, failed=$count_failed, total=$count_total"
