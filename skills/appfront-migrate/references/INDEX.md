# Reference Files Index

Load this file at the start of every migration session. Use it to decide which reference files to load for the current migration context. Load only the relevant files — do not load all of them.

## Index

| File | Description | Load When |
|------|-------------|-----------|
| `overview/appfront-architecture.md` | What appFront is, how the runtime works, service model, MTA deployer role | First session or when user asks "what is appFront?" |
| `overview/appfront-vs-html5repo.md` | Side-by-side comparison: html5-repo vs appFront, why to migrate | When user asks for justification or comparison |
| `overview/migration-decision-tree.md` | Decision tree: source type × runtime × auth service → migration path | Phase 0b, when source/target is unclear |
| `source-types/html5-repo-app.md` | html5-repo 3 modeling types, MTA structure, xs-app.json patterns, WorkZone signals | Phase 1, source is html5-repo |
| `source-types/neo-html5-app.md` | Neo HTML5 app structure: neo-mta.yaml, parameters.json, Neo deploy artifacts | Phase 1, source is Neo |
| `source-types/standalone-approuter.md` | Standalone approuter: approuter.nodejs module, localDir routes, MTA group injection, CAP backend wiring | Phase 1, source is standalone-approuter |
| `source-types/saas-approuter-creds-handling.md` | 3 credential modeling types for Managed Approuter, migration section with undeploy steps | Phase 1, any html5-repo source |
| `source-types/instance-level-dest-mta.yaml` | Full "before" MTA with destination-content, html5-apps-repo, HTML5Runtime_enabled | Phase 1, Instance-Level Destinations source |
| `migration-guides/html5-repo-to-appfront.md` | Complete step-by-step guide: html5-apps-repo → appFront | Phase 1 + Phase 3, html5-repo source |
| `migration-guides/neo-to-appfront.md` | Complete step-by-step guide: SAP Neo HTML5 → appFront | Phase 1 + Phase 3, Neo source |
| `migration-guides/standalone-approuter-to-appfront.md` | Complete step-by-step guide: standalone approuter (localDir) → appFront, including build tooling setup | Phase 1 + Phase 3, standalone-approuter source |
| `migration-guides/managed-approuter-to-appfront.md` | WorkZone managed approuter variant migration steps | Phase 1, WorkZone-integrated source |
| `target-configs/cf-xsuaa-mta.yaml.md` | Annotated canonical CF + XSUAA target mta.yaml | Phase 3a, CF+XSUAA target |
| `target-configs/cf-ias-mta.yaml.md` | Annotated canonical CF + IAS target mta.yaml | Phase 3a, CF+IAS target |
| `target-configs/kyma-deployment.md` | Kyma ServiceInstance, ServiceBinding, APIRule, Function yaml guide | Phase 3d, Kyma target |
| `target-configs/xs-app-patterns.md` | All xs-app.json routing patterns: none/xsuaa/ias auth, app-front service routes | Phase 3b, always |
| `services/xsuaa-config.md` | xs-security.json patterns: xsappname, scopes, role templates, role collections | Phase 3c, XSUAA auth |
| `services/ias-config.md` | IAS security config: oauth2-configuration, xs-security.json IAS variant | Phase 3c, IAS auth |
| `services/app-front-service.md` | appFront service plans (developer, build-default), binding, CDM, credentials | Phase 3a, always |
| `services/destination-service.md` | When destination service is still needed after migration, HTML5Runtime removal | Phase 3a, when backend destinations present |
| `golden-path/golden-path-overview.md` | SAP Golden Path concept: BTP-hosted backend + appFront frontend | Phase 0b, backend is BTP |
| `golden-path/cap-backend-mta.yaml.md` | Full MTA example: CAP backend + appFront frontend | Phase 3, CAP backend |
| `golden-path/fiori-elements-setup.md` | Fiori Elements manifest.json, dataSources, sap.fe.templates dependency | Phase 3, Fiori Elements UI |
| `troubleshooting/known-issues.md` | Compatibility matrix, known blockers, platform-specific caveats | Phase 4, critic finds issues |
| `troubleshooting/workzone-integration.md` | CDM format, site assignment, role collections for WorkZone | Phase 0c, WorkZone detected |
| `troubleshooting/deployment-errors.md` | Common MTA deploy failures after migration with fixes | Phase 5, deploy fails |

## Status Legend

- ✅ Populated — ready for use
- 🔲 Placeholder — Claude uses built-in knowledge as fallback; populate with team-specific content

## Current Status

| File | Status |
|------|--------|
| `overview/appfront-architecture.md` | ✅ Populated |
| `overview/appfront-vs-html5repo.md` | 🔲 Placeholder |
| `overview/migration-decision-tree.md` | ✅ Populated |
| `source-types/html5-repo-app.md` | ✅ Populated — 3 modeling types, MTA structure, WorkZone signals |
| `source-types/neo-html5-app.md` | 🔲 Placeholder |
| `source-types/standalone-approuter.md` | ✅ Populated — approuter.nodejs, localDir routes, group:destinations, CAP wiring |
| `source-types/saas-approuter-creds-handling.md` | ✅ Populated — 3 credential modeling types, migration section |
| `source-types/instance-level-dest-mta.yaml` | ✅ Populated — "before" MTA example with destination-content |
| `migration-guides/html5-repo-to-appfront.md` | ✅ Populated |
| `migration-guides/neo-to-appfront.md` | 🔲 Placeholder |
| `migration-guides/standalone-approuter-to-appfront.md` | ✅ Populated — before/after mta.yaml, localDir→app-front conversion, build tooling |
| `migration-guides/managed-approuter-to-appfront.md` | 🔲 Placeholder |
| `target-configs/cf-xsuaa-mta.yaml.md` | ✅ Populated |
| `target-configs/cf-ias-mta.yaml.md` | ✅ Populated — pure IAS mta.yaml (IASDependencyName, identity service), xs-app.json, IAS trust |
| `target-configs/kyma-deployment.md` | 🔲 Placeholder |
| `target-configs/xs-app-patterns.md` | ✅ Populated — 4 real patterns from examples |
| `target-configs/canonical-app-front-mta.yaml` | ✅ Populated — minimal appFront MTA template |
| `services/xsuaa-config.md` | ✅ Populated |
| `services/ias-config.md` | ✅ Populated — identity resource config, IASDependencyName, XSUAA→IAS migration table |
| `services/app-front-service.md` | ✅ Populated |
| `services/destination-service.md` | 🔲 Placeholder |
| `golden-path/golden-path-overview.md` | 🔲 Placeholder |
| `golden-path/cap-backend-mta.yaml.md` | ✅ Populated — bookshop CAP + appFront full example |
| `golden-path/fiori-elements-setup.md` | ✅ Populated — manifest.json patterns, FE setup |
| `troubleshooting/known-issues.md` | ✅ Populated — 14 known issues |
| `troubleshooting/workzone-integration.md` | ✅ Populated |
| `troubleshooting/deployment-errors.md` | 🔲 Placeholder |
