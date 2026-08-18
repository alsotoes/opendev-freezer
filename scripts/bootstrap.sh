#!/usr/bin/env bash
# bootstrap.sh — per-submodule venv setup for the Freezer umbrella.
#
# Creates a venv INSIDE each code/ submodule (mandated by PROJECT STEERING
# RULES: never run tools from the umbrella root), installs the repo's
# requirements + test-requirements (CI-pinned linters), sets up pre-commit,
# and reports git-review readiness. Root-only operation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOS="freezer freezer-api freezer-web-ui python-freezerclient"
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

for repo in $REPOS; do
  dir="$ROOT/code/$repo"
  echo "=== $repo ==="
  [ -d "$dir" ] || { echo "  skip: missing $dir"; continue; }
  # Local (untracked) exclude so .venv never dirties a submodule; works even
  # where the upstream repo has no handler in its own .gitignore.
  exclude="$dir/.git/info/exclude"
  [ -f "$exclude" ] && grep -qxF '.venv/' "$exclude" || printf '\n# per-builder venv (umbrella bootstrap.sh)\n.venv/\n' >> "$exclude"
  if [ ! -x "$dir/.venv/bin/python" ]; then
    python3 -m venv "$dir/.venv"
    "$dir/.venv/bin/pip" install --quiet --upgrade pip
  else
    echo "  venv present"
  fi
  if [ "$QUICK" -eq 1 ]; then
    echo "  (quick: venv only)"
    continue
  fi
  # shellcheck disable=SC1090
  source "$dir/.venv/bin/activate"
  cd "$dir"
  pip install --quiet -r requirements.txt -r test-requirements.txt
  pip install --quiet tox pre-commit
  if [ -f .pre-commit-config.yaml ]; then
    pre-commit install
  fi
  echo "  deps + pre-commit ready"
  cd "$ROOT"
done

printf '\nDone. Verify with:  scripts/audit.sh\n'
printf 'git-review availability: %s\n' "$(command -v git-review || echo 'MISSING (install for human pushes)')"