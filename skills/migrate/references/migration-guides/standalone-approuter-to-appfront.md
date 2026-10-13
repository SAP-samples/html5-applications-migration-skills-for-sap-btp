# Migration Guide: Standalone Approuter (localDir) → appFront

This guide covers migrating a CAP + standalone approuter application (MTA module type `approuter.nodejs` with `localDir` routes) to the appFront deployment model.

## Overview

A standalone approuter serves static HTML5 content directly from its own Cloud Foundry application filesystem via `localDir` routes. The migration to appFront involves:

1. **Extracting** static content out of the approuter module into a proper HTML5 module with a built zip artifact
2. **Replacing** the `approuter.nodejs` module with an `app-content` deployer module
3. **Adding** an `app-front` service resource (replaces the approuter CF app)
4. **Converting** `localDir` routes to `"service": "app-front"` routes in `xs-app.json`
5. **Converting** the MTA destination injection (`group: destinations`) to `config.destinations` in the deployer

---

## Source Structure

A typical standalone approuter CAP project:

```
mta.yaml
app/
└── router/
    ├── xs-app.json           ← routes with localDir for static content
    └── <app-name>/           ← static UI5/Fiori files (served via localDir)
        └── webapp/
            └── index.html
gen/
├── srv/                      ← CAP compiled backend
└── db/                       ← HANA HDI artifacts
xs-security.json
```

**Source `mta.yaml` (standalone approuter pattern):**

```yaml
_schema-version: 3.3.0
ID: MyApp
version: 1.0.0
parameters:
  enable-parallel-deployments: true
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm ci
        - npx cds build --production

modules:
  # CAP backend
  - name: MyApp-srv
    type: nodejs
    path: gen/srv
    parameters:
      buildpack: nodejs_buildpack
      readiness-health-check-type: http
      readiness-health-check-http-endpoint: /health
    build-parameters:
      builder: npm
    provides:
      - name: srv-api
        properties:
          srv-url: ${default-url}
    requires:
      - name: MyApp-auth
      - name: MyApp-db

  # HDI deployer
  - name: MyApp-db-deployer
    type: hdb
    path: gen/db
    parameters:
      buildpack: nodejs_buildpack
    requires:
      - name: MyApp-db

  # *** STANDALONE APPROUTER — target of this migration ***
  - name: MyApp
    type: approuter.nodejs
    path: app/router
    parameters:
      keep-existing-routes: true
      disk-quota: 256M
      memory: 256M
    requires:
      - name: srv-api
        group: destinations
        properties:
          name: srv-api
          url: ~{srv-url}
          forwardAuthToken: true
      - name: MyApp-auth

resources:
  - name: MyApp-auth
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: ./xs-security.json
      config:
        xsappname: MyApp-${org}-${space}
        tenant-mode: dedicated
  - name: MyApp-db
    type: com.sap.xs.hdi-container
    parameters:
      service: hana
      service-plan: hdi-shared
```

**Source `xs-app.json` (with `localDir` routes):**

```json
{
  "authenticationMethod": "route",
  "welcomeFile": "/interaction_items/webapp/index.html",
  "compression": { "minSize": 2048 },
  "logout": {
    "logoutEndpoint": "/app-logout",
    "logoutPage": "/"
  },
  "routes": [
    {
      "source": "^/app/(.*)$",
      "target": "$1",
      "localDir": ".",                   ← static content from approuter's own path
      "cacheControl": "no-cache, no-store, must-revalidate",
      "authenticationType": "xsuaa"
    },
    {
      "source": "^/appconfig/",
      "localDir": ".",
      "cacheControl": "no-cache, no-store, must-revalidate"
    },
    {
      "source": "^/user-api(.*)",
      "target": "$1",
      "service": "sap-approuter-userapi"
    },
    {
      "source": "^/(.*)$",
      "target": "$1",
      "destination": "srv-api",
      "csrfProtection": true,
      "authenticationType": "xsuaa"
    }
  ]
}
```

---

## Target Structure

```
appfront-migrated/
├── mta.yaml                  ← replaced approuter module with app-content deployer
├── xs-security.json          ← unchanged (XSUAA stays)
├── app/
│   └── <app-name>/           ← HTML5 module (was inside router path)
│       ├── ui5.yaml          ← NEW — needed to build zip with ui5 tooling
│       ├── package.json      ← NEW — needed for build toolchain
│       └── webapp/
│           └── index.html
gen/
├── srv/
└── db/
```

---

## Phase 3 Changes — Standalone Approuter

### 3a — Update `mta.yaml`

**Changes required:**

