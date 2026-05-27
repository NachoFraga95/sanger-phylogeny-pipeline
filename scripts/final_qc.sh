#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${1:-$HOME/compartida_ubuntu/sanger-arboles/project/sanger_out}"

# 1) duplicates in strict_core
for f in "$ROOT"/align_consensus/strict_core/*.fasta; do
  d=$(grep -c '^>' "$f" || true)
  if [[ $d -gt 0 ]]; then
    u=$(grep '^>' "$f" | sort | uniq -d | wc -l)
    [[ $u -eq 0 ]] || echo "[dup] $f"
  fi
done

# 2) N >10%
python3 - <<'PY'
import glob, sys
from Bio import SeqIO
flag=False
for f in glob.glob(sys.argv[1]+"/align_consensus/strict_core/*.fasta"):
    bad=[(r.id, r.seq.count('N')/len(r.seq)) for r in SeqIO.parse(f,"fasta") if len(r)>0 and r.seq.count('N')/len(r.seq)>0.10]
    if bad:
        flag=True
        print("[N>10%]", f, ":", ", ".join(f"{i}={p:.1%}" for i,p in bad))
sys.exit(1 if flag else 0)
PY "$ROOT" || true

column -t -s $'\t' "$ROOT/summary.tsv"
