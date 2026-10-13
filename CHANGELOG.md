# Changelog

All notable changes to `sap-appfront-skills` will be documented in this file.

## [Unreleased]

### Fixed
- Fix five migration skill logic issues: node_modules copy (#9), frontend-only route confirmation (#10), Neo cacheControl detection and translation (#5), critic deploy_mode false positive (#6), afctl session check and URI example (#8)
- Fix `config.destinations` keys in `neo-to-appfront.md` templates: `Name`/`URL`/`ProxyType`/`Type` → `name`/`url` (PascalCase keys rejected by appFront API at deploy time)
- Remove non-existent `af_rc` role collection from prerequisites; replace with correct role collections (`Application Frontend Developer`, `Application Frontend Viewer`)
- Add missing prerequisites to README and `neo-to-appfront.md`: CF environment must be enabled with org and space created; CF CLI must be logged in and targeted; CF MultiApps plugin must be installed (`cf install-plugin multiapps`)

### Added
- `standalone-approuter` migration source: migrate apps using `approuter.nodejs` with `localDir` routes to appFront. Converts `localDir` routes to `"service": "app-front"` and `group: destinations` to `config.destinations` in the deployer module.
- `appfront-validate` Phase 7 — runtime validation: optionally fetches live files from a deployed app via Playwright (browser automation) and diffs them against local config.
- Live documentation fetching in `appfront-migrate`: skill can fetch relevant SAP Help Portal pages via `WebFetch` when local references are placeholders.
- Destination methodology in migrate Phase 0d: BTP backends use `config.destinations` (no destination service resource); external/on-prem backends use a destination service resource with `init_data`.

## [1.0.0] - 2026-04-19

### Added
- `appfront-migrate` skill: migrate html5-apps-repo (managed approuter) or SAP Neo HTML5 apps to appFront. Supports CF and Kyma runtimes, XSUAA and IAS auth.
- `appfront-validate` skill: validate appFront application configuration for deployment readiness.
- Reference folder structure with smart placeholders for migration guides, target configs, service configs, golden path, and troubleshooting.
- Annotated before/after mta.yaml and xs-app.json examples for html5-repo → appFront migration.
