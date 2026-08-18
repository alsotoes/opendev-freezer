---
description: Run the Freezer umbrella readiness/sync audit (scripts/audit.sh). Invoke before proposing changes or after any config/docs edit.
---

Run the umbrella audit and report which checks passed/failed:

```bash
bash scripts/audit.sh
```

Exit nonzero + FAIL lines demand attention before further work: