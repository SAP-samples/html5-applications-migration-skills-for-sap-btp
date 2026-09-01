# SAP Neo HTML5 App → appFront Migration Guide

Source: SAP Help Portal — *Migrating Applications in SAP BTP from the Neo Environment to the Multi-Cloud Foundation*
https://help.sap.com/docs/HTML5_APPLICATIONS/b98f42a4d2cd40a9a3095e9f0492b465?locale=en-US&state=PRODUCTION&version=Cloud

## Load trigger

Load during Phase 1 and Phase 3 when the source type is `neo`.

---

## Prerequisites

### BTP subaccount (Cloud Foundry)
- Cloud Foundry environment enabled for the subaccount
- A Cloud Foundry space created
- Entitlements for: SAP Business Application Studio, Cloud Foundry runtime, SAP Cloud Identity Services
- A SAP Cloud Identity Services (IAS) tenant with trust relationship configured
- Administrative permissions in the CF subaccount

### Application Frontend Service
- Subaccount entitled to Application Frontend service
- Subscriptions to both the **`build default`** and **`developer`** service plans
- Role collections **Application Frontend Developer** and **Application Frontend Viewer** created and assigned to the user
- The `af_rc` role collection assigned (required for `afctl` CLI operations)

### Local tooling
- `mbt` (Cloud MTA Build Tool): `npm install -g mbt`
- `cf` CLI installed and logged in
- `afctl` CLI installed (for post-deploy URL lookup): `npm install -g @sap/appfront-cli`

---

## Step 0 — Export from Neo (if starting from the Neo cockpit)

If the source files haven't been exported yet, the user must do this manually in the SAP BTP cockpit:

1. In the SAP BTP cockpit, access the Neo subaccount
2. From the navigation pane, choose **Solutions**
3. Choose **Export**
4. When the *Discovering subaccount components* process finishes, select **Automatically select dependent components** and select the application to migrate
5. Choose **Next** → **Next**
6. Enter a title, description, solution ID, and version (Solution ID and Version are mandatory)
7. Choose **Export** (keep default export options)
8. Choose **Download Development Descriptor (mta.yaml)** and **Download MTA Archive** to download both files
9. **Rename** the downloaded `mta.yaml` to `neo-mta.yaml` — the migration tool requires this exact filename

> After migration, the application is configured as a Multitarget Application in the Cloud Foundry environment.

---

## Step 1 — Identify source files

Read from the source:
- `neo-app.json` — extract: `welcomeFile`, `routes` (destinations, SAPUI5 service routes, application routes), `securityConstraints`, `cacheControl`, `responseHeaders`, `logoutPage`
- `neo-mta.yaml` — extract: application name, version
- `webapp/manifest.json` — extract: `sap.app.id` (used for folder naming), `sap.cloud.service` (or ask user — see Phase 1a-naming)

---

## Step 2 — Migrate destinations

Before generating `mta.yaml`, establish the destination mapping:

1. Export all destinations from the Neo subaccount as text files (use the **Export** action in the Neo cockpit)
2. In the Cloud Foundry subaccount, use **Import Destinations** to import them
3. For destinations with secrets, passwords, or certificates: add these manually in the CF destination entries (they are not exported for security reasons)
4. Create a new destination named `ui5` pointing to `https://ui5.sap.com`

---

## Step 3 — Define the business solution (`sap.cloud.service`)

### Why this matters: Neo apps vs appFront business solutions

In **SAP Neo**, each HTML5 application is deployed independently — there is no concept of grouping apps together. Every app has its own lifecycle, its own security configuration, and its own runtime entry.

In **appFront**, the `sap.cloud.service` property in `manifest.json` defines a **business solution**: a logical grouping of one or more HTML5 apps that share:
- A single `app-front` service instance
- A single XSUAA service instance and `xs-security.json`
- A single MTA deployment unit

This means you have a choice when migrating from Neo:

| Migration style | When to use |
|---|---|
| **One app → one business solution** | The app is self-contained; no plans to group it with others |
| **Multiple Neo apps → one business solution** | Apps belong to the same product or team; consolidating reduces operational overhead |

