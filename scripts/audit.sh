#!/usr/bin/env bash
# audit.sh [--quick] — Freezer umbrella readiness report.
#
# Offline-friendly consistency checks. Each check reports PASS/FAIL; the
# script exits nonzero if any check fails. Purely read-only: never writes
# into code/ submodules, never pushes.
#
# --quick: skips submodule checks (used by the umbrella pre-commit hook, so a
# root commit is never blocked by in-flight submodule work).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUICK=0; [ "${1:-}" = "--quick" ] && QUICK=1
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
check "config-reference.md mirrors config.yaml sections" python3 - "$ROOT" <<'PY'
import re, sys
root = sys.argv[1]
cfg = open(f"{root}/openspec/config.yaml").read()
ref = open(f"{root}/docs/config-reference.md").read()
sects = re.findall(r'^  # ([A-Z][A-Z &\'\-]+) —', cfg, re.M)
missing = [s for s in sects if s not in ref]
raise SystemExit(0 if not missing else 1)
PY

if [ "$QUICK" -eq 1 ]; then
  echo "== result (quick — submodule checks skipped) =="
  if [ "$FAIL" -eq 0 ]; then echo "  ALL QUICK CHECKS PASSED"; else echo "  $FAIL CHECK(S) FAILED" >&2; exit 1; fi
  exit 0
fi

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