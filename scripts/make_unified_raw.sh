#!/usr/bin/env bash
set -euo pipefail

# Punto de partida: este script se asume ejecutado desde la raíz del proyecto
#   ~/compartida_ubuntu/sanger-arboles/project

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RAW2024="$PROJ_DIR/2024_raw_ab1"
RAW2025="$PROJ_DIR/2025_raw_ab1"

NORM2024="$RAW2024/2024_normalized"
NORM2025="$RAW2025/2025_normalized"

UNIFIED="$PROJ_DIR/unified_raw_ab1"

echo "Proyecto:           $PROJ_DIR"
echo "2024_normalized:    $NORM2024"
echo "2025_normalized:    $NORM2025"
echo "unified_raw_ab1:    $UNIFIED"
echo

# Crear carpeta unified si no existe
mkdir -p "$UNIFIED"

# Limpiar solo los .ab1 anteriores en unified (NO tocar 2024/2025_raw_ab1)
find "$UNIFIED" -maxdepth 1 -type f -name '*.ab1' -delete

copy_from_norm () {
    local src="$1"
    local label="$2"

    if [ ! -d "$src" ]; then
        echo "[$label] No existe directorio: $src (saltando)"
        return
    fi

    echo "[$label] Copiando desde: $src"

    # Si no hay .ab1, no hacer nada
    if ! compgen -G "$src/*.ab1" > /dev/null; then
        echo "[$label] No se encontraron .ab1 en $src"
        return
    fi

    for f in "$src"/*.ab1; do
        base="$(basename "$f")"
        # Si existiera un duplicado exacto, lo sobrescribe silenciosamente
        cp -f "$f" "$UNIFIED/$base"
    done
}

copy_from_norm "$NORM2024" "2024"
copy_from_norm "$NORM2025" "2025"

COUNT="$(find "$UNIFIED" -maxdepth 1 -type f -name '*.ab1' | wc -l)"
echo
echo "Unified raw_ab1 count: $COUNT"
