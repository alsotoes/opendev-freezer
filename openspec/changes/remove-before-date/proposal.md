## Repo Layout

This change targets the freezer-agent repository only. In this umbrella repo, file
paths written as `freezer/...` resolve to `code/freezer/freezer/...` (i.e. the
`freezer` package inside the `code/freezer` submodule).

## Why

Bug 1599592 tracks backup removal that does not work reliably against ISO datetime
input. The existing `--remove-from-date` option misleads users (its name implies the
opposite of its behavior) and invalid input is only caught late at execution, after
auth and job setup have occurred. Users need a clearly-named, strictly-validated way
to remove backups older than a specific datetime.

## What Changes

- Add a new `--remove-before-date` CLI argument accepting a canonical ISO datetime
  (`YYYY-MM-DDTHH:MM:SS`) that sets an explicit removal cutoff timestamp.
- Deprecate `--remove-from-date` in favor of `--remove-before-date` while keeping it
  functional and **BREAKING**-free for existing users.
- Keep `--remove-older-than N` (days) fully functional as a fallback.
- Validate all removal inputs **early** in `AdminJob._validate()`:
  - date options must match the canonical ISO format,
  - `--remove-older-than` must be numeric,
  - exactly one removal option must be supplied (zero or more than one is
    rejected, including a date plus `--remove-older-than`).
- Introduce a specific `DateException` instead of raising a bare `Exception` on
  invalid date input, and compute the cutoff timestamp once during validation so the
  value executed is exactly the value checked.

## Capabilities

### New Capabilities
- `freezer/backup-removal`: defines how freezer removes old backups from exactly
  one removal option, and the validation contract for each.

### Modified Capabilities
- (none)

## Impact

- `freezer/common/config.py`: add `remove_before_date` option, mark
  `remove_from_date` as `deprecated_for_removal`.
- `freezer/job.py`: `AdminJob._validate()` rejects zero or more than one removal
  option and computes/stores the removal cutoff via `_get_remove_timestamp()`;
  `execute()` re-uses it. Validation runs before any cloud client is created.
- `freezer/utils/utils.py`: `date_to_timestamp()` raises `DateException` and is the
  single ISO-date validation/parsing path.
- `freezer/exceptions/utils.py`: new `DateException`.
- `freezer/main.py`: after `freezer_job.execute()` for backup/restore actions,
  construct and run `job.AdminJob(conf, storage).execute()` when any removal
  option is set — this is the actual fix for the "removal during backup does
  nothing" symptom of bug 1599592.
- `freezer/storage/swift.py`: `listdir()` handles both `subdir` and `name` return
  keys from swiftclient (no longer crashes on stray file entries and silently
  returns `[]`); `rmtree()` uses `full_listing=True` so large backups with >10000
  segments are fully deleted.
- Tests: unit tests for validation, date parsing, main.py hook behavior, and Swift
  storage listdir/rmtree.
- Release notes: reno note documenting the new option and deprecation.