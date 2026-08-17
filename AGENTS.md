# AGENTS.md

All project steering rules and engineering standards are defined in **one** primary file:
[`openspec/config.yaml`](openspec/config.yaml) (inside the `context` block — sections
"REPOSITORY MAP", "COMPONENT MAP", "DATA FLOW", "FEATURE PLACEMENT",
"ONE-OFF ANALYSIS", "GERRIT REVIEW ANALYSIS", "AGENT & CLIENT USAGE", and
"PROJECT STEERING RULES" for engineering conventions).

This file is the single source of truth (Rule 39). Do not duplicate rules here.
All AI agents MUST load `openspec/config.yaml` before analyzing or writing any
Freezer code. Product source lives only in the `code/` submodules; this umbrella
repo hosts specs, docs (`docs/`), and analysis artifacts (`openspec/`).
