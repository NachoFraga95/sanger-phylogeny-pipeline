#!/usr/bin/env python3
import os, sys, glob, re
from collections import defaultdict
from Bio import SeqIO, pairwise2
from Bio.Seq import Seq

IN_DIR = sys.argv[1] if len(sys.argv) > 1 else "work/01_trimmed"
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else "work/02_consensus"
os.makedirs(OUT_DIR, exist_ok=True)

iupac = {
    frozenset("AG"): "R", frozenset("CT"): "Y",
    frozenset("CG"): "S", frozenset("AT"): "W",
    frozenset("GT"): "K", frozenset("AC"): "M",
    frozenset("ACG"): "V", frozenset("ACT"): "H",
    frozenset("AGT"): "D", frozenset("CGT"): "B",
}
def iupac_code(chars):
    chars = {c for c in chars if c in "ACGT"}
    if not chars:
        return "N"
    if len(chars) == 1:
        return list(chars)[0]
    return iupac.get(frozenset(chars), "N")

def read_one_fastq(path):
    """Return (seq, qual_list) or (None, None) if file absent/empty."""
    if not path or not os.path.exists(path) or os.path.getsize(path) == 0:
        return (None, None)
    recs = list(SeqIO.parse(path, "fastq"))
    if not recs:
        return (None, None)
    r = recs[0]
    return str(r.seq).upper(), list(r.letter_annotations["phred_quality"])

def rc(seq, qual):
    return str(Seq(seq).reverse_complement()), list(reversed(qual))

def consensus_from_pair(seqF, qF, seqR, qR):
    # global alignment, affine gaps
    alns = pairwise2.align.globalms(seqF, seqR, 2, -1, -5, -1, one_alignment_only=True)
    aF, aR, *_ = alns[0]
    iF = iR = 0
    qFa = []
    qRa = []
    for cF, cR in zip(aF, aR):
        if cF == "-":
            qFa.append(0)
        else:
            qFa.append(qF[iF]); iF += 1
        if cR == "-":
            qRa.append(0)
        else:
            qRa.append(qR[iR]); iR += 1

    cons = []
    for bF, bR, qf, qr in zip(aF, aR, qFa, qRa):
        if bF == "-" and bR == "-":
            cons.append("-"); continue
        if bF == "-":
            cons.append(bR); continue
        if bR == "-":
            cons.append(bF); continue
        if bF == bR:
            cons.append(bF); continue
        # quality-weighted choice; if close, IUPAC
        if abs(qf - qr) >= 10:
            cons.append(bF if qf > qr else bR)
        else:
            cons.append(iupac_code({bF, bR}))
    cons = "".join(cons).strip("-").replace("-", "")
    cons = re.sub(r"[^ACGTURYSWKMBDHVN]", "N", cons)
    return cons

# group F/R by (year, sample, marker)
pairs = defaultdict(dict)

for fq in sorted(glob.glob(os.path.join(IN_DIR, "*.fastq"))):
    base = os.path.basename(fq).replace(".fastq", "")
    parts = base.split("_")
    # Esperamos: year, sample, [optional_copy], marker, dir(F/R)
    if len(parts) not in (4, 5):
        # nombre raro, lo saltamos
        print(f"[skip] nombre inesperado: {base}")
        continue

    d = parts[-1]
    marker = parts[-2]
    if d not in ("F", "R"):
        print(f"[skip] sin F/R claro: {base}")
        continue

    year = parts[0]
    sample = parts[1]
    # parts[2] puede ser copia, pero por ahora no la usamos como clave
    key = (year, sample, marker)
    pairs[key][d] = fq

wrote = skipped = 0

for (year, sample, marker), dct in sorted(
        pairs.items(),
        key=lambda x: (x[0][0], int(x[0][1]), x[0][2])
):
    f = dct.get("F")
    r = dct.get("R")

    seqF, qF = read_one_fastq(f) if f else (None, None)
    seqR_raw, qR_raw = read_one_fastq(r) if r else (None, None)

    # handle empty/missing reads
    if seqF is None and seqR_raw is None:
        print(f"[skip] {(year, sample, marker)}: both reads missing/empty after trimming")
        skipped += 1
        continue

    if seqF is not None and seqR_raw is not None:
        # pair: reverse-complement R and build consensus
        seqR, qR = rc(seqR_raw, qR_raw)
        cons = consensus_from_pair(seqF, qF, seqR, qR)
    else:
        # single-end fallback
        only = f if seqF is not None else r
        rec = next(SeqIO.parse(only, "fastq"))
        cons = str(rec.seq).upper()

    out_base = f"{year}_{sample}_{marker}"
    out_path = os.path.join(OUT_DIR, f"{out_base}.fasta")
    with open(out_path, "w") as fh:
        fh.write(f">{out_base}\n{cons}\n")

    wrote += 1
    print(f"[consensus] {(year, sample, marker)} -> {out_path}")

print(f"done: wrote {wrote} consensus sequences; skipped={skipped}.")
