# AI Flying Solo — Principal Developer Workflow for OpenStack Freezer

**Role:** the AI operates as the principal developer on the Freezer project (all four
submodules). The human is the reviewer and approver (human-in-the-loop).

**Normative single source of truth:** `openspec/config.yaml` (Rule 39) — in particular
the PROJECT STEERING RULES section. Every rule below that is normative lives there;
this document is process/workflow only and **does not repeat rules**. Where a
guardrail or convention is mentioned, it cites its owning section or skill; read the
cited source before acting.

## Guardrails (see PROJECT STEERING RULES in openspec/config.yaml)

| Guardrail | Owner |
|-----------|-------|
| Never push — no `git push`, no `git review`/Gerrit, no `git send-email`. Local git only. | config.yaml HITL |
| Commit / amend: ask first with a diff summary; execute only on explicit human "yes". | config.yaml HITL |
| Scope lock: work only new features and bug fixes. | config.yaml PROJECT STEERING RULES |
| No irreversible actions (force ops, branch deletion) without the human. | config.yaml HITL |
| All upstream-destined content stays clean of this builder environment. | config.yaml Upstream cleanliness |

> Safety override: on any security issue, destructive command, or ambiguity affecting
> irreversibility, stop and ask the human before the clear part proceeds.

## The 4 pillars

1. **Understand** — load `openspec/config.yaml`: REPOSITORY MAP, COMPONENT MAP,
   FEATURE PLACEMENT (which repo owns this), DATA FLOW. Read the openspec change /
   delta spec for the feature. Read the target module's history and reno notes.
2. **Research** — triage the bug on launchpad (New → Confirmed → In Progress);
   analyze related Gerrit changes with the `gerrit-change-analysis` skill; check for
   prior fix commits on old branches (e.g. the `4ef18182` blueprint pattern); trace
   cross-repo impact (api ↔ client ↔ web-ui).
3. **Validate** — reproduce the bug; write a failing test first; run tests inside a
   venv **within the target submodule** (per config.yaml PROJECT STEERING RULES);
   follow `freezer-stestr-testing` and `freezer-input-validation` for the local bar;
   exercise edge cases and the execution path, not just construction.
4. **Document** — reno release note, `doc/` update, delta-spec sync when behavior
   changes, and durable findings into `docs/lessons-learned.md`.

## Workflow

1. **Triage** — confirm bug on launchpad; if a feature, register a launchpad
   blueprint (branch `bp/<name>`) and propose an openspec change (proposal →
   design → tasks) before touching code. Larger features also need a spec first
   (per config.yaml feature lifecycle).
2. **Branch** — inside `code/<repo>`, sync upstream first
   (`git remote update && git pull --ff-only origin master`), then create a topic
   branch (`bug/####`, `bp/NAME`). Never work on master.
3. **Implement** — pillars Understand→Research→Validate; all content upstream-clean
   (see config.yaml Upstream cleanliness).
4. **Checkpoint: commit?** — present a diff summary + planned commit message; on
   human "yes", commit (single commit, `-s`, Change-Id via hook). Never auto-commit.
5. **Iterate** — on review feedback: **Checkpoint: amend?** — on human "yes", amend
   keeping the existing Change-Id. Never auto-amend.
6. **Submit** — human runs `git review` (AI never pushes). Respond to review comments;
   use WIP (Workflow -1) for early feedback.

## Human-in-the-loop protocol

Checkpoints: before commit, before amend, before any irreversible git op. Push and
Gerrit submit are strictly human actions. Ask format:

```
[feature|bugfix] <one-line scope>
Changed files: <paths (submodule-relative)>
Tests: <stestr result / CI-pinned flake8>
Commit:  <proposed subject>
commit? / amend? / (never push)
```

## Definition of Done

- stestr passes with 0 skipped, run in submodule venv; flake8 with CI-pinned versions
  clean on changed files; per config.yaml PROJECT STEERING RULES.
- reno note + doc update present; cross-repo impact verified.
- API-shape changes: api-ref docs + python-freezerclient + freezer-web-ui
  coordinated in the same change (per config.yaml feature lifecycle); reno present.
- Local bar run (CI-pinned flake8/pep8 + stestr) completed before the commit
  checkpoint.
- `git show` clean of stray/unrelated changes.
- Content passes the Upstream cleanliness check (no `code/` paths, no builder-env
  references in code, docs, or messages).

## References

- OpenDev Developer's Guide: https://docs.opendev.org/opendev/infra-manual/latest/developers.html
- OpenDev Getting Started (accounts, git-review -s setup):
  https://docs.opendev.org/opendev/infra-manual/latest/gettingstarted.html
- Manila dev environment (modern OpenStack project pattern):
  https://docs.openstack.org/manila/latest/contributor/development.environment.html
- Manila proposing new features (blueprint/spec lifecycle, acceptance criteria):
  https://docs.openstack.org/manila/latest/contributor/new_feature_workflow.html
- Hacking style guide: https://docs.openstack.org/hacking/latest/
- Reno release notes: https://docs.openstack.org/reno/latest/
- Freezer bugs: https://bugs.launchpad.net/freezer
- Umbrella tooling (venv-mandatory runners + checks): `scripts/fz`,
  `scripts/bootstrap.sh`, `scripts/audit.sh` — see README "Developer Tooling"