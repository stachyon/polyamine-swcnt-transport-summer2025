#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-polyamine-swcnt-transport-summer2025}"
ROOT="${PWD}"
OUT="$ROOT/$REPO"
MAN="$OUT/results/AUDIT_MANIFEST.tsv"
LOG="$OUT/results/AUDIT_LOG.txt"
mkdir -p "$OUT/results"

echo -e "REL_PATH\tORIG_ABS\tBYTES\tSHA256" > "$MAN"

sha() { shasum -a 256 "$1" | awk '{print $1}'; }

copy_strip() {
  src="$1"; dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
  "$OUT/tools/strip_comments.py" "$dest" || true
  printf "%s\t%s\t%s\t%s\n" \
    "$(realpath --relative-to="$OUT" "$dest" 2>/dev/null || python3 - <<PY
import os,sys;print(os.path.relpath("$dest","$OUT"))
PY
)" \
    "$(realpath "$src" 2>/dev/null || python3 - <<PY
import os,sys;print(os.path.abspath("$src"))
PY
)" \
    "$(stat -f %z "$dest" 2>/dev/null || stat -c %s "$dest")" \
    "$(sha "$dest")" >> "$MAN"
}

# 1) Gnuplot & plotting scripts
mapfile -t GP < <(rg -i -g '!'"$REPO"'/**' -n --no-messages -S -t \
    -e 'set term.*pngcairo|set multiplot|plot .* using' -e '\.gnu$|\.gp$|\.gpl$' \
    -l / 2>/dev/null || true)
for f in "${GP[@]}"; do copy_strip "$f" "$OUT/figures/gnuplot/$(basename "$f")"; done

# 2) CSV/processed data used in figures
mapfile -t CSV < <(rg -i -g '!'"$REPO"'/**' -n --no-messages -S \
    -e 'signature_vectors\.csv|occ_summary.*\.csv|dndv.*\.csv|spearman.*\.csv|heatmap.*\.csv' \
    -l / 2>/dev/null || true)
for f in "${CSV[@]}"; do copy_strip "$f" "$OUT/data/processed/$(basename "$f")"; done

# 3) RDF outputs
mapfile -t RDF < <(rg -i -g '!'"$REPO"'/**' -n --no-messages -S \
    -e 'rdf.*\.(dat|xvg)$' -l / 2>/dev/null || true)
for f in "${RDF[@]}"; do copy_strip "$f" "$OUT/data/processed/rdf/$(basename "$f")"; done

# 4) Analysis scripts (py/R/sh)
mapfile -t ANA < <(rg -i -g '!'"$REPO"'/**' -n --no-messages -S \
    -e 'spearman|glm|valence|box.*whisker|residence|r_over_R|occ|dndv' \
    -e '\.py$|\.R$|\.r$|\.sh$|\.bash$' -l / 2>/dev/null || true)
for f in "${ANA[@]}"; do copy_strip "$f" "$OUT/scripts/analysis/$(basename "$f")"; done

# 5) Simulation inputs/params/topology/jobs
mapfile -t SIM < <(rg -i -g '!'"$REPO"'/**' -n --no-messages -S \
    -e 'cnt[135]|spermine|spermidine|putrescine|ethylamine|kcl|ions|water|gromacs|lammps' \
    -e '\.pdb$|\.gro$|\.top$|\.itp$|\.prm$|\.psf$|\.rtp$|\.ndx$|\.mdp$|\.in$|\.slurm$|\.sbatch$|\.sh$' \
    -l / 2>/dev/null || true)
for f in "${SIM[@]}"; do
  case "$f" in
    *.pdb|*.gro) sub="inputs" ;;
    *.top|*.itp|*.prm|*.psf|*.rtp|*.ndx) sub="topology" ;;
    *.mdp|*.in)  sub="params" ;;
    *.slurm|*.sbatch|*run_*.sh) sub="jobs" ;;
    *) sub="inputs" ;;
  esac
  copy_strip "$f" "$OUT/sim/$sub/$(basename "$f")"
done

# 6) Figure exports (optional grab)
mapfile -t PNG < <(rg -i -g '!'"$REPO"'/**' -n --no-messages -S \
    -e 'fig.*\.(png|svg)$' -l / 2>/dev/null || true)
for f in "${PNG[@]}"; do copy_strip "$f" "$OUT/figures/exports/$(basename "$f")"; done

echo "=== AUDIT COMPLETE ===" | tee -a "$LOG"
echo "Manifest: $MAN" | tee -a "$LOG"
