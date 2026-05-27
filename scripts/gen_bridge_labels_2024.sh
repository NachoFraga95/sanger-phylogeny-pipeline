#!/usr/bin/env bash
set -Eeuo pipefail
in="${1:-$HOME/compartida_ubuntu/sanger-arboles/project/meta/samples_2024_clean.csv}"
out="${2:-$HOME/compartida_ubuntu/sanger-arboles/project/2024_raw_ab1/bridge_labels_2024.tsv}"

tmp=$(mktemp)
tr -d '\r' < "$in" | sed -e $'s/\t/,/g' -e 's/;/,/g' > "$tmp"

awk -F',' 'NR>1{
  num=$1; code=$3
  gsub(/"/,"",code); gsub(/[[:space:]]/,"",code)
  pre=code; sub(/[0-9]{2,}$/, "", pre)
  if (match(pre, /(.+[^0-9])([0-9]{2})([A-Za-z]?)$/, m)) {
    core=m[1]; nn=m[2]; let=m[3]
    base=core; sub(/[a-z]{2}$/, "", base)
    cand[0]=core nn;      cand[1]=core "." nn
    cand[2]=base nn;      cand[3]=base "." nn
    if (let!=""){ cand[4]=core nn let; cand[5]=core "." nn let; cand[6]=base nn let; cand[7]=base "." nn let }
    for(i=0;i<8;i++) if(cand[i]!="") printf "%s\t%02d\n", cand[i], num
    delete cand
  }
}' "$tmp" | awk '!seen[$0]++' > "$out"

rm -f "$tmp"
echo "bridge map => $out"
head -20 "$out"
