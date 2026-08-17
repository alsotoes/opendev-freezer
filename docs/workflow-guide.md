# OpenSpec Workflow for OpenStack Freezer

## Overview

This document describes the OpenSpec workflow for the OpenStack Freezer project, including how to create proposals, archive changes, and use the spec-driven configuration.

## Prerequisites

- Python 3.10+ environment activated
- `source .venv/bin/activate` to activate the virtual environment
- `stestr run` must pass (all unit tests; count varies per checkout)

## Repo layout note

This umbrella repo bundles the upstream Freezer repos as submodules under `code/`.
OpenSpec artifacts (config, specs, changes) live at the repo root; product code and
tests live inside the submodules. Commands like `stestr run` and `flake8` operate
inside `code/freezer/` (the agent repo). E.g.:

```bash
cd code/freezer
source .venv/bin/activate   # or the environment for that submodule
stestr run
```

## Directory Structure

```
<repo-root>/
├── README.md              # Project overview
├── openspec/
│   ├── config.yaml        # Single source of truth (steering rules + repo maps)
│   ├── specs/             # Spec proposals (empty, populated when creating)
│   └── changes/           # Active + archived changes
└── docs/                  # Project docs (config-reference, workflow-guide, ...)
```

## Creating a New Spec Proposal

### Step 1: Prepare the config context

The `openspec/config.yaml` provides the AI with project context. Ensure it's up-to-date with:
- Current tech stack
- Testing framework (stestr)
- Documentation tools (Sphinx)
- Code style (flake8)

### Step 2: Generate the proposal

Use the `openspec propose` skill:

```bash
# The skill will use config.yaml context to guide the AI
# Generates a proposal in openspec/specs/
```

### Step 3: Review and refine

- Follow the `proposal` rules in config.yaml:
  - Keep under 500 words
  - Include "Non-goals" section
  - Reference related blueprints/gardens from specs.openstack.org

### Step 4: Implement the spec

Once approved, implement the changes following OpenStack conventions:
- Use Oslo config for new options
- Run `stestr run` to verify no regressions
- Build docs with `tox -e docs`
- Generate release notes with Reno

## Archiving a Completed Change

### Step 1: Verify completion

Ensure all criteria are met:
- Tests pass (`stestr run`)
- Documentation updated (`tox -e docs`)
- Config options generated (`tox -e genconfig`)
- Release notes written

### Step 2: Archive the change

Use the `openspec archive-change` skill:

```bash
# The skill will:
# 1. Summarize the archive outcome (per operations guidance)
# 2. Update release notes (per operations guidance)
# 3. Record the change in the changes directory
```

### Step 3: Post-archive steps

- Verify the change is properly recorded
- Ensure no pending tasks remain
- Update any related documentation

## Working with Specs

### Spec Location

- Proposals go in `openspec/specs/`
- Reference OpenStack specs at `https://specs.openstack.org/openstack/freezer-specs/`

### Related Blueprints

- Search at `https://blueprints.launchpad.net/freezer`
- Reference in proposal `Non-goals` section if out of scope

### Spec Lifecycle

```
Proposal (openspec/specs/) --> Review --> Implementation --> Archive (openspec/changes/archive/)
```

## Configuration Reference

See `docs/config-reference.md` for detailed documentation of the `config.yaml` structure and all sections.

## Commands Summary

| Action | Command |
|--------|---------|
| Activate environment | `source .venv/bin/activate` |
| Run all tests | `stestr run` |
| Lint code | `flake8 freezer` |
| Build documentation | `tox -e docs` |
| Generate config samples | `tox -e genconfig` |
| Create spec proposal | Use `openspec propose` skill |
| Archive change | Use `openspec archive-change` skill |
| Install dependencies | `pip install -r requirements.txt` |

## Best Practices

1. **Keep proposals focused** - Single feature or fix per proposal
2. **Reference existing specs** - Link to related OpenStack specs and blueprints
3. **Include non-goals** - Clearly state what's out of scope
4. **Update config** - New options require oslo-config-generator updates
5. **Run full test suite** - Ensure no regressions before archiving
6. **Update release notes** - Mandatory per the archive operations guidance