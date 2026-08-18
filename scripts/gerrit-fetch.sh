#!/usr/bin/env bash
# gerrit-fetch.sh <change-id> — fetch an OpenDev Gerrit change (JSON + human
# summary) for the Freezer umbrella study area. Read-only against Gerrit;
# writes an analysis artifact to reviews/<change-id>.json (root-side only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CID="${1:?usage: gerrit-fetch.sh <change-id|number>}"
BASE="https://review.opendev.org"
OUT="$ROOT/reviews"; mkdir -p "$OUT"

tmp="$(mktemp)"  # JSON before Gerrit's magic-prefix strip
curl -fsSL -H 'Accept: application/json' "$BASE/changes/$CID?o=CURRENT_REVISION&o=CURRENT_COMMIT&o=MESSAGES" -o "$tmp"

python3 - "$tmp" "$OUT/$CID.json" <<'PY'
import json, sys
raw, out = sys.argv[1], sys.argv[2]
data = json.load(open(raw)) if not open(raw).read().lstrip().startswith(")]}'") else json.loads(open(raw).read()[4:])
open(out, "w").write(json.dumps(data, indent=2))
print(f"Change: {data.get('subject','')}  [{data.get('status','?')}]")
print(f"  project: {data.get('project','?')}  branch: {data.get('branch','?')}")
print(f"  ref: {data.get('refs','?')}  updates: {data.get('updated','?')}")
rev = (data.get('revisions') or {})
for patchset, meta in reversed(list(rev.items())):
    print(f"  patchset:  {meta.get('_number','?')}  {meta.get('ref','?')}")
msgs = data.get('messages') or []
print(f"\n  messages ({len(msgs)}):")
for m in msgs:
    author = (m.get('author') or {}).get('name', m.get('author', {}).get('username','?'))
    print(f"   - [{m.get('date','?')}] {author}: {m.get('message','').strip()[:200]}")
print(f"\nSaved: {out}")
PY