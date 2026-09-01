---
name: appfront-validate
description: Validate SAP appFront (Application Frontend) application configuration for correctness and deployment readiness. Checks mta.yaml structure, xs-app.json routing, xs-security.json scopes, service bindings, and CDM configuration. Use when the user asks to validate, check, or verify an appFront application.
argument-hint: "[path/to/project]"
allowed-tools: Bash, Read, Glob, Grep, WebFetch, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_fill_form, mcp__playwright__browser_click, mcp__playwright__browser_type, mcp__playwright__browser_wait_for, mcp__playwright__browser_evaluate, mcp__playwright__browser_take_screenshot
---

# appFront Application Validation Skill

Validate an appFront application — both static configuration (local files) and runtime (live deployed app via afctl + Playwright).

The skill has two modes:
- **Static only** — validates local project files (Phases 1–6). Always runs.
- **Runtime** — fetches live files from the deployed app via Playwright after login (Phase 7). Runs only if the user confirms.

---

## Validation Workflow

### Phase 1 — Project Discovery

Scan the project for all configuration files:

```bash
# Find configuration files
find . -name "mta.yaml" -o -name "xs-app.json" -o -name "xs-security.json" -o -name "ias-security.json" -o -name "manifest.json" 2>/dev/null
```

Build an inventory:
- List all found files
- Note any **missing** expected files (mta.yaml, xs-app.json — both required for a valid appFront app)
- Identify auth service type: XSUAA (`xs-security.json` present) or IAS (`ias-security.json` present)
- Identify runtime: CF (mta.yaml present) or Kyma (k8s yaml files present)

---

### Phase 2 — MTA Validation

Read `mta.yaml` and check:

| Check | Condition | Result |
|-------|-----------|--------|
| appFront resource present | A resource with `service: app-front` exists | FAIL if absent |
| appFront service plan | Plan is `developer` | WARN if any other plan name is used |
| html5-apps-repo residue | No resource with `service: html5-apps-repo` | FAIL if present |
| destination-content module absent | No module named `destination-content` or similar | FAIL if present |
| HTML5Runtime_enabled absent | No `HTML5Runtime_enabled: true` in any resource | FAIL if present |
| app-content module present | A `com.sap.application.content` module exists | FAIL if absent |
| app-content requires app-front | The deployer module `requires` the appFront resource | FAIL if missing |
| Build result path | `build-parameters.build-result` points to a directory that exists or will exist after build | WARN if path looks wrong |
| XSUAA/IAS resource present | Auth service resource is present (xsuaa or identity service) | FAIL if absent |

---

### Phase 3 — xs-app.json Validation

Read each `xs-app.json` and check:

| Check | Condition | Result |
|-------|-----------|--------|
| `welcomeFile` present | `welcomeFile` property is set | WARN if absent |
| `welcomeFile` reachable | `welcomeFile` value corresponds to a file that will be served by appFront | WARN if file not found in app directory |
| `authenticationMethod` set | Root-level `authenticationMethod` is present | WARN if absent |
| appFront service route | At least one route has `"service": "app-front"` | FAIL if absent |
| No html5-apps-repo-rt | No route has `"service": "html5-apps-repo-rt"` | FAIL if present (migration residue) |
| Route order valid | Catch-all route `^(.*)$` is the last route | WARN if not last |
| /resources route is public | Route for `/resources/` has `authenticationType: "none"` | WARN if auth on resources route (will break UI5 bootstrap) |
| No circular source/target | No route where source would match its own target | WARN if detected |
| Destination names exist | Destination names referenced in routes match destinations configured in mta.yaml or destination service | WARN if mismatch found |

---

### Phase 4 — xs-security.json / ias-security.json Validation

**For XSUAA (`xs-security.json`):**

| Check | Condition | Result |
|-------|-----------|--------|
| `xsappname` present | `xsappname` field exists and is non-empty | FAIL if absent |
| `xsappname` format | Does not contain spaces, follows `<app-id>-<qualifier>` pattern | WARN if unusual format |
| `tenant-mode` present | `tenant-mode` is `dedicated` or `shared` | WARN if absent |
| Scopes defined if routes require auth | If xs-app.json has `authenticationType: "xsuaa"` routes, scopes should be defined | WARN if empty scopes array with authenticated routes |
| Role templates valid | Each role-template references only defined scopes | FAIL if undefined scope referenced |

**For IAS (`ias-security.json`):**

| Check | Condition | Result |
|-------|-----------|--------|
| `oauth2-configuration` present | Required for IAS app registration | FAIL if absent |
| `redirect-uris` non-empty | Must contain at least one valid redirect URI | FAIL if empty |
| `grant-types` includes `authorization_code` | Required for web app login flow | WARN if absent |

---

### Phase 5 — manifest.json Validation (if present)

Read `app/*/webapp/manifest.json` or `webapp/manifest.json` and check:

| Check | Condition | Result |
|-------|-----------|--------|
| `sap.app.id` present | Application ID is defined | FAIL if absent |
| `sap.app.id` format | Follows reverse-domain notation (e.g., `com.example.myapp`) | WARN if does not contain dots |
| `dataSources` URIs | Each dataSource `uri` matches a route in xs-app.json | WARN if no matching xs-app.json route found |
| Fiori Elements dependency | If `sap.ui5.rootView` uses `sap.fe.templates`, then `sap.fe.templates` is in `sap.ui5.dependencies.libs` | WARN if missing |
| `sap.fiori.registrationIds` | Present if app is to be registered in SAP Fiori Launchpad | WARN if absent (not a hard requirement) |

