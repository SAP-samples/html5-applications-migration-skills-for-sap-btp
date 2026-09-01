# Assertions — Case 04: Neo HTML5 App → appFront + XSUAA on CF

Run the eval, then verify each item against Claude's output and the modified files.

## Phase behavior

- [ ] Claude detects source type as **Neo HTML5 App** (not html5-repo, not standalone approuter)
- [ ] Claude identifies the Neo indicators: `neo-app.json` present, `sap.platform.hcp` section in `manifest.json`, no `mta.yaml`
- [ ] Claude presents a **migration plan (Phase 2 checkpoint)** listing every file to be created before writing anything
- [ ] No files are written before the user confirms the plan
- [ ] Claude runs a **critic review (Phase 4)** via Task sub-agent after executing changes
- [ ] All critic FAIL/WARN items are addressed before the final report

## Neo source analysis

- [ ] Claude reads and documents `neo-app.json` routes (SAPUI5 resources, `/api` → `java_referenceapp` destination, test-resources)
- [ ] Claude reads `webapp/manifest.json` and extracts `sap.app.id` (`com.sap.library`) and `sap.platform.hcp.uri` (`webapp`)
- [ ] Claude notes the absence of `sap.cloud.service` in the manifest and explains the naming implication
- [ ] Claude documents the Neo security constraints (`p_sap_employees`, `p_neo-app.json_access`) and their appFront equivalents

## mta.yaml — created from scratch

- [ ] A new `mta.yaml` is created (not converted from a Neo descriptor)
- [ ] `mta.yaml` contains an `app-content` deployer module (`type: com.sap.application.content`)
- [ ] An `app-front` resource exists (`service: app-front`, plan `developer`)
- [ ] An `xsuaa` resource exists (`service: xsuaa`, plan `application`)
- [ ] A `destination` resource exists (`service: destination`) for the `java_referenceapp` backend destination
- [ ] `deploy_mode: html5-repo` is present at the MTA root `parameters` block
- [ ] The app-content deployer `requires` the `app-front` resource with `content-target: true`
- [ ] The app-content deployer `requires` the XSUAA service instance directly (no service-key)

## xs-security.json — created from scratch

- [ ] A new `xs-security.json` is created (Neo had no XSUAA security descriptor)
- [ ] `xs-security.json` has `xsappname` derived from `sap.app.id` (`com.sap.library` → `comsaplibrary` or similar)
- [ ] `tenant-mode` is set to `dedicated`
- [ ] A scope equivalent to `p_sap_employees` is defined (or Claude documents why a role is needed instead)

## xs-app.json — created from scratch

- [ ] A new `xs-app.json` is created (Neo had no xs-app.json)
- [ ] `authenticationMethod` is `route`
- [ ] The `/api` route maps to the `java_referenceapp` destination with `authenticationType: xsuaa`
- [ ] SAPUI5 resource routes (`/resources`, `/test-resources`) are present
- [ ] The catch-all (`/`) route has `"service": "app-front"`
- [ ] No Neo-specific route types remain (`type: application` with `name: sapui5preview`, `type: service` with `name: sapui5`)

## Resource naming

- [ ] Since `sap.cloud.service` is absent, Claude either proposes a name derived from `sap.app.id` (`com.sap.library` → `comsaplibrary`) or asks the user to provide one
- [ ] The `app-front` resource name follows the chosen prefix convention
- [ ] The `xsuaa` resource name follows the chosen prefix convention

## Post-migration guidance

- [ ] Claude explains that Neo used SAP ID Service (SAML) and BTP uses XSUAA (OAuth2) — existing users and roles must be re-created in BTP
- [ ] Claude provides `mbt build` and `cf deploy` commands
- [ ] Claude provides the undeploy sequence: `cf undeploy <mta-id> --delete-services --delete-service-keys`
- [ ] Claude notes that the `java_referenceapp` destination must be configured in the BTP destination service
