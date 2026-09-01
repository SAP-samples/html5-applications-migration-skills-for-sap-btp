---
name: appfront-migrate
description: Migrate SAP BTP HTML5 applications to the appFront (Application Frontend) deployment model. Handles migration from SAP Neo HTML5 apps, html5-apps-repo with managed approuter, and standalone approuter (approuter.nodejs with localDir routes). Supports Cloud Foundry and Kyma runtimes with XSUAA or IAS authentication. Produces updated mta.yaml, xs-app.json, and xs-security.json files. Use when the user asks to migrate, convert, or move an HTML5 app to appFront.
argument-hint: "[neo | html5-repo | standalone-approuter] [cf | kyma] [xsuaa | ias]"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, WebFetch
---

# appFront Migration Skill

## HARD RULES (NEVER VIOLATE)

1. **Never touch the source project.** All migration work happens exclusively inside `appfront-migrated/`. The source directory is read-only — never edit, delete, or overwrite any file outside `appfront-migrated/`.
2. **Never assume the auth service.** Always read `xs-security.json` (or `ias-security.json`) and every `xs-app.json` before deciding XSUAA vs IAS. The source may mix both.
3. **Never apply html5-repo migration rules to a Neo source.** Neo uses a different MTA structure (`neo-mta.yaml`, parameters-based artifacts). Check first.
4. **`HTML5Runtime_enabled: true` on a destination-service resource must be removed.** Its presence signals html5-apps-repo usage. appFront does not use this property.
5. **The `destination-content` module must be removed entirely.** This module creates instance-level destinations with service keys — a pattern only used by html5-apps-repo. appFront's deployer module binds directly to service instances.
6. **The `app-content` module's `requires` list must include all backend service instances directly.** Not via destination mapping. Credentials injected into the running approuter come from direct `requires`.
7. **Never change `xs-app.json` `authenticationType` on any route without explicit user confirmation** of the target auth service. Wrong authenticationType = 401 in production.
8. **If the source uses `sap.cloud.service` in a destination-content module**, flag this as a WorkZone integration pattern requiring additional CDM steps. Document it clearly in the migration plan and wait for user acknowledgment before proceeding.
9. **Resource and service naming must use the `sap.cloud.service` prefix (without dots).** Given prefix `P` (dots stripped):
   - Resource name: `P-<service>` (e.g. `comsapfavorites-app-front`, `comsapfavorites-xsuaa`)
   - `service-name` parameter: `P-<service>-service` (e.g. `comsapfavorites-app-front-service`)
   - Never invent arbitrary names. Never reuse the source app names. Always derive from the `sap.cloud.service` value extracted in Phase 1a-naming.
10. **Always ask for the backend URL when the backend exists.** Only emit `<<REPLACE_WITH_REAL_BACKEND_URL>>` when the user explicitly says the URL is not yet known. This placeholder is intentionally invalid — it will cause an MTA build error, forcing the user to replace it before deploying.
11. **Never add `redirect-uris` to generated `xs-security.json`.** appFront does not require them — omit the field entirely, even if the source had them.

---

## Source Type Identification (MANDATORY FIRST STEP)

Before anything else, identify the source type by examining the project structure:

**html5-apps-repo (managed approuter) indicators:**
- `mta.yaml` contains a module with `type: com.sap.application.content` and `parameters.content.subaccount.service-keys` or `parameters.content.subaccount.instances`
- A resource of type `org.cloudfoundry.managed-service` with service `html5-apps-repo` and plan `app-host`
- A resource of type `org.cloudfoundry.managed-service` with service `destination` (HTML5Runtime destination)
- `xs-app.json` routes reference destinations pointing to html5-apps-repo URLs

**SAP Neo HTML5 App indicators:**
- A `neo-mta.yaml` or `neoUpdated.mtar` artifact
- `parameters.json` with SAP Cloud Platform Neo-style properties
- No Cloud Foundry org/space references in the MTA
- HTML5 app zip artifact deployed to SAP Neo HTML5 Applications Runtime service

**WorkZone managed approuter indicators:**
- `xs-app.json` has routes with `service: "approuter-extension"` or similar Managed Approuter patterns
- `mta.yaml` module with `sap.cloud.service` in destination-content
- A `cdm.json` or similar CDM (Content Deployment Manifest) file

