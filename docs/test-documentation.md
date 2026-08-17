# OpenSpec and Testing for OpenStack Freezer

## Repo layout note

Test commands below run inside the `code/freezer` submodule (the agent repo), where
`.stestr.conf`, `test-requirements.txt` and the `.venv` live. Change into it first:

```bash
cd code/freezer
source .venv/bin/activate
stestr run
```

## Test Results

Reference run (historical, freezer agent suite):

```
Ran: 311 tests in 5.6891 sec.
Passed: 311
Skipped: 0
Failed: 0
```

> The exact count depends on the `code/freezer` checkout. Run `stestr run` inside
> `code/freezer/` to get the current number for your commit (current unit-tree has
> ~331 `def test_*` functions, some ddt-expanded).

## Test Coverage

The test suite covers these key areas:

### Unit Tests (reference run)

| Category | Tests | Purpose |
|----------|-------|---------|
| **Engines** | Tar, rsync, nova | Backup engine implementations |
| **Scheduler** | Coordination, job management | Distributed locking, job scheduling |
| **Storages** | Local, Swift, FTP | Storage backend implementations |
| **Snapshots** | LVM, VSS | Volume snapshot management |
| **Jobs** | Backup, restore, info | Job execution patterns |
| **Utils** | Checksum, config, streaming | Utility functions |

### Test Discovery

- **Test path**: `./freezer/tests/unit` (configured in `code/freezer/.stestr.conf`)
- **Base class**: `FreezerBaseTestCase` in `freezer/tests/commons.py`
- **Workers**: 8 parallel workers (balanced execution)

## OpenSpec Config Impact on Tests

The `openspec/config.yaml` influences the testing workflow:

### Convention Notes (from config.yaml)

These conventions affect how tests are written and reviewed:

```yaml
context: |
  ...
  Convention notes:
  - Testing via stestr with coverage
  - Code style: flake8 (ignore H405,H404,H403,H401,W504,W605)
  - Release notes generated with Oslo Reno
```

### Test Writing Guidelines

1. **Use stestr** - All tests must be discoverable by stestr
2. **Follow flake8 rules** - The ignores from config.yaml apply
3. **Include release notes** - New features require Reno release notes
4. **Coverage expected** - Tests should have adequate coverage

### Passing Tests Verification

After any code change, run:

```bash
source .venv/bin/activate
stestr run
```

Must produce:
- All tests passed (exact count varies per checkout; see historical run above)
- No unexpected failures
- Execution time within acceptable range (< 10 seconds typical)

## OpenSpec Workflow Integration

### Before Implementing a Feature

1. **Create spec proposal** in `openspec/specs/`
   - Use `openspec propose` skill
   - Reference `openspec/config.yaml` context
   - Follow `proposal` rules (500 words, Non-goals, blueprints)

2. **Run existing tests** to establish baseline:
   ```bash
   stestr run  # all unit tests pass in code/freezer
   ```

3. **Implement the feature** following OpenStack conventions:
   - Oslo config for options
   - Proper test patterns
   - Documentation updates

### After Implementation

1. **Run full test suite**:
   ```bash
   stestr run
   ```

2. **Build documentation**:
   ```bash
   tox -e docs
   ```

3. **Generate config samples** (if new options):
   ```bash
   tox -e genconfig
   ```

4. **Archive the change**:
   - Use `openspec archive-change` skill
   - References `operations` guidance in config.yaml
   - Updates release notes automatically

## Dependencies

The test suite requires these packages (installed in `.venv`):

```
hacking>=3.0.1,<3.1.0
coverage>=4.5.1
ddt>=1.0.1
stestr>=2.0.0
testtools>=2.2.0
tempest>=17.1.0 (integration)
python-openstackclient>=3.12.0
openstacksdk>=0.13.0
doc8>=0.6.0
pylint>=2.6.0
```

Plus OpenStack-specific:
- `keystoneauth1`
- `openstacksdk`
- `python-swiftclient`
- `oslo.concurrency`
- And others as needed per test module

## Troubleshooting Test Failures

### Common Issues

1. **Missing dependencies**: Install from `requirements.txt` and `test-requirements.txt`
2. **Import errors**: Ensure `.venv` is activated and all packages installed
3. **Configuration gaps**: Check `openspec/config.yaml` context for missing conventions
4. **Style violations**: Run `flake8 freezer` to check compliance

### When Tests Fail After Config Change

If modifying `openspec/config.yaml`:
1. Verify YAML is valid: `python -c "import yaml; yaml.safe_load(open('openspec/config.yaml'))"`
2. Re-run tests: `stestr run`
3. If new failures, check if convention notes need updating

## Summary

- **Unit tests must pass** via `stestr run` (see Test Results for the reference count)
- **openspec/config.yaml** provides context for AI-assisted development
- **Test workflow** integrates with spec creation and archiving
- **Documentation** must be updated alongside code changes
- **Release notes** mandatory per Oslo Reno convention