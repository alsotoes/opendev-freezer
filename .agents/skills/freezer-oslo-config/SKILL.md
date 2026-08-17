---
name: freezer-oslo-config
description: Define new or deprecated Freezer CLI/config options the OpenStack way. Use when adding or changing scheduler/agent options in the freezer repo (code/freezer), generating sample configs, or writing reno release notes. Covers the full 5-step convention so reviewers accept the change.
---

## What this skill covers

Adding a config option to OpenStack Freezer (code/freezer) requires five
coordinated changes. Missing any one fails CI or review.

## The full chain for a new/deprecated CLI option

1. **Declare the option** in the right module:
   - Scheduler/agent CLI options → `freezer/scheduler/arguments.py`
   - Agent configuration options → `freezer/common/config.py`
   - Both use `oslo_config.cfg`. Marking for removal:
     `cfg.StrOpt(..., deprecated_for_removal=True, deprecated_reason=...)`.
2. **Regenerate the sample config**:
   ```bash
   cd code/freezer        # always run inside the submodule venv
   tox -e genconfig       # or oslo-config-generator --config-file etc/config-generator.conf
   ```
3. **Update user docs**: `doc/README.rst` (or the relevant doc source) exposes the
   new option.
4. **Reno release note** (features and deprecations are mandatory):
   ```bash
   cd code/freezer
   reno new <slug>
   # fills releasenotes/notes/<slug>.yaml — describe user-visible behavior
   ```
5. **Lint with CI-pinned versions** (local linters can be newer than CI and miss
   errors CI enforces):
   ```bash
   cd code/freezer
   pip install "$(rg 'hacking|pycodestyle' test-requirements.txt)"
   stestr run && flake8 <changed files>
   ```

## Cross-repo reach

- If the option shape is exposed via the freezer-api v2 schema → coordinate with
  `code/freezer-api` (json_schemas.py) and `code/python-freezerclient` (client
  method signatures).
- If it changes only runtime behavior inside the agent → code/freezer only.

## Commit-message rule

Explain *why* the option exists if it duplicates an existing one: cite the
misleading-name semantics, any prior abandoned fix, and confirm the old option
stays functional/deprecated. Otherwise the rename reads as scope creep to Gerrit
reviewers.

## Common gotchas

- `is not None` (not `if x:`) to detect *supplied* vs *falsy* values (`''`, `0`).
- Don't build permissive `int()`/`float()` gate helpers — route input through the
  strict conversion (see freezer-input-validation skill).
- `.gitreview` marks the Gerrit host; push changes there, never force-push master.