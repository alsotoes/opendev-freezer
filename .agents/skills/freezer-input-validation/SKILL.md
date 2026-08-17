---
name: freezer-input-validation
description: Enforce OpenStack Freezer's strict input-validation rules for dates, numbers, and option combinations before writing or reviewing code. Use when handling --remove-before-date/--remove-from-date/--remove-older-than style options, ISO datetimes, numeric limits, or "exactly one" exclusivity in the freezer repo (code/freezer).
---

## Source of truth

These rules came from bug 1599592 and are documented in
`docs/lessons-learned.md` and `openspec/config.yaml` (PROJECT STEERING RULES).
Follow them for any user input that reaches timestamps, timedeltas, or exclusive
option groups.

## Dates

- Canonical ISO datetime is `YYYY-MM-DDTHH:MM:SS` (T separator, zero-padded).
- **A regex shape check is NOT a validity check.** Never keep a separate
  shape-only gate; validate *through the parser used for conversion*
  (`utils.date_to_timestamp()` in `freezer/utils/utils.py`). Parse with
  `strptime`, round-trip through `strftime` so impossible calendar dates
  (`2014-99-99T99:99:99`, `2014-02-31`) and unpadded fields are rejected.
- Invalid dates raise `DateException` from `freezer/exceptions/utils.py` — never
  a bare `Exception`.

## Numbers (days, sizes, limits)

- `float()` accepts `'inf'`, `'nan'`, and `float(True) is 1.0`. Always gate with
  `math.isfinite()`, a sign check, and explicit `bool` rejection.
- Huge finite values can still overflow `datetime.timedelta` / `time.mktime`:
  perform the conversion *at validation time* so overflow surfaces as a clean
  error, not a crash at execution.
- `int()` truncates floats, accepts booleans, and strips whitespace — do not
  build permissive `int()`-based gate helpers.

## Combinations

- Enforce "exactly one" exclusive groups: zero *or more than one* option is an
  error (dates plus days together are ambiguous — reject, don't silently pick
  priority).

## Supplied-ness

- `if x:` conflates *absent* with *falsy*. Use `is not None` to detect whether a
  config value was provided, so `''` or `0` are validated, not ignored.

## Ordering

- Validate all input BEFORE expensive or side-effecting setup (client/auth
  creation), so errors are cheap and unambiguous.

## Tests to write alongside

- Non-finite numbers (inf/nan), huge finite overflow, negatives, whitespace,
  bools, impossible calendar dates, missing option, conflicting combinations,
  and a test proving an invalid value fails before any cloud client is created.