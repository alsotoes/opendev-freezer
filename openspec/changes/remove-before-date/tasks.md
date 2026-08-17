## Repo Layout

This change targets the freezer-agent repository only. File paths written as
`freezer/...` resolve to `code/freezer/freezer/...` in this umbrella repo.

## 1. Config option

- [x] 1.1 Add `remove_before_date: None` to `freezer/common/config.py`
- [x] 1.2 Add `remove_before_date` StrOpt and mark `remove_from_date` with
  `deprecated_for_removal=True`

## 2. Date utilities

- [x] 2.1 Add `DateException` to `freezer/exceptions/utils.py`
- [x] 2.2 Update `date_to_timestamp()` to raise `DateException` on
  `ValueError`/`TypeError`/`OverflowError`/`AttributeError`; this is the single
  ISO-date validation and parsing path

## 3. AdminJob validation and execution

- [x] 3.1 Update `AdminJob._validate()` to require exactly one removal option
- [x] 3.2 Add `_get_remove_timestamp()` and compute the cutoff once in `_validate()`,
  storing it as `self.remove_timestamp`; `execute()` re-uses it
- [x] 3.3 Guard `remove_older_than` with `float()` + `math.isfinite()` +
  non-negative check, and perform the `timedelta`/`mktime` conversion inside
  `_get_remove_timestamp()` (rejects `inf`, `nan`, negatives, and overflow)
- [x] 3.4 Update `AdminJob.execute()` to use the pre-computed `remove_timestamp`
- [x] 3.5 Move `_general_validation()`/`_validate()` before client creation in
  `Job.__init__` so invalid input fails before auth/setup

## 4. Tests

- [x] 4.1 Add `remove_before_date` fixture to `freezer/tests/commons.py`
- [x] 4.2 Add unit tests for `date_to_timestamp` (valid, invalid, extreme years)
- [x] 4.3 Add `AdminJob` validation tests (missing option, invalid dates,
  conflicting dates, non-numeric days, inf/nan/negative/overflow days, impossible
  calendar dates)
- [x] 4.4 Add tests proving validation runs before client creation and that
  `remove_timestamp` is stored and re-used
- [x] 4.5 Run full `stestr run` and confirm no regressions

## 5. Docs and release notes

- [x] 5.1 Add reno release note for `--remove-before-date`
- [x] 5.2 Update `doc/README.rst` with the new option

## 6. Deliverable

- [x] 6.1 Confirm `flake8` clean on all changed files
- [ ] 6.2 Push to Gerrit for review

## 7. Removal injection for backup and restore jobs

- [x] 7.1 Add `AdminJob` hook in `main.py run_job()` after `freezer_job.execute()`:
  inject removal for backup/restore actions when a removal option is set
  (using `is not None` checks to handle `remove_older_than=0` correctly,
  mirroring the 2016 merged fix at commit `4ef18182e0c9`)
- [x] 7.2 Verify `AdminJob(conf, storage).execute()` works with `action='backup'`
  (the non-cindernative path uses `self.storage.remove_older_than`,
  and `AdminJob._validate` only checks removal options, not action)
- [x] 7.3 Add unit tests: backup+removal triggers AdminJob, backup-only skips it,
  admin action doesn't double-trigger, `remove_older_than=0` triggers it,
  `remove_before_date` triggers it, `remove_from_date` triggers it

## 8. Swift storage removal verification

- [x] 8.1 Fix `swift.listdir()` to handle both `subdir` and `name` entries from
  `get_container`; the original `f['subdir']` access raised KeyError when
  `get_container` returned file entries, caught by the broad `except Exception`
  which silently returned `[]`, making removal appear to do nothing
- [x] 8.2 Fix `swift.rmtree()` to pass `full_listing=True` to `get_container()`
  so large backups with >10000 objects are fully deleted (without it
  swiftclient returns only the first page)
- [x] 8.3 Add unit tests covering swift `listdir` with subdir entries only, name
  entries only, mixed entries, empty entries, exceptions, and malformed entries;
  and `rmtree` with multiple objects, full_listing flag, error propagation, and
  empty listing
