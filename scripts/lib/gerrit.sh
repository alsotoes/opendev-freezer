#!/usr/bin/env bash
# lib/gerrit.sh — shared OpenDev Gerrit REST helpers for the umbrella scripts.
# Read-only against review.opendev.org; never pushes, never mutates submodules.
# Source with: . "$ROOT/scripts/lib/gerrit.sh"
set -uo pipefail

GERRIT_BASE="https://review.opendev.org"
REPO_NAME_MAP="freezer openstack/freezer
freezer-api openstack/freezer-api
web-ui openstack/freezer-web-ui
client openstack/python-freezerclient"

gerrit_url_for() { # <repo-short> -> opendev project name
  printf '%s\n' "$REPO_NAME_MAP" | awk -v n="$1" '$1==n {print $2; exit}'
}

# gerrit_get <api-path> — curl a Gerrit REST endpoint, strip the magic `)]}'`
# prefix used to thwart XSSI, print raw JSON. Callers pipe to python for parsing.
gerrit_get() {
  curl -fsSL -H 'Accept: application/json' "$GERRIT_BASE/$1" | tail -n +2
}

# gerrit_json <api-path> — JSON with the prefix stripped, pretty-printed.
gerrit_json() {
  gerrit_get "$1" | python3 -m json.tool
}