# Deployment Errors After Migration

**Status: 🔲 PLACEHOLDER — populate with common MTA deploy failures and their fixes.**

## Load trigger

Load during Phase 5 if the user reports a deploy failure after migration, or proactively include in the Phase 5 report's "Known Issues" section.

## What to put here

For each common error, provide: the exact error message (or prefix), root cause, and fix.

## Common Errors

### `Error: Unknown resource type 'html5-apps-repo'`
- **Cause**: residual `html5-apps-repo` app-host resource not removed from mta.yaml
- **Fix**: Remove the resource and all `requires` references to it

### `Error: Service 'app-front' not found in space`
- **Cause**: appFront service not entitled or not available in the CF space
- **Fix**: Check BTP cockpit entitlements, create service instance manually before deploying

### `Error: Route already exists`
- **Cause**: old html5-repo app still deployed; the new appFront deploy tries to claim the same CF route
- **Fix**: `cf undeploy` the old MTA first, or use a different route temporarily

### `401 Unauthorized on all routes`
- **Cause**: `authenticationType` mismatch in xs-app.json after migration
- **Fix**: Verify xs-app.json against `references/target-configs/xs-app-patterns.md`

### _(add your team's cases here)_

## Current Knowledge (built-in fallback)

Until populated, Claude uses the four seed entries above and its training knowledge of CF MTA deployment error patterns.
