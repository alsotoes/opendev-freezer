---
name: gerrit-change-analysis
description: Analyze OpenStack Freezer Gerrit reviews on review.opendev.org. Use when reviewing a commit or change, answering review comments, mapping a launched feature or bugfix to its review, or summarizing review outcomes. Covers the REST API, votes/bots/patchsets semantics, and the verdict template.
---

## Where things live

- Gerrit host: `review.opendev.org` (project refs in each submodule's `.gitreview`,
  SSH port 29418). CI is Zuul (`.zuul.yaml` per repo).
- A commit embeds `Change-Id: Ic...` — search/fetch the change by that id.

## Fetching a change (REST API)

```bash
# list / fetch a change (open endpoints work unauthenticated)
curl -s https://review.opendev.org/changes/<change-id>?o=CURRENT_REVISION -H 'Accept: application/json' | sed '1d' | python3 -m json.tool

# inline comments for a revision
curl -s https://review.opendev.org/changes/<change-id>/revisions/<rev>/comments -H 'Accept: application/json' | sed '1d' | python3 -m json.tool

# apply a specific patchset as a fetch into the local submodule (read-only inspection)
git -C code/<repo> fetch https://opendev.org/openstack/<repo> refs/changes/<NN>/<change>/<ps>
git -C code/<repo> show FETCH_HEAD
```

## Reading the conversation

- **Bots** (`openstack-ci`, `zuul`, `no-op`): -1 = failed check/gate job, +1 =
  verified. A `recheck` comment = operator asked Zuul to retry (often flaky).
- **Human votes**: `CRVW +2` = core approved; `-1` = blocking concern; `JFYI`
  comments are informational.
- **Patch-set N progression**: reworked responses to review feedback — diff
  consecutive patchsets to see the review-driven change.
- **Gate jobs**: `openstack-tox-pep8` (pycodestyle 2.5.0 pinned), `openstack-tox-pylint`,
  devstack jobs pulling all freezer repos together, horizon jobs for the UI.

## Verdict template (store in docs/lessons-learned.md)

```
change-id: <Ic...>
title: <...>
repo: <freezer | freezer-api | freezer-web-ui | python-freezerclient>
patchsets: <N>
votes: <+2/-1 summary>
gate: <PASS/FAIL + job names>
review themes: <bullets>
outcome: <merged | abandoned | open>
```

## Tips

- Cross-repo changes span 2+ repos — pull the sibling commits too.
- Pair the change with its reno release note
  (`releasenotes/notes/*.yaml`) and launchpad bug ref to confirm intent.
- Prefer analyzing upstream `master` state in the submodule for "current truth";
  use fetched patchsets only to inspect a specific iteration.