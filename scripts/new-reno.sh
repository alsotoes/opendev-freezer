#!/usr/bin/env bash
# new-reno.sh <repo> <slug> — scaffold an Oslo reno release note for a submodule
# WITHOUT touching its tracked files directly: writes the note file under the
# submodule's releasenotes/notes/. Prefers `reno new` when available (adds the
# hash suffix + registers in reno cache); otherwise writes an equivalent stub.
# Root-side driver only; the note is product content for the human to review.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DEFS="freezer code/freezer
freezer-api code/freezer-api
web-ui code/freezer-web-ui
client code/python-freezerclient"

repo="${1:?usage: new-reno.sh <repo> <slug>}"
slug="${2:?usage: new-reno.sh <repo> <slug>}"

dir="$(printf '%s\n' "$REPO_DEFS" | awk -v n="$repo" '$1==n {print $2; exit}')"
[ -n "$dir" ] || { echo "new-reno: unknown repo '$repo'" >&2; exit 2; }
notes="$ROOT/$dir/releasenotes/notes"
[ -d "$notes" ] || { echo "new-reno: no releasenotes/notes in $dir" >&2; exit 3; }

if command -v reno >/dev/null 2>&1; then
  (cd "$ROOT/$dir" && reno new "$slug")
else
  if [ ! -f "$ROOT/$dir/releasenotes/source/index.rst" ]; then
    echo "new-reno: NOTE $dir has no releasenotes/source/index.rst (web-ui); add it or run \`reno\` to register." >&2
  fi
  hash="$(openssl rand -hex 8 2>/dev/null || printf '%016x' "$RANDOM$RANDOM$RANDOM$RANDOM")"
  f="$notes/$slug-$hash.yaml"
  cat > "$f" <<EOF
---
features:
  - |
    <one-line feature summary here>
EOF
  echo "new-reno: wrote $f (stub; review + fill text)"
fi