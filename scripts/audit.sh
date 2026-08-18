#!/usr/bin/env bash
# audit.sh — Freezer umbrella readiness report.
#
# Offline-friendly consistency checks. Each check reports PASS/FAIL; the
# script exits nonzero if any check fails. Purely read-only: never writes
# into code/ submodules, never pushes.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; FAIL=1; }

check() { # check <name> <cmd...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}

echo "== config.yaml =="
check "config.yaml parses as YAML" python3 -c "import yaml; yaml.safe_load(open('$ROOT/openspec/config.yaml'))"
check "expected context sections present" python3 - "$ROOT" <<'PY'
import sys, yaml
sections = ["REPOSITORY MAP","COMPONENT MAP","DATA FLOW","FEATURE PLACEMENT",
            "ONE-OFF ANALYSIS","GERRIT REVIEW ANALYSIS","AGENT & CLIENT USAGE",
            "PROJECT STEERING RULES"]
d = yaml.safe_load(open(sys.argv[1] + "/openspec/config.yaml"))
ctx = d.get("context", "")
raise SystemExit(0 if all(s in ctx for s in sections) else 1)
PY

echo "== docs sync =="
check "no stale 'openspec/docs' references" bash -c "! grep -rn 'openspec/docs' '$ROOT' --include='*.md' --include='*.yaml' --include='AGENTS.md' | grep -v '.git/'"
check "README lists all docs/ files" python3 - "$ROOT" <<'PY'
import os, sys
root = sys.argv[1]
docs = sorted(os.listdir(os.path.join(root, "docs")))
readme = open(os.path.join(root, "README.md")).read()
missing = [d for d in docs if d not in readme]
raise SystemExit(0 if not missing else 1)
PY

echo "== submodules =="
while read -r _name path; do
  [ -z "$path" ] && continue
  if [ -d "$ROOT/$path/.git" ] || [ -f "$ROOT/$path/.git" ]; then
    if [ -z "$(cd "$ROOT/$path" && git status --porcelain 2>/dev/null)" ]; then
      pass "submodule $path clean"
    else
      fail "submodule $path has uncommitted changes"
    fi
  else
    fail "submodule $path not initialized"
  fi
done <<< "x code/freezer
x code/freezer-api
x code/freezer-web-ui
x code/python-freezerclient"

check ".gitmodules paths/URLs parse" python3 - "$ROOT" <<'PY'
import configparser, sys, os
root = sys.argv[1]
c = configparser.ConfigParser(); c.read(os.path.join(root, ".gitmodules"))
for s in c.sections():
    if not os.path.isdir(os.path.join(root, c.get(s, "path"))):
        raise SystemExit(1)
PY

echo "== skills =="
check "agent skills present at root" bash -c "ls '$ROOT/.agents/skills/'*/SKILL.md >/dev/null 2>&1"
check "skills-lock.json parses" python3 -c "import json; json.load(open('$ROOT/skills-lock.json'))"

echo "== result =="
if [ "$FAIL" -eq 0 ]; then
  echo "  ALL CHECKS PASSED"
else
  echo "  $FAIL CHECK(S) FAILED" >&2
  exit 1
fi