> See the [Mass Migration](#mass-migration--grouping-multiple-neo-apps-into-one-business-solution) section below if you want to consolidate multiple Neo apps.

### Determine the naming prefix (single-app migration)

Since `sap.cloud.service` does not exist in Neo, you must define it now. Ask the user:

> **What `sap.cloud.service` value should be used for this app?**
> This becomes the namespace for the business solution on appFront (e.g. `com.sap.myteam`, `com.company.hr`).
> If you plan to migrate multiple Neo apps into one solution later, choose a value that represents the whole product, not just this single app.

Once the user provides the value, derive the naming prefix:

| `sap.cloud.service` | Naming prefix |
|---|---|
| `com.sap.library` | `comsaplibrary` |
| `com.sap.products` | `comsapproducts` |

Strip all dots. This prefix is used for all resource and service names in `mta.yaml`.

The app folder name = last segment of `sap.app.id`, lowercased (e.g. `com.sap.library` → `library`; or use the full dotless form `comsaplibrary` if there is no clear last segment).

---

## Mass Migration — Grouping Multiple Neo Apps into One Business Solution

When migrating several related Neo HTML5 apps, you can consolidate them into a single appFront business solution. This produces one `mta.yaml` with shared infrastructure and one deployment.

### Structure

```
appfront-migrated/
├── mta.yaml                      ← single MTA for all apps
├── xs-security.json              ← single XSUAA config (merged scopes from all apps)
├── <app1FolderName>/             ← first app (e.g. comsapmyteam-app1)
│   ├── package.json
│   ├── ui5.yaml
│   ├── xs-app.json
│   └── webapp/
└── <app2FolderName>/             ← second app (e.g. comsapmyteam-app2)
    ├── package.json
    ├── ui5.yaml
    ├── xs-app.json
    └── webapp/
```

### `mta.yaml` pattern for multiple apps

```yaml
_schema-version: "3.2"
ID: <namingPrefix>-af
version: 0.0.1

modules:
  # One html5 source module per app
  - name: <namingPrefix>-<app1>-ui
    type: html5
    path: <app1FolderName>
    build-parameters:
      build-result: dist
      builder: custom
      commands:
        - npm install
        - npm run build:cf
      supported-platforms: []

  - name: <namingPrefix>-<app2>-ui
    type: html5
    path: <app2FolderName>
    build-parameters:
      build-result: dist
      builder: custom
      commands:
        - npm install
        - npm run build:cf
      supported-platforms: []

  # Single deployer module — references ALL app zips
  - name: <namingPrefix>-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: <namingPrefix>-xsuaa
      - name: <namingPrefix>-app-front
        parameters:
          content-target: true
    parameters:
      config:
        destinations:
          - Name: ui5
            URL: https://ui5.sap.com
            ProxyType: Internet
            Type: HTTP
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - <app1FolderName>.zip
          name: <namingPrefix>-<app1>-ui
          target-path: resources/
        - artifacts:
            - <app2FolderName>.zip
          name: <namingPrefix>-<app2>-ui
          target-path: resources/

resources:
  - name: <namingPrefix>-app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: <namingPrefix>-app-front-service
      service-plan: developer

  - name: <namingPrefix>-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      path: ./xs-security.json
      service: xsuaa
      service-plan: application
      service-name: <namingPrefix>-xsuaa-service

parameters:
  deploy_mode: html5-repo
```

### `xs-security.json` for multiple apps

Merge the scopes from all Neo apps' `securityConstraints` into a single `xs-security.json`. Each distinct permission becomes one scope entry. Use the shared `xsappname` derived from the business solution `sap.cloud.service`.

### `manifest.json` — same `sap.cloud.service` for all apps

Every app in the business solution must carry the **same** `sap.cloud.service` value:

```json
"sap.cloud": {
  "service": "<sap.cloud.service value>",
  "public": true
}
```

This is what binds all the apps together into one solution on the appFront runtime.

---

## Step 4 — Create target structure in `appfront-migrated/`

```
appfront-migrated/
├── mta.yaml                        ← CREATE (see Step 5)
├── xs-security.json                ← CREATE (see Step 6)
└── <appFolderName>/                ← CREATE (e.g. comsaplibrary)
    ├── package.json                ← CREATE (UI5 CLI build)
    ├── ui5.yaml                    ← CREATE (UI5 build config)
    ├── xs-app.json                 ← CREATE (translated from neo-app.json routes — see Step 7)
    └── webapp/                     ← MOVE from source root webapp/
        ├── Component.js
        ├── manifest.json           ← ADD sap.cloud.service (see Step 9)
        ├── index.html              ← FIX src path (see Step 10)
        └── ...
```

**Never place `xs-app.json` or `ui5.yaml` inside `webapp/`** — they belong at the app folder root.

Files to DELETE from `appfront-migrated/`:
- `neo-app.json`
- `neo-mta.yaml`
- `Gruntfile.js`
- Root-level `package.json` (Grunt-based)

---

## Step 5 — Create `mta.yaml`

### Destination methodology

Apply the methodology confirmed in Phase 0d Question 4:

- **BTP backend (same subaccount):** use `config.destinations` on the deployer module with `forwardAuthToken: true`. No destination service resource needed.
- **External / on-prem backend:** use a destination service resource (`service: destination`, `service-plan: lite`) with `init_data.subaccount.destinations`. Set `Authentication: NoAuthentication` — credentials added later in BTP Cockpit.
- **`ui5` destination:** always goes in `config.destinations` on the deployer module regardless of backend type — never in `init_data`.

### Template

```yaml
_schema-version: "3.2"
ID: <namingPrefix>-af
version: 0.0.1

modules:
  - name: <namingPrefix>-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: <namingPrefix>-xsuaa
      - name: <namingPrefix>-app-front
        parameters:
          content-target: true
    parameters:
      config:
        destinations:
          - Name: ui5
            URL: https://ui5.sap.com
            ProxyType: Internet
            Type: HTTP
          # BTP backends: add here with forwardAuthToken: true
          # External backends: use destination service resource instead (see below)
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - <appFolderName>.zip
          name: <namingPrefix>-ui
          target-path: resources/

  - name: <namingPrefix>-ui
    type: html5
    path: <appFolderName>
    build-parameters:
      build-result: dist
      builder: custom
      commands:
        - npm install
        - npm run build:cf
      supported-platforms: []

resources:
  - name: <namingPrefix>-app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: <namingPrefix>-app-front-service
      service-plan: developer

  - name: <namingPrefix>-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      path: ./xs-security.json
      service: xsuaa
      service-plan: application
      service-name: <namingPrefix>-xsuaa-service

  # Include ONLY for external/on-prem backends:
  # - name: <namingPrefix>-destination
  #   type: org.cloudfoundry.managed-service
  #   parameters:
  #     service: destination
  #     service-plan: lite
  #     service-name: <namingPrefix>-destination-service
  #     config:
  #       init_data:
  #         subaccount:
  #           destinations:
  #             - Authentication: NoAuthentication
  #               Name: <dest-name>
  #               URL: <<REPLACE_WITH_REAL_BACKEND_URL>>
  #               ProxyType: Internet
  #               Type: HTTP
  #           existing_destinations_policy: update
  #       version: 1.0.0

parameters:
  deploy_mode: html5-repo
```

> The MTA ID gets the `-af` suffix to avoid deployment clashes with any existing Neo-sourced artifact.

---

## Step 6 — Create `xs-security.json`

Read **every** `securityConstraints` entry from `neo-app.json`. Map each `"permission"` value to a dedicated XSUAA scope. Do not skip any permission.

Mapping rules:
- Strip any `p_` prefix, lowercase, use underscores (e.g. `p_sap_employees` → `$XSAPPNAME.employee`)
- Create one `scope`, one `role-template`, and one `role-collection` entry per distinct permission
- Routes protected by that permission in `neo-app.json` must carry the matching `"scope"` in `xs-app.json` (Step 7)

The scopes are **not enforced automatically** — they must be explicitly referenced via `"scope"` on each protected route in `xs-app.json`.

Example based on official SAP documentation (adapt to actual permissions found):

```json
{
  "xsappname": "<namingPrefix>-af",
  "tenant-mode": "dedicated",
  "description": "Security profile of called application",
  "scopes": [
    {
      "name": "$XSAPPNAME.globalrole",
      "description": "Migrated role"
    }
  ],
  "role-templates": [
    {
      "name": "globaltemplate",
      "description": "Migrated Role Template",
      "scope-references": [
        "$XSAPPNAME.globalrole"
      ]
    }
  ],
  "role-collections": [
    {
      "name": "GlobalRole",
      "description": "Global from migrated neo",
      "role-template-references": [
        "$XSAPPNAME.globaltemplate"
      ]
    }
  ],
  "oauth2-configuration": {
    "token-validity": 43200
  }
}
```

> Do NOT add `redirect-uris` — appFront does not require them.

---

## Step 7 — Create `xs-app.json`

Translate `neo-app.json` routes to `xs-app.json`. The mapping is based on the official SAP feature mapping table:

### neo-app.json → xs-app.json feature mapping

| neo-app.json feature | xs-app.json equivalent | Notes |
|---|---|---|
| `"authenticationMethod": "saml"` (root) | `"authenticationMethod": "route"` | SAML → XSUAA OAuth2 |
| `"authenticationMethod": "none"` (root) | `"authenticationMethod": "none"` | Preserved |
| `securityConstraints[].permission` | `routes[].scope: "$XSAPPNAME.<scope>"` | Each permission → scope on the protected route |
| SAPUI5 service route (`"type": "service", "name": "sapui5"`) | Route with `"destination": "ui5"`, `"authenticationType": "none"` | SAPUI5 resources via destination |
| Destination route (`"target.type": "destination"`) | Route with `"destination": "<name>"` | Direct mapping |
| Application route (`"target.type": "application"`) | Reuse library or business service pattern | See note below |
| User API service (`"target.type": "service", "name": "userapi"`) | `"service": "sap-approuter-userapi"` | Route source: `"^/user-api(.*)"` |
| `"welcomeFile"` | `"welcomeFile"` | Direct mapping; `sendWelcomeFileRedirect` not supported in CF |
| `"logoutPage"` | `"logout": {"logoutEndpoint": "<path>"}` | Syntax changes |
| `"cacheControl"` | `"cacheControl": <value>` per route | Direct mapping |
| `"responseHeaders"` | `"responseHeaders": [{"name":"...","value":"..."}]` | Syntax changes |
| `"headerWhiteList"` | Not needed | CF approuter forwards all headers except hop-by-hop |

> **Application Routes** (reuse libraries): Consume as a reuse library via `sap.ui5.resourceRoots` in `manifest.json`, or expose as a business service. The `"type": "application"` route concept from Neo has no direct 1:1 CF equivalent.

> **SAPUI5 libraries**: Load from `https://ui5.sap.com/resources/sap-ui-core.js` via the `ui5` destination. Replace all indirect paths in source code (e.g. `/resources/*` or `../../resources/*`) with the relative path `resources/` — the xs-app.json `/resources/` route proxies them through the `ui5` destination.

### Template

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "destination": "ui5",
      "authenticationType": "none"
    },
    {
      "source": "^/test-resources/(.*)$",
      "target": "/test-resources/$1",
      "destination": "ui5",
      "authenticationType": "none"
    },
    {
      "source": "^/user-api(.*)",
      "target": "$1",
      "service": "sap-approuter-userapi"
    },
    {
      "source": "^/<neo-dest-path>/(.*)$",
      "target": "/<neo-dest-path>/$1",
      "destination": "<neo-dest-name>",
      "authenticationType": "xsuaa",
      "scope": "$XSAPPNAME.<scope-name>",
      "csrfProtection": false
    },
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front",
      "authenticationType": "xsuaa",
      "scope": "$XSAPPNAME.<scope-name>"
    }
  ]
}
```

**Scope enforcement rule:** Every route protected by a Neo `securityConstraint` must carry a `"scope"` property referencing the corresponding XSUAA scope. Without it, any authenticated user (regardless of role collection) can access the route. The `resources` and `test-resources` routes are always `authenticationType: none` with no scope.

**Destination routes example** (from official docs):

```json
{
  "source": "^/sap/opu/odata/sap/API_BUSINESS_PARTNER/(.*)$",
  "destination": "bupa_onprem_pp_fullpath",
  "target": "$1"
}
```

---

## Step 8 — Create `<appFolderName>/ui5.yaml`

```yaml
specVersion: "3.0"
metadata:
  name: <namingPrefix>-ui
