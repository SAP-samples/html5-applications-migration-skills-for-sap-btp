# Known Migration Issues

## Load trigger

Load during Phase 4 (critic review) if the critic flags issues, and during Phase 5 to populate the "Known Issues" section of the migration report.

---

## Compatibility Matrix

| # | Issue | Source Type | Runtime | Auth | Symptom | Fix |
|---|-------|-------------|---------|------|---------|-----|
| 1 | WorkZone CDM breaks | html5-repo (any type) | CF | any | App disappears from WorkZone after migration | Update CDM, see `workzone-integration.md`; check IAS trust is established |
| 2 | 401 on all routes | any | CF | XSUAA | HTTP 401 after deploying migrated app | Verify `authenticationType` in xs-app.json matches xs-security.json scopes |
| 3 | MTA build fails: unknown type | html5-repo | CF | any | `Unknown resource type: html5-apps-repo` | Remove app-host resource; replace with `app-front` resource |
| 4 | Destination not found | any | CF | any | HTTP 404 on backend routes | Verify destination name in xs-app.json matches `parameters.config.destinations` name in mta.yaml |
| 5 | IAS trust not established | html5-repo Embedded | CF | IAS | 401 or subscription fails after migration | Subscriber subaccount must have IAS trust in Security → Trust Configuration |
| 6 | Subaccount destinations not deleted | Subaccount-Level Dest | CF | any | Old html5-repo app still accessible after undeploy | Manually delete subaccount-level destinations with `sap.cloud.service` via BTP Cockpit |
| 7 | `HTML5Runtime_enabled: true` not removed | Instance-Level Dest | CF | any | Deploy succeeds but Managed Approuter still tries instance-level lookup | Remove `HTML5Runtime_enabled: true` from destination service config in mta.yaml |
| 8 | destination-content module not removed | any | CF | any | Deployer fails creating service keys for html5-repo instance that no longer exists | Remove entire `destination-content` module from mta.yaml |
| 9 | service-key requires still present | any | CF | any | `service-key` parameters on xsuaa/workflow in app-content module | Remove `service-key` sub-parameters; keep only direct service instance name in `requires` |
| 10 | xs-app.json uses html5-apps-repo-rt | html5-repo | CF | any | HTTP 500 or "service not available" | Change `"service": "html5-apps-repo-rt"` to `"service": "app-front"` in all static routes |
| 11 | `deploy_mode: html5-repo` missing | any | CF | any | MTA deploy fails with deployer module error | Add `parameters: { deploy_mode: html5-repo }` at MTA root level |
| 12 | content-target not on app-front resource | any | CF | any | HTML5 content not uploaded, app loads blank | Add `parameters: { content-target: true }` under app-front in app-content requires block |
| 13 | Multiple sap.cloud.service in destinations | Subaccount-Level | CF | any | Apps resolve to wrong credentials | Backend destinations must NOT have `sap.cloud.service` property |
| 14 | IAS + XSUAA mixed auth routes not updated | any | CF | both | Some routes return 403 after auth service change | Verify all route `authenticationType` values match the auth service in xs-security.json |

---

## Source Type Detection Issues

| Issue | Indicator | Action |
|-------|-----------|--------|
| Misidentified as Instance-Level when Subaccount-Level | `content.subaccount.destinations` vs `content.instance.destinations` in destination-content module | Check the `content` key — `subaccount` = Type 1, `instance` = Type 2 |
| Misidentified as html5-repo when it's appFront | `service: app-front` already present | App is already migrated — run `appfront-validate` instead |
| No destination-content module but html5-repo app-host present | Embedded Credentials Flow (Type 3) | Most similar to appFront — change service name/plan and xs-app.json routes only |

---

## Service Plan Confusion

Some landscapes use a non-standard plan name for production. The `app-front-omer-af2` plan observed in `integration-app` example is a landscape-specific variant. Always verify with:

```bash
cf marketplace -s app-front
```

If `developer` plan is not available, use whatever `app-front-*` plan is listed for your landscape.
