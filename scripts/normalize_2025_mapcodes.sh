#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#  ./normalize_2025_mapcodes.sh [DIR] [--apply]
#  default DIR = ./2025_raw_ab1
#
# Dry-run by default. Pass --apply to actually rename files.

DIR="${1:-$PWD/2025_raw_ab1}"
APPLY=false
if [[ "${2:-}" == "--apply" || "${1:-}" == "--apply" ]]; then
  APPLY=true
fi

timestamp() { date +%Y%m%d-%H%M%S; }

cd "$DIR" || { echo "ERROR: cannot cd to $DIR"; exit 2; }

# ---------------------------
# Mapping: código -> número
# ---------------------------
declare -A CODE2NUM

# Emig (migueli) corrected as you provided:
CODE2NUM["Emig1"]="43"
CODE2NUM["Emig2"]="44"
CODE2NUM["Emig3"]="45"
CODE2NUM["Emig4"]="46"
CODE2NUM["Emig5"]="47"
CODE2NUM["Emig6"]="48"
CODE2NUM["Emig7"]="49"

# Ealt (altor) as confirmed previously:
CODE2NUM["Ealt1"]="19"
CODE2NUM["Ealt2"]="24"
CODE2NUM["Ealt3"]="31"
CODE2NUM["Ealt4"]="56"
CODE2NUM["Ealt5"]="57"
CODE2NUM["Ealt6"]="58"
CODE2NUM["Ealt7"]="59"
CODE2NUM["Ealt8"]="60"
CODE2NUM["Ealt9"]="61"
CODE2NUM["Ealt10"]="62"
CODE2NUM["Ealt11"]="63"

# You can add more aliases if needed:
# CODE2NUM["Emigcol0516"]="43"  # optional extra pattern mapping

# ---------------------------
# helper: canonicalize marker
# ---------------------------
canon_marker() {
  local s="$1"
  s="${s^^}"           # uppercase
  s="${s//-/_}"
  # common variants -> canonical
  if [[ "$s" =~ 16S ]]; then echo "16S"; return; fi
  if [[ "$s" =~ 12S ]]; then echo "12S"; return; fi
  if [[ "$s" =~ COI|LCO|HCO ]]; then echo "COI"; return; fi
  if [[ "$s" =~ CYT|CYTB|CytB ]]; then echo "CYTB"; return; fi
  if [[ "$s" =~ CRY|CRYB ]]; then echo "CRY"; return; fi
  if [[ "$s" =~ POMC ]]; then echo "POMC"; return; fi
  if [[ "$s" =~ DLOOP|D-LOOP|DLOOP ]]; then echo "DLOOP"; return; fi
  if [[ "$s" =~ RHO|RHOD ]]; then echo "RHO"; return; fi
  # fallback: letters-only uppercase token
  s2="$(echo "$s" | sed -E 's/[^A-Z0-9]//g')"
  echo "${s2:-UNKNOWN}"
}

# ---------------------------
# helper: detect direction
# ---------------------------
detect_dir() {
  local name="$1"
  # prefer explicit F or R tokens
  if grep -qiE '(^|[^A-Za-z0-9])F([0-9]*|_|-|\.)' <<< "$name"; then echo "F"; return; fi
  if grep -qiE '(^|[^A-Za-z0-9])R([0-9]*|_|-|\.)' <<< "$name"; then echo "R"; return; fi
  # common suffixes from your examples: -L -> treat as F (left), -H -> treat as R (right/high)
  if grep -qiE '([_-]L(\.|_|$)|_L[0-9]*|L_[0-9]*$)' <<< "$name"; then echo "F"; return; fi
  if grep -qiE '([_-]H(\.|_|$)|_H[0-9]*|H_[0-9]*$)' <<< "$name"; then echo "R"; return; fi
  # fallback: unknown
  echo "?"
}

