# WorkZone Integration After Migration

## Load trigger

Load during Phase 0c when `sap.cloud.service` is detected in the source, indicating WorkZone integration. Also load during Phase 5 when the migration report includes WorkZone steps.

---

## Background: What sap.cloud.service Means

`sap.cloud.service` is the **Business Solution ID** — it groups all components of a deployable solution: XSUAA instance, HTML5 apps, backend apps, and reuse services. It appears in three places:

1. **`manifest.json`** (`sap.cloud.service`) — connects the app to WorkZone's catalog
2. **`destination-content` module** (`sap.cloud.service` on destinations) — tells the Managed Approuter which service credentials belong together
3. **CDM (`cdm.json`)** — the WorkZone Content Deployment Manifest that registers the app in a site catalog/group

If your source MTA has `sap.cloud.service` in the `destination-content` destinations, the app is using WorkZone Managed Approuter. Migration to appFront changes how credentials are stored but **does not change the WorkZone CDM integration** — the `sap.cloud.service` in `manifest.json` and `cdm.json` remain unchanged.

---

## Migration Steps for WorkZone-Integrated Apps

### Step 1 — Verify CDM is present

Check for `configurations/cdm.json` (or `resources/cdm.json`) in the source project. If missing, the app is not WorkZone-integrated (despite having `sap.cloud.service` in destination-content).

### Step 2 — Verify manifest.json has sap.cloud

```json
{
  "sap.cloud": {
    "public": true,
    "service": "bookssvc"
  }
}
```

This property in `manifest.json` **stays unchanged** after migration. It connects the app to WorkZone's catalog lookup.

### Step 3 — CDM stays unchanged

The `cdm.json` file remains identical. Its content deploys via the MTA `before-all` build step which copies it to `resources/`:

```yaml
build-parameters:
  before-all:
    - builder: custom
      commands:
        - mkdir -p resources
        - cp configurations/cdm.json resources/cdm.json
```

The `resources/cdm.json` is picked up by the appFront deployer module as part of the content upload.

### Step 4 — Remove destination-content CDM destination

In the **Embedded Credentials Flow** (source type 3), the `destination-content` module creates a CDM design-time destination pointing to the html5-apps-repo runtime:

```yaml
# REMOVE this entire destination-content module
- name: business-solution-destination-content
  ...
  parameters:
    content:
      subaccount:
        destinations:
          - Name: business-solution-cdm-destination
            ServiceInstanceName: business-solution-html5-app-runtime-service
            ServiceKeyName: business-solution-html5-app-runtime-key
            URL: https://html5-apps-repo-rt.${default-domain}/applications/cdm/business.solution.service
```

The appFront service registers its CDM endpoint automatically — this manual destination is not needed.

---

## IAS Trust Requirement

**Critical**: For appFront subscriptions, the subscriber subaccount **must** have IAS (SAP Cloud Identity) trust established before the subscription works.

If users see authentication errors after migration, check IAS trust in the BTP Cockpit:
- Go to **Security → Trust Configuration**
- Verify the SAP Identity Authentication Service tenant is listed and Active

---

## Full Migration Sequence for WorkZone-Integrated Apps

```bash
# 1. Undeploy the existing html5-apps-repo MTA (destroys service instances + keys)
cf undeploy <yourMTAId> --delete-services --delete-service-keys

# 2. IMPORTANT: Manually delete subaccount-level destinations if they exist
#    (cf undeploy does NOT delete these)
#    BTP Cockpit → Connectivity → Destinations → delete destinations with sap.cloud.service

# 3. Verify IAS trust is established in subscriber subaccount
#    BTP Cockpit → Security → Trust Configuration → SAP Identity Authentication Service

# 4. Deploy the appFront MTA
cf deploy <mta-archive>.mtar
```

---

## Source Type Detection for WorkZone Integration

| Source Indicator | WorkZone Type | Migration Notes |
|-----------------|---------------|-----------------|
| `destination-content` module with `content.subaccount.destinations` having `sap.cloud.service` | Subaccount-Level Destinations | Delete entire `destination-content` module; delete subaccount destinations manually after undeploy |
| `destination-content` module with `content.instance.destinations` having `sap.cloud.service` | Instance-Level Destinations | Delete entire `destination-content` module; `HTML5Runtime_enabled: true` must also be removed |
| `app-content` module `requires` block has service instances directly (no destination-content) | Embedded Credentials (close to appFront) | Remove html5-repo references; replace with app-front; remove CDM destination from destination-content if present |
| No `sap.cloud.service` anywhere in MTA | Not WorkZone-integrated | Standard migration, no CDM steps needed |

---

## CDM.json Structure Reference

```json
{
  "_version": "3.0.0",
  "site": {
    "_version": "3.0.0",
    "identification": {
      "id": "business-solution-site",
      "entityType": "site"
    },
    "payload": {
      "config": {
        "ushellConfig": {
          "renderers": {
            "fiori2": {
              "componentData": {
                "config": {
                  "applications": {}
                }
              }
            }
          }
        }
      },
      "visualizations": {},
      "catalogs": [{}],
      "groups": [{}],
      "pages": []
    }
  }
}
```

The CDM is uploaded as-is by the appFront deployer — no structural changes required.

---

## Known WorkZone + appFront Compatibility

| Feature | html5-apps-repo + WorkZone | appFront + WorkZone | Notes |
|---------|---------------------------|---------------------|-------|
| CDM catalog/group registration | ✅ | ✅ | Identical |
| `sap.cloud.service` app routing | ✅ | ✅ | Unchanged |
| IAS trust required | Optional | **Required** | Must be set up before subscription |
| Subaccount-level destinations | Required | Not used | Delete after undeploy |
| Instance-level destinations | Required | Not used | Removed during migration |
