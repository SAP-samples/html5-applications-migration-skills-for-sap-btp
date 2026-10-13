# Common appFront Misconfigurations

**Status: 🔲 PLACEHOLDER — populate from real migration and deployment experience.**

## Purpose

Patterns that look syntactically correct but are semantically wrong. Load when a FAIL is found and the cause is not obvious from the basic check.

## What to put here

For each misconfiguration pattern, document:
- **Pattern name**: short identifier
- **Symptom**: what the user observes (error, HTTP code, broken behavior)
- **The trap**: why it looks correct at first glance
- **The actual issue**: what is wrong
- **Detection**: how to identify it
- **Fix**: exact correction

## Known Patterns

### Pattern: `welcomeFile` path mismatch

- **Symptom**: Deployed app shows 404 or blank page
- **The trap**: `welcomeFile: "/index.html"` looks correct
- **The actual issue**: The `index.html` is in a subdirectory of the build output but the path in xs-app.json does not include the subpath
- **Fix**: Verify the build output structure with `ls dist/` after `npm run build`

### Pattern: XSUAA scopes defined but not assigned to role templates

- **Symptom**: Users get 403 even after role assignment in BTP cockpit
- **The trap**: Scopes are defined in xs-security.json, role-templates exist
- **The actual issue**: The role-templates reference the scopes but there is no role-collection defined, or the role-collection is defined but not assigned to users
- **Fix**: Add role-collections in xs-security.json or assign manually in BTP cockpit

### Pattern: `destination-content` module still present after migration

- **Symptom**: `mbt build` succeeds but `cf deploy` fails with service key not found errors
- **The trap**: The destination-content module does not cause build failures
- **The actual issue**: At deploy time, CF tries to create service keys for resources that no longer exist (html5-repo app-host removed but destination-content still references it)
- **Fix**: Remove the destination-content module entirely

### Pattern: html5-repo route in xs-app.json not updated

- **Symptom**: 404 on all static content routes after migration
- **The trap**: xs-app.json was updated but a second xs-app.json file in a different module was missed
- **Detection**: `find . -name xs-app.json` to find all instances
- **Fix**: Update `"service"` to `"app-front"` in all xs-app.json files

### _(add your team's patterns here)_

## Current Knowledge (built-in fallback)

Until populated, Claude uses these 4 seed patterns and its training knowledge of appFront deployment issues.
