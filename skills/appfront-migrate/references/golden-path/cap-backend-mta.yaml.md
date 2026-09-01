# CAP Backend + appFront: Full MTA Example

## Load trigger

Load during Phase 3 when the backend is a CAP (Cloud Application Programming Model) application and the target is appFront.

---

## Overview

The bookshop MTA is the canonical SAP Golden Path example: CAP Node.js backend + appFront HTML5 frontend in a single MTA. Key structural points:

- **One deployer module** (`bookshop-app-content`) handles both the app upload and credential injection
- **Destinations are inline** in the deployer module's `parameters.config.destinations` block — no `destination-content` module needed
- **CAP module** (`bookshop-srv`) provides its URL via `provides.srv-url` which the deployer consumes via `~{srv-api/srv-url}`
- **XSUAA** is shared between the CAP backend and the appFront deployer

---

## Annotated mta.yaml

```yaml
_schema-version: '3.1'
ID: capire.bookshop
version: 1.0.0
description: "A simple self-contained bookshop service."

modules:
  # AppFront deployer — uploads HTML5 zip AND stores backend destinations + XSUAA credentials
  - name: bookshop-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: srv-api                    # ← CAP service URL injected here
      - name: bookshop-auth              # ← XSUAA credentials stored in app-front
      - name: bookshop_app-front
        parameters:
          content-target: true           # ← marks this as the upload target
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - bookshop-ui.zip
          name: bookshop-ui
          target-path: resources/
    parameters:
      config:
        destinations:
          # Backend destination — no sap.cloud.service property
          - name: bookshop
            url: ~{srv-api/srv-url}      # ← resolved from CAP module's provides block
            forwardAuthToken: true
          # UI5 resources destination
          - name: ui5
            url: https://ui5.sap.com

  # HTML5 module — builds the UI5/Fiori app to a zip
  - name: bookshop-ui
    type: html5
    path: bookshop-ui
    build-parameters:
      build-result: dist
      builder: custom
      commands:
        - npm install
        - npm run build:cf
      supported-platforms: []

  # CAP backend — Node.js service
  - name: bookshop-srv
    type: nodejs
    path: gen/srv                        # ← CDS build output goes here
    parameters:
      buildpack: nodejs_buildpack
      readiness-health-check-type: http
      readiness-health-check-http-endpoint: /health
    build-parameters:
      builder: npm
      ignore:
        - "node_modules/"
    provides:
      - name: srv-api                    # ← consumed by bookshop-app-content
        properties:
          srv-url: ${default-url}
    requires:
      - name: bookshop-auth

resources:
  # appFront service — replaces html5-apps-repo app-host
  - name: bookshop_app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: bookshop_app-front_service
      service-plan: developer

  # Shared XSUAA — used by both CAP backend and appFront deployer
  - name: bookshop-auth
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: ./xs-security.json
      config:
        xsappname: bookshop-${org}-${space}   # ← unique per CF space
        tenant-mode: dedicated

parameters:
  deploy_mode: html5-repo
  enable-parallel-deployments: true

# CDS build runs before the HTML5 module builder
build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm install
        - npx cds build --production
        - cp -R db/data gen/srv/srv/
        - mkdir -p resources
        - cp configurations/cdm.json resources/cdm.json  # CDM for WorkZone (if needed)
```

Source: `examples/bookshop-mta-cdm/mta.yaml`

---

## Key Rules

| Pattern | Explanation |
|---------|-------------|
| `~{srv-api/srv-url}` | MTA cross-reference — CAP module's `provides.srv-url` resolves to the deployed CF app URL |
| No `destination-content` module | Destinations are stored directly in appFront via `parameters.config.destinations` |
| `forwardAuthToken: true` | Passes the user's JWT to the CAP backend — required for CDS authorization checks |
| `xsappname: bookshop-${org}-${space}` | Dynamic xsappname ensures uniqueness across CF spaces |
| `gen/srv` path | CDS build output directory — must exist before MTA build starts (handled by `before-all`) |
| `enable-parallel-deployments: true` | CAP backend and HTML5 module build in parallel for faster deploy |

---

## xs-app.json for CAP Backend

The bookshop xs-app.json routes the `/browse/` prefix to the `bookshop` destination:

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/browse/(.*)$",
      "target": "/browse/$1",
      "destination": "bookshop",
      "authenticationType": "ias",
      "csrfProtection": false
    },
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "authenticationType": "none",
      "destination": "ui5"
    },
    {
      "source": "^/test-resources/(.*)$",
      "target": "/test-resources/$1",
      "authenticationType": "none",
      "destination": "ui5"
    },
    {
      "source": "^/manifest.json$",
      "target": "/manifest.json",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate",
      "authenticationType": "none"
    },
    {
      "source": "^/index.html$",
      "target": "/index.html",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate",
      "authenticationType": "ias"
    },
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front",
      "authenticationType": "ias"
    }
  ]
}
```

The `destination: "bookshop"` name matches the destination name in `mta.yaml`'s `parameters.config.destinations`.

---

## manifest.json for WorkZone Integration

The bookshop app includes `sap.cloud` for WorkZone integration:

```json
{
  "sap.cloud": {
    "public": true,
    "service": "bookssvc"
  }
}
```

And uses `sap.fe.templates` for Fiori Elements:

```json
{
  "sap.ui5": {
    "dependencies": {
      "libs": {
        "sap.m": {},
        "sap.ui.core": {},
        "sap.ushell": {},
        "sap.fe.templates": {}
      }
    }
  }
}
```

Source: `examples/bookshop-mta-cdm/bookshop-ui/webapp/manifest.json`