type: application
builder:
  resources:
    excludes:
      - "/test/**"
      - "/localService/**"
      - "/node_modules/**"
      - "/dist/**"
  customTasks:
    - name: ui5-task-zipper
      afterTask: generateCachebusterInfo
      configuration:
        archiveName: <appFolderName>
        additionalFiles:
          - xs-app.json
```

> `ui5-task-zipper` is the cross-platform way to produce the zip artifact and include `xs-app.json`. It replaces any manual `cp`/`zip`/`mv` shell commands in `build:cf`. Add `ui5-task-zipper` to your `devDependencies` in `package.json` (see Step 9).

---

---

## Step 9 — Create `<appFolderName>/package.json`

```json
{
  "name": "<namingPrefix>-ui",
  "version": "0.0.1",
  "private": true,
  "devDependencies": {
    "@ui5/cli": "^3.0.0",
    "ui5-task-zipper": "^3.0.0"
  },
  "scripts": {
    "build:cf": "ui5 build --dest dist"
  }
}
```

> **Note:** `ui5-task-zipper` (declared in `ui5.yaml`) handles packaging `xs-app.json` into the zip cross-platform. The `build:cf` script only runs `ui5 build --dest dist` — no shell commands for copying or zipping are needed. The previous pattern using `cp`, `zip -r`, and `mv` was macOS/Linux-only and failed on Windows.

---

## Step 9b — Handle `-dbg.js` files (Neo cockpit exports without source access)

When an app is exported from the Neo cockpit without source access, the `webapp/` folder (typically under `controller/`) may contain **both** a compiled file and its debug counterpart:

```
controller/App.controller.js        ← minified, may be incomplete
controller/App.controller-dbg.js    ← full source, use this one
```

Scan for this pattern and clean it up before migrating:

```bash
# Find all -dbg.js files in the webapp folder
find webapp/ -name "*-dbg.js"
```

For each `-dbg.js` file found:
1. **Delete** the non-debug counterpart (the same filename without `-dbg`, e.g. `App.controller.js`)
2. **Rename** the `-dbg.js` file by removing the `-dbg` suffix (e.g. `App.controller-dbg.js` → `App.controller.js`)

```bash
# Example: process all -dbg.js files automatically
for f in $(find webapp/ -name "*-dbg.js"); do
  base="${f%-dbg.js}.js"
  rm -f "$base"
  mv "$f" "$base"