**Standalone approuter (localDir) indicators:**
- `mta.yaml` contains a module with `type: approuter.nodejs`
- The approuter module's `path` directory contains `xs-app.json` with routes that have `"localDir"` properties
- No `html5-apps-repo` resource anywhere in `mta.yaml`
- No `destination-content` module
- Backend destinations are injected via `group: destinations` in the approuter's `requires` block
- Typically co-located with a CAP backend (`type: nodejs`) and HDI deployer (`type: hdb`)

---

## Load Reference Index First

At the start of every migration session, load `references/INDEX.md`. This index tells you which reference files to load for each decision branch. Only load the specific reference files relevant to the current migration — do not load all of them.

## Fetching Live Documentation

Load `references/online-docs.md` at the start of every session. It contains a curated index of SAP Help Portal URLs mapped to migration phases.

**When to fetch a URL:**
- The local reference file for the current phase is marked `🔲 Placeholder` in `references/INDEX.md`
- A question arises that the local references do not clearly answer
- The user explicitly asks about official documentation

**How to fetch:**
- Use `WebFetch` with the relevant URL from `references/online-docs.md`
- Fetch only the page relevant to the current phase — do not fetch all URLs upfront
- Use the fetched content in-context only; do not write it to disk
- If the page returns no content (some SAP Help Portal pages require authentication), fall back to local references or training knowledge and inform the user

---

## Migration Workflow

### Phase 0 — Discovery (MANDATORY)

**0a — Locate the MTA root**

Determine the working directory for the migration:

```bash
# Check if mta.yaml exists in the current directory
ls mta.yaml neo-mta.yaml 2>/dev/null || echo "NOT_IN_ROOT"

# If not found, search subdirectories (up to 3 levels deep)
find . -maxdepth 3 \( -name "mta.yaml" -o -name "neo-mta.yaml" \) 2>/dev/null
```

- **If `mta.yaml` is found in the current directory**: the project root is `.`
- **If `mta.yaml` is found in a subdirectory** (e.g. `./my-project/mta.yaml`): the project root is that subdirectory. Inform the user: "I found `mta.yaml` at `./my-project/mta.yaml`. I will run the migration from that directory."
- **If no `mta.yaml` is found anywhere**: STOP. Ask the user — "I could not find an `mta.yaml` in this directory or any subdirectory. Please confirm the project path or navigate to the project root and retry."

**0b — Copy source to `appfront-migrated/`**

Immediately copy the entire source project into `appfront-migrated/` at the same level as the project root. Do this **without asking** — the source is never touched.

```bash
# SOURCE_ROOT = the project root identified in 0a (e.g. . or ./my-project)
# Copy everything, preserving structure, excluding any existing appfront-migrated folder
cp -r <SOURCE_ROOT>/. appfront-migrated/
```

If `appfront-migrated/` already exists, inform the user and ask whether to overwrite it before proceeding.

From this point on, **all file reads for analysis use the source**, and **all file writes and edits target `appfront-migrated/` exclusively**.

**0c — Source Type Detection**

Scan the **source** project for the indicators in the "Source Type Identification" section above.

```bash
# Find all mta.yaml files
find <SOURCE_ROOT> -name "mta.yaml" -o -name "neo-mta.yaml" 2>/dev/null

# Find all xs-app.json files
find <SOURCE_ROOT> -name "xs-app.json" 2>/dev/null

# Find all xs-security.json / ias-security.json files
find <SOURCE_ROOT> -name "xs-security.json" -o -name "ias-security.json" 2>/dev/null

# Check for html5-apps-repo resource type
grep -r "html5-apps-repo" <SOURCE_ROOT> --include="*.yaml" -l 2>/dev/null

# Check for standalone approuter
grep -r "approuter.nodejs" <SOURCE_ROOT> --include="*.yaml" -l 2>/dev/null

# Check for localDir routes in xs-app.json
grep -r '"localDir"' <SOURCE_ROOT> --include="*.json" -l 2>/dev/null

# Check for Neo indicators
find <SOURCE_ROOT> -name "neo-mta.yaml" -o -name "parameters.json" 2>/dev/null
```

Document your findings: `Source type: [neo | html5-repo | managed-approuter | standalone-approuter]`

**0d — Target Runtime and Auth Service**

Ask the user these BLOCKING questions **one at a time**. Wait for the answer before asking the next. Present choices as a numbered list so the user can reply with a number.

**Question 1 — Source type** (confirm or correct your detection from 0c):
> I detected the source type as **[detected type]**. Is that correct?
> 1. Yes, that's correct
> 2. No — it's Neo
> 3. No — it's html5-repo (managed approuter)
> 4. No — it's standalone approuter