---

### Phase 6 — Validation Report

Produce a structured report:

**Validation Summary**
| File | PASS | WARN | FAIL |
|------|------|------|------|
| mta.yaml | | | |
| xs-app.json | | | |
| xs-security.json | | | |
| manifest.json | | | |
| **TOTAL** | | | |

**Overall Verdict:**
- All PASS → `DEPLOYMENT READY`
- Any WARN, no FAIL → `READY WITH WARNINGS — review warnings before deploying`
- Any FAIL → `NOT READY — fix FAILs before deploying`

**FAILs (require action):**

For each FAIL:
```
[FAIL] <check name>
  File: <file>:<line if known>
  Issue: <description>
  Fix: <exact fix instruction>
```

**WARNs (recommended review):**

For each WARN:
```
[WARN] <check name>
  File: <file>
  Issue: <description>
  Recommendation: <what to consider>
```

---

## Phase 7 — Runtime Validation (Live App)

After completing Phases 1–6, ask:
> Would you like to also validate the **live deployed app** by fetching files directly from the runtime?
> 1. Yes — validate the live app
> 2. No — static validation only

If the user chooses **2**, skip this phase entirely.

---

### Phase 7a — Detect app name and fetch runtime URL via afctl

**Step 1 — Detect the deployed app name**

Read the app name from the local project:
```bash
# Try manifest.json sap.app.id first
grep -r '"id"' . --include="manifest.json" -m1 | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1

# Fall back to mta.yaml ID
grep "^ID:" mta.yaml 2>/dev/null | head -1
```

If multiple apps are found, list them and ask the user which one to validate.

**Step 2 — Check afctl login status**

```bash
afctl list -o json 2>&1
```

If the command fails with an authentication error, prompt for credentials **one field at a time**:

> What is your SAP BTP Application Frontend API server URI?
> (e.g. `https://app-front.cfapps.eu10.hana.ondemand.com`)

> What is your username (email)?

Then run (password is read securely — never echoed or stored):
```bash
read -s -p "Password: " AF_PASSWORD && echo && afctl login -a "<api-uri>" -u "<username>" -p "$AF_PASSWORD"
```

**Step 3 — Fetch the runtime URL**

```bash
afctl list "<app-name>" -o json 2>&1
```

Parse the JSON output to extract the runtime URL. The URL is the value of the `url` or `applicationUrl` field in the response. Present it to the user:
> Runtime URL: `https://...`

---

### Phase 7b — Authenticate via Playwright and fetch live files

**Step 1 — Prompt for login credentials** (securely — one at a time):

> What is your email address for the SAP login page?

Then:
```bash
read -s -p "Password (will not be echoed): " APP_PASSWORD && echo
```

Store the password only in a shell variable for the duration of this step. Never log, print, or write it to a file.

**Step 2 — Navigate and log in via Playwright**

Use the Playwright MCP tools to:
1. Navigate to the runtime URL
2. Take a snapshot to identify the login page structure
3. Fill the email field and submit
4. Fill the password field and submit
5. Wait for the app to load (detect absence of login page elements)

Handle common SAP login flows:
- SAP ID Service (IAS): email field → Next → password field → Sign In
- XSUAA / SAP Universal ID: email field → Continue → password field → Log On

If login fails (login page still visible after submit), report a FAIL and stop.

**Step 3 — Fetch runtime files**

Once authenticated, use Playwright to fetch each file by navigating to its URL:

| File | URL pattern | Purpose |
|------|-------------|---------|
| `xs-app.json` | `<runtime-url>/xs-app.json` | Routing config served at runtime |
| `manifest.json` | `<runtime-url>/manifest.json` | App descriptor served at runtime |
| `index.html` | `<runtime-url>/index.html` (or `welcomeFile` path) | Entry point |

For each file, evaluate the page content and save it:
```javascript
() => document.body.innerText
```

---

### Phase 7c — Compare runtime files to local files

For each fetched file, diff it against the local version:

| Check | PASS condition |
|---|---|
| `xs-app.json` matches local | Runtime content identical to local `xs-app.json` |
| `manifest.json` matches local | Runtime content identical to local `webapp/manifest.json` |
| `index.html` reachable | HTTP 200, non-empty content |
| `xs-app.json` is valid JSON | Parses without error |
| `manifest.json` `sap.app.id` matches local | Same value as local manifest |
| No login page content in fetched files | Files do not contain login form HTML (would indicate auth failed silently) |

Report any mismatches as WARN (runtime differs from local — possible stale deployment).

---

### Phase 7d — Report runtime findings

Append a **Runtime Validation** section to the Phase 6 report:

```
## Runtime Validation

App URL: <url>

| File | Status | Notes |
|------|--------|-------|
| xs-app.json | PASS/FAIL | |
| manifest.json | PASS/FAIL | |
| index.html | PASS/FAIL | |

Runtime verdict: LIVE APP OK / ISSUES FOUND
```

---

## Reference Files

Load `references/validation-checklist.md` for the extended validation rule set.
Load `references/common-misconfigurations.md` if any FAIL is found and the cause is unclear.
Load `references/approuter-troubleshooting.md` when a FAIL relates to routing, authentication errors, or token exchange — it contains error codes 1–9, decision trees, and approuter request processing flow.
Load `references/approuter-flows.md` for the 9-step approuter request processing flow when debugging route resolution or authentication sequencing.
Load `references/service-to-approuter-flow.md` when validating programmatic authentication patterns (`x-approuter-authorization` header, IAS app2app flows, mTLS requirements).
