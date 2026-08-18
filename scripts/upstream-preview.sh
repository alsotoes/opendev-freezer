#!/usr/bin/env bash
# upstream-preview.sh <repo> <ref> — analyze a pending (or published) upstream
# OpenStack Freezer change WITHOUT touching the code/ submodules.
#
# Strategy: sideload a bare mirror of each upstream repo under .upstream/
# (gitignored), fetch the requested Gerrit ref or Change-Id into it, then diff
# the mirror ref against the umbrella's pinned submodule HEAD.
#
# <ref> forms: numeric Gerrit change id, `refs/changes/NN/<id>/<ps>`, or a
# Change-Id (`I<40-hex>`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/gerrit.sh"

repo="${1:?usage: upstream-preview.sh <repo> <ref|change-id|Change-Id> [--light]}"
ref="${2:?usage: upstream-preview.sh <repo> <ref|change-id|Change-Id> [--light]}"
LIGHT=0; [ "${3:-}" = "--light" ] && LIGHT=1

proj="$(gerrit_url_for "$repo")"
[ -n "$proj" ] || { echo "preview: unknown repo '$repo'" >&2; exit 2; }

url="https://opendev.org/$proj"
pin="$(cd "$ROOT/code/$repo" && git rev-parse HEAD 2>/dev/null || echo '?')"
[ "$pin" != '?' ] || { echo "preview: no pin for $repo (submodule missing?)" >&2; exit 3; }

mirror="$ROOT/.upstream/${repo}.git"
mkdir -p "$ROOT/.upstream"
if [ ! -d "$mirror" ]; then
  echo "preview: bootstrapping bare mirror $mirror ..."
  extra=(); [ "$LIGHT" -eq 1 ] && extra=(--filter=blob:none)
  git clone --bare --quiet "${extra[@]}" "$url" "$mirror"
else
  git -C "$mirror" fetch --quiet origin '+refs/heads/*:refs/heads/*' '+refs/changes/*:refs/changes/*' 2>/dev/null || true
fi

case "$ref" in
  refs/changes/*) target="$ref" ;;
  I[0-9a-fA-F]*|*[0-9]*)
    num="$ref"
    case "$ref" in
      I*) num="$(gerrit_get "changes/?q=change:$ref&n=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d[0]["_number"] if d else "")')" ;;
    esac
    [ -n "$num" ] || { echo "preview: change not found" >&2; exit 4; }
    gdir="$(printf '%02d' $((10#$num % 100)))"
    cur="$(gerrit_get "changes/$num?o=CURRENT_REVISION" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("revisions",{}); m=max(r.values(), key=lambda k: k["_number"]) if r else None; print(m.get("ref","") if m else "")')"
    [ -n "$cur" ] || { echo "preview: change $num not found" >&2; exit 4; }
    target="$cur"
    echo "preview: resolving to current patchset of change $num -> $target"
    ;;
  *) echo "preview: unrecognized ref '$ref'" >&2; exit 2 ;;
esac

git -C "$mirror" fetch --quiet --no-tags origin "$target:refs/preview/target"
remote="$(git -C "$mirror" rev-parse refs/preview/target)"

echo "== $proj =="
echo "  pin:      $(echo "$pin" | cut -c1-12)  (submodule HEAD)"
echo "  preview:  $(echo "$remote" | cut -c1-12)  ($target)"
echo
git -C "$mirror" log --oneline -1 refs/preview/target
echo
echo "== diff vs current pin (stat) =="
git -C "$mirror" diff --stat "$pin" "$remote" -- . ':!releasenotes' | tail -25
echo
echo "== release notes touched =="
git -C "$mirror" diff --name-only "$pin" "$remote" -- releasenotes/
echo
echo "== message =="
git -C "$mirror" show -s --format='%s%n%b' refs/preview/target | sed -n '1,12p'