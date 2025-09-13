#!/usr/bin/env sh
set -euf

# Require ripgrep
if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) not found. Install with: brew install ripgrep"
  exit 1
fi

REPO_ROOT="$(pwd)"
OUT="$REPO_ROOT"
LOG="$REPO_ROOT/results/AUDIT_LOG.txt"
MAN="$REPO_ROOT/results/AUDIT_MANIFEST.tsv"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p results figures/{gnuplot,exports} data/processed sim/{inputs,params,topology,jobs} scripts/{plotting,analysis}

echo "=== AUDIT START $TS ===" | tee "$LOG"
echo "path	sha256" > "$MAN"

# Scope: default only this repo. To broaden later:
#   SEARCH_ROOTS="$HOME/Desktop $HOME/Documents $PWD" sh tools/audit_collect.sh
SEARCH_ROOTS="${SEARCH_ROOTS:-$REPO_ROOT}"

copy_strip () {
  src="$1"; dst="$2"
  mkdir -p "$(dirname "$dst")"
  # copy
  rsync -a "$src" "$dst" 2>>"$LOG" || cp -p "$src" "$dst"
  # strip comments (keeps .orig beside)
  if command -v python3 >/dev/null 2>&1; then
    python3 "$REPO_ROOT/tools/strip_comments.py" "$dst" 2>>"$LOG" || true
  fi
  # checksum
  if command -v shasum >/dev/null 2>&1; then
    sum="$(shasum -a 256 "$dst" | awk '{print $1}')"
  else
    sum="$(md5 -q "$dst" 2>/dev/null || echo NA)"
  fi
  printf "%s\t%s\n" "${dst#$REPO_ROOT/}" "$sum" >> "$MAN"
  echo "OK  $dst" >> "$LOG"
}

# Helper: run ripgrep and stream NUL-delimited results through a loop
rg_list () {
  # args: pattern(s)
  # shellcheck disable=SC2068
  rg -0 -n --no-messages -S -l $@ $SEARCH_ROOTS 2>/dev/null || true
}

# 1) Gnuplot & plotting scripts + figure assets
rg_list '\.(gnu|gp|gpl)$' 'signature_vectors\.csv' 'fig.*\.(png|svg)$' | \
while IFS= read -r -d '' f; do
  case "$f" in
    *.gnu|*.gp|*.gpl)    dst="figures/gnuplot/$(basename "$f")" ;;
    *.png|*.svg)         dst="figures/exports/$(basename "$f")" ;;
    *.csv|*.tsv|*.dat)   dst="data/processed/$(basename "$f")" ;;
    *)                   dst="scripts/plotting/$(basename "$f")" ;;
  esac
  copy_strip "$f" "$OUT/$dst"
done

# 2) Data files used in analysis
rg_list '\.(csv|tsv|dat|json)$' 'signature_vectors\.csv|dn[_-]?dv|rdf|spearman|box.*whisker|heatmap' | \
while IFS= read -r -d '' f; do
  copy_strip "$f" "$OUT/data/processed/$(basename "$f")"
done

# 3) Simulation inputs/topology/params/jobs
rg_list 'cnt[135]|spermine|spermidine|putrescine|ethylamine|kcl|ions|water|gromacs|lammps' '\.(pdb|gro|top|itp|prm|psf|rtp|ndx|mdp|in|slurm|sbatch|sh)$' | \
while IFS= read -r -d '' f; do
  case "$f" in
    *.pdb|*.gro) sub="inputs" ;;
    *.top|*.itp|*.prm|*.psf|*.rtp|*.ndx) sub="topology" ;;
    *.mdp|*.in)  sub="params" ;;
    *.slurm|*.sbatch|*run_*.sh|*.sh) sub="jobs" ;;
    *) sub="inputs" ;;
  esac
  copy_strip "$f" "$OUT/sim/$sub/$(basename "$f")"
done

echo "=== AUDIT COMPLETE ===" | tee -a "$LOG"
echo "Manifest: $MAN" | tee -a "$LOG"
