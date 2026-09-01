# Assertions — Case 01: Instance-Level Destinations → appFront + XSUAA

Run the eval, then verify each item against Claude's output and the modified files.

## Phase behavior

- [ ] Claude detects source type as **html5-repo, instance-level destinations** (not subaccount-level, not embedded)
- [ ] Claude presents a **migration plan (Phase 2 checkpoint)** listing every file change before modifying anything
- [ ] No files are modified before the user confirms the plan
- [ ] Claude runs a **critic review (Phase 4)** via Task sub-agent after executing changes
- [ ] All critic FAIL/WARN items are addressed before the final report

## mta.yaml — removals

- [ ] `destination-content` module is **absent** from the migrated `mta.yaml`
- [ ] No `service-key` sub-parameters remain under `xsuaa`, `workflow`, or any other service in the `app-content` requires block
- [ ] `html5-apps-repo` resource (plan `app-host`) is **absent**
- [ ] `HTML5Runtime_enabled: true` is **absent** from the destination service config (or the entire flag is removed)

## mta.yaml — additions and changes

- [ ] An `app-front` resource exists (`service: app-front`, plan `developer` or landscape equivalent)
- [ ] The app-content deployer module `requires` the `app-front` resource with `content-target: true`
- [ ] The app-content deployer module `requires` the XSUAA service instance **directly** (no service-key)
- [ ] `deploy_mode: html5-repo` is present at the MTA root `parameters` block

## xs-app.json

- [ ] No route has `"service": "html5-apps-repo-rt"`
- [ ] The catch-all route (or main static route) has `"service": "app-front"`

## mta.yaml — resource naming convention

- [ ] `sap.cloud.service` (`favorites.svc`) is read from `manifest.json` and used as naming prefix (`favoritessvc`)
- [ ] The `app-front` resource name is `favoritessvc-app-front` and `service-name` is `favoritessvc-app-front-service`
- [ ] The XSUAA resource name is `favoritessvc-xsuaa` and `service-name` is `favoritessvc-xsuaa-service`
- [ ] No resource names use the old source app folder names (e.g. `favoritesInstLevel`, `favoritesapp`)

## Post-migration guidance

- [ ] Claude provides `mbt build` and `cf deploy` commands in the report
- [ ] Claude notes the **undeploy sequence**: `cf undeploy <mta-id> --delete-services --delete-service-keys` before deploying appFront MTA
