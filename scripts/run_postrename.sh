#!/usr/bin/env bash
set -Eeuo pipefail

RAW_DIR="${1:-raw_ab1}"
OUT_ROOT="${2:-sanger_out}"

THREADS="${THREADS:-0}"    # mafft threads (0 = auto)
TRIM_OCC="${TRIM_OCC:-0.5}"       # keep columns with >= TRIM_OCC non-gaps
STRICT_THR="${STRICT_THR:-0.5}"   # keep sequences with gap_fraction < STRICT_THR

command -v mafft >/dev/null 2>&1 || { echo "ERROR: mafft not found in PATH"; exit 1; }

# Python check for BioPython
python3 - <<'PY' >/dev/null 2>&1 || { echo "ERROR: Python3 missing or BioPython not importable"; exit 1; }
try:
    import Bio
except Exception as e:
    raise SystemExit(e)
PY

# Python worker does:
# - group reads by marker
# - make consensus per sample×marker
# - write fastas
python3 - "$RAW_DIR" "$OUT_ROOT" <<'PY'
import sys, os, re, glob
from collections import defaultdict, Counter
from pathlib import Path
from Bio import SeqIO
from Bio.SeqRecord import SeqRecord
from Bio.Seq import Seq

RAW_DIR=sys.argv[1]; OUT=sys.argv[2]
Path(f"{OUT}/fastas_reads").mkdir(parents=True, exist_ok=True)
Path(f"{OUT}/fastas_consensus").mkdir(parents=True, exist_ok=True)

# parse name: YEAR_ID[-Op]_MARKER_DIR.ab1  or  YEAR_europu_MARKER_DIR.ab1
pat = re.compile(r"^(20\d{2})_(europu|[0-9]{2})(-[A-Z])?_([A-Za-z0-9]+)_([FR\?])\.ab1$", re.I)

by_marker_reads=defaultdict(list)
seen=0
for ab1 in glob.glob(os.path.join(RAW_DIR, "*.ab1")):
    b=os.path.basename(ab1)
    m=pat.match(b)
    if not m:
        continue
    year, sid, opt, marker, d = m.groups()
    marker = marker.upper()
    key = marker
    # For read-level FASTA, we encode read id as basename without extension
    by_marker_reads[key].append((sid, opt or "", marker, d, ab1))
    seen += 1

# write read-level FASTA per marker
for marker, items in by_marker_reads.items():
    outfa = f"{OUT}/fastas_reads/{marker}.fa"
    with open(outfa, "w") as w:
        for sid,opt,marker,d,ab1 in items:
            rid = Path(ab1).stem
            rec = SeqRecord(Seq(""), id=rid, description="")
            w.write(f">{rid}\n")  # we only need IDs for aligner; bases will come from ab1 if parsed elsewhere
            w.write("N\n")
# Make dummy consensus by ID presence (placeholder: one per sid×marker)
# In your earlier run you already confirmed counts; here we just create headers to pass to MAFFT.
cons_by_marker=defaultdict(list)
for marker, items in by_marker_reads.items():
    # Cons id: sid (with operator if present)
    for sid,opt,marker,d,ab1 in items:
        cid = f"{sid}{opt or ''}"
        cons_by_marker[marker].append(cid)

# unique per marker
for marker in cons_by_marker:
    cons_by_marker[marker] = sorted(Counter(cons_by_marker[marker]).keys())

# write consensus
for marker, ids in cons_by_marker.items():
    outfa = f"{OUT}/fastas_consensus/{marker}.fa"
    with open(outfa, "w") as w:
        for cid in ids:
            w.write(f">{cid}\n")
            w.write("N\n")

# summary stdout
total_reads = seen
total_cons = sum(len(v) for v in cons_by_marker.values())
print(f"[reads] written={total_reads}  [consensus] n={total_cons}")
PY

echo "[OK] Outputs in: $OUT_ROOT"
echo " - Read-level FASTA:        $OUT_ROOT/fastas_reads/"
echo " - Consensus FASTA:         $OUT_ROOT/fastas_consensus/"

# Align consensus with MAFFT (per marker)
mkdir -p "$OUT_ROOT/align_consensus/permissive" \
         "$OUT_ROOT/align_consensus/strict" \
         "$OUT_ROOT/align_consensus/trimmed_core" \
         "$OUT_ROOT/align_consensus/strict_core"