# ---------------------------
# helper: unique filename (append _2, _3 ...)
# ---------------------------
unique_name() {
  local dir="$1"; local fname="$2"
  local base="${fname%.*}"; local ext="${fname##*.}"; local cand="$fname"; local i=2
  while [[ -e "$dir/$cand" ]]; do
    cand="${base}_${i}.${ext}"
    ((i++))
  done
  echo "$cand"
}

# ---------------------------
# Prepare report + undo
# ---------------------------
TS=$(timestamp)
REPORT="rename_report_${TS}.tsv"
UNDO="undo_renames_${TS}.sh"
printf "old_path\tnew_name\tstatus\treason\n" > "$REPORT"
printf '#!/usr/bin/env bash\nset -Eeuo pipefail\n' > "$UNDO"

# iterate files
shopt -s nullglob
count_total=0 count_done=0 count_skip=0 count_fail=0
for f in *.ab1; do
  ((count_total++))
  # skip if it's already in normalized format (2025_NN_MARKER_D.ab1)
  if [[ "$f" =~ ^2025_[0-9]{1,3}_[A-Z0-9]+_([FR]|\?)\.ab1$ ]]; then
    printf "%s\t%s\tskipped\talready_normalized\n" "$f" "$f" >> "$REPORT"
    ((count_skip++))
    continue
  fi

  # 1) Try extract leading number (NN-... pattern)
  num=""
  if [[ "$f" =~ ^([0-9]{1,4})- ]]; then
    num="${BASH_REMATCH[1]}"
  fi

  # 2) If no leading num, try to detect code (Emig/Ealt variants)
  code_found=""
  if [[ -z "$num" ]]; then
    # look for patterns like Emig, Emigcol0516, Ealt, Ealtale01, etc.
    # generate candidate token list and check mapping keys
    # tokens separated by - or _
    IFS='-_.' read -ra TOKS <<< "$f"
    for t in "${TOKS[@]}"; do
      # normalize token
      tt="$(echo "$t" | sed -E 's/[^A-Za-z0-9]//g')"
      # direct key lookup (Emig1, Ealt2)
      if [[ -n "${CODE2NUM[$tt]:-}" ]]; then
        code_found="$tt"
        break
      fi
      # some tokens may be like Emigcol0516 -> map to Emig1..7? try to match prefix Emig or Emigcol
      if [[ "$tt" =~ ^(Emigcol|Emig) ]]; then
        # attempt to map by numeric suffix (e.g., Emigcol0516 -> Emig1/2... ) — prefer exact mapping not heuristic
        # but we expect you gave us Emig1..Emig7; so if token equals "Emigcol0516" we try common normalized forms:
        # common normalized: Emigcol0516 -> Emig1? we can't guess; prefer explicit "Emig1" token earlier.
        # nevertheless try simple mapping patterns if present:
        # If exact key exists as-is (case-insensitive), use it
        if [[ -n "${CODE2NUM[${tt^}]:-}" ]]; then code_found="${tt^}"; break; fi
        if [[ -n "${CODE2NUM[${tt,,}]:-}" ]]; then code_found="${tt,,}"; break; fi
      fi
      # Ealt variants: try Ealt + digits
      if [[ "$tt" =~ ^(Ealt|Ealtale|Ealtpocon|Ealtcha)[0-9]* ]]; then
        # normalize to EaltN by extracting trailing digits if any, else try to match mapping keys by prefix
        digits="$(echo "$tt" | sed -E 's/^[^0-9]*([0-9]+).*$/\1/;t;d')"
        if [[ $? -eq 0 && -n "$digits" ]]; then
          key="Ealt${digits}"
          if [[ -n "${CODE2NUM[$key]:-}" ]]; then code_found="$key"; break; fi
        fi
        # fallback: if mapping contains any key that starts with Ealt and the token contains 'ealt' use heuristics
        for k in "${!CODE2NUM[@]}"; do
          if [[ "$k" =~ ^Ealt[0-9]+$ ]] && grep -qi "ealt" <<< "$tt"; then
            # don't automatically assign; continue scanning other tokens
            :
          fi
        done
      fi
    done
    if [[ -n "$code_found" && -n "${CODE2NUM[$code_found]:-}" ]]; then
      num="${CODE2NUM[$code_found]}"
    fi
  fi

  # 3) If still no num found -> fail (we don't guess)
  if [[ -z "$num" ]]; then
    printf "%s\t\tfail\tno_sample_number_or_code_found\n" "$f" >> "$REPORT"
    ((count_fail++))
    echo "[FAIL] $f  (no_sample_number_or_code_found)"
    continue
  fi

  # 4) detect marker: search tokens for known markers (priority order)
  marker=""
  # pick first matching token from name (case-insensitive)
  if grep -qiE '16s' <<< "$f"; then marker="16S"; fi
  if grep -qiE '12s' <<< "$f"; then marker="12S"; fi
  if [[ -z "$marker" && ( $(echo "$f" | tr '[:upper:]' '[:lower:]') =~ coi|lco|hco ) ]]; then marker="COI"; fi
  if [[ -z "$marker" && ( $(echo "$f" | tr '[:upper:]' '[:lower:]') =~ cytb|citb|cit\.b|cyt ) ]]; then marker="CYTB"; fi
  if [[ -z "$marker" && ( $(echo "$f" | tr '[:upper:]' '[:lower:]') =~ cry|cryb ) ]]; then marker="CRY"; fi
  if [[ -z "$marker" && ( $(echo "$f" | tr '[:upper:]' '[:lower:]') =~ pomc ) ]]; then marker="POMC"; fi
  if [[ -z "$marker" && ( $(echo "$f" | tr '[:upper:]' '[:lower:]') =~ dloop|d-loop ) ]]; then marker="DLOOP"; fi
  if [[ -z "$marker" && ( $(echo "$f" | tr '[:upper:]' '[:lower:]') =~ rho|rhod ) ]]; then marker="RHO"; fi
  if [[ -z "$marker" ]]; then
    # fallback: try to pick the 4th token after splitting by '-'
    IFS='-' read -ra TOKS2 <<< "$f"
    if [[ ${#TOKS2[@]} -ge 4 ]]; then
      marker=$(canon_marker "${TOKS2[3]}")
    fi
  fi
  if [[ -z "$marker" || "$marker" == "UNKNOWN" ]]; then
    printf "%s\t\tfail\tno_marker_detected\n" "$f" >> "$REPORT"
    ((count_fail++))
    echo "[FAIL] $f  (no_marker_detected)"
    continue
  fi

  # 5) direction
  dir=$(detect_dir "$f")

  # 6) final new name
  newbase="2025_${num}_${marker}_${dir}.ab1"
  newbase=$(unique_name "." "$newbase")  # ensure no collision

  if [[ "$APPLY" == "true" || "$APPLY" == "True" || "$APPLY" == "TRUE" ]]; then
    # actually rename (no-clobber)
    mv -n -- "$f" "$newbase"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      printf "%s\t%s\trenamed\t\n" "$f" "$newbase" >> "$REPORT"
      printf "mv -n -- %q %q\n" "$newbase" "$f" >> "$UNDO"
      ((count_done++))
      echo "[mv] $f -> $newbase"
    else
      printf "%s\t%s\tfail\tmv_failed\n" "$f" "$newbase" >> "$REPORT"
      ((count_fail++))
      echo "[FAIL mv] $f -> $newbase"
    fi
  else
    printf "%s\t%s\tdry-run\t\n" "$f" "$newbase" >> "$REPORT"
    ((count_skip++))
    echo "[dry] $f -> $newbase"
  fi
done

chmod +x "$UNDO" || true

echo "Report: $REPORT"
echo "Undo script: $UNDO"
echo "Summary: total=$count_total renamed=$count_done skipped(dry)=$count_skip failed=$count_fail"
exit 0
