#!/usr/bin/env bash
# Normaliza nombres 2025 → 2025_NUM_MARKER_DIR.ab1
# - NO toca los originales (cp)
# - Usa mapa EaltX / EmigY
# - Detecta marcador por el nombre completo
# - Detecta F/R por primer (case-insensitive, basado en subcadenas)

set -Eeuo pipefail

RAW_DIR="${1:-$HOME/compartida_ubuntu/sanger-arboles/project/2025_raw_ab1}"
OUT_DIR="${RAW_DIR}/2025_normalized"

mkdir -p "$OUT_DIR"

# ---------- mapas de códigos especiales ----------

map_ealt() {
  case "$1" in
    EALT1)  echo 19 ;;
    EALT2)  echo 24 ;;
    EALT3)  echo 31 ;;
    EALT4)  echo 56 ;;
    EALT5)  echo 57 ;;
    EALT6)  echo 58 ;;
    EALT7)  echo 59 ;;
    EALT8)  echo 60 ;;
    EALT9)  echo 61 ;;
    EALT10) echo 62 ;;
    EALT11) echo 63 ;;
    *)      echo "" ;;
  esac
}

map_emig() {
  case "$1" in
    EMIG1) echo 43 ;;
    EMIG2) echo 44 ;;
    EMIG3) echo 45 ;;
    EMIG4) echo 46 ;;
    EMIG5) echo 47 ;;
    EMIG6) echo 48 ;;
    EMIG7) echo 49 ;;
    *)     echo "" ;;
  esac
}

# ---------- marcador (COI, CYTB, DLOOP, CRY, POMC, 12S, 16S) ----------

detect_marker() {
  local b="$1"
  local u
  u="$(echo "$b" | tr '[:lower:]' '[:upper:]')"

  if   [[ "$u" == *"-COI-"* ]]; then
    echo "COI"
  elif [[ "$u" == *"-CB-"* ]]; then
    echo "CYTB"
  elif [[ "$u" == *"DLOOP"* ]] || [[ "$u" == *"-DLOOP-"* ]] || [[ "$u" == *"-DLOOP_"* ]] || [[ "$u" == *"DLOOP-"* ]]; then
    echo "DLOOP"
  elif [[ "$u" == *"-CRY-"* ]]; then
    echo "CRY"
  elif [[ "$u" == *"-POMC-"* ]] || [[ "$u" == *"POMC_DRV"* ]]; then
    # algunos tienen "-POMC-", otros solo "POMC_DRV_F1"
    echo "POMC"
  elif [[ "$u" == *"-12S-"* ]]; then
    echo "12S"
  elif [[ "$u" == *"-16S-"* ]]; then
    echo "16S"
  else
    echo ""
  fi
}

# ---------- dirección F / R según primer (subcadenas, case-insensitive) ----------

detect_dir() {
  local b="$1"
  local u
  u="$(echo "$b" | tr '[:lower:]' '[:upper:]')"

  # COI
  if   [[ "$u" == *"LCO_1490"* ]]; then
    echo "F"
  elif [[ "$u" == *"HCO_2198"* ]]; then
    echo "R"

  # CYTB
  elif [[ "$u" == *"MVZ15"* ]]; then
    echo "F"
  elif [[ "$u" == *"EUPCB180-H"* ]]; then
    echo "R"

  # CRY (CRYB1Ls / CRYB1LS / variantes)
  elif [[ "$u" == *"CRYB1LS"* ]]; then
    echo "F"
  elif [[ "$u" == *"CRYB2LS"* ]]; then
    echo "R"

  # DLOOP (incluye bug ControlU2-L)
  elif [[ "$u" == *"CONTROLJ2-L"* ]] || [[ "$u" == *"CONTROLU2-L"* ]]; then
    echo "F"
  elif [[ "$u" == *"CONTROLP-H"* ]]; then
    echo "R"

  # POMC
  elif [[ "$u" == *"POMC_DRV_F1"* ]]; then
    echo "F"
  elif [[ "$u" == *"POMC_DRV_R1"* ]]; then
    echo "R"

  # 12S
  elif [[ "$u" == *"12SA"* ]]; then
    echo "F"
  elif [[ "$u" == *"12SB"* ]]; then
    echo "R"

  # 16S
  elif [[ "$u" == *"16SAR"* ]]; then
    echo "F"
  elif [[ "$u" == *"16SBR"* ]]; then
    echo "R"

  else
    echo "X"   # no se pudo determinar
  fi
}

# ---------- número de muestra ----------

detect_num() {
  local b="$1"
  local u
  u="$(echo "$b" | tr '[:lower:]' '[:upper:]')"

  # quitar la parte de fecha/pozo (desde el primer "_")
  local prefix="${u%%_*}"   # ej: 32523-CRISTIAN-CRY-34-CRYB1LS

  IFS='-' read -r -a parts <<< "$prefix"

  # encontrar índice de CRISTIAN
  local idxC=-1
  local i
  for i in "${!parts[@]}"; do
    if [[ "${parts[$i]}" == "CRISTIAN" ]]; then
      idxC="$i"
      break
    fi
  done

  if (( idxC < 0 )); then
    echo ""
    return
  fi

  local tok num=""
  for (( i=idxC+1; i<${#parts[@]}; i++ )); do
    tok="${parts[$i]}"

    # códigos especiales EALT / EMIG
    if [[ "$tok" =~ ^EALT[0-9]+$ ]]; then
      num="$(map_ealt "$tok")"
      [[ -n "$num" ]] && break
    elif [[ "$tok" =~ ^EMIG[0-9]+$ ]]; then
      num="$(map_emig "$tok")"
      [[ -n "$num" ]] && break

    # número puro (acepta sufijo S: 5S, 18S, etc.)
    elif [[ "$tok" =~ ^[0-9]+S?$ ]]; then
      num="${tok%S}"   # si termina en S, la quita
      break
    fi
  done

  echo "$num"
}

# ---------- bucle principal ----------

shopt -s nullglob

echo "Normalizando archivos en: $RAW_DIR"
echo "Salida en:                $OUT_DIR"
echo

for f in "$RAW_DIR"/*.ab1; do
  # saltar archivos ya dentro de la carpeta de salida
  [[ "$f" == "$OUT_DIR/"* ]] && continue
  [[ -e "$f" ]] || continue

  base="$(basename "$f")"
  base_noext="${base%.ab1}"

  marker="$(detect_marker "$base_noext")"
  if [[ -z "$marker" ]]; then
    echo "WARNING: no se pudo detectar marcador en '$base_noext'"
    continue
  fi

  num="$(detect_num "$base_noext")"
  if [[ -z "$num" ]]; then
    echo "WARNING: no se pudo obtener número de muestra en '$base_noext'"
    continue
  fi

  dir="$(detect_dir "$base_noext")"
  if [[ "$dir" == "X" ]]; then
    echo "WARNING: no se pudo detectar dirección F/R en '$base_noext' (marker=$marker)"
  fi

  new="${OUT_DIR}/2025_${num}_${marker}_${dir}.ab1"

  if [[ -e "$new" ]]; then
    echo "WARNING: destino ya existe, sobrescribiendo: $(basename "$new")"
  fi

  cp -v -- "$f" "$new"
done

echo
echo "[OK] Normalización completada en: $OUT_DIR"
