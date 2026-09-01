# html5-apps-repo Source App Structure

## Load trigger

Load during Phase 1 baseline analysis when the source type is identified as `html5-apps-repo`.

---

## The Three html5-apps-repo Modeling Types

html5-apps-repo apps come in three credential modeling variants. Identifying the variant determines what exactly needs to change. See `saas-approuter-creds-handling.md` for the full technical background.

| Variant | Identifier in mta.yaml | Migration Complexity |
|---------|------------------------|---------------------|
| **Type 1**: Subaccount-Level Destinations | `destination-content` with `content.subaccount.destinations` having `sap.cloud.service` | Medium — delete destination-content, manually delete subaccount destinations after undeploy |
| **Type 2**: Instance-Level Destinations | `destination-content` with `content.instance.destinations` having `sap.cloud.service` + `HTML5Runtime_enabled: true` | Medium — same as Type 1 plus remove HTML5Runtime_enabled |
| **Type 3**: Embedded Credentials | No `destination-content` module; `app-content` requires list includes XSUAA/services directly | **Easiest** — change service name/plan only |

---

## Type 2: Instance-Level Destinations (Most Common)

Full annotated "before" example at `instance-level-dest-mta.yaml`.

**Structure:**

```
mta.yaml
├── modules
│   ├── business-solution-destination-content   ← REMOVE ENTIRELY
│   │   requires:
│   │   ├── destination-service (content-target: true)
│   │   ├── html-repo-host (service-key: ...)   ← service key pattern
│   │   ├── xsuaa (service-key: ...)
│   │   └── workflow (service-key: ...)
│   │   parameters.content.instance.destinations:
│   │   ├── html-repo-host destination (sap.cloud.service: "...")
│   │   ├── xsuaa destination (sap.cloud.service: "...")
│   │   └── workflow destination
│   │
│   ├── business-solution-app-content           ← MODIFY
│   │   requires: [html-repo-host (content-target: true)]
│   │
│   └── html5-app (builder)                     ← UNCHANGED
│
└── resources
    ├── destination-service                     ← MODIFY: remove HTML5Runtime_enabled: true
    │   config.HTML5Runtime_enabled: true       ← REMOVE
    ├── html-repo-host (html5-apps-repo/app-host) ← REPLACE with app-front
    ├── xsuaa                                   ← UNCHANGED
    └── workflow                                ← UNCHANGED
```

**Key signals to detect Type 2:**
- `destination-content` module is present
- `content.instance.destinations` (not `subaccount`)
- `HTML5Runtime_enabled: true` on destination service resource
- `html5-apps-repo` resource with plan `app-host`

---

## Type 1: Subaccount-Level Destinations

**Structure** (same as Type 2 but with `content.subaccount.destinations`):

```yaml
# destination-content module
parameters:
  content:
    subaccount:          # ← "subaccount" not "instance"
      destinations:
        - Name: html-repo-destination
          sap.cloud.service: "my.service"
```

**Key difference vs Type 2:**
- `HTML5Runtime_enabled` is typically `false` (not `true`)
- After undeploy: subaccount-level destinations **must be manually deleted** from BTP Cockpit
- Instance-level destinations are deleted automatically by `cf undeploy --delete-services --delete-service-keys`

---

## Type 3: Embedded Credentials (Closest to appFront)

```yaml
# app-content module already has direct requires:
- name: app-content
  requires:
    - name: xsuaa           # ← already direct, not via service-key
    - name: html-repo-host
      parameters:
        content-target: true
  parameters:
    config:
      destinations:
        - name: backend-api
          url: ...
          forwardAuthToken: true
```

**Migration**: Change `html5-apps-repo` → `app-front`, `app-host` → `developer`. No structural changes to `requires` block needed. This is already the appFront pattern.

---

## xs-app.json Structure for html5-apps-repo Source

Routes use `"service": "html5-apps-repo-rt"` for static content:

```json
{
  "source": "^(.*)$",
  "target": "$1",
  "service": "html5-apps-repo-rt"   ← CHANGE TO "app-front"
}
```

Or via destination routing (managed approuter with subaccount destinations):

```json
{
  "source": "^(.*)$",
  "target": "$1",
  "destination": "html5-apps-repo-rt-dest"
}
```

The destination-based pattern is replaced by the `"service": "app-front"` pattern in appFront.

---

## WorkZone Integration Signals

| Signal | Location | Meaning |
|--------|----------|---------|
| `sap.cloud.service` on destination | `destination-content` module | WorkZone Managed Approuter integration — see `workzone-integration.md` |
| `cdm.json` present | `configurations/cdm.json` | WorkZone CDM — stays unchanged after migration |
| `sap.cloud` in `manifest.json` | `webapp/manifest.json` | WorkZone site integration — stays unchanged |
