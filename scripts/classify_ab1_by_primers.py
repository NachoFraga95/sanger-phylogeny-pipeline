#!/usr/bin/env python3
import sys, os, argparse, math
from pathlib import Path
from Bio import SeqIO
from Bio.Seq import Seq

# Primer sequences (IUPAC allowed)
PRIMERS = {
    "POMC_F": "ATATGTCATGASCCAYTTYCGCTGGAA",
    "POMC_R": "GGCRTTYTTGAAWAGAGTCATTAGWGG",
    "RHOD_F": "ACCATGAACGGAACAGAAGGYCC",
    "RHOD_R": "CCAAGGGTAGCGAAGAARCCTTC",
}

IUPAC = {
    "A":{"A"}, "C":{"C"}, "G":{"G"}, "T":{"T"}, "U":{"T"},
    "R":{"A","G"}, "Y":{"C","T"}, "S":{"G","C"}, "W":{"A","T"},
    "K":{"G","T"}, "M":{"A","C"}, "B":{"C","G","T"}, "D":{"A","G","T"},
    "H":{"A","C","T"}, "V":{"A","C","G"}, "N":{"A","C","G","T"},
}

def rc(s:str)->str:
    return str(Seq(s).reverse_complement()).upper().replace("U","T")

def iupac_mismatches(pattern:str, target:str)->int:
    """Count mismatches with IUPAC in pattern vs target (U->T). Penalize shortness."""
    pattern = pattern.upper()
    target  = target.upper().replace("U","T")
    mm = 0
    L = min(len(pattern), len(target))
    for i in range(L):
        p = pattern[i]
        t = target[i]
        if t not in IUPAC.get(p, {p}):
            mm += 1
    mm += (len(pattern) - L)  # penalty if target shorter than primer
    return mm

def best_end_match(seq:str, primer:str, near:str, window:int=80, err:float=0.25, overlap:int=10):
    """
    Search for primer near 'start' or 'end' within a window of bp from the end.
    Slide 0..window and compute mismatches; return the best (lowest) mm and its offset.
    'ok' if mm <= ceil(err*len(primer)) and aligned length >= overlap.
    Returns: (mm, ok, offset)
    """
    seq = seq.upper().replace("U","T")
    Lp = len(primer)
    tol = math.ceil(Lp * err)

    if near == "start":
        region = seq[:max(Lp+window, Lp)]
        best_mm, best_off = 10**9, None
        for off in range(0, min(window+1, max(1, len(region)-Lp+1))):
            chunk = region[off:off+Lp]
            mm = iupac_mismatches(primer, chunk)
            if mm < best_mm:
                best_mm, best_off = mm, off
        ok = (best_mm <= tol) and (Lp >= overlap)
        return best_mm, ok, (best_off if best_off is not None else -1)

    elif near == "end":
        region = seq[-max(Lp+window, Lp):] if len(seq) >= Lp else seq
        best_mm, best_off = 10**9, None
        # offset measured from the end side (0 means perfectly flush at end)
        # we iterate starting positions within region and convert to "distance to end"
        for start in range(0, max(1, len(region)-Lp+1)):
            chunk = region[start:start+Lp]
            mm = iupac_mismatches(primer, chunk)
            off_from_end = max(0, (len(region)-(start+Lp)))
            if mm < best_mm:
                best_mm, best_off = mm, off_from_end
        ok = (best_mm <= tol) and (Lp >= overlap)
        return best_mm, ok, (best_off if best_off is not None else -1)

    else:
        raise ValueError("near must be 'start' or 'end'")

def score_pair(seq:str, fwd:str, rev:str, err=0.25, window=80, overlap=10):
    """
    Score a pair on both strands; choose strand with lower total mismatches.
    Returns dict with: strand ('+' or '-'), f_mm, r_mm, f_ok, r_ok, f_off, r_off, total_mm.
    For the reverse strand, we test on rc(seq) with the same logic.
    """
    def _one(s):
        f_mm,f_ok,f_off = best_end_match(s, fwd, near="start", window=window, err=err, overlap=overlap)
        r_mm,r_ok,r_off = best_end_match(s, rev, near="end",   window=window, err=err, overlap=overlap)
        return f_mm, r_mm, f_ok, r_ok, f_off, r_off, f_mm+r_mm

    f1, r1, fok1, rok1, offF1, offR1, tot1 = _one(seq)
    rseq = rc(seq)
    f2, r2, fok2, rok2, offF2, offR2, tot2 = _one(rseq)

    if tot2 < tot1:
        return {"strand":"-","f_mm":f2,"r_mm":r2,"f_ok":fok2,"r_ok":rok2,"f_off":offF2,"r_off":offR2,"total_mm":tot2}
    else:
        return {"strand":"+","f_mm":f1,"r_mm":r1,"f_ok":fok1,"r_ok":rok1,"f_off":offF1,"r_off":offR1,"total_mm":tot1}

