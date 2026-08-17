---
name: freezer-stestr-testing
description: Write and run Freezer unit tests with stestr/testtools the OpenStack way. Use when adding or modifying tests in the freezer repo (code/freezer), distinguishing unit vs integration tests, or running the suite locally. Freezer does not use pytest — this skill replaces pytest-centric patterns.
---

## Test runner

Freezer uses **stestr + testtools**, not pytest. Always run inside the
`code/freezer` submodule with an active venv:

```bash
cd code/freezer
source .venv/bin/activate
stestr run
```

Configuration lives in `code/freezer/.stestr.conf` (test path
`./freezer/tests/unit`, 8 parallel workers by default).

## Structure

- Test path: `freezer/tests/unit/` (unit) and `freezer/tests/integration/`.
- Base class: `FreezerBaseTestCase` in `freezer/tests/commons.py`.
- Integration tests are gated by `FREEZER_TEST_*` env vars (SSH/Swift/LVM) and
  require real infrastructure — they run in CI, do not chase them locally.
- Local bar: **unit tests pass with 0 skipped.**

## Rules

- Use `oslotest.base.BaseTestCase`-style classes and testtools assertions
  (`assertRaises`, `assertIn`, etc.).
- Never `assertRaises(Exception)` — hacking H202 flags it; raise specific typed
  exceptions (e.g. `DateException`).
- Cover edge cases regardless of whether they look reachable: `nan`, `inf`,
  huge values, negatives, whitespace, bools, impossible dates.
- Test combinations too, not just single inputs (date + days silently accepted
  is how bug 1599592 hid).
- Test the execution path, not only construction/validation (the missing
  main.py removal hook and Swift listdir/rmtree gaps were only caught by
  execution-path tests).

## Verification before commit

```bash
stestr run && flake8 <changed files>
```

Run flake8 with the **CI-pinned** toolchain versions from `test-requirements.txt`
(local pycodestyle can be newer and miss what CI's 2.5.0 enforces, e.g. E302).
New features must be discoverable by stestr (no pytest-only collection).

## Cross-repo testing

- `code/freezer-api` → stestr, sqlalchemy driver tests in freezer_api/tests.
- `code/python-freezerclient` → stestr + openstack client mocks.
- `code/freezer-web-ui` → django/horizon test runner (`run_tests.sh`, tox).
Each repo owns its `.stestr.conf` and `test-requirements.txt`.