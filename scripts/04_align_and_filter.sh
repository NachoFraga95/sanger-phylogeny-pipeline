#!/usr/bin/env bash
set -euo pipefail

# Directorio del proyecto (raíz)
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IN_DIR="$PROJ_DIR/work/03_markers_raw"
ALN_DIR="$PROJ_DIR/work/04_align"
FLT_DIR="$PROJ_DIR/work/04_align_filtered"

echo "Proyecto:        $PROJ_DIR"
echo "Input markers:   $IN_DIR"
echo "Align out:       $ALN_DIR"
echo "Filtered out:    $FLT_DIR"
echo

mkdir -p "$ALN_DIR" "$FLT_DIR"

# Detectar todos los marcadores disponibles en work/03_markers_raw/*.fa
mapfile -t MARKERS < <(find "$IN_DIR" -maxdepth 1 -type f -name '*.fa' -printf '%f\n' | sort)

if [ "${#MARKERS[@]}" -eq 0 ]; then
    echo "ERROR: no se encontraron archivos .fa en $IN_DIR"
    exit 1
fi

for fa in "${MARKERS[@]}"; do
    marker="${fa%.fa}"   # p.ej. COI.fa -> COI
    in_fa="$IN_DIR/$fa"
    aln_fa="$ALN_DIR/${marker}.aln.fa"
    flt_fa="$FLT_DIR/${marker}.filtered.fa"

    if [ ! -s "$in_fa" ]; then
        echo "[WARN] marcador $marker: archivo vacío o no existe, saltando."
        continue
    fi

    # contar cuántas secuencias hay
    nseq=$(grep -c '^>' "$in_fa" || true)

    if [ "$nseq" -lt 2 ]; then
        echo "[WARN] marcador $marker: solo $nseq secuencia(s); copiando sin alinear."
        cp -f "$in_fa" "$aln_fa"
        cp -f "$in_fa" "$flt_fa"
        echo
        continue
    fi

    echo "[align] marcador $marker  (nseq=$nseq)"
    mafft --auto --reorder "$in_fa" > "$aln_fa"

    # Por ahora, el “filtrado” es simplemente copiar el alineamiento tal cual.
    cp -f "$aln_fa" "$flt_fa"

    nseq_flt=$(grep -c '^>' "$flt_fa" || true)
    echo "[filter] marcador $marker -> $nseq_flt secuencias en $flt_fa"
    echo
done

echo "Listo: alineamientos en:"
echo "  $ALN_DIR"
echo "y copias 'filtradas' en:"
echo "  $FLT_DIR"
