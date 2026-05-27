#!/usr/bin/env bash
set -euo pipefail

YEAR=2024
RAW_DIR="$(pwd)/${YEAR}_raw_ab1"
OUT_DIR="${RAW_DIR}/${YEAR}_normalized"
MAP_FILE="${RAW_DIR}/pattern_map_${YEAR}.tsv"

mkdir -p "$OUT_DIR"

if [[ ! -f "$MAP_FILE" ]]; then
    echo "ERROR: no se encontró el archivo de mapa de patrones: $MAP_FILE" >&2
    exit 1
fi

# =========================
# 1) Cargar pattern_map_2024.tsv
# =========================
declare -A PATTERN2NUM

while IFS=$'\t' read -r pattern num; do
    # saltar líneas vacías
    [[ -z "${pattern// }" ]] && continue
    # saltar líneas con sólo un campo
    [[ -z "${num// }" ]] && continue
    PATTERN2NUM["$pattern"]="$num"
done < "$MAP_FILE"

# =========================
# 2) Función para buscar número de muestra según el filename
# =========================
lookup_sample_num() {
    local fname="$1"
    local -a matches=()
    local pat

    # 1) Buscar todos los patrones que calzan como substring
    for pat in "${!PATTERN2NUM[@]}"; do
        if [[ "$fname" == *"$pat"* ]]; then
            matches+=("$pat")
        fi
    done

    # Si no hubo matches, devolvemos vacío
    if ((${#matches[@]} == 0)); then
        echo ""
        return 1
    fi

    # 2) Filtrar patrones que son subcadenas de otros más largos
    #    (ej: Pbuf1 dentro de Pbuf10, Ealt_1 dentro de Ealt_10, etc.)
    if ((${#matches[@]} > 1)); then
        local -a pruned=()
        local m n
        local drop

        for m in "${matches[@]}"; do
            drop=0
            for n in "${matches[@]}"; do
                [[ "$m" == "$n" ]] && continue
                # si m es subcadena de n y n es más largo -> tirar m
                if [[ "$n" == *"$m"* ]] && ((${#n} > ${#m})); then
                    drop=1
                    break
                fi
            done
            ((drop == 0)) && pruned+=("$m")
        done

        # si después de filtrar no queda nada (caso extremo), volvemos al original
        if ((${#pruned[@]} > 0)); then
            matches=("${pruned[@]}")
        fi
    fi

    # 3) Elegir el patrón más largo (más específico) entre los que quedan
    local best="${matches[0]}"
    local m
    for m in "${matches[@]}"; do
        if ((${#m} > ${#best})); then
            best="$m"
        fi
    done

    # 4) Ver si los patrones restantes apuntan a números distintos
    declare -A seen_nums=()
    for m in "${matches[@]}"; do
        seen_nums["${PATTERN2NUM[$m]}"]=1
    done
    if ((${#seen_nums[@]} > 1)); then
        local nums=()
        for k in "${!seen_nums[@]}"; do
            nums+=("$k")
        done
        echo "WARNING: múltiples patrones para '$fname' (${nums[*]})" >&2
    fi

    echo "${PATTERN2NUM[$best]}"
    return 0
}


# =========================
# 3) Función para detectar marcador y dirección F/R desde el primer
# =========================
detect_marker_and_dir() {
    local fname="$1"
    local primer_token=""
    local marker="UNK"
    local dir="X"

    # COI
    for p in LCO_1490 LCO-1490 LCO1490 HCO_2198 HCO-2198 HCO2198; do
        [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
    done

    # CytB
    if [[ -z "$primer_token" ]]; then
        for p in MVZ15 EUPCB180-H; do
            [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
        done
    fi

    # CRY
    if [[ -z "$primer_token" ]]; then
        for p in CRYB1Ls CRYB2Ls; do
            [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
        done
    fi

    # dLoop (incluyendo typos)
    if [[ -z "$primer_token" ]]; then
        for p in ControlU2-L ControlJ2-L ControlIJ2-L ControlP-H ControlIP-H; do
            [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
        done
    fi

    # POMC
    if [[ -z "$primer_token" ]]; then
        for p in POMC_DRV_F1 POMC-DRV_F1 POMC_DRV_R1 POMC-DRV_R1; do
            [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
        done
    fi

    # 16S
    if [[ -z "$primer_token" ]]; then
        for p in 16Sar 16SAr 16Sbr 16SBr; do
            [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
        done
    fi

    # 12S (incluyendo typo 12br)
    if [[ -z "$primer_token" ]]; then
        for p in 12Sa 12Sb 12br; do
            [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
        done
    fi

    # Rhod
    if [[ -z "$primer_token" ]]; then
        for p in Rhod1A Rhod1C; do
            [[ "$fname" == *"$p"* ]] && primer_token="$p" && break
        done
    fi

    if [[ -z "$primer_token" ]]; then
        echo "UNK X"
        return 1
    fi

    # --- Normalización del token del primer ---
    local primer_raw="$primer_token"

    # COI
    primer_token="${primer_token/LCO-1490/LCO_1490}"
    primer_token="${primer_token/LCO1490/LCO_1490}"
    primer_token="${primer_token/HCO-2198/HCO_2198}"
    primer_token="${primer_token/HCO2198/HCO_2198}"

    # dLoop typos
    primer_token="${primer_token/ControlIJ2-L/ControlJ2-L}"
    primer_token="${primer_token/ControlIP-H/ControlP-H}"

    # 12S typo
    primer_token="${primer_token/12br/12Sb}"

    # POMC con guion
    primer_token="${primer_token/POMC-DRV_F1/POMC_DRV_F1}"
    primer_token="${primer_token/POMC-DRV_R1/POMC_DRV_R1}"

    # --- Asignar marcador y F/R ---
    case "$primer_token" in
        # COI
        LCO_1490)      marker="COI";  dir="F" ;;
        HCO_2198)      marker="COI";  dir="R" ;;

        # CytB
        MVZ15)         marker="CYTB"; dir="F" ;;
        EUPCB180-H)    marker="CYTB"; dir="R" ;;

        # CRY
        CRYB1Ls)       marker="CRY";  dir="F" ;;
        CRYB2Ls)       marker="CRY";  dir="R" ;;

        # dLoop
        ControlU2-L|ControlJ2-L)
                        marker="DLOOP"; dir="F" ;;
        ControlP-H)     marker="DLOOP"; dir="R" ;;

        # POMC
        POMC_DRV_F1)   marker="POMC"; dir="F" ;;
        POMC_DRV_R1)   marker="POMC"; dir="R" ;;

        # 16S
        16Sar|16SAr)   marker="16S";  dir="F" ;;
        16Sbr|16SBr)   marker="16S";  dir="R" ;;

        # 12S
        12Sa)          marker="12S";  dir="F" ;;
        12Sb)          marker="12S";  dir="R" ;;

        # Rhod
        Rhod1A)        marker="RHOD"; dir="F" ;;
        Rhod1C)        marker="RHOD"; dir="R" ;;

        *)
            marker="UNK"; dir="X"
            ;;
    esac

    if [[ "$marker" == "UNK" ]]; then
        echo "WARNING: no se pudo detectar marcador en '$fname'" >&2
    fi
    if [[ "$dir" == "X" ]]; then
        echo "WARNING: no se pudo detectar dirección F/R en '$fname' (marker=$marker)" >&2
    fi

    echo "$marker $dir"
    return 0
}

# =========================
# 4) Recorrer todos los .ab1 y renombrar
# =========================

declare -A COUNTS

for path in "${RAW_DIR}"/*.ab1; do
    # saltar si ya está en el directorio de salida
    if [[ "$path" == "$OUT_DIR/"* ]]; then
        continue
    fi

    fname="$(basename "$path")"

    # 4.1. Buscar número de muestra según pattern_map
    sample_num="$(lookup_sample_num "$fname" || true)"
    if [[ -z "${sample_num:-}" ]]; then
        echo "WARNING: no se encontró número de muestra para '$fname'" >&2
        continue
    fi

    # 4.2. Detectar marcador y dirección F/R
    read -r marker dir <<<"$(detect_marker_and_dir "$fname")"

    # 4.3. Contar replicados
    key="${sample_num}_${marker}_${dir}"
    COUNTS["$key"]=$(( ${COUNTS["$key"]:-0} + 1 ))
    copy_idx=${COUNTS["$key"]}

    # 4.4. Construir nombre nuevo
    if (( copy_idx == 1 )); then
        new_name="${YEAR}_${sample_num}_${marker}_${dir}.ab1"
    else
        new_name="${YEAR}_${sample_num}_${copy_idx}_${marker}_${dir}.ab1"
    fi

    dest="${OUT_DIR}/${new_name}"

    if [[ -e "$dest" ]]; then
        echo "WARNING: destino ya existe, sobrescribiendo: $(basename "$dest")" >&2
    fi

    # *** AQUÍ EL CAMBIO IMPORTANTE: cp en vez de mv ***
    cp "$path" "$dest"

    echo "-> '$fname'  =>  '$(basename "$dest")'"
done
