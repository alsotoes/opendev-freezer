---
description: Human-in-the-loop commit/amend checkpoint (HITL). Print the ask-first template; never auto-commit. Owner: openspec/config.yaml HITL rules.
---

At every commit/amend boundary, present exactly this and wait for an explicit
human "yes" before running `git commit` / `git commit --amend`:

```text
[feature|bugfix] <one-line scope>
Changed files: <paths (submodule-relative)>
Tests: <stestr result / CI-pinned flake8>
Commit:  <proposed subject>
commit? / amend? / (never push)
```

Hard rules (openspec/config.yaml PROJECT STEERING RULES, HITL):

- never push (no git push / git review / git send-email)
- never commit/amend without explicit approval
- execute commit only for the approved scope; keep upstream cleanliness
- never present fabricated Change-Id; let the git-review hook add it