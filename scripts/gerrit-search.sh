#!/usr/bin/env bash
# gerrit-search.sh ["query"] — compact table of OpenDev Gerrit changes across
# the four Freezer projects. Default: open changes touching any of them.
# Read-only; one row per change: # | ps | V | CR | WIP | status | project | subject.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/gerrit.sh"

q="${1:-project:openstack/freezer OR project:openstack/freezer-api OR project:openstack/freezer-web-ui OR project:openstack/python-freezerclient status:open}"
enc="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$q")"

printf '%-9s %-3s %-10s %-9s %-8s %-7s %-19s %s\n' "#change" "ps" "verified" "code-review" "workflow" "status" "project" "subject"
gerrit_get "changes/?q=$enc&n=50&o=LABELS&o=CURRENT_REVISION" | python3 -c '
import sys, json
for d in json.load(sys.stdin):
    n = d.get("_number")
    rs = d.get("revisions") or {}
    ps = max((r["_number"] for r in rs.values()), default=0)
    v = (d.get("labels") or {}).get("Verified", {}).get("value", "-")
    cr = (d.get("labels") or {}).get("Code-Review", {}).get("value", "-")
    wf = (d.get("labels") or {}).get("Workflow", {}).get("value", "-")
    proj = d.get("project", "?").replace("openstack/", "")
    print("{n:<9} {ps:<3} {v:<10} {cr:<9} {wf:<8} {st:<7} {proj:<19} {sub}".format(
        n=n, ps=ps, v=v, cr=cr, wf=wf,
        st=d.get("status", "?"), proj=proj, sub=d.get("subject", "?")[:58]))
'