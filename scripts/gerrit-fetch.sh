#!/usr/bin/env bash
# gerrit-fetch.sh <change-id> — fetch an OpenDev Gerrit change (JSON + human
# summary) for the Freezer umbrella study area. Read-only against Gerrit;
# writes an analysis artifact to reviews/<change-id>.json (root-side only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/gerrit.sh"

CID="${1:?usage: gerrit-fetch.sh <change-id|number>}"
OUT="$ROOT/reviews"; mkdir -p "$OUT"

tmp="$(mktemp)"
gerrit_get "changes/$CID?o=CURRENT_REVISION&o=CURRENT_COMMIT&o=MESSAGES&o=DETAILED_ACCOUNTS" > "$tmp"
python3 - "$tmp" "$OUT/$CID.json" <<'PY'
import json, sys
raw = open(sys.argv[1]).read()
data = json.loads(raw)
open(sys.argv[2], "w").write(json.dumps(data, indent=2))
print(f"Change: {data.get('subject','')}  [{data.get('status','?')}]")
print(f"  project: {data.get('project','?')}  branch: {data.get('branch','?')}")
print(f"  updates: {data.get('updated','?')}")
rev = (data.get('revisions') or {})
for patchset, meta in sorted(rev.items(), key=lambda kv: (kv[1].get('_number',0))):
    print(f"  patchset:  {meta.get('_number','?')}  {meta.get('ref','?')}")
msgs = data.get('messages') or []
print(f"\n  messages ({len(msgs)}):")
for m in msgs:
    a = m.get('author') or {}
    author = a.get('name') or a.get('username') or '?'
    print(f"   - [{m.get('date','?')}] {author}: {m.get('message','').strip()[:200]}")
print(f"\nSaved: {sys.argv[2]}")
PY
rm -f "$tmp"