def classify_sequence(seq:str):
    pf, pr = PRIMERS["POMC_F"], PRIMERS["POMC_R"]
    rf, rr = PRIMERS["RHOD_F"], PRIMERS["RHOD_R"]

    pomc = score_pair(seq, pf, pr, err=0.25, window=80, overlap=10)
    rhod = score_pair(seq, rf, rr, err=0.25, window=80, overlap=10)

    pomc_ok = pomc["f_ok"] and pomc["r_ok"]
    rhod_ok = rhod["f_ok"] and rhod["r_ok"]

    if pomc_ok and not rhod_ok:
        call = "POMC"
    elif rhod_ok and not pomc_ok:
        call = "Rhod1"
    else:
        # choose lower total mismatches; tie -> undetermined
        if pomc["total_mm"] < rhod["total_mm"]:
            call = "POMC"
        elif rhod["total_mm"] < pomc["total_mm"]:
            call = "Rhod1"
        else:
            call = "undetermined"

    return {
        "call": call,
        "POMC_score": pomc["total_mm"],
        "Rhod1_score": rhod["total_mm"],
        "P_strand": pomc["strand"], "R_strand": rhod["strand"],
        "pf_ok": pomc["f_ok"], "pr_ok": pomc["r_ok"],
        "rf_ok": rhod["f_ok"], "rr_ok": rhod["r_ok"],
        "pf_mm": pomc["f_mm"], "pr_mm": pomc["r_mm"],
        "rf_mm": rhod["f_mm"], "rr_mm": rhod["r_mm"],
        "pf_off": pomc["f_off"], "pr_off": pomc["r_off"],
        "rf_off": rhod["f_off"], "rr_off": rhod["r_off"],
    }

def read_ab1_sequence(path:Path):
    rec = SeqIO.read(str(path), "abi")
    return str(rec.seq).upper().replace("U","T")

def main():
    ap = argparse.ArgumentParser(description="Classify AB1 as POMC vs Rhod1 via primer matches (handles reverse strand; end windows).")
    ap.add_argument("ab1_dir", nargs="?", default=".", help="Directory with .ab1 files")
    ap.add_argument("--apply", action="store_true", help="Rename filenames if detected marker disagrees with name (POMC <-> Rhod1)")
    args = ap.parse_args()

    ab1_paths = [Path(root)/fn
                 for root,_,files in os.walk(args.ab1_dir)
                 for fn in files if fn.lower().endswith(".ab1")]
    if not ab1_paths:
        print("No .ab1 files found.", file=sys.stderr); return

    rep = f"primer_classify_{Path(args.ab1_dir).name}_{os.getpid()}.tsv"
    with open(rep, "w") as w:
        print("file\tcall\tPOMC_score\tRhod1_score\tP_strand\tR_strand\tpf_ok\tpr_ok\trf_ok\trr_ok\tpf_mm\tpr_mm\trf_mm\trr_mm\tpf_off\tpr_off\trf_off\trr_off\taction", file=w)
        for p in ab1_paths:
            action = "none"
            try:
                seq = read_ab1_sequence(p)
            except Exception as e:
                print(f"{p.name}\tNA\t.\t.\t.\t.\t.\t.\t.\t.\t.\t.\t.\t.\t.\t.\t.\t.\tskip(read_failed:{e.__class__.__name__})", file=w)
                continue

            res = classify_sequence(seq)
            call = res["call"]

            if args.apply and call in ("POMC","Rhod1"):
                base = p.name
                if "POMC" in base and call == "Rhod1":
                    new = base.replace("POMC","Rhod1")
                    p.rename(p.with_name(new)); action = f"rename:{new}"
                elif "Rhod1" in base and call == "POMC":
                    new = base.replace("Rhod1","POMC")
                    p.rename(p.with_name(new)); action = f"rename:{new}"

            print("{name}\t{call}\t{ps}\t{rs}\t{pstr}\t{rstr}\t{pf}\t{pr}\t{rf}\t{rr}\t{pfm}\t{prm}\t{rfm}\t{rrm}\t{pfo}\t{pro}\t{rfo}\t{rro}\t{act}".format(
                name=p.name, call=call,
                ps=res["POMC_score"], rs=res["Rhod1_score"],
                pstr=res["P_strand"], rstr=res["R_strand"],
                pf=int(res["pf_ok"]), pr=int(res["pr_ok"]), rf=int(res["rf_ok"]), rr=int(res["rr_ok"]),
                pfm=res["pf_mm"], prm=res["pr_mm"], rfm=res["rf_mm"], rrm=res["rr_mm"],
                pfo=res["pf_off"], pro=res["pr_off"], rfo=res["rf_off"], rro=res["rr_off"],
                act=action
            ), file=w)

    print(f"Done. Report: {rep}")

if __name__ == "__main__":
    main()