**Question 2 — Target runtime:**
> Which runtime should the migrated app deploy to?
> 1. Cloud Foundry (CF)
> 2. Kyma

**Question 3 — Auth service:**
> Which auth service should the migrated app use?
> 1. XSUAA
> 2. IAS
> 3. Keep existing (same as source)

**Question 4 — Backend type** (ask for each backend destination found in `xs-app.json` / `neo-app.json`, one at a time — skip `ui5` and `test-resources`):

For each destination `<dest-name>`:
> What type of backend is **`<dest-name>`**?
> 1. SAP BTP backend (same BTP subaccount — CF app, CAP service, etc.)
> 2. External / on-prem backend (outside BTP, or a different BTP subaccount)
> 3. No backend (frontend-only app — skip destinations entirely)

**Destination methodology based on backend type:**

- **BTP backend (answer 1):**
  - Use a **configuration destination** — defined in the deployer module's `parameters.config.destinations` block in `mta.yaml`
  - **No destination service resource needed** in `mta.yaml`
  - Set `forwardAuthToken: true` on the destination entry
  - Ask for the backend URL:
    > What is the URL for **`<dest-name>`**? (e.g. `https://myapp.cfapps.eu12.hana.ondemand.com`)

- **External / on-prem backend (answer 2):**
  - Use a **destination service resource** in `mta.yaml` (`service: destination`, `service-plan: lite`)
  - Define the destination in `init_data.subaccount.destinations` with `Authentication: NoAuthentication` — **do not ask for or configure authentication credentials**; the user will add them later in the BTP Cockpit
  - Ask for the backend URL (use `<<REPLACE_WITH_REAL_BACKEND_URL>>` only if the user explicitly says the URL is not yet known):
    > What is the URL for **`<dest-name>`**? (leave blank if not yet known)
  - If blank, emit `<<REPLACE_WITH_REAL_BACKEND_URL>>` as the URL value

**Question 5 — Backend migration status** (ask only for BTP backends where the URL is not yet known):
> Has the BTP backend for **`<dest-name>`** already been deployed?
> 1. Yes — already deployed (I will provide the URL)
> 2. No — not yet deployed (use placeholder URL for now)

**Question 6 — XSUAA instance** (ask only if auth service is XSUAA):
> Should the migration create a new XSUAA service instance, or bind to an existing one?
> 1. Create a new XSUAA instance
> 2. Bind to an existing instance

If the user chooses **2 — existing instance**, ask:
> What is the name of the existing XSUAA service instance?

Then ask:
> Please list the existing scopes defined in that XSUAA instance (paste the `scopes` array from its `xs-security.json`, or list scope names). This is needed to avoid conflicts and to determine which new scopes must be added for the migrated app.

**0e — Workaround Detection**

Note any of these conditions that require special handling:
- `sap.cloud.service` in destination-content → WorkZone integration (load `references/troubleshooting/workzone-integration.md`)
- IAS-only source (`ias-security.json` present, no `xs-security.json`) → IAS migration path (load `references/services/ias-config.md`)
- Multiple `xs-app.json` files → multi-module app (document all modules)
- Kyma target → load `references/target-configs/kyma-deployment.md`

---

### Phase 1 — Baseline Analysis (MANDATORY)

Read from the **source** project and document the current state. All analysis is read-only against the source.

**1a — Read all configuration files:**
- All `mta.yaml` files (full content)
- All `xs-app.json` files (full content of each)
- `xs-security.json` or `ias-security.json` (full content)
- All `manifest.json` files (extract `sap.cloud.service` — see naming convention below)
- **For Neo sources: `neo-app.json`** (full content — extract `routes`, `welcomeFile`, and all `securityConstraints` entries)

**1a-naming — Extract `sap.cloud.service` for resource naming (MANDATORY)**

Run:
```bash
# Handles both flat "sap.cloud.service" and nested "sap.cloud": { "service": ... } formats
grep -r '"service"' . --include="manifest.json" -A2 -B2 | grep -A1 '"sap.cloud"'
# Also try:
grep -r 'sap\.cloud' . --include="manifest.json" -l
```

Read each matching `manifest.json` and locate the value at `sap.cloud.service` (either as a flat key or nested under `"sap.cloud": { "service": "..." }`).

