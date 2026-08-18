# OpenStack Freezer — Analysis & Spec-Driven Workbench

Umbrella study repository for the **OpenStack Freezer** project. This repo is not a
product: it bundles the four upstream Freezer repositories as git submodules so that
agents (openspec, Gemini, Cody, Kiro, antigravity, ...) and humans can analyze
commits, new features, bug fixes, component layout, and Gerrit reviews across the
whole project from one place.

License: Apache-2.0 (upstream OpenStack Freezer project)

## Submodules

All upstream code lives under `code/` (opendev.org, reviewed on Gerrit, CI via Zuul).

| Submodule | Component | Role |
|-----------|-----------|------|
| `code/freezer` | freezer-agent + freezer-scheduler | Runs on backup nodes: backup/restore engines, modes, snapshots, storage backends, scheduling daemon |
| `code/freezer-api` | REST API service | Stores metadata for clients, jobs, sessions, backups, actions (SQLAlchemy/MariaDB backend) |
| `code/freezer-web-ui` | Horizon dashboard plugin | Django panels/tables/workflows for managing Freezer via Horizon |
| `code/python-freezerclient` | CLI + Python bindings | `freezer` CLI, openstackclient plugin, library used by UI and scheduler |

## Documentation

Main project knowledge base:

| File | Contents |
|------|----------|
| `docs/config-reference.md` | Reference for `openspec/config.yaml` structure, per-artifact rules, operations guidance |
| `docs/workflow-guide.md` | OpenSpec propose → update → apply → archive workflow |
| `docs/ai_flying_solo.md` | AI-as-principal-developer operating procedure (HITL checkpoints, 4 pillars, DoD; references config.yaml) |
| `docs/test-documentation.md` | Test conventions and how to run them |
| `docs/lessons-learned.md` | Durable analysis findings, Gerrit verdicts, feature-placement corrections |

Source of truth for all steering rules and engineering standards:
[`openspec/config.yaml`](openspec/config.yaml) (see `context` block — "Project Steering
Rules", Rule 39). It contains the repository/component maps, data flow, feature
placement, commit/feature/bugfix analysis workflow, and Gerrit review analysis guide.

## Quick Start

```bash
# Clone with submodules (if not already available)
git submodule update --init --recursive

# Inspect a submodule
git -C code/freezer log --oneline -10
git -C code/freezer-api log -p -- freezer_api/api/v2/sessions.py

# Verify config.yaml is valid
python3 -c "import yaml; yaml.safe_load(open('openspec/config.yaml'))"
```

## Developer Tooling (umbrella root, read-only against code/ submodules)

| Command | What it does |
|---------|--------------|
| `scripts/fz test <repo>` | Run unit tests in the submodule venv (`stestr`, or repo test runner) |
| `scripts/fz lint <repo>` | CI-style lint in the venv (`flake8`/pre-commit) |
| `scripts/fz tox <repo> [env]` | Run tox inside the submodule venv |
| `scripts/fz drift [--fetch]` | Report submodule pin drift vs upstream `master` |
| `scripts/fz triage [--open]` | Open the launchpad freezer bug queue |
| `scripts/fz audit` | Full readiness report (alias of `scripts/audit.sh`) |
| `scripts/bootstrap.sh [--quick]` | Create per-submodule venvs + CI-pinned deps + pre-commit hooks |
| `scripts/audit.sh` | Offline consistency checks (config, docs sync, submodules, skills) |
| `scripts/gerrit-fetch.sh <change-id>` | Fetch an OpenDev Gerrit change summary to `reviews/` |

`repo` ∈ {`freezer`, `freezer-api`, `web-ui`, `client`}. Venv-mandatory rule:
tools run only inside `code/<repo>/.venv`, never from the umbrella root.
`scripts/*` and `.devcontainer/` give a reproducible environment (also via the
GitHub Action in `.github/workflows/audit.yml` — check-only, never pushes).

## Analysis Workflow (TL;DR)

1. Load `openspec/config.yaml` → REPOSITORY MAP, COMPONENT MAP, FEATURE PLACEMENT.
2. Identify the target repo by feature (see FEATURE PLACEMENT).
3. Read the commit (Change-Id → Gerrit), the reno release note, and sibling repos.
4. Record durable findings in `docs/lessons-learned.md`; model structured changes with
   the OpenSpec workflow under `openspec/changes/`.

See `docs/workflow-guide.md` for the full OpenSpec workflow and
`docs/config-reference.md` for the config schema.