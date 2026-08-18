# OpenSpec Configuration Reference

## `openspec/config.yaml`

The `openspec/config.yaml` file configures the spec-driven workflow for the OpenStack
Freezer multi-repository project. It provides context, rules, and guidance for
AI-assisted development and analysis of all four Freezer submodules.

### Structure

Sections in the `context` block:

| Section | Purpose |
|---------|---------|
| REPOSITORY MAP | Lists the umbrella-repo purpose and the four `code/` submodules, their upstream URLs, Gerrit host, Zuul CI |
| COMPONENT MAP | Per-submodule file-to-function layout of every repo |
| DATA FLOW | How the agent, scheduler, API, client and UI talk to each other |
| FEATURE PLACEMENT | Which feature/bugfix belongs in which repo (decision table) |
| ONE-OFF ANALYSIS | Workflow for analyzing commits, features, bug fixes across repos |
| GERRIT REVIEW ANALYSIS | How to read review.opendev.org conversations (votes, bots, patchsets, REST API) and a verdict-summary template |
| AGENT & CLIENT USAGE | Guidance for openspec, Gemini, Cody, Kiro, antigravity, etc.: component answers and cross-repo search discipline |
| PROJECT STEERING RULES | Engineering conventions: Oslo config, stestr testing, flake8, validation rules, Swift gotchas |

Top-level keys:

```yaml
schema: spec-driven

context: |
  # (see table above)

per-artifact_rules:
  task:
    - Break tasks into chunks of max 2 hours
    - Reference relevant specs from specs.openstack.org
    - Include explicit tasks for edge-case input validation
    - Name the target repo from FEATURE PLACEMENT; check sibling repos
    - For review tasks: pull the Gerrit change + reno note first
  proposal:
    - Keep proposals under 500 words
    - Include "Non-goals" section
    - Reference related blueprints/gardens
    - State explicitly which submodules are affected

operations:
  apply:
    guidance:
      - Keep test summaries concise
      - oslo-config-generator update for new options
      - stestr + flake8 (CI-pinned versions) before commit
      - config.py StrOpt + sample + doc + reno note for CLI options
      - Verify each affected submodule gets code, tests, and reno note
  archive:
    guidance:
      - Summarize archive outcome
      - Update release notes with new findings
      - Log durable analysis results into docs/lessons-learned.md
```

### Sections

#### `schema`
- **Value**: `spec-driven`
- **Purpose**: Indicates the project uses the spec-driven artifact generation pattern

#### `context`
- **Purpose**: Shown to AI when creating artifacts or analyzing the codebase. Defines
  technical context, repo map, component layout, data flow, feature placement,
  analysis/review workflows, and engineering conventions.
- **Key content**:
  - Repo map, component map, data flow, feature placement (see table above)
  - Gerrit review analysis workflow and verdict summary template
  - Engineering convention notes (validation rules, testing, style, Swift gotchas)

##### `context` sections (anchors used throughout the umbrella docs/skills)

| Section (anchor) | Purpose |
|------------------|---------|
| `REPOSITORY MAP` | Umbrella study repo vs the 4 upstream product repos, CI (Zuul), Gerrit |
| `COMPONENT MAP` | Where each Freezer component lives per submodule |
| `DATA FLOW` | How the four repos talk to each other (API ↔ client ↔ web-ui) |
| `FEATURE PLACEMENT` | Which feature belongs in which repo (canonical "where is X") |
| `ONE-OFF ANALYSIS` | Commit / feature / bugfix analysis workflow |
| `GERRIT REVIEW ANALYSIS` | Gerrit + Zuul verify semantics + verdict template |
| `AGENT & CLIENT USAGE` | Which agents load what; `fz` tooling usage; domain answers |
| `PROJECT STEERING RULES` | Normative engineering conventions + HITL guardrails (Rule 39) |

These eight anchors MUST remain listed here: `scripts/audit.sh` verifies the mirror.

#### `per-artifact_rules`
- **Purpose**: Custom rules for specific artifact types (proposals, tasks)
- **Rules**:
  - `task`: Break into max 2-hour chunks, reference OpenStack specs, name the target
    repo and check cross-repo impact, pull Gerrit change + reno note for review tasks
  - `proposal`: Under 500 words, include "Non-goals", reference blueprints, state which
    submodules are affected

#### `operations`
- **Purpose**: Advisory guidance for apply/archive workflows
- **Apply guidance**: Concise test summaries, oslo-config-generator updates, stestr +
  flake8 (CI-pinned), full reno/doc/deprecation coverage, cross-repo completeness
- **Archive guidance**: Summarize outcome, update release notes, persist durable
  analysis results to `docs/lessons-learned.md`

### Workflow Integration

#### Creating a Proposal
```bash
# Uses openspec propose skill to generate a proposal artifact
# The config.yaml provides context and rules for the AI
```

#### Archiving a Change
```bash
# Uses openspec archive-change skill
# References the operations guidance in config.yaml
```

#### Related Directories

| Directory | Purpose | Status |
|-----------|---------|--------|
| `openspec/config.yaml` | Main configuration file (single source of truth, Rule 39) | ✓ Populated |
| `docs/` | config-reference, workflow-guide, ai_flying_solo, test-documentation, lessons-learned | ✓ Populated |
| `openspec/changes/` | Active change artifacts (`<change>/specs/freezer/<feature>/` delta specs) | Active |
| `openspec/specs/` | Spec proposals and blueprints | Empty (populated when creating proposals) |
| `code/freezer` | upstream freezer-agent + scheduler submodule | ✓ Cloned |
| `code/freezer-api` | upstream freezer REST API submodule | ✓ Cloned |
| `code/freezer-web-ui` | upstream Horizon dashboard submodule | ✓ Cloned |
| `code/python-freezerclient` | upstream CLI/bindings submodule | ✓ Cloned |

### Project-Specific Conventions

- **Configuration**: Scheduler options in `freezer/scheduler/arguments.py`, agent options
  in `freezer/common/config.py`
- **Testing**: `stestr` with coverage; integration tests gated behind `FREEZER_TEST_*` env
- **Documentation**: Sphinx with `openstackdocstheme`, built via `tox -e docs`
- **Code style**: `flake8` with specific ignores (H405,H404,H403,H401,W504,W605)
- **Config generation**: `oslo-config-generator --config-file etc/config-generator.conf`
- **Release notes**: Generated with Oslo `reno`, per affected repo
- **Reviews**: Gerrit `review.opendev.org` (see GERRIT REVIEW ANALYSIS in context)

### How to Extend

1. **Add new per-artifact rules**: Edit `per-artifact_rules` section in `config.yaml`
2. **Add new operations guidance**: Edit `operations` section in `config.yaml`
3. **Add project-specific conventions**: Add to the `context` block under `Convention notes:`
4. **Update repo layout / feature placement**: Edit the COMPONENT MAP / FEATURE PLACEMENT
   sections in `context` (tree-change = structural doc update, mirrored here)
5. **Create spec proposals**: Use the `openspec propose` skill with the config context
6. **Archive changes**: Use the `openspec archive-change` skill, which references the
   operations guidance