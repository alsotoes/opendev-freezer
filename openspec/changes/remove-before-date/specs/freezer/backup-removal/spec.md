## Repo Layout

This change targets the freezer-agent repository only. File paths written as
`freezer/...` resolve to `code/freezer/freezer/...` in this umbrella repo.

## Purpose

Defines how Freezer removes old backups when an administrator requests removal by
datetime cutoff, and the strict input-validation contract each removal option must
satisfy before any backup is deleted.

## ADDED Requirements

### Requirement: Removal options and priority
Freezer SHALL remove backups older than a cutoff computed from exactly one of the
removal options: `remove_before_date`, `remove_from_date`, or `remove_older_than`.
When more than one removal option is supplied, the job MUST be rejected.

#### Scenario: Only remove_before_date supplied
- **WHEN** an admin supplies only `--remove-before-date`
- **THEN** Freezer removes backups created before that datetime

#### Scenario: Multiple removal options supplied
- **WHEN** an admin supplies both `--remove-before-date` and `--remove-from-date`
- **THEN** Freezer rejects the request with an error and removes nothing

#### Scenario: Removal date and days supplied together
- **WHEN** an admin supplies `--remove-before-date` or `--remove-from-date`
  together with `--remove-older-than`
- **THEN** Freezer rejects the request with an error naming the conflicting
  options and removes nothing

#### Scenario: No removal option supplied
- **WHEN** an admin runs an admin action with none of the removal options set
- **THEN** Freezer rejects the request with an error naming the expected options

### Requirement: ISO datetime validation
A `remove_before_date` or `remove_from_date` value MUST be a canonical ISO datetime
in the form `YYYY-MM-DDTHH:MM:SS` that is also a valid calendar datetime.
Any other value (wrong shape, space separator, unpadded fields, or an impossible
calendar date such as `2014-99-99T99:99:99` or `2014-02-31T23:23:23`) MUST be
rejected before any backup is removed.

#### Scenario: Valid ISO datetime accepted
- **WHEN** an admin supplies a value matching `YYYY-MM-DDTHH:MM:SS`
- **THEN** Freezer accepts the option and removes backups older than that datetime

#### Scenario: Malformed datetime rejected
- **WHEN** an admin supplies a value that does not match the canonical ISO format
- **THEN** Freezer rejects the request with a clear error and removes nothing

#### Scenario: Impossible calendar date rejected
- **WHEN** an admin supplies a value that matches the shape but is not a valid
  calendar datetime (e.g. month 99, or day 31 in a 30-day month)
- **THEN** Freezer rejects the request with a clear error and removes nothing

### Requirement: remove_older_than must be numeric
A `remove_older_than` value MUST be a finite, non-negative number of days that also
produces a valid cutoff timestamp. Infinity, NaN, negatives, and values too large to
represent as a timestamp MUST be rejected before any backup is removed.

#### Scenario: Valid number of days accepted
- **WHEN** an admin supplies a numeric `--remove-older-than`
- **THEN** Freezer removes backups older than that many days

#### Scenario: Non-numeric value rejected
- **WHEN** an admin supplies a non-numeric `--remove-older-than`
- **THEN** Freezer rejects the request with a clear error and removes nothing

#### Scenario: Infinite or NaN value rejected
- **WHEN** an admin supplies `inf` or `nan` as `--remove-older-than`
- **THEN** Freezer rejects the request with a clear error and removes nothing

#### Scenario: Negative value rejected
- **WHEN** an admin supplies a negative `--remove-older-than`
- **THEN** Freezer rejects the request with a clear error and removes nothing

#### Scenario: Boolean value rejected
- **WHEN** an admin supplies a boolean as `--remove-older-than`
- **THEN** Freezer rejects the request with a clear error and removes nothing

#### Scenario: Unrepresentable value rejected
- **WHEN** an admin supplies a finite but extremely large `--remove-older-than`
  that cannot be converted into a valid timestamp
- **THEN** Freezer rejects the request with a clear error and removes nothing

### Requirement: Input validation precedes any setup
Freezer MUST validate all removal inputs before creating any cloud client or
performing auth-related setup.

#### Scenario: Invalid input fails before client creation
- **WHEN** an admin supplies an invalid removal option
- **THEN** Freezer rejects the request without creating any cloud client

### Requirement: Deprecated remove_from_date remains functional
The `remove_from_date` option MUST remain functional for backward compatibility
while being marked deprecated, and MUST behave identically to `remove_before_date`.

#### Scenario: Deprecated option still removes backups
- **WHEN** an admin supplies only a valid `--remove-from-date`
- **THEN** Freezer removes backups created before that datetime and emits a
  deprecation notice

### Requirement: Removal during backup and restore actions

When a backup or restore job has a removal option set, Freezer MUST run removal
after the primary job completes, using the same removal execution path as
`--action admin`. The removal MUST NOT run before the primary job, because the
newly-created backup's timestamp (if a backup) would be subject to the cutoff.

#### Scenario: Backup with remove_older_than triggers removal
- **WHEN** a user runs `--action backup --remove-older-than 1`
- **THEN** Freezer completes the backup and then removes backups older than 1 day

#### Scenario: Backup without removal option skips removal
- **WHEN** a user runs `--action backup` with no removal option
- **THEN** Freezer completes the backup and does not run removal

#### Scenario: Admin action does not double-run removal
- **WHEN** a user runs `--action admin --remove-older-than 1`
- **THEN** Freezer runs removal exactly once via the AdminJob dispatch

### Requirement: Swift storage directory listing handles both files and directories

Swift's `get_container` with `delimiter='/'` returns both pseudo-directory entries
(with a `subdir` key) and file entries (with a `name` key). Freezer's `listdir` MUST
handle both key types, extracting the leaf component regardless of which key is
present, so that a single stray object in a metadata path does not silently abort the
entire listing.

#### Scenario: Metadata path with only subdirs is listed correctly
- **WHEN** the metadata path contains only level-zero timestamp subdirectories
- **THEN** `listdir` returns the set of those timestamps

#### Scenario: Mixed subdirs and files are listed correctly
- **WHEN** the metadata path contains both subdirectories and a stray file
- **THEN** `listdir` returns both directory names and the file name

#### Scenario: listing error returns empty set
- **WHEN** `get_container` raises an exception
- **THEN** `listdir` returns an empty set and logs the error

### Requirement: Swift storage removal paginates beyond 10000 objects

Swift's `get_container` returns at most 10000 objects per request without
pagination. Freezer's `rmtree` MUST pass `full_listing=True` so that backups
with more than 10000 segments are fully deleted.

#### Scenario: Large backup segments fully deleted
- **WHEN** a backup has more than 10000 objects under its data prefix
- **THEN** `rmtree` deletes all of them (not just the first page)