1. **Remove** the `approuter.nodejs` module entirely
2. **Add** an HTML5 source module (type `html5`) for each UI app that was served via `localDir`
3. **Add** an `app-content` deployer module (type `com.sap.application.content`)
4. **Replace** nothing in resources — no `html5-apps-repo` was present, so just **add** the `app-front` resource
5. **Convert** destination injection from `group: destinations` in the approuter to `config.destinations` in the deployer module
6. **Remove** `deploy_mode: html5-repo` is NOT needed for CAP backends — add only if required
7. **Keep** the CAP backend (`nodejs`) and HDI deployer (`hdb`) modules unchanged
8. **Keep** the XSUAA and HANA resources unchanged

**After `mta.yaml`:**

```yaml
_schema-version: 3.3.0
ID: MyApp
version: 1.0.0
parameters:
  enable-parallel-deployments: true
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm ci
        - npx cds build --production

modules:
  # CAP backend — unchanged
  - name: MyApp-srv
    type: nodejs
    path: gen/srv
    parameters:
      buildpack: nodejs_buildpack
      readiness-health-check-type: http
      readiness-health-check-http-endpoint: /health
    build-parameters:
      builder: npm
    provides:
      - name: srv-api
        properties:
          srv-url: ${default-url}
    requires:
      - name: MyApp-auth
      - name: MyApp-db

  # HDI deployer — unchanged
  - name: MyApp-db-deployer
    type: hdb
    path: gen/db
    parameters:
      buildpack: nodejs_buildpack
    requires:
      - name: MyApp-db

  # NEW: HTML5 source module — builds static content to zip artifact
  - name: MyApp-ui
    type: html5
    path: app/<app-name>            # path to the UI app directory
    build-parameters:
      build-result: dist
      builder: custom
      commands:
        - npm install
        - npm run build:cf           # or: npx ui5 build --dest dist
      supported-platforms: []

  # NEW: appFront deployer — uploads zip + injects service credentials
  - name: MyApp-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: MyApp-auth             # XSUAA credentials injected into appFront
      - name: MyApp-app-front        # appFront service (content-target)
        parameters:
          content-target: true
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - MyApp-ui.zip           # artifact name: <module-name>.zip
          name: MyApp-ui
          target-path: resources/
    parameters:
      config:
        destinations:
          # Backend API destination (was: group: destinations in approuter requires)
          - name: srv-api
            url: ~{srv-api/srv-url}
            forwardAuthToken: true

resources:
  # NEW: appFront service (replaces the approuter.nodejs module)
  - name: MyApp-app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: MyApp-app-front-service
      service-plan: developer

  # XSUAA — unchanged
  - name: MyApp-auth
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: ./xs-security.json
      config:
        xsappname: MyApp-${org}-${space}
        tenant-mode: dedicated

  # HANA — unchanged
  - name: MyApp-db
    type: com.sap.xs.hdi-container
    parameters:
      service: hana
      service-plan: hdi-shared
```

> **Note on `srv-api` destination resolution**: The `~{srv-api/srv-url}` reference in `config.destinations` requires the CAP backend module to still `provides: srv-api`. This is unchanged. The deployer module must `requires: MyApp-srv` (or the provided interface name) **if** you use the `~{...}` reference — OR use `~{srv-api/srv-url}` directly which resolves via the global provides map. Verify the reference resolves with `mbt build`.

### 3b — Update `xs-app.json`

**`localDir` routes must be replaced with `"service": "app-front"` routes.**

`localDir` served files from the approuter's own CF filesystem. With appFront, static content is stored in the appFront service, so the route must use `"service": "app-front"` to fetch it.

**Before:**
```json
{
  "source": "^/app/(.*)$",
  "target": "$1",
  "localDir": ".",
  "cacheControl": "no-cache, no-store, must-revalidate",
  "authenticationType": "xsuaa"
}
```

**After:**
```json
{
  "source": "^/app/(.*)$",
  "target": "$1",
  "service": "app-front",
  "cacheControl": "no-cache, no-store, must-revalidate",
  "authenticationType": "xsuaa"
}
```

**Full migrated `xs-app.json`:**

```json
{
  "authenticationMethod": "route",
  "welcomeFile": "/interaction_items/webapp/index.html",
  "compression": { "minSize": 2048 },
  "logout": {
    "logoutEndpoint": "/app-logout",
    "logoutPage": "/"
  },
  "routes": [
    {
      "source": "^/app/(.*)$",
      "target": "$1",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate",
      "authenticationType": "xsuaa"
    },
    {
      "source": "^/appconfig/",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate"
    },
    {
      "source": "^/user-api(.*)",
      "target": "$1",
      "service": "sap-approuter-userapi"
    },
    {
      "source": "^/(.*)$",
      "target": "$1",
      "destination": "srv-api",
      "csrfProtection": true,
      "authenticationType": "xsuaa"
    }
  ]
}
```