Then:
1. Collect all `sap.cloud.service` values found across all `manifest.json` files.
2. **If multiple values differ** — STOP. All apps in the same MTA must share one `sap.cloud.service`. Report the conflict and ask the user which value to use.
3. **If no `sap.cloud.service` is found (always the case for Neo sources)** — this is expected for Neo apps. Explain the concept and ask:
   > "`sap.cloud.service` does not exist in Neo. In appFront, this value defines a **business solution** — a logical grouping of one or more HTML5 apps sharing a single XSUAA instance and a single `app-front` service instance.
   >
   > **Are you migrating this app as part of a larger group of Neo apps that belong to the same product or team?**
   > 1. No — migrate this app as a standalone solution
   > 2. Yes — I want to group multiple Neo apps into one business solution (mass migration)
   >
   > In either case, please provide a `sap.cloud.service` value for this solution (e.g. `com.sap.myteam`, `com.company.hr`). Choose a namespace that represents the whole product, not just this single app."

   If the user chooses **mass migration (option 2)**, ask:
   > "Please list all the Neo app directories (or paths) you want to include in this business solution. I will create a single `mta.yaml` with one deployer module and one shared XSUAA instance for all of them."
   Then follow the mass migration pattern in `references/migration-guides/neo-to-appfront.md` (Mass Migration section).

4. Strip all dots from the value to form the **naming prefix** (e.g. `com.sap.favorites` → `comsapfavorites`).

Use this prefix for ALL resource and service names in the migrated `mta.yaml` (see Hard Rule #9 below).

**1b — Build a Findings Table:**

| Item | Current Value | Migration Action Needed |
|------|--------------|------------------------|
| MTA modules | List each module name and type | |
| Resources | List each resource name and service | |
| html5-repo app-host resource | Present / Absent | Remove if present |
| destination-content module | Present / Absent | Remove if present |
| HTML5Runtime_enabled flag | Present / Absent | Remove if present |
| xs-app.json authenticationMethod | value | Keep / Change |
| Route authenticationType | List each | Keep / Change per route |
| sap.cloud.service usage | Present / Absent | Flag for WorkZone steps |
| Neo securityConstraints (Neo sources only) | List each `permission` value from all `securityConstraints` entries in `neo-app.json` | Map each to a XSUAA scope in `xs-security.json` |

**1c — Load source-type reference:**
- html5-repo source → load `references/source-types/html5-repo-app.md` (modeling type identification), `references/source-types/saas-approuter-creds-handling.md` (full credential chain details for the detected type), and `references/migration-guides/html5-repo-to-appfront.md`
- Neo source → load `references/source-types/neo-html5-app.md` and `references/migration-guides/neo-to-appfront.md`
- Standalone approuter source → load `references/source-types/standalone-approuter.md` and `references/migration-guides/standalone-approuter-to-appfront.md`
- Load the relevant target config reference: `references/target-configs/cf-xsuaa-mta.yaml.md` or `references/target-configs/cf-ias-mta.yaml.md` or `references/target-configs/kyma-deployment.md`

---

### Phase 2 — Migration Plan Checkpoint (MANDATORY — no changes to `appfront-migrated/` before user confirms)

The source has already been copied to `appfront-migrated/`. Now present the exact changes that will be applied inside `appfront-migrated/` to complete the migration:

**Files to MODIFY in `appfront-migrated/`:**
| File | Changes |
|------|---------|
| `mta.yaml` | List exact changes: modules to add/remove/modify, resources to add/remove/modify |
| `xs-app.json` | List exact property changes |
| `xs-security.json` | List exact changes (or "no changes needed") |

**Files to DELETE from `appfront-migrated/`:**
| File | Reason |
|------|--------|
| (list files if any) | |

**Files to CREATE in `appfront-migrated/`:**
| File | Content |
|------|---------|
| (list new files needed, e.g. Kyma yaml files) | |

**WorkZone / CDM steps required:** (list if applicable)

Then present this plan to the user and ask:

> **Does this migration plan look correct? Should I proceed with these changes? (yes to continue / no to adjust)**

⛔ **STOP HERE until the user explicitly says yes.** Do not modify any file in `appfront-migrated/` before receiving confirmation.

---

### Phase 3 — Execute Migration

Only proceed after Phase 2 confirmation.

**3a — Update mta.yaml**

For **Neo** → appFront (CF) migration, **first load and read `references/migration-guides/neo-to-appfront.md`** in full, then create `mta.yaml` from scratch following its Step 4 template exactly:
- The MTA **must** contain an `app-front` resource (`service: app-front`, `service-plan: developer`) — **never** `html5-apps-repo app-host`
- The `app-content` deployer module requires the `app-front` resource with `content-target: true`, plus XSUAA and destination resources
- Add `deploy_mode: html5-repo` to the MTA root `parameters` block
- **Destination configuration** — apply the methodology determined in Phase 0d Question 4:
  - **BTP backend → configuration destination:** add a `parameters.config.destinations` block to the deployer module with `forwardAuthToken: true` and the backend URL. Do NOT add a destination service resource.
  - **External/on-prem backend → destination service resource:** add `comsaplibrary-destination` resource (`service: destination`, `service-plan: lite`) with `init_data.subaccount.destinations` containing one entry per external destination (`Authentication: NoAuthentication`, URL from user or placeholder). Do NOT configure credentials — they are added later in the BTP Cockpit.
  - The `ui5` entry (`https://ui5.sap.com`) always goes in `config.destinations` on the deployer module regardless of backend type — it is never in the destination service `init_data`.
- Replace `html5-apps-repo` `app-host` resource with `app-front` resource (service: `app-front`, plan: `developer` — always use `developer`, never any other value)
- Remove the `destination-content` module entirely
- In the `app-content` module (renamed to `app-front-deployer` or similar):
  - Change `type` from `com.sap.application.content` to `com.sap.application.content` (type stays, but parameters change)
  - Remove `parameters.content.subaccount.service-keys` entries referencing html5-repo destinations
  - Add `requires` entries for each service instance the app needs credentials from (XSUAA, backend OData service, etc.)
  - Remove `HTML5Runtime_enabled: true` from destination resource parameters
- Keep the destination service resource **only** for external/on-prem backends (as determined in Phase 0d Question 4). BTP backends use `config.destinations` on the deployer module — no destination service resource needed.

For **standalone approuter (localDir)** → appFront (CF) migration, apply these structural changes:
- **Remove** the `approuter.nodejs` module entirely
- **Add** an HTML5 source module (`type: html5`) for each UI app directory that was served via `localDir`
- **Add** an `app-content` deployer module (`type: com.sap.application.content`) with:
  - `requires` entries for XSUAA and any other bound services (the credentials injected into appFront)
  - `content-target: true` on the `app-front` resource reference
  - `config.destinations` block listing backend API destinations (replaces the `group: destinations` from the old approuter `requires`)
- **Add** an `app-front` resource (`service: app-front`, `service-plan: developer`)
- **Keep** the CAP backend (`type: nodejs`), HDI deployer (`type: hdb`), XSUAA resource, and HANA resource completely unchanged
- Load `references/migration-guides/standalone-approuter-to-appfront.md` for the complete step-by-step guide with annotated before/after examples

Load `examples/appfront-target-mta-xsuaa.yaml` or `examples/appfront-target-mta-ias.yaml` as the canonical target reference.

**3a-neo-cleanup — Neo source pre-processing (Neo sources only)**

Before making any other changes to `appfront-migrated/`, apply these Neo-specific cleanup steps:

1. **Handle `-dbg.js` files** — Neo cockpit exports without source access produce both a minified file and a `-dbg.js` debug copy in `controller/` (and other folders). The `-dbg.js` file is the full source; the non-debug counterpart is incomplete or minified. Fix this:
   - Scan for all `*-dbg.js` files: `find appfront-migrated/ -name "*-dbg.js"`
   - For each `-dbg.js` file found: delete the corresponding non-debug `.js` file (same name without `-dbg`), then rename the `-dbg.js` file by removing the `-dbg` suffix
   - On macOS/Linux run:
     ```bash
     for f in $(find appfront-migrated/ -name "*-dbg.js"); do
       base="${f%-dbg.js}.js"; rm -f "$base"; mv "$f" "$base"
     done
     ```
   - On Windows, perform the equivalent rename manually or via PowerShell

2. **Update `manifest.json` `_version`** — Neo apps commonly have `"_version": "1.1.0"` or `"1.2.0"`. Update to:
   ```json
   "_version": "1.65.0"
   ```

3. **`build:cf` script** — The `package.json` `build:cf` script must only contain `ui5 build --dest dist`. Use `ui5-task-zipper` in `ui5.yaml` (with `additionalFiles: [xs-app.json]`) to package `xs-app.json` into the zip cross-platform. Do NOT use shell commands for copying or zipping — `cp`, `zip -r`, and `mv` fail on Windows.

**3b — Update xs-app.json**

- For routes serving static HTML5 content: add `"service": "app-front"` property
- **For standalone approuter sources**: replace every `"localDir"` route property with `"service": "app-front"`. The `localDir` key must be removed entirely — it is not a valid property in appFront's xs-app.json and will be silently ignored, causing 404s on static content
- **For Neo sources**: **load and read `references/migration-guides/neo-to-appfront.md`** then create `xs-app.json` from scratch following its Step 6 template exactly. The file **must** include:
  1. `/resources` and `/test-resources` routes pointing to the `ui5` destination with `authenticationType: none`
  2. One route per backend destination from `neo-app.json` with `authenticationType: xsuaa` and the matching `scope`
  3. A catch-all route `^(.*)$` with `"service": "app-front"` — **never omit this**, it is what serves the static app content
  - Remove all Neo-specific route types (`type: application` with `name: sapui5preview`, `type: service` with `name: sapui5`)
- Ensure `authenticationMethod` at root matches the target auth service (XSUAA = `"route"`, IAS varies)
- For routes with `authenticationType`: confirm with user which routes should be `"xsuaa"`, `"ias"`, or `"none"` before changing
- Load `references/target-configs/xs-app-patterns.md` for the correct pattern per auth service

**3c — Update xs-security.json (if auth service changes)**

- XSUAA → IAS switch: the `xsappname` field moves to IAS application, scopes/role-templates may need restructuring
- Load `references/services/xsuaa-config.md` (XSUAA) or `references/services/ias-config.md` (IAS) for exact patterns

**3d — Kyma-specific files (if target is Kyma)**

Load `references/target-configs/kyma-deployment.md` and create:
- `ServiceInstance.yaml` for app-front service
- `ServiceBinding.yaml` for credential mounting
- `APIRule.yaml` for routing
- `Function.yaml` or deployment yaml for the app content

---

### Phase 4 — Critic Review (MANDATORY)

Before writing the final report, spawn a critic sub-agent using the Task tool with this prompt:

```
You are a migration critic reviewing a completed SAP appFront migration. The user has just migrated an HTML5 application from [SOURCE_TYPE] to appFront on [TARGET_RUNTIME] with [AUTH_SERVICE] auth.

Review the migration against these checks. For each check, say PASS, WARN, or FAIL and explain briefly:

1. SERVICE REMOVAL (html5-repo source only): Were all three html5-repo components removed?
   - destination-content module (should not exist in migrated mta.yaml)
   - html5-apps-repo app-host resource (should not exist)
   - HTML5Runtime_enabled: true on destination service parameters (should not exist)

2. REQUIRES COMPLETENESS: Does the app-content / app-front-deployer module's `requires` block include ALL service instances the app binds to for credentials? (XSUAA, backend services, etc.)

3. XS-APP CONSISTENCY:
   - Do static content routes have `"service": "app-front"`?
   - Does the root `authenticationMethod` match the intended auth service?
   - Is `authenticationType` consistent per route?
   - (standalone-approuter source) Are ALL `"localDir"` entries removed? Any remaining `localDir` causes silent 404s.

4. AUTH FLOW: If switching to IAS, does xs-security.json need structural changes that were NOT addressed (missing oauth2-configuration, wrong xsappname format, etc.)?

5. KYMA COMPLETENESS (if Kyma target): Are ServiceInstance, ServiceBinding, APIRule, and Function/Deployment yaml all present and correctly referencing each other?

6. DESTINATION RESIDUE: Are there any remaining references to `sap.cloud.service`, `HTML5Runtime_enabled`, or html5-repo destination URL patterns that would break with app-front?

7. STANDALONE APPROUTER CONVERSION (standalone-approuter source only):
   - Is the `approuter.nodejs` module completely removed from the migrated mta.yaml?
   - Is `group: destinations` fully converted to `config.destinations` in the deployer module?
   - Does the new HTML5 module (`type: html5`) have a valid build configuration (package.json with build:cf script, ui5.yaml)?

Return a table: Check | Result | Details
Then list any FAIL or WARN items as ACTION REQUIRED.
```

After the critic returns, address every FAIL and WARN before writing Phase 5. If the critic finds issues, go back and fix them, then re-run the critic.

---

### Phase 5 — Post-Migration Report

**5a — Persist the summary**

Before presenting the report to the user, write it to disk:

```bash
mkdir -p .claude/appfront
```

Use the current timestamp as the filename (format `YYYYMMDD-HHmmss`):
```bash
date +"%Y%m%d-%H%M%S"
```

Write the full summary to `.claude/appfront/<timestamp>-migration.md`. The file must contain all sections below (Migration Summary table, build/deploy outcome, runtime URL if available, WorkZone steps, known issues).

---

Produce a final summary:

**Migration Summary**
| | Before | After |
|--|--------|-------|
| Deployment model | html5-apps-repo / Neo | appFront |
| Runtime | (original) | CF / Kyma |
| Auth service | (original) | XSUAA / IAS |
| Files modified | — | List |
| Files deleted | — | List |
| Files created | — | List |

**Build & Deploy**

Ask the user **once**:
> **Would you like to build and deploy the migrated project now?**

⛔ If the user says yes, **do not ask any further confirmation questions** for the build and deploy steps — run `mbt build`, `cf deploy`, `afctl login`, and `afctl list` sequentially without additional prompts. The original project is never touched, so no additional confirmation is needed.

If yes, guide them through:

```bash
# 1. Build the MTA archive
mbt build

# 2. Deploy to CF
cf deploy <project-name>.mtar
```

After a successful deployment, use the appFront CLI to fetch the runtime URL:

**Step 1 — Check if afctl is installed:**
```bash
afctl --version 2>/dev/null || echo "NOT_INSTALLED"
```
If not installed, prompt the user:
```bash
npm install -g @sap/appfront-cli
```

**Step 2 — Prerequisites: BTP role assignment**

Before logging in, the user must be assigned the **`af_rc` role collection** as an Application User in the SAP BTP Cockpit. Remind the user:
> **Make sure you have been assigned the `af_rc` role collection in BTP Cockpit.** Without it, the login will succeed but operations will be rejected. If you are unsure, ask your BTP subaccount administrator.

**Step 3 — Log in to appFront CLI:**

Ask the user:
> **Please provide your appFront API endpoint URI.** You can find it in the SAP BTP Cockpit by opening your subscribed Application Frontend application — it is displayed on the welcome page under "Application Frontend CLI", for example:
> `https://api.eu12.dt.appfront.cloud.sap?apptid=d3229742-dc50-4cd0-8ea9-0a07f8e7b5a5`

Once the user provides the URI, log in using SSO (recommended — avoids typing credentials in the terminal):
```bash
afctl login -a <provided-uri> --sso
```
This opens a browser window for SSO authentication. After completing the browser login, the CLI session is established.

**Step 4 — Fetch the runtime URL:**
```bash
afctl list <app-name>
```
Present the runtime URL from the output to the user so they can open the application.

---

**Cleanup (optional)**

Ask the user:
> **Would you like to clean up the migrated deployment and remove all generated files?**

If yes, ask a second confirmation:
> **Should service instances and service keys also be deleted? This will permanently remove all provisioned services (e.g. app-front, xsuaa). This cannot be undone.**

- **If the user says no to deleting services:**
  ```bash
  cf undeploy <mta-id>
  ```

- **If the user says yes to deleting services and keys:**
  ```bash
  cf undeploy <mta-id> --delete-services --delete-service-keys
  ```

After a successful undeploy, remove the migrated output folder:
```bash
rm -rf appfront-migrated/
```

⛔ **Do NOT run the cleanup commands automatically.** Only execute after both confirmations above are received from the user.

---

**WorkZone Steps Required** (if applicable)
List any CDM/site assignment steps the user must complete manually.

**Known Issues / Next Steps**
Any outstanding items flagged during migration that require user action.

---

## Reference Files

| File | Description | Load When |
|------|-------------|-----------|
| `references/INDEX.md` | Full index of all reference files | Always, at start |
| `references/online-docs.md` | Curated SAP Help Portal URLs by migration phase | Always, at start — fetch live docs when local references are placeholders |
| `references/overview/appfront-architecture.md` | What appFront is and how it works | Phase 0, first time using this skill |
| `references/overview/appfront-vs-html5repo.md` | Side-by-side comparison table | Phase 1, when user asks "why migrate?" |
| `references/overview/migration-decision-tree.md` | Which migration path to take | Phase 0b, when source/target unclear |
| `references/source-types/html5-repo-app.md` | html5-repo source structure details | Phase 1, when source is html5-repo |
| `references/source-types/neo-html5-app.md` | Neo HTML5 app structure details | Phase 1, when source is Neo |
| `references/source-types/standalone-approuter.md` | Standalone approuter source: localDir routes, MTA group injection, CAP backend wiring | Phase 1, when source is standalone-approuter |
| `references/migration-guides/html5-repo-to-appfront.md` | Step-by-step html5-repo migration guide | Phase 1 and Phase 3, html5-repo source |
| `references/migration-guides/neo-to-appfront.md` | Step-by-step Neo migration guide | Phase 1 and Phase 3, Neo source |
| `references/migration-guides/standalone-approuter-to-appfront.md` | Step-by-step standalone approuter (localDir) migration guide | Phase 1 and Phase 3, standalone-approuter source |
| `references/migration-guides/managed-approuter-to-appfront.md` | WorkZone managed approuter variant | Phase 1, WorkZone source |
| `references/target-configs/cf-xsuaa-mta.yaml.md` | Canonical CF + XSUAA target mta.yaml | Phase 3, CF+XSUAA target |
| `references/target-configs/cf-ias-mta.yaml.md` | Canonical CF + IAS target mta.yaml | Phase 3, CF+IAS target |
| `references/target-configs/kyma-deployment.md` | Kyma deployment artifacts guide | Phase 3d, Kyma target |
| `references/target-configs/xs-app-patterns.md` | xs-app.json patterns per auth service | Phase 3b |
| `references/services/xsuaa-config.md` | xs-security.json patterns and scopes | Phase 3c, XSUAA auth |
| `references/services/ias-config.md` | IAS security config patterns | Phase 3c, IAS auth |
| `references/services/app-front-service.md` | appFront service plans and binding | Phase 3a, always |
| `references/services/destination-service.md` | When destination service is still needed | Phase 3a, if keeping backend destinations |
| `references/golden-path/golden-path-overview.md` | SAP Golden Path concept | Phase 0b, if backend is BTP |
| `references/golden-path/cap-backend-mta.yaml.md` | CAP + appFront full MTA example | Phase 3, CAP backend |
| `references/golden-path/fiori-elements-setup.md` | Fiori Elements manifest.json setup | Phase 3, Fiori Elements UI |
| `references/troubleshooting/known-issues.md` | Compatibility matrix and known blockers | Phase 4, if critic finds issues |
| `references/troubleshooting/workzone-integration.md` | CDM, site assignment, role collections | Phase 0c, if WorkZone detected |
| `references/troubleshooting/deployment-errors.md` | Common deploy failures post-migration | Phase 5, if deploy fails |

---

## Known Migration Issues

| Issue | Source Type | Condition | Workaround |
|-------|-------------|-----------|-----------|
| WorkZone CDM breaks after migration | html5-repo | `sap.cloud.service` present in source | See `references/troubleshooting/workzone-integration.md` |
| 401 on all routes after migration | any | `authenticationMethod` or `authenticationType` mismatch in xs-app.json | Verify xs-app.json against `references/target-configs/xs-app-patterns.md` |
| MTA build fails: unknown resource type | html5-repo | residual `html5-apps-repo` resource not removed | Remove `app-host` resource and all `requires` references to it |
| 404 on all static content | standalone-approuter | `"localDir"` routes not converted to `"service": "app-front"` | Replace all `"localDir"` entries with `"service": "app-front"` in xs-app.json |
| Backend 502 after migration | standalone-approuter | `group: destinations` not converted to `config.destinations` | Add `config.destinations` block in deployer module with backend URL `~{srv-api/srv-url}` |
| `mbt build` fails: artifact not found | standalone-approuter | HTML5 module missing `package.json` or `build:cf` script | Add `package.json` with `"build:cf": "ui5 build --dest dist"` and `ui5.yaml` to app directory |
| Duplicate approuter CF app deployed | standalone-approuter | `approuter.nodejs` module left in migrated mta.yaml | Remove the `approuter.nodejs` module entirely from migrated mta.yaml |
| Destination service created unnecessarily | any | BTP backend used config.destinations but destination service resource was also added | Remove destination service resource from mta.yaml — config.destinations is self-contained, no service instance needed |
| Build fails on Windows | Neo | `build:cf` script uses shell commands (`cp`, `zip`, `mv`) that are not available on Windows | Use `"build:cf": "ui5 build --dest dist"` only — mbt handles the rest |
| App shows blank or broken UI after deploy | Neo | `-dbg.js` files present in controller folder; minified counterparts are incomplete | Delete non-debug `.js` files and rename `-dbg.js` → `.js` before deploying (see 3a-neo-cleanup) |
| `manifest.json` version validation error | Neo | `_version` is too old (e.g. `1.1.0`) for CF runtime | Update `_version` to `"1.65.0"` in `manifest.json` |
| (populate from your team's experience) | | | |
