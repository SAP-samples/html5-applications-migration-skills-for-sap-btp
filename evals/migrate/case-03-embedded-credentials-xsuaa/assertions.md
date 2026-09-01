# Assertions — Case 03: Embedded Credentials → appFront + XSUAA

Run the eval, then verify each item against Claude's output and the modified files.

## Phase behavior

- [ ] Claude detects source type as **html5-repo, embedded credentials** (Type 3 — no destination-content module)
- [ ] Claude notes this is the **closest source type to appFront** and that only service name/plan need to change
- [ ] Claude presents a **migration plan (Phase 2 checkpoint)** listing every file change before modifying anything
- [ ] No files are modified before the user confirms the plan
- [ ] Claude runs a **critic review (Phase 4)** via Task sub-agent after executing changes
- [ ] All critic FAIL/WARN items are addressed before the final report

## mta.yaml — minimal changes only

- [ ] No `destination-content` module is added (it was absent in source — should stay absent)
- [ ] The `requires` block structure of the app-content module is **unchanged** (XSUAA was already a direct requires)
- [ ] `html5-apps-repo` resource is replaced by `app-front` resource (`service: app-front`)
- [ ] Service plan changed from `app-host` to `developer` (or landscape equivalent)
- [ ] `deploy_mode: html5-repo` is present (was present in source — must be preserved)

## mta.yaml — nothing over-migrated

- [ ] Claude does **not** restructure the `requires` block unnecessarily
- [ ] Claude does **not** add a `destination-content` module
- [ ] Claude does **not** remove backend destinations from `parameters.config.destinations`

## xs-app.json

- [ ] No route has `"service": "html5-apps-repo-rt"`
- [ ] The catch-all route (or main static route) has `"service": "app-front"`

## Post-migration guidance

- [ ] Claude provides `mbt build` and `cf deploy` commands
- [ ] Claude notes that no `cf undeploy` is required before deployment (no instance-level destinations to clean up), unless the user's environment has the existing html5-repo MTA running