> **The backend catch-all route stays unchanged.** Routes with `"destination"` (pointing to the CAP backend) are not affected by the migration. The `srv-api` destination is now provided via `config.destinations` in the deployer module instead of via `group: destinations` in the approuter requires.

### 3c — `xs-security.json` — No Changes Required

The XSUAA configuration is unchanged when keeping XSUAA as the auth service. The `xsappname` pattern `MyApp-${org}-${space}` continues to work.

### 3d — Build Tooling for the New HTML5 Module

The extracted HTML5 app needs a build step to produce the zip artifact. The approuter previously ran no build — files were served directly. Now a build step is required.

**Minimum `package.json` for the HTML5 module** (if using ui5-tooling):
```json
{
  "name": "myapp-ui",
  "version": "0.0.1",
  "scripts": {
    "build:cf": "ui5 build --dest dist --clean-dest",
    "start": "ui5 serve"
  },
  "devDependencies": {
    "@ui5/cli": "^3"
  }
}
```

**Minimum `ui5.yaml`:**
```yaml
specVersion: "3.0"
metadata:
  name: myapp-ui
type: application
```

> If the app already has `package.json` and `ui5.yaml` in place (BAS-generated apps typically do), this step may not require new files — just verify the `build:cf` script exists and produces output in `dist/`.

---

## Migration Checklist

### ✅ Changes Required

1. **Remove** the `approuter.nodejs` module from `mta.yaml`
2. **Add** an HTML5 source module (`type: html5`) for each UI app directory
3. **Add** an `app-content` deployer module with:
   - Direct `requires` for XSUAA and any other bound services
   - `content-target: true` on the `app-front` resource reference
   - `config.destinations` for backend API (replaces `group: destinations`)
4. **Add** an `app-front` resource (`service: app-front`, `service-plan: developer`)
5. **Replace** every `"localDir"` route in `xs-app.json` with `"service": "app-front"`
6. **Add** build tooling (`package.json`, `ui5.yaml`, build script) to the HTML5 app directory if not already present

### 🔄 No Changes Required

- CAP backend module (`type: nodejs`)
- HDI deployer module (`type: hdb`)
- XSUAA resource (`MyApp-auth`)
- HANA resource (`MyApp-db`)
- `xs-security.json`
- Backend `"destination"` routes in `xs-app.json`
- `"service": "sap-approuter-userapi"` routes in `xs-app.json`

### ❌ Must Remove

- The `approuter.nodejs` module
- All `group: destinations` entries in the old approuter's `requires` block (converted to `config.destinations`)

---

## CF App Removal After Migration

The `approuter.nodejs` module was deployed as a CF application consuming memory and disk quota. After migration:

- The approuter CF app is replaced by the appFront service instance (a BTP managed service — no CF app running)
- Run `cf undeploy <mta-id>` before deploying the migrated MTA if the old approuter app is still running
- The `MyApp-app-front-service` service instance must be created before first deploy (the MTA deployer handles this automatically)

---

## Critic Check Additions for Standalone Approuter

When running the Phase 4 critic review, add these checks specific to this source type:

7. **`localDir` REMOVAL**: Are all `"localDir"` entries removed from `xs-app.json`? Any remaining `localDir` will silently fail (appFront has no local filesystem to serve from).

8. **DESTINATION CONVERSION**: Is the `group: destinations` requires block fully converted to `config.destinations` in the deployer? A missed conversion means the CAP backend URL is never injected and all backend requests will return 502.

9. **HTML5 MODULE BUILD**: Does the new `html5` module have a valid `build:cf` script and `ui5.yaml`? A missing build step means the zip artifact is never produced, breaking the deployer.

10. **APPROUTER MODULE REMOVED**: Is the `approuter.nodejs` module completely removed from the migrated `mta.yaml`? Leaving it in causes a duplicate CF app deployment.

---

## Known Issues

| Issue | Condition | Fix |
|-------|-----------|-----|
| `Cannot find module` on deploy | HTML5 module lacks `node_modules/` | Run `npm install` in the HTML5 module path before `mbt build` |
| `dist/` directory empty after build | `ui5 build` config missing or misconfigured | Verify `ui5.yaml` `type: application` and that `src` path is correct |
| Backend 502 after migration | `config.destinations` URL resolution failed | Check `~{srv-api/srv-url}` reference — add `requires: MyApp-srv` if needed in deployer module |
| `localDir` 404 in appFront | `localDir` not converted to `"service": "app-front"` | Replace all `"localDir"` with `"service": "app-front"` in `xs-app.json` |
| Auth 401 on static routes | `authenticationType` missing on `"service": "app-front"` routes | Add `"authenticationType": "xsuaa"` to routes that required auth before migration |