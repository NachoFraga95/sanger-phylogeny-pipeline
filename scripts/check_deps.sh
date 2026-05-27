#!/usr/bin/env bash
set -Eeuo pipefail
ok=1
for x in python3 mafft zip awk sed grep tr dos2unix; do
  command -v "$x" >/dev/null || { echo "MISSING: $x"; ok=0; }
done
python3 - <<'PY' || { echo "Python missing BioPython"; exit 1; }
try:
    import Bio
except Exception as e:
    raise SystemExit("BioPython not importable: %s" % e)
print("BioPython OK")
PY
[[ $ok -eq 1 ]] && echo "All CLI deps OK" || { echo "Install missing deps and re-run"; exit 1; }
