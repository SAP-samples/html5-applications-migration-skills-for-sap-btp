# Target Config: CF + IAS appFront mta.yaml

## Load trigger

Load during Phase 3a when the target runtime is Cloud Foundry and auth service is IAS (Cloud Identity Service / Identity Authentication Service).

---

## Key Differences from CF + XSUAA

| Aspect | CF + XSUAA | CF + IAS |
|--------|-----------|---------|
| Auth resource | `service: xsuaa`, plan `application` | `service: identity`, plan `application` |
| Security manifest | `xs-security.json` with scopes/roles | Not needed by appFront deployer — IAS config is in the `identity` resource |
| xs-app.json `authenticationType` | `"xsuaa"` | `"ias"` |
| Deployer `requires` | Includes XSUAA instance | **No XSUAA** — only `app-front` + backend service |
| Deployer `config` | — | `IASDependencyName: <name>` for IAS app2app token exchange |
| Backend auth | OAuth2UserTokenExchange via XSUAA | IAS app2app token exchange via `IASDependencyName` |

---

## Annotated mta.yaml (Pure IAS — no XSUAA)

```yaml
_schema-version: '3.1'
ID: capire.bookshop
version: 1.0.0

modules:
  # appFront deployer — no XSUAA in requires; uses IASDependencyName for token exchange
  - name: bookshop-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: srv-api                      # CAP backend URL
      - name: bookshop_app-front
        parameters:
          content-target: true
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - bookshop-ui.zip
          name: bookshop-ui
          target-path: resources/
    parameters:
      config:
        IASDependencyName: myCAPbackend    # ← IAS app2app dependency name
        #HTML5Runtime_enabled: true        # ← NOT needed (commented out here, remove entirely)
        destinations:
          - name: bookshop
            url: ~{srv-api/srv-url}        # ← CAP backend URL (use httpbin.org for testing)
            forwardAuthToken: true
          - name: ui5
            url: https://ui5.sap.com

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

  - name: bookshop-srv
    type: nodejs
    path: gen/srv
    parameters:
      buildpack: nodejs_buildpack
      readiness-health-check-type: http
      readiness-health-check-http-endpoint: /health
    build-parameters:
      builder: npm
      ignore:
        - "node_modules/"
    provides:
      - name: srv-api
        properties:
          srv-url: ${default-url}
    requires:
      - name: bookshop-ias                 # ← CAP backend bound to IAS (not XSUAA)

resources:
  # appFront service
  - name: bookshop_app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front                   # use landscape-specific name if needed (e.g. app-front-stg-eu12)
      service-name: bookshop_app-front_service
      service-plan: developer

  # IAS service instance — replaces XSUAA entirely
  - name: bookshop-ias
    type: org.cloudfoundry.managed-service
    parameters:
      service: identity
      service-name: bookshop-ias
      service-plan: application
      config:
        provided-apis:
          - name: bookshop-ias-api         # ← API exposed for app2app token exchange
            description: API exposed by the application
        display-name: bookshop             # ← app name shown in Cloud Identity cockpit
        oauth2-configuration:
          token-policy:
            access-token-format: "jwt"     # ← required for forwarding JWT to backend
        xsuaa-cross-consumption: true      # ← allows XSUAA-based clients to call this IAS app
        authorization:
          enabled: true

parameters:
  deploy_mode: html5-repo
  enable-parallel-deployments: true

build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm install
        - npx cds build --production
        - cp -R db/data gen/srv/srv/
```

Source: `examples/bookshop-mta-ias/mta.yaml`

---

## IASDependencyName

`IASDependencyName` in the deployer `config` block enables **IAS app2app token exchange**. The appFront service uses this to perform a token exchange when forwarding requests to backend destinations with `forwardAuthToken: true`.

The value (`myCAPbackend`) must match a **dependency configured manually in the IAS admin UI** — this is a required manual step that cannot be done via mta.yaml:

> **Manual step — IAS Admin UI:**
> 1. Open the SAP Cloud Identity Services admin console
> 2. Navigate to **Applications** → find the **subscribed Application Frontend** application (provisioned automatically when appFront is subscribed in the subaccount)
> 3. Go to **Dependencies**
> 4. Add a dependency named `myCAPbackend` (matching `IASDependencyName`), pointing to the API exposed by the customer's IAS application instance (the `provided-apis.name` in the customer's `identity` resource — e.g. `bookshop-ias-api`)

**Without this manual step**, token exchange will fail at runtime even if mta.yaml is correctly configured.

---

## xs-app.json for Pure IAS

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

Source: `examples/bookshop-mta-ias/bookshop-ui/xs-app.json`

All authenticated routes use `"authenticationType": "ias"`. No `"xsuaa"` routes.

---

## IAS service-name Variants

The appFront service name may be landscape-specific. Observed values:
- `app-front` — standard
- `app-front-stg-eu12` — staging landscape variant (seen in bookshop-mta-ias)

Always verify with `cf marketplace | grep app-front` in the target landscape.

---

## IAS Trust Requirement

The subscriber subaccount **must** have IAS trust configured before the app works:

1. BTP Cockpit → subaccount → **Security → Trust Configuration**
2. Add SAP Identity Authentication Service tenant
3. Set status to **Active**

Without this, all `authenticationType: "ias"` routes return 401.

---

## xs-security.json in a Pure IAS App

`xs-security.json` is not used by the appFront deployer when auth is IAS. It may still exist if there are XSUAA-based components in the same MTA. In the bookshop-mta-ias example, `xs-security.json` is present but not referenced by any MTA module — it's a leftover from the XSUAA variant and can be removed.

The IAS authorization model is configured in the `identity` resource's `config` block and in the Cloud Identity cockpit, not in `xs-security.json`.
