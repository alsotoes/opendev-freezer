# Lessons Learned

Lessons from the `remove-before-date` work (bug 1599592), captured so future
changes avoid the same pitfalls.

## Input validation

- **A regex shape check is not a validity check.** An early `is_iso_date()` only
  matched `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$`, which accepted impossible dates
  like `2014-99-99T99:99:99` and `2014-02-31T23:23:23`; the parser
  (`datetime.strptime`) then raised later. The lasting fix: drop the separate gate
  and route validation through the parser itself (`date_to_timestamp`), so there is
  one path and no chance of the gate drifting from the parser.
- **`float()` accepts `inf` and `nan`.** `float('inf')` and `float('nan')` succeed,
  so a numeric check alone is not enough. `--remove-older-than inf` passed
  validation and crashed in `execute()` with `OverflowError` when the value reached
  `datetime.timedelta`. Fix: check `math.isfinite()` and sign explicitly.
- **Huge finite values overflow too.** Even `1e11` days passed `math.isfinite` but
  blew up `datetime.timedelta`/`time.mktime`. Fix: perform the conversion during
  validation (in `_get_remove_timestamp()`), so overflow surfaces as a clean error,
  not a crash at execution.
- **`int()` is far too permissive.** `int(1.5)` truncates to `1`, `int(True)` is
  `1`, `int(' 5 ')` strips whitespace. We initially wrote `is_timestamp()` to
  compensate, but it became dead code once validation used the parser directly —
  the right answer was no extra gate at all.
- **`float()` is just as permissive as `int()` for booleans.** `float('inf')` and
  `float('nan')` succeed, and so does `float(True)` → `1.0`. The days guard
  rejects `bool` input explicitly before converting.
- **A single-input gate can still miss combination inputs.** Even after
  validating each option individually, `_validate()` *silently accepted* a date
  plus `remove_older_than` together and applied priority — the exact ambiguity of
  bug 1599592. The counter also checks the *combination*: exactly one removal
  option may be supplied; zero or more than one is rejected.
- **Truthiness is not "was it supplied".** `if x:` conflates *absent* with `None`
  and *falsy values* like `''` or `0`. A `remove_older_than=0` (a valid, explicit
  value) was rejected as "no removal option", and `remove_before_date=''` combined
  with days was silently ignored. Use `is not None` when deciding whether a
  config value was provided; let the value's own parser judge validity.
- **Don't compute the same value in two places.** Validation and execution each
  computed the cutoff independently, and they drifted (input passed one, crashed
  the other). Fix: compute once in `_validate()` (`self.remove_timestamp`) and have
  `execute()` re-use it.
- **Validate before expensive or side-effecting setup.** `Job.__init__` originally
  created the OpenStack client manager *before* `_validate()`, so bad input still
  attempted auth. Validation now runs first, so errors are cheap and unambiguous.

## Static analysis / lint traps

- **H202 flags `assertRaises(Exception)`** (via the hacking plugin). The correct fix
  is raising a specific exception type, not adding `# noqa`. This surfaced the
  missing `DateException`.
- **H102 (license header) only fires on files over 10 lines.** Adding a class to a
  tiny file can silently start triggering it. When growing a small file, add the
  Apache-2.0 header proactively.
- **Local linters may be newer than CI's.** Local pycodestyle 2.14 did *not* flag
  the `E302 expected 2 blank lines` that CI's `openstack-tox-pep8`
  (pycodestyle 2.5.0) caught in `freezer/exceptions/utils.py`, failing the check
  pipeline. Install the CI toolchain versions (hacking/pep8 pinned via test
  requirements) and run with them, not just whatever is installed latest.

## Process

- Test the edge cases you *don't* expect to work: `nan`, `inf`, huge values,
  negatives, whitespace, bools, impossible calendar dates. Each revealed a real gap.
- After adversarial probes, also test the *combinations* of inputs, not just each
  input alone (a date plus `remove_older_than` was silently accepted).
- Keep the spec's observable-behavior requirements aligned with what tests assert;
  when validation behavior changed, the delta spec was updated in the same change.
- Watch for dead code after refactors: helper functions written before the design
  settled can silently lose all callers.
- Write the "why does this exist / why not just fix the old option" rationale into
  the commit message up front; a reviewer asked exactly that and the answer
  (misleading name + a prior rename fix that was abandoned before merge) came from
  history rather than the change itself.

## Scope analysis

- **Ask the honest question: "does this patch fully fix the bug?"** We built an
  input-validation layer that fixed symptom (a) of bug 1599592. Proactively
  checking whether the remaining symptoms were resolved revealed the actual root
  cause: removal during backup/restore did nothing because `main.py` had no hook,
  and Swift storage's `listdir` could silently return `[]` on any stray file
  entry. The validation-only patch would have passed review but left the core
  defect — removal never executing — unfixed.
- **A bug report with multiple symptoms needs each symptom traced through the
  current code.** 1599592 reported (a) a crash crash, (b) removal-not-working
  during backup, and (c) Swift-specific issues. Tracing (b) uncovered the missing
  main.py hook; tracing (c) uncovered the `listdir` KeyError and the `rmtree`
  pagination gap. The 2016 merged fix for stable/mitaka proved the hook was the
  intended resolution.
- **Cross-reference the prior fix commits, even if they are for old branches.**
  The 2016 fix at 4ef18182e0c9 (stable/mitaka) was our blueprint for the main.py
  hook. Without it, we would have reinvented the approach from bug lore.
- **A broad `except Exception` that silently returns `[]` is a correctness bug.**
  Swift's `listdir` swallowed every error (KeyError, auth failure, network
  timeout) into an empty return, reporting "no entries found" to the removal
  path. The caller then removed nothing. When a storage listing can fail, prefer
  propagating the error, or at minimum log it distinctly so an operator can
  distinguish "directory is empty" from "listing failed."
- **`get_container` without `full_listing=True` is a pagination trap.**
  python-swiftclient returns at most 10000 objects by default. `rmtree` that
  iterates `get_container(...)[1]` without pagination silently deletes only the
  first page. For large backups (many segments), the rest are orphaned. Always
  pass `full_listing=True` when deleting by prefix.
- **Test the execution path, not just construction/validation.** Our original
  tests validated input and AdminJob construction but never actually triggered
  removal. The main.py hook test and Swift storage tests validate the full path
  from config through storage deletion.

## Reviewer feedback (Dmitriy Rabotyagov, review 1000670 ps7)

- **A rename/deprecation reads as scope creep unless the naming problem is
  obvious.** The reviewer flagged adding `--remove-before-date` when
  `--remove-from-date` already accepts the same format: "these options seemingly
  should be doing the same thing". The whole point of the change is that the
  *name* is semantically backwards (it removes backups created **before** the
  date), which is invisible in the code. Establish the naming flaw and the
  abandoned prior fix (review 340307, bug 1599592) explicitly in the change
  itself — assume the reviewer has no Launchpad history loaded.
- **Deprecation is the correct, reviewable pattern for a rename.** Keep
  `--remove-from-date` functional and `deprecated_for_removal` rather than
  removing it; reviewers can then judge the new option on its naming and
  validation merit without a backwards-compatibility objection. The commit message
  must state both options accept the same format and behave identically, so the
  reviewer sees exactly what is changing.
