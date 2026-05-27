#!/usr/bin/env bash
set -Eeuo pipefail
PROJ="$HOME/compartida_ubuntu/sanger-arboles/project"
SRC="$PROJ/sanger_out"
DEST="$PROJ/sanger_out_para_boss"

rm -rf "$DEST"
mkdir -p \
  "$DEST/00_resumen" \
  "$DEST/01_consensos" \
  "$DEST/02_consensos alineados permisivos" \
  "$DEST/03_consensos alineados estrictos" \
  "$DEST/04_consensos alineados estrictos (nucleo)"

cp "$SRC/summary.tsv" "$DEST/00_resumen/summary.tsv"

cat > "$DEST/00_resumen/LEEME.txt" <<'EOF'
Contenido del paquete (archivos listos para revisar y hacer árboles):

01_consensos/                       → FASTA de consensos por marcador, SIN alinear
02_consensos alineados permisivos/  → MAFFT alineado (sin filtros estrictos)
03_consensos alineados estrictos/   → Alineado + filtro por proporción de gaps (<50% por secuencia)
04_consensos alineados estrictos (nucleo)/ → Alineado, recortado al “núcleo” (≥50% ocupación de columna) y luego filtro por gaps (<50%). RECOMENDADO para filogenia.

Notas:
- Nombres “2024_NN-Op_MARKER_D” y “2025_NN_MARKER_D”:
  año, número de muestra (NN), operador opcional (-C/-J), marcador (12S/16S/COI/CRY/CYTB/DLOOP/POMC/RHO) y dirección (F/R).
- “europu” son casos fuera de planilla: 2024_europu_MARKER_D.
- Recomendación: usar “04_consensos alineados estrictos (nucleo)” para inferencia filogenética.

Cualquier duda sobre criterios (permisivo vs estricto vs núcleo), ver summary.tsv.
EOF

cp "$SRC/fastas_consensus/"*.fa "$DEST/01_consensos/" 2>/dev/null || true
for f in "$DEST/01_consensos/"*.fa 2>/dev/null; do
  [[ -e "$f" ]] && mv -- "$f" "${f%.fa}.fasta"
done

cp "$SRC/align_consensus/permissive/"*.aln.fasta  "$DEST/02_consensos alineados permisivos/"  2>/dev/null || true
cp "$SRC/align_consensus/strict/"*.aln.fasta      "$DEST/03_consensos alineados estrictos/"   2>/dev/null || true
cp "$SRC/align_consensus/strict_core/"*.fasta     "$DEST/04_consensos alineados estrictos (nucleo)/" 2>/dev/null || true

cd "$PROJ"
zip -r "$(basename "$DEST").zip" "$(basename "$DEST")" >/dev/null
echo "OK => $DEST/"
ls -lh "$(basename "$DEST").zip"
