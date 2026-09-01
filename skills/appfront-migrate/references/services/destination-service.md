# Destination Service Configuration (When Still Needed)

**Status: 🔲 PLACEHOLDER — populate with destination service patterns for appFront.**

## Load trigger

Load during Phase 3a when the source app has backend OData or API destinations that must be preserved after migration.

## What to put here

- **When destination service is still needed**: appFront apps that proxy backend calls through destinations still need the destination service — only the `HTML5Runtime_enabled: true` flag and the `destination-content` module are removed, not the destination service resource itself
- **When destination service can be removed**: apps with only static content and no backend proxy calls
- **Updated destination service resource**: mta.yaml resource definition without `HTML5Runtime_enabled: true`
- **Instance-level vs subaccount-level destinations**: appFront requires subaccount-level destinations (or service-instance-level with proper binding) — document which type your apps use
- **Authentication for backend destinations**: `OAuth2SAMLBearerAssertion`, `OAuth2ClientCredentials`, `BasicAuthentication` — which type and how xs-app.json route `authenticationType` interacts with it
- **Destination validation commands**: `cf env <app>` to check bound destination credentials, destination service API to verify destinations exist

## Current Knowledge (built-in fallback)

Until populated, Claude applies its training knowledge of SAP BTP destination service. If `HTML5Runtime_enabled: true` is found, it will be flagged for removal regardless.