done
```

> On Windows, run this step manually or use the equivalent PowerShell commands.

---

## Step 10 — Update `manifest.json`

### 10a — Update `_version`

Neo apps commonly have an old `_version` value (e.g. `"1.1.0"` or `"1.2.0"`). Update it to the current minimum supported version for BTP CF:

```json
"_version": "1.65.0"
```

### 10b — Add `sap.cloud.service`

```json
"sap.cloud": {
  "service": "<sap.cloud.service value>",
  "public": true
}
```

### 10c — Remove Neo-specific blocks

Remove `sap.platform.hcp` block if present (Neo artifact, not needed on BTP CF).

---

## Step 11 — Fix `index.html` bootstrap src

Change `src="../../resources/sap-ui-core.js"` (Neo relative path) to `src="resources/sap-ui-core.js"`.

Replace all indirect resource paths in source code (e.g. `/resources/*` or `../../resources/*`) with the relative path `resources/`. The `/resources/` route in `xs-app.json` proxies them to the `ui5` destination.

**Never use an absolute CDN URL** (`https://ui5.sap.com/resources/sap-ui-core.js`) directly — always proxy via destination.

---

## Step 12 — Build and Deploy

```bash
mbt build
cf deploy mta_archives/<namingPrefix>-af_0.0.1.mtar
afctl list
```

---

## Neo Features with No Direct BTP Equivalent

| Neo Feature | BTP / appFront Handling |
|---|---|
| SAP ID Service / SAML auth | Replace with XSUAA OAuth2 + role collections |
| `p_sap_employees` permission | XSUAA scope + role collection assigned in BTP Cockpit |
| Neo destination (AppToAppSSO) | BTP destination service — auth type may need to change |
| `/resources` sapui5 service route | `ui5` destination → `https://ui5.sap.com` proxied via xs-app.json route |
| `sapui5preview` service | Not needed — use the `ui5` destination for both resources and test-resources |
| `"headerWhiteList"` in neo-app.json | Not needed — CF approuter forwards all headers except hop-by-hop |
| `sendWelcomeFileRedirect: false` | Not supported in CF — welcome file is always redirected |
| `HTML5.SocketReadTimeoutInSeconds` | Not supported in CF |
| `HTML5.HandleRedirects` | Not supported in CF |
| Application route (`type: application`) | Reuse library or business service pattern (no direct 1:1 equivalent) |