# Assertions — Case 02: Subaccount-Level Destinations → appFront + XSUAA

Run the eval, then verify each item against Claude's output and the modified files.

## Phase behavior

- [ ] Claude detects source type as **html5-repo, subaccount-level destinations** (distinguishes from instance-level)
- [ ] Claude presents a **migration plan (Phase 2 checkpoint)** listing every file change before modifying anything
- [ ] No files are modified before the user confirms the plan
- [ ] Claude runs a **critic review (Phase 4)** via Task sub-agent after executing changes
- [ ] All critic FAIL/WARN items are addressed before the final report

## WorkZone / subaccount destination warning

- [ ] Claude **flags that subaccount-level destinations must be deleted manually** from BTP Cockpit after `cf undeploy` (they are not removed by `--delete-services`)
- [ ] The manual deletion step appears in the migration plan (Phase 2) and/or the post-migration report (Phase 5)

## mta.yaml — removals

- [ ] `destination-content` module is **absent** from the migrated `mta.yaml`
- [ ] `html5-apps-repo` resource (plan `app-host`) is **absent**
- [ ] `HTML5Runtime_enabled` flag is **absent** (was `false` in source, should be removed entirely)

## mta.yaml — additions and changes

- [ ] An `app-front` resource exists (`service: app-front`, plan `developer` or equivalent)
- [ ] The app-content deployer module `requires` the `app-front` resource with `content-target: true`
- [ ] The app-content deployer module `requires` the XSUAA service instance **directly**
- [ ] `deploy_mode: html5-repo` is present at the MTA root `parameters` block

## xs-app.json

- [ ] No route has `"service": "html5-apps-repo-rt"`
- [ ] The catch-all route (or main static route) has `"service": "app-front"`

## Post-migration guidance

- [ ] Claude provides the full undeploy + manual destination cleanup sequence:
  1. `cf undeploy <mta-id> --delete-services --delete-service-keys`
  2. Manually delete subaccount-level destinations with `sap.cloud.service` from BTP Cockpit
  3. `cf deploy <mtar>`