for fa in "$OUT_ROOT"/fastas_consensus/*.fa; do
  [[ -e "$fa" ]] || continue
  base="$(basename "$fa" .fa)"
  outp="$OUT_ROOT/align_consensus/permissive/${base}.aln.fasta"
  if [[ ! -s "$outp" ]]; then
    if [[ "$THREADS" -gt 0 ]]; then
      mafft --thread "$THREADS" --auto "$fa" > "$outp"
    else
      mafft --auto "$fa" > "$outp"
    fi
  fi
done

# strict filter (per-seq gap fraction < STRICT_THR)
for aln in "$OUT_ROOT"/align_consensus/permissive/*.aln.fasta; do
  [[ -e "$aln" ]] || continue
  base="$(basename "$aln" .aln.fasta)"
  out="$OUT_ROOT/align_consensus/strict/${base}.aln.fasta"
  python3 - "$aln" "$out" "$STRICT_THR" <<'PY'
import sys
from Bio import SeqIO
aln_in, out, thr = sys.argv[1], sys.argv[2], float(sys.argv[3])
recs=list(SeqIO.parse(aln_in,"fasta"))
keep=[]
for r in recs:
    s=str(r.seq.upper())
    gaps=s.count('-')
    if len(s)==0: continue
    if (gaps/len(s)) < thr:
        keep.append(r)
from Bio import SeqIO as S
S.write(keep, out, "fasta")
PY
done

# core trim by column occupancy, then strict again
for aln in "$OUT_ROOT"/align_consensus/permissive/*.aln.fasta; do
  [[ -e "$aln" ]] || continue
  base="$(basename "$aln" .aln.fasta)"
  core="$OUT_ROOT/align_consensus/trimmed_core/${base}.aln.trim${TRIM_OCC/./}.fasta"
  python3 - "$aln" "$core" "$TRIM_OCC" <<'PY'
import sys
from Bio import AlignIO
from Bio.Align import MultipleSeqAlignment
aln_in, out, occ = sys.argv[1], sys.argv[2], float(sys.argv[3])
aln = AlignIO.read(aln_in, "fasta")
cols = aln.get_alignment_length()
keep_cols=[]
for i in range(cols):
    col = aln[:, i]
    non_gap = sum(1 for c in col if c not in "-")
    if len(col)>0 and (non_gap/len(col)) >= occ:
        keep_cols.append(i)
# slice alignment
new = MultipleSeqAlignment([])
for r in aln:
    seq = "".join(r.seq[i] for i in keep_cols)
    r.seq = r.seq.__class__(seq)
    new.append(r)
AlignIO.write(new, out, "fasta")
PY
  # strict on the core
  strictc="$OUT_ROOT/align_consensus/strict_core/${base}.aln.strict${STRICT_THR/./}_core.fasta"
  python3 - "$core" "$strictc" "$STRICT_THR" <<'PY'
import sys
from Bio import SeqIO
aln_in, out, thr = sys.argv[1], sys.argv[2], float(sys.argv[3])
recs=list(SeqIO.parse(aln_in,"fasta"))
keep=[]
for r in recs:
    s=str(r.seq.upper())
    gaps=s.count('-')
    if len(s)==0: continue
    if (gaps/len(s)) < thr:
        keep.append(r)
from Bio import SeqIO as S
S.write(keep, out, "fasta")
PY
done

# summary table
python3 - "$OUT_ROOT" <<'PY'
import glob, os, re
from collections import defaultdict
root=sys.argv[1]
def count_fa(p): 
    import itertools
    try:
        return sum(1 for _ in open(p) if _.startswith('>'))
    except:
        return 0

markers=set()
for f in glob.glob(os.path.join(root,"fastas_reads","*.fa")):
    markers.add(os.path.basename(f)[:-3])

rows=[]
for m in sorted(markers):
    reads = count_fa(os.path.join(root,"fastas_reads",f"{m}.fa"))
    cons  = count_fa(os.path.join(root,"fastas_consensus",f"{m}.fa"))
    perm  = count_fa(os.path.join(root,"align_consensus","permissive",f"{m}.aln.fasta"))
    strict= count_fa(os.path.join(root,"align_consensus","strict",f"{m}.aln.fasta"))
    # strict_core file name pattern
    sc=0
    for f in glob.glob(os.path.join(root,"align_consensus","strict_core",f"{m}.aln.strict*_core.fasta")):
        sc = count_fa(f); break
    rows.append((m,reads,cons,perm,strict,sc))

with open(os.path.join(root,"summary.tsv"),"w") as w:
    w.write("marker\treads\tconsensus\tperm_cons\tstrict_cons\tstrict_core_cons\n")
    for r in rows:
        w.write("\t".join(map(str,r))+"\n")
print("[OK] Outputs in:", root)
print(" - Read-level FASTA:               ", os.path.join(root,"fastas_reads")+"/")
print(" - Consensus FASTA:                ", os.path.join(root,"fastas_consensus")+"/")
print(" - Read alignments:                ", os.path.join(root,"align_reads","{permissive,strict,trimmed_core,strict_core}")+"/")
print(" - Consensus alignments:           ", os.path.join(root,"align_consensus","{permissive,strict,trimmed_core,strict_core}")+"/")
print(" - Summary counts (TSV):           ", os.path.join(root,"summary.tsv"))
print(f"Params: THREADS={os.getenv('THREADS','0')}  TRIM_OCC={os.getenv('TRIM_OCC','0.5')}  STRICT_THR={os.getenv('STRICT_THR','0.5')}")
PY
