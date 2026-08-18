# Development Environment — as built & tested

Current working environment for the `opendev-freezer` umbrella, with the
tested-vs-configured status of each piece. Facts captured 2026-08-17.

## Machine & OS

| | |
|---|---|
| Host | Fedora Linux 43 |
| Shell | bash |

## Runtimes

| Tool | Version | Used for |
|---|---|---|
| Python | 3.14.6 | scripts, venvs, audit checks |
| git | 2.55.0 | submodule + repo operations |
| curl | 8.15.0 | Gerrit REST (lib/gerrit.sh) |
| Node.js | v22.22.2 | repomix/autoskills/openspec packages under `.opencode/` |
| git-review | 2.5.0 (`/usr/bin/git-review`) | **human-only** push path to Gerrit |
| pre-commit | 4.6.2 | in `.venv-tools/` (umbrella hooks, installed) |
| venvs | `code/<repo>/.venv` (created, deps NOT yet installed) + `.venv-tools/` | venv-mandatory rule |

## IDE & model

- **opencode** CLI `1.18.3` (TUI), model `opencode/deepseek-v4-flash-free`
  (this session).
- Global config `~/.config/opencode/opencode.jsonc`: LSP servers `gopls`,
  `typescript-language-server`, `rust-analyzer`; `rtk` preferred for
  token-cheap shell output.

## MCP servers (connected)

| Server | Kind | Where |
|---|---|---|
| `context7` | remote `https://mcp.context7.com/mcp` | current library docs |
| `mempalace` | local `/home/alvaro/.local/bin/mempalace-mcp`, DB `~/.mempalace/palace` | knowledge palace (diary, drawers, artifacts, event log) |
| websearch/webfetch | builtin tools | research |

## Skills

| Location | Skills |
|---|---|
| `.agents/skills/` (project, root-only) | `bash-defensive-patterns`, `python-executor`, `python-testing-patterns`, `freezer-oslo-config`, `freezer-input-validation`, `freezer-stestr-testing`, `gerrit-change-analysis` |
| `.opencode/skills/` (openspec) | `openspec-apply-change`, `openspec-archive-change`, `openspec-explore`, `openspec-propose`, `openspec-sync-specs`, `openspec-update-change` |
| `~/.agents/skills/` (user) | `context7-mcp`, `find-docs` |

Autoskills registry: `skills-lock.json` pins `bash-defensive-patterns`,
`python-executor`, `python-testing-patterns` (computed hashes, lockfile v1).

## Umbrella tooling (scripts/)

| Script | Status |
|---|---|
| `scripts/fz` (test/lint/tox/drift/triage/audit/preview/search/status) | **tested live** (drift 4/4 pinned, search, status 987400) |
| `scripts/audit.sh [--quick]` | **tested live** — ALL PASSED |
| `scripts/bootstrap.sh [--quick] [--tools]` | **tested live** (venvs + hooks); full deps install pending (needs solid network) |
| `scripts/gerrit-fetch.sh` | **tested live** (change 987400 → `reviews/`) |
| `scripts/gerrit-search.sh` | **tested live** (8 open freezer changes) |
| `scripts/upstream-preview.sh` | **tested live** (987400 diff vs pin via `.upstream/` mirror) |
| `scripts/new-reno.sh` | **tested live** (stub create + cleanup) |
| `scripts/palace-sync.sh` | configured, **not runnable locally** (no `mempalace` CLI module; use MCP tools instead) |

## Reproducibility

- `.devcontainer/` (Dockerfile + devcontainer.json) — **configured, NOT built/tested**.
- `.github/workflows/audit.yml` — check-only audit + drift; runs on push/PR/weekly.
- `.pre-commit-config.yaml` — installed into umbrella `.git/hooks` (audit `--quick`,
  config.yaml parse, script `bash -n`).

## Tested matrix summary

- Passed: Gerrit REST (fetch/search/status/preview), drift (4/4 pinned),
  audit full+quick, bootstrap `--quick`/`--tools`, new-reno stub, excludes
  (`.git/info/exclude` via `--absolute-git-dir`), pip `--isolated` (0 warning
  dry-run).
- Pending: full `bootstrap.sh` deps install + `fz test`/`fz lint` smoke,
  devcontainer build, palace-sync CLI.

See `README.md` → "Developer Tooling" for usage; all normative rules stay in
`openspec/config.yaml` (this file is inventory, not rules).
