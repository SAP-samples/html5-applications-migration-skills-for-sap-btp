---
name: appfront-cleanup
description: Clean up a deployed SAP appFront application. Undeploys from Cloud Foundry (optionally deleting service instances and keys), and removes the local output folder if applicable (appfront-migrated/ for migrated apps; the project folder itself for apps created from scratch). Use when the user asks to clean up, remove, or tear down an appFront app.
argument-hint: "[path/to/project]"
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep
---

# appFront Cleanup Skill

## HARD RULES (NEVER VIOLATE)

1. **Never run any destructive command without explicit user confirmation.** Every destructive step requires a separate confirmation.
2. **Never delete the source/original project directory.** Only delete the `appfront-migrated/` folder (migration output) or the scaffolded project folder (create output). Never touch the original input project.
3. **Never skip the undeploy step before deleting local files.** Always undeploy from CF first (if the app was deployed), then clean up local files.

---

## Phase 0 — Identify Project Type and Output Folder

Determine what kind of appFront project this is:

```bash
# Check for migration output folder
ls -d appfront-migrated/ 2>/dev/null && echo "MIGRATED" || echo "NOT_MIGRATED"

# Check for mta.yaml to find the MTA ID
find . -maxdepth 3 -name "mta.yaml" 2>/dev/null
```

**Project type determination:**

| Condition | Project type | Local folder to delete |
|-----------|-------------|----------------------|
| `appfront-migrated/` exists alongside original project | Migration output | `appfront-migrated/` only |
| Neither applies | Unknown — ask user | Ask user which folder to remove |

Extract the MTA ID from the relevant `mta.yaml`:
```bash
grep "^ID:" appfront-migrated/mta.yaml 2>/dev/null || grep "^ID:" mta.yaml 2>/dev/null
```

---

## Phase 1 — Undeploy from Cloud Foundry

### Step 1 — Confirm undeploy

Ask the user:
> **Should I undeploy the appFront application `<mta-id>` from Cloud Foundry?**

⛔ STOP if the user says no. Do not proceed to local file deletion without undeploying first (unless the user explicitly confirms the app was never deployed).

### Step 2 — Confirm service deletion

Ask the user:
> **Should service instances and service keys also be deleted?**
> ⚠️ This will permanently remove all provisioned services (e.g. `app-front`, `xsuaa`). **This cannot be undone.**

- **No → undeploy only:**
  ```bash
  cf undeploy <mta-id>
  ```

- **Yes → undeploy and delete services:**
  ```bash
  cf undeploy <mta-id> --delete-services --delete-service-keys
  ```

Wait for the undeploy to complete successfully before proceeding.

---

## Phase 2 — Remove Local Output Folder

Only proceed after Phase 1 completes (or user confirms app was never deployed).

Ask the user:
> **Should I also delete the local `<output-folder>` directory?**

If yes:
```bash
rm -rf <output-folder>
```

Where `<output-folder>` is:
- `appfront-migrated/` — for migration output
- The scaffolded project folder — for apps created from scratch (confirm the exact folder name with the user before deleting)

---

## Phase 3 — Cleanup Summary

**Persist the summary** before presenting it to the user:

```bash
mkdir -p .claude/appfront
date +"%Y%m%d-%H%M%S"
```

Write the full summary to `.claude/appfront/<timestamp>-cleanup.md`.

---

Report what was done:

| Action | Status |
|--------|--------|
| CF undeploy `<mta-id>` | Done / Skipped |
| Service instances deleted | Yes / No / Skipped |
| Service keys deleted | Yes / No / Skipped |
| Local folder `<output-folder>` removed | Done / Skipped |
