## Repo Layout

This change targets the freezer-agent repository only. File paths written as
`freezer/...` resolve to `code/freezer/freezer/...` in this umbrella repo.

## Context

See proposal.md - Why. The current `AdminJob.execute()` computes the cutoff
timestamp from whatever removal option is present (ISO date or days) and only then
touches storage. `date_to_timestamp()` swallowed all exceptions into a bare
`Exception`, and validation and execution computed the cutoff in two different
places, allowing them to drift (e.g. input that passed validation still crashed at
execution). See the delta spec at specs/freezer/backup-removal/spec.md for the
behavior contract.

## Goals / Non-Goals

**Goals:**
- Validate all removal inputs at job-construction time, before auth/storage setup.
- One canonical, unambiguous cutoff from exactly one option.
- A dedicated exception type for date errors.
- Compute the cutoff exactly once, at validation time, and re-use it at execution so
  what is validated is exactly what is executed.

**Non-Goals:**
- New storage backends or new backup formats.
- Removing `remove_from_date` now; it is only deprecated.

## Decisions

- **Early validation in `AdminJob._validate()`** rather than relying on execution.
  `Job.__init__` now runs `_general_validation()` and `_validate()` **before**
  `get_client_manager()`, so bad input fails fast at construction and no cloud
  client is created. Alternative considered: validating inside `execute()`;
  rejected because it happens after auth setup and mixes concerns.
- **Mutual exclusivity is an error.** The spec requires exactly one option;
  `_validate()` rejects when zero **or more than one** removal option is set
  (both dates together, a date plus `remove_older_than`, or all three).
  Alternative: silent priority ordering; rejected twice — the old priority
  behavior was part of bug 1599592's ambiguity, and an adversarial probe found
  date+days combos were still silently accepted.
- **Single computation point: `_get_remove_timestamp()`.** `_validate()` calls it and
  stores the result as `self.remove_timestamp`; `execute()` only reads that value.
  For dates it defers to `date_to_timestamp()`, which parses with `strptime` and
  then round-trips through `strftime`, so unpadded fields (`2014-12-3T23:23:23`),
  space separators, and impossible calendar dates (`2014-99-99T99:99:99`) are all
  rejected, accepting only the strict `YYYY-MM-DDTHH:MM:SS` form. For days it converts
  with `float()`, requires `math.isfinite()` and non-negativity, and performs the
  actual `timedelta`/`mktime` conversion inside the same method so overflow (e.g.
  `1e300` days) surfaces as a clean `ValueError` at validation, not a crash at
  execution. Lesson learned: validating shape separately from parsing (regex gate +
  parser) drifted; a single parser-backed conversion eliminates the drift by
  construction.
- **`DateException`** in `freezer/exceptions/utils.py` (pattern-matching existing
  `TimeoutException`) replaces bare `Exception`, giving callers and tests a precise
  type to catch. Narrow `except (ValueError, TypeError, OverflowError,
  AttributeError)` around parsing so extreme years and non-string input are also
  covered. `_get_remove_timestamp()` maps it to a user-facing `ValueError`.
- **`remove_older_than` guard** uses `float()` inside try/except **plus**
  `math.isfinite()` and a non-negative check, an explicit `bool` rejection
  (`float(True)` is `1.0`, same trap as `int()`), and the full conversion is
  performed in `_get_remove_timestamp()`. Lesson learned: `float('inf')` and
  `float('nan')` succeed, so numeric *and* finite *and* sign checks are all
  needed; previously `inf` passed validation and crashed in `execute()` with
  OverflowError, and huge finite values had the same problem.
- **No standalone regex/int helper functions.** An earlier design added
  `is_iso_date()`/`is_timestamp()`/`days_to_seconds()`; once `_get_remove_timestamp()`
  validated via the parser directly, they became dead code and were removed. Lesson
  learned: `int(ts)` is far too permissive (truncates floats, accepts `bool`, strips
  whitespace), but the right answer was to have no such gate at all rather than a
  second, potentially-divergent one.

### Expanded scope: removal execution for backup/restore

Bug 1599592 has three symptoms, and the validation layer only fixed one of them.
The remaining two — removal during backup/restore doing nothing, and Swift storage
removal silently skipping — were uncovered by an honest probe that asked "does this
patch fully fix the bug?"

- **main.py hook.** The 2016 merged fix (commit `4ef18182e0c9`, stable/mitaka) added
  an `AdminJob` construction+execute after the primary job ran, gated on removal options
  being set and `conf.action != 'admin'`. Current master had no such hook. The hook
  mirrors the original, adapted to use `is not None` checks (not truthiness) so that
  `remove_older_than=0` correctly triggers removal.
  - Construction `job.AdminJob(conf, storage)` works with a backup/restore conf because
    `AdminJob._validate` only examines removal options and backup_media; it does not
    depend on `conf.action`.
  - The execution calls `self.storage.remove_older_than(...)` which is the same path
    used by `--action admin`, so the removal is consistent regardless of how it was
    triggered.
  - Runs **after** the primary job so the newly-created backup is not removed by the
    same invocation (its timestamp > cutoff for any `remove_older_than > 0`).

- **Swift `listdir` robustness.** The original implementation accessed `f['subdir']`
  unconditionally inside a generator expression. With `delimiter='/'`, `get_container`
  returns both pseudo-directories (`subdir` key) and objects (`name` key). When a file
  entry was present (atypical but possible), `f['subdir']` raised KeyError, caught by
  the broad `except Exception`, and the entire `listdir` returned `[]` — silently
  making `get_level_zero` report "no backups found" and removal appear to do nothing.
  Fixed by iterating explicitly and handling both key types, returning only the leaf
  directory/object name.

- **Swift `rmtree` pagination.** The original called `get_container` without
  `full_listing=True`, so only the first 10000 objects were deleted. For large backups
  with many segments, removal would be incomplete. Added `full_listing=True` so
  swiftclient paginates internally and all objects under the prefix are deleted.

## Lessons learned

- A regex shape check is not a validity check. Validate calendar semantics with the
  same parser used for conversion — or better, compute through the one parser path.
- `float()` accepts `inf`/`nan`; use `math.isfinite` before producing timestamps.
- Huge finite values can still overflow `datetime.timedelta`/`mktime`; perform the
  conversion at validation time so overflow is a clean error, not a crash.
- Python's `int()` silently truncates floats, accepts booleans, and strips
  whitespace — don't build permissive gate helpers; route input through strict
  conversions.
- Avoid two code paths computing the same value (validation vs execution); compute
  once and re-use. Drift between them was the root cause of several bugs.
- Validate user input before any expensive or side-effecting setup (clients,
  auth), so errors are cheap and unambiguous.
- Flake8 H202 (via hacking) flags `assertRaises(Exception)`; raising a specific
  exception type is the fix, not a `# noqa` bypass. Also H102 (license header)
  only fires on files over 10 lines — appending a class to a tiny file can silently
  start triggering it.
- Local flake8/pycodestyle can be **newer than CI's**: local pycodestyle 2.14 did
  not flag the E302 that CI's pycodestyle 2.5.0 (job `openstack-tox-pep8`) caught
  in `freezer/exceptions/utils.py`. Verify against the CI toolchain versions
  (hacking/pep8 pinned via test requirements), not just the latest installed.
- Truthiness is not "was it supplied": `if x:` conflates absent with falsy values
  like `''` and `0`. Use `is not None` when deciding whether a config value was
  provided, so explicit valid values like `--remove-older-than 0` are not rejected
  and empty strings are validated rather than silently ignored.
- A review may ask "why does this option exist when it duplicates another?";
  capture the rationale in the commit message up front: misleading name semantics
  vs. historical bug-fix attempt abandoned before merge.
- Rename-via-deprecation reads as scope creep to a reviewer unless the naming
  flaw is spelled out: `--remove-from-date` removes backups created *before* the
  date yet reads like "remove from this date onward". Name the wrongness and the
  abandoned 2016 fix (review 340307) in the change; do not assume reviewers load
  Launchpad history.

## Risks / Trade-offs

- [Stricter validation could reject input that previously parsed] → The canonical
  format is what the CLI help documents; `date_to_timestamp` rejects space
  separators anyway, so no previously-working input is lost.
- [Behavior change: previously silent precedence is now an error] → This is
  intentional per the spec and reported clearly to the user with the offending
  option names. This also closes the gap where a date plus `remove_older_than`
  was silently accepted with priority instead of being rejected.
- [Validation now runs before client creation] → `_validate()` implementations only
  touch `self.conf`/`backup_name`/`container`; verified no `_validate` reads cloud
  clients. Existing fixtures updated and covered by ordering tests.
- [`remove_older_than 0` is allowed and removes everything older than now] → Consistent
  with the documented "number of days" contract; only non-finite, negative, and
  unrepresentable values are rejected.
