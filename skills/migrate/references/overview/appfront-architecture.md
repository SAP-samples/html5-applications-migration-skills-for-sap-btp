# appFront Architecture

## Load trigger

Load during Phase 0 when the user is new to appFront, or when they ask "what is appFront?" or "how does appFront work?".

---

## What is appFront?

**SAP Application Frontend (appFront)** is an SAP BTP service that provides a simplified deployment model for HTML5 applications. It replaces the `html5-apps-repo` (HTML5 Application Repository) service for modern BTP applications.

appFront is the **SAP Golden Path** service for HTML5 frontend delivery. It is part of the same infrastructure as html5-apps-repo (NGINX-based static asset delivery with optimized caching) but eliminates the complex credential routing chain required by the Managed Approuter model.

---

## html5-apps-repo vs. appFront

| Aspect | html5-apps-repo | appFront |
|--------|----------------|----------|
| Service name | `html5-apps-repo` | `app-front` |
| Deploy plan | `app-host` | `developer` |
| xs-app.json service key | `"service": "html5-apps-repo-rt"` | `"service": "app-front"` |
| Credential chain | Destination → service key → service binding | Direct binding in deployer `requires` block |
| `destination-content` module | Required (creates credential destinations) | **Not needed** |
| `HTML5Runtime_enabled: true` | Required on destination service | **Not needed** (remove it) |
| Managed Approuter integration | Via `sap.cloud.service` destinations | Via `sap.cloud.service` in manifest.json + CDM (unchanged) |
| IAS trust requirement | Optional | **Required** for subscriber subaccounts |

---

## How Credentials Flow in appFront

In html5-apps-repo, the Managed Approuter resolves credentials by:
1. Reading subaccount-level or instance-level destinations that contain service keys
2. Using those keys to call XSUAA or reuse services

In appFront, credentials are stored **directly in the appFront service instance** during deployment:
1. The `app-content` deployer module `requires` the XSUAA and reuse service instances directly
2. The MTA deployer binds those credentials into the appFront service at deploy time
3. The appFront runtime uses the stored credentials — no destination lookup needed

This is the same model as "HTML5 Repo Embedded Credentials Flow" (Type 3 in `saas-approuter-creds-handling.md`) but with the service name changed from `html5-apps-repo` to `app-front`.

---

## Deployment Model

```
mta.yaml
├── modules
│   ├── app-content (deployer)     ← uploads HTML5 zip + stores credentials in appFront
│   │   requires:
│   │   ├── xsuaa                  ← credentials stored in appFront
│   │   ├── backend-service        ← optional, CAP or other backend URL
│   │   └── app-front (content-target: true)
│   │
│   └── html5-app (builder)        ← builds UI5 app to zip
│
└── resources
    ├── app-front                  ← appFront service instance
    ├── xsuaa                      ← XSUAA instance (unchanged)
    └── destination-service        ← only if backend OData routes exist
        (no HTML5Runtime_enabled)
```

---

## xs-app.json Service Name

Static HTML5 content routes use `"service": "app-front"` instead of the legacy `"service": "html5-apps-repo-rt"`:

```json
{
  "source": "^(.*)$",
  "target": "$1",
  "service": "app-front",
  "authenticationType": "ias"
}
```

---

## Supported Runtimes

| Runtime | Deployment | Notes |
|---------|-----------|-------|
| Cloud Foundry | `mta.yaml` + `cf deploy` | All examples in this repo use CF |
| Kyma | Kubernetes YAML (ServiceInstance, ServiceBinding, APIRule, Job) | Requires separate k8s YAML files — see `references/target-configs/kyma-deployment.md` |

---

## WorkZone Integration

appFront integrates with SAP Build Work Zone in the same way as html5-apps-repo:
- `sap.cloud.service` in `manifest.json` registers the app with the Managed Approuter
- `cdm.json` (Content Deployment Manifest) defines catalog/group/role for site integration
- The CDM is uploaded alongside the app via the deployer module's `before-all` build step

Key difference: the `destination-content` module that registered html5-apps-repo credentials with WorkZone is **no longer needed**. The CDM destination that pointed to html5-apps-repo-rt is also removed.

See `troubleshooting/workzone-integration.md` for the full migration sequence.
