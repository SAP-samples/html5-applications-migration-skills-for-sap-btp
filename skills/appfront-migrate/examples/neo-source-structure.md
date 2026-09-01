# Neo HTML5 App Source Structure Reference

This file documents the typical structure of a **SAP Neo HTML5 Application** before migration to appFront. Use as a reference to understand the source during Phase 1 baseline analysis.

## Typical Neo HTML5 App Directory Layout

```
neo-html5-app/
├── neo-mta.yaml              # Neo-specific MTA descriptor (not standard CF mta.yaml)
├── parameters.json           # Neo deployment parameters
├── src/
│   └── webapp/               # UI5 application sources
│       ├── Component.js
│       ├── manifest.json     # UI5 app manifest (sap.app, sap.ui5, sap.fiori sections)
│       ├── index.html
│       └── ...
└── .gitignore
```

## neo-mta.yaml Structure (Annotated)

```yaml
# Neo MTA descriptor — different schema from BTP/CF mta.yaml
_schema-version: "2.1"
ID: my-neo-app
version: 1.0.0

modules:
  - name: my-neo-app-ui
    type: com.sap.hcp.html5           # Neo HTML5 module type
    path: src/webapp
    parameters:
      # Neo HTML5-specific runtime properties
      displayName: My Neo App
      description: A UI5 app on Neo

    properties:
      # Neo-specific configuration
      WebIDEEnabled: true
      WebIDEUsage: "odata_gen"

resources:
  # Neo service resources use different type prefix: com.sap.hcp.*
  - name: uaa
    type: com.sap.hcp.xsuaa           # Neo XSUAA (different from BTP XSUAA)
    parameters:
      service-plan: application
      config: ./neo-xs-security.json

  - name: destination
    type: com.sap.hcp.destination     # Neo destination service
```

## parameters.json Structure

```json
{
  "accountName": "<neo-account-name>",
  "applicationName": "my-neo-app",
  "host": "<region>.hana.ondemand.com",
  "destinations": [
    {
      "name": "BACKEND_DEST",
      "url": "https://<backend-host>",
      "authentication": "AppToAppSSO"
    }
  ]
}
```

## Key Differences from BTP/CF

| Aspect | SAP Neo | SAP BTP / CF |
|--------|---------|--------------|
| MTA type | `com.sap.hcp.html5` | `html5` + `com.sap.application.content` |
| Auth service | `com.sap.hcp.xsuaa` | `org.cloudfoundry.managed-service` (xsuaa) |
| Destinations | `parameters.json` + Neo cockpit | CF `destination` service + `xs-app.json` |
| Deployment | Neo cockpit / Neo CLI | `mbt build` + `cf deploy` |
| Content hosting | Neo HTML5 Applications Runtime | appFront service |
| Authentication | SAP ID Service (SAML) | XSUAA or IAS (OAuth2) |

## ⚠️ Important: Neo → BTP is a Rewrite, Not a Conversion

The `neo-mta.yaml` cannot be mechanically converted to a BTP `mta.yaml`. The module types, resource types, and authentication model are fundamentally different. A Neo migration requires:
1. Creating a new `mta.yaml` from scratch using the appFront target template
2. Manually mapping Neo destinations to BTP destination service entries
3. Migrating the authentication model from SAP ID Service/SAML to XSUAA or IAS
4. Verifying all backend calls work with the new token format

Populate `references/migration-guides/neo-to-appfront.md` with your team's specific steps for this rewrite process.
