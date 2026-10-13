# SAP Neo HTML5 App Source Structure

## Load trigger

Load during Phase 1 baseline analysis when the source type is identified as `neo`.

## Typical Neo HTML5 App Directory Layout

A simple Neo HTML5 app (no `neo-mta.yaml`) has this structure:

```
neo-html5-app/
├── neo-app.json          # Neo runtime config: routes, security constraints, welcome file
├── package.json          # Grunt-based build (grunt-sapui5-bestpractice-build)
├── Gruntfile.js          # Grunt build config — DELETE on migration
└── webapp/               # UI5 application sources (flat, no app subfolder)
    ├── Component.js
    ├── manifest.json
    ├── index.html        # ⚠️ src="../../resources/sap-ui-core.js" — relative Neo path, MUST be fixed
    └── ...
```

## Key Differences from BTP/CF

| Aspect | SAP Neo | SAP BTP / CF (appFront) |
|--------|---------|--------------------------|
| Runtime config | `neo-app.json` | `xs-app.json` (inside app folder root) |
| MTA | None or `neo-mta.yaml` | `mta.yaml` (created from scratch) |
| Module type | `com.sap.hcp.html5` | `html5` + `com.sap.application.content` |
| Auth | Neo securityConstraints (SAP ID Service / SAML) | XSUAA or IAS (OAuth2) |
| SAPUI5 resources | Served by Neo `sapui5` service via `/resources` route | Proxied via `ui5` destination → `https://ui5.sap.com` |
| Backend destinations | Defined in `neo-app.json` `routes` | BTP destination service (`init_data.subaccount.destinations`) |
| Build tooling | Grunt (`grunt-sapui5-bestpractice-build`) | UI5 CLI (`@ui5/cli`) |
| Folder structure | `webapp/` at project root | `<appId>/webapp/` nested inside an app folder |

## ⚠️ Neo → BTP is a Rewrite, Not a Conversion

The `neo-app.json` cannot be mechanically converted. A Neo migration requires creating everything from scratch using appFront target templates.

## Critical Migration Rules (MANDATORY)

### Rule 1 — App Folder Structure

Neo apps have `webapp/` at project root. appFront requires a named app folder:

```
<project-root>/
├── mta.yaml
├── xs-security.json
└── <appId-no-dots>/          ← derived from sap.app.id without dots (e.g. com.sap.library → comsaplibrary)
    ├── package.json          ← build tooling lives here
    ├── ui5.yaml              ← UI5 build config lives here (NOT inside webapp/)
    ├── xs-app.json           ← routing config lives here (NOT inside webapp/)
    └── webapp/               ← UI5 sources
        ├── Component.js
        ├── manifest.json
        ├── index.html
        └── ...
```

The `mta.yaml` html5 module `path` must point to `<appId-no-dots>/` (e.g. `path: comsaplibrary`), with `build-result: dist`.

### Rule 2 — SAPUI5 Resources Must Be Proxied via Destination (NEVER direct CDN URL)

Neo apps load UI5 via `src="../../resources/sap-ui-core.js"` (Neo `/resources` service). In appFront, this path is replaced with a relative `resources/` path proxied through a `ui5` destination.

**`index.html`** — use a relative path (no domain):
```html
<script id="sap-ui-bootstrap"
    src="resources/sap-ui-core.js"
    ...>
```

Do NOT use `https://ui5.sap.com/resources/sap-ui-core.js` directly — always proxy through the destination.

**`xs-app.json`** — add routes before the catch-all:
```json
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
}
```

**`mta.yaml`** — add `ui5` destination alongside the backend destination:
```yaml
- Authentication: NoAuthentication
  Name: ui5
  URL: https://ui5.sap.com
  ProxyType: Internet
  Type: HTTP
```

### Rule 3 — Delete Neo Artifacts

Always delete from `appfront-migrated/`:
- `neo-app.json` — Neo runtime config, not used by appFront
- `Gruntfile.js` — replaced by UI5 CLI build

### Rule 4 — Build Tooling Replacement

Replace Grunt with UI5 CLI in `<appId-no-dots>/package.json`:

```json
{
  "name": "<appId-no-dots>-ui",
  "version": "0.0.1",
  "private": true,
  "devDependencies": {
    "@ui5/cli": "^3.0.0"
  },
  "scripts": {
    "build:cf": "ui5 build --dest dist && (cd dist && zip -r ../comsapitlibrary.zip .) && mv comsapitlibrary.zip dist/"
  }
}
```

Root-level `package.json` (Grunt) can be deleted — it is not used by MBT.

### Rule 5 — index.html Bootstrap Style

Neo-era `index.html` often uses the old `sap.ui.getCore().attachInit` pattern. This works but for new projects the preferred pattern is `data-sap-ui-oninit="module:sap/ui/core/ComponentSupport"` with a `<div data-sap-ui-component>` body. Either works — do not change unless the user asks.