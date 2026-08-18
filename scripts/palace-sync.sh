#!/usr/bin/env bash
# palace-sync.sh — personal, on-demand only (NOT in CI). Mines this umbrella's
# durable knowledge (docs/, openspec/) into the MemPalace so hard-won verdicts,
# Gerrit outcomes, and steering decisions are searchable across sessions.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wing="${1:-opendev-freezer}"

if ! command -v mempalace >/dev/null 2>&1 && ! python3 -c 'import mempalace' 2>/dev/null; then
  echo "palace-sync: mempalace not installed (pip install mempalace) or run via the MCP add_drawer tools." >&2
  exit 1
fi

echo "palace-sync: mining docs/ + openspec/ into wing '$wing' ..."
python3 -m mempalace mine "$ROOT/docs" --mode projects --wing "$wing" \
  || python3 -m mempalace mine "$ROOT/docs" --wing "$wing" \
  || { echo "palace-sync: CLI differs — file via MCP add_drawer/checkpoint instead." >&2; exit 1; }
echo "palace-sync: done. Cross-check with the MCP mempalace search/query tools."