# Migration Decision Tree

## Load trigger

Load during Phase 0b when the source type, target runtime, or auth service is unclear or needs disambiguation.

---

## Step 1 — Identify Source Type

```
Does mta.yaml contain a module with type: approuter.nodejs?
├── YES → Does xs-app.json (in that module's path) contain "localDir" routes?
│         ├── YES → Source type: standalone-approuter
│         │         → Load: source-types/standalone-approuter.md
│         │         → Load: migration-guides/standalone-approuter-to-appfront.md
│         └── NO  → Unusual: standalone approuter without localDir
│                   → Inspect xs-app.json manually; may be a custom approuter setup
│
└── NO → Does mta.yaml contain a resource with service: html5-apps-repo?
          ├── YES → Is there a destination-content module with sap.cloud.service on destinations?
          │         ├── YES → Does it reference "approuter-extension" or have a cdm.json?
          │         │         ├── YES → Source type: workzone-managed-approuter
          │         │         │         → Load: migration-guides/managed-approuter-to-appfront.md
          │         │         │         → Flag: WorkZone CDM steps required (BLOCKING)
          │         │         └── NO  → Source type: html5-repo (Type 1 or Type 2)
          │         │                   → Load: source-types/html5-repo-app.md
          │         │                   → Load: migration-guides/html5-repo-to-appfront.md
          │         └── NO  → Source type: html5-repo (Type 3 — embedded credentials)
          │                   → Load: source-types/html5-repo-app.md
          │                   → Load: migration-guides/html5-repo-to-appfront.md
          │
          └── NO → Does the project have a neo-mta.yaml or parameters.json (Neo-style)?
                    ├── YES → Source type: neo
                    │         → Load: source-types/neo-html5-app.md
                    │         → Load: migration-guides/neo-to-appfront.md
                    └── NO  → UNKNOWN — ask the user to describe the deployment model
```

---

## Step 2 — Target Runtime

```
Target runtime?
├── CF (Cloud Foundry) → Continue to Step 3
└── Kyma              → Load: target-configs/kyma-deployment.md
                        Additional k8s yaml files required (ServiceInstance, ServiceBinding, APIRule)
```

---

## Step 3 — Target Auth Service

```
Auth service?
├── XSUAA (keep existing) → Load: target-configs/cf-xsuaa-mta.yaml.md
│                           xs-security.json: no changes needed
│
├── IAS (new or migrate)  → Load: target-configs/cf-ias-mta.yaml.md
│                           Load: services/ias-config.md
│                           xs-security.json: requires oauth2-configuration block
│                           IASDependencyName: required in deployer module requires
│
└── Keep existing         → Detect from xs-security.json / ias-security.json presence
                            If both present → ask user which auth is primary
```

---

## Risk Assessment

| Source Type | Runtime | Auth | Complexity | Notes |
|-------------|---------|------|-----------|-------|
| standalone-approuter | CF | XSUAA (keep) | **Medium** | Must extract static content into HTML5 module; add build tooling; convert localDir routes; convert group:destinations |
| standalone-approuter | CF | IAS (migrate) | **High** | All medium steps + xs-security.json restructuring + IASDependencyName |
| html5-repo Type 3 | CF | XSUAA (keep) | **Low** | Change service name/plan only |
| html5-repo Type 1/2 | CF | XSUAA (keep) | **Medium** | Remove destination-content; update app-content requires |
| workzone-managed-approuter | CF | any | **High** | CDM changes required; site assignment manual steps |
| neo | CF | any | **High** | Full restructure; no automated tooling |

---

## Prerequisites per Path

### standalone-approuter
- `mbt` (MTA Build Tool) installed: `npm install -g mbt`
- `ui5` CLI installed (if UI5 apps): `npm install -g @ui5/cli`
- HTML5 app directory must have or receive a `package.json` with a `build:cf` script
- XSUAA service instance must exist in the target CF space (or be created by the MTA deployer)
- IAS trust established in subscriber subaccounts (if using IAS auth)

### html5-repo
- `cf undeploy <mta-id> --delete-services --delete-service-keys` required before re-deploying
- Subaccount-level destinations (Type 1) must be deleted manually from BTP Cockpit after undeploy

### neo
- SAP BTP Cloud Foundry environment must be set up
- Migrate all Neo-specific configuration before attempting CF deployment