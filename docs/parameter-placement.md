# Parameter Placement — where options and variables live

Analysis backing the `PARAMETER PLACEMENT` section in `openspec/config.yaml`
(classify-before-placing rules for new options). Boundaries *between* repos are
defined by FEATURE PLACEMENT in `openspec/config.yaml`; this document maps the
option surfaces *inside* the repos, as found in the upstream submodules.

## The four parameter planes

### code/freezer — three distinct surfaces

**1. Agent / job options — `freezer/common/config.py`**

- `DEFAULT_PARAMS` dict (~80 entries) holds the default values, underscore names.
- `_COMMON` list holds the oslo options (dashed CLI name → underscore `dest`).
- `get_backup_args()` (config.py:728) is the single merge point:
  `DEFAULT_PARAMS` ← CLI `CONF` ← `--config` file (dashed keys, applied via
  `CONF.set_override`, with deprecated-name fallback). It also computes the
  **derived fields** every consumer relies on: `backup_media` (decided from
  cinder/nova/glance option combinations), `work_dir`, `hostname` (defaults to
  socket hostname), `trickle_command` (bandwidth limiting), `storages`.
- Output is an opaque `FreezerConfig` namespace (`backup_args`) consumed by
  `main.py` → `BackupJob`/`RestoreJob` → engines/modes/storage.
- Extra registrations: `os_brick` group (`_OS_BRICK_GROUP`) and
  oslo.concurrency `lock_path`; oslo.log options.

**2. Scheduler daemon options — `freezer/scheduler/arguments.py`**

Registered for project `freezer-scheduler`, disjoint from the agent options:

| Group | Options |
|-------|---------|
| `[scheduler]` | client-id, no-api, jobs-dir, interval, no-daemon, insecure, disable-exec, concurrent-jobs, enable-v1-api, centralized-scheduler |
| `[capabilities]` | supported-actions / -modes / -storages / -engines (defaults mirrored in `DEFAULT_SUPPORTED_*` constants) |
| `[service_auth]` | OS_* auth options, each seeded from its environment variable |
| `[coordination]` | backend-url (tooz cluster backend) |

`[capabilities]` values flow into the API `clients.create` registration payload
(`freezer/scheduler/utils.py:do_register`) — they are node capabilities, not
daemon knobs.

**3. Job document fields — not oslo options at all**

Fields inside `job_actions[].job_action` arrive as JSON from freezer-api and are
executed by `scheduler_job.py` → Job classes. Their wire shape is owned by
freezer-api's `json_schemas.py` (see below); the agent never parses them
through oslo config.

### code/freezer-api

`freezer_api/common/config.py`:

| Group | Options |
|-------|---------|
| DEFAULT | bind-host, bind-port |
| `[storage]` | backend, driver — both `deprecated_for_removal` (Elasticsearch removed; sqlalchemy only) |
| `[centralized_scheduler]` | enabled, enforce_trusts, auth_section, trusts_delegated_roles; service_user + service_user_domain deprecated in favor of auth_section |
| `[paste_deploy]` | config_file (freezer-paste.ini) |
| `[keystone_authtoken]` | from keystonemiddleware `opts.list_auth_token_opts()` |

`freezer_api/common/json_schemas.py` is the **wire contract**: the
`job_action` properties mirror the agent's dashed option names. It is the
schema anchor every other repo must stay in sync with.

### code/python-freezerclient

No oslo config. Parameters come from CLI/OSC arguments and the environment
(`OS_BACKUP_URL`, `OS_ENDPOINT_TYPE`) resolved in `freezerclient/client.py`.
The v2 manager classes serialize payloads that must match json_schemas.

### code/freezer-web-ui

No oslo options. Panel enablement is Django settings
(`freezer_ui/enabled/_505*.py`); the API URL is resolved in
`freezer_ui/utils.py` (FREEZER_API_URL fallback via keystone). Job/session
fields are produced as plain dicts by `freezer_ui/api` wrappers on top of
python-freezerclient.

## Cross-repo ripple for a job-settable option

Adding one option (e.g. a new backup knob) touches, in one coordinated change:

1. `code/freezer` — `StrOpt` in `_COMMON` + `DEFAULT_PARAMS` entry
   (+ validation, + engine consumption).
2. `code/freezer-api` — `json_schemas.py` `job_action` property (same dashed name).
3. `code/python-freezerclient` — manager/CLI support if user-settable.
4. `code/freezer-web-ui` — workflow field if user-facing.

## Implementation mapping

| Change type | freezer | freezer-api | python-freezerclient | freezer-web-ui |
|---|---|---|---|---|
| New backup option | `_COMMON` + `DEFAULT_PARAMS` | json_schemas `job_action` | manager + CLI arg | workflow field |
| New scheduler knob | `arguments.py` group | — (unless API-mode opt) | — | — |
| New REST field | — | v2 resource + schema + migration | manager method | panel/workflow |
| New storage backend | `storage/` + `storage` choices in `_COMMON` | — | — | — |
| New capability on node | `[capabilities]` default/constants | clients schema (if shaped) | clients manager | clients panel |

## Placement rules (normative; mirrored in openspec/config.yaml)

- Classify first: job/backup semantics → agent config; daemon behavior →
  scheduler arguments; node capabilities → `[capabilities]`; anything crossing
  a repo boundary → json_schemas first.
- Validation at option definition (oslo `choices`/`min`); semantics in the
  `get_backup_args()` merge path or the engine — never in the scheduler.
- Derived values (`backup_media`, `trickle_command`) are computed only in
  `get_backup_args()`; consumers read `backup_args` and never recompute.
- python-freezerclient: no oslo config, ever — env/args only.
- freezer-web-ui: no oslo opts — Django `enabled/` files and `utils.py`
  URL resolution only.
- DB/storage backend options → freezer-api `[storage]` group; sqlalchemy
  only, do not resurrect Elasticsearch.
