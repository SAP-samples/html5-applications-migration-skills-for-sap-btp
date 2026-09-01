# Fiori Elements Setup for appFront

## Load trigger

Load during Phase 3 when the UI is built with Fiori Elements (SAP Fiori Elements library) or when migrating a Fiori Elements app to appFront.

---

## manifest.json Structure (List Report + Object Page)

Based on the bookshop example — a CAP OData V4 backend with Fiori Elements List Report + Object Page:

```json
{
  "_version": "1.59.0",
  "sap.app": {
    "id": "bookshopapp",
    "type": "application",
    "i18n": "i18n/i18n.properties",
    "applicationVersion": { "version": "0.0.1" },
    "title": "{{appTitle}}",
    "description": "{{appDescription}}",
    "dataSources": {
      "mainService": {
        "uri": "/browse/",
        "type": "OData",
        "settings": {
          "annotations": [],
          "odataVersion": "4.0"
        }
      }
    },
    "crossNavigation": {
      "inbounds": {
        "intent1": {
          "signature": {
            "parameters": {},
            "additionalParameters": "allowed"
          },
          "semanticObject": "object1",
          "action": "action1"
        }
      }
    }
  },
  "sap.cloud": {
    "public": true,
    "service": "bookssvc"
  },
  "sap.ui": {
    "technology": "UI5",
    "deviceTypes": { "desktop": true, "tablet": true, "phone": true }
  },
  "sap.ui5": {
    "dependencies": {
      "minUI5Version": "1.123.1",
      "libs": {
        "sap.m": {},
        "sap.ui.core": {},
        "sap.ushell": {},
        "sap.fe.templates": {}
      }
    },
    "models": {
      "": {
        "dataSource": "mainService",
        "preload": true,
        "settings": {
          "synchronizationMode": "None",
          "operationMode": "Server",
          "autoExpandSelect": true,
          "earlyRequests": true
        }
      }
    },
    "routing": {
      "config": {},
      "routes": [
        {
          "pattern": ":?query:",
          "name": "ListOfBooksList",
          "target": "ListOfBooksList"
        },
        {
          "pattern": "ListOfBooks({key}):?query:",
          "name": "ListOfBooksObjectPage",
          "target": "ListOfBooksObjectPage"
        }
      ],
      "targets": {
        "ListOfBooksList": {
          "type": "Component",
          "id": "ListOfBooksList",
          "name": "sap.fe.templates.ListReport",
          "options": {
            "settings": {
              "contextPath": "/ListOfBooks",
              "variantManagement": "Page",
              "navigation": {
                "ListOfBooks": { "detail": { "route": "ListOfBooksObjectPage" } }
              }
            }
          }
        },
        "ListOfBooksObjectPage": {
          "type": "Component",
          "id": "ListOfBooksObjectPage",
          "name": "sap.fe.templates.ObjectPage",
          "options": {
            "settings": {
              "editableHeaderContent": false,
              "contextPath": "/ListOfBooks"
            }
          }
        }
      }
    }
  },
  "sap.fiori": {
    "registrationIds": [],
    "archeType": "transactional"
  }
}
```

Source: `examples/bookshop-mta-cdm/bookshop-ui/webapp/manifest.json`

---

## Key Fields

| Field | Required | Notes |
|-------|----------|-------|
| `sap.app.id` | Yes | App ID — used as the HTML5 app identifier in appFront; must match the `id` in the MTA's `html5-app` module build output |
| `sap.app.dataSources.mainService.uri` | Yes | Must match the route `source` prefix in `xs-app.json` (e.g., `/browse/` → route `^/browse/(.*)$`) |
| `sap.app.dataSources.settings.odataVersion` | Yes | `"4.0"` for CAP, `"2.0"` for classic OData |
| `sap.cloud.service` | For WorkZone | Value used as Business Solution ID; matches CDM and destination-content `sap.cloud.service` |
| `sap.ui5.dependencies.libs.sap.fe.templates` | Yes (FE apps) | Required library for Fiori Elements templates |
| `sap.ui5.dependencies.minUI5Version` | Yes | Minimum `1.123.1` for current `sap.fe.templates` |
| `sap.ui5.routing.targets[*].name` | Yes | `"sap.fe.templates.ListReport"` or `"sap.fe.templates.ObjectPage"` |

---

## dataSource URI ↔ xs-app.json Alignment

The `dataSources.mainService.uri` MUST have a matching route in `xs-app.json`:

**manifest.json:**
```json
"dataSources": {
  "mainService": {
    "uri": "/browse/"
  }
}
```

**xs-app.json:**
```json
{
  "source": "^/browse/(.*)$",
  "target": "/browse/$1",
  "destination": "bookshop",
  "authenticationType": "ias",
  "csrfProtection": false
}
```

The destination name (`bookshop`) must match what's defined in `mta.yaml`'s `parameters.config.destinations`.

---

## sap.cloud.service in manifest.json vs. mta.yaml

| Location | Purpose |
|----------|---------|
| `manifest.json` `sap.cloud` section | Runtime: tells WorkZone Managed Approuter which Business Solution this app belongs to; used for URL routing |
| `mta.yaml` `destination-content` destinations `sap.cloud.service` | Deploy-time: creates credentials destinations grouped by Business Solution ID (html5-repo pattern — removed in appFront) |

After migrating to appFront: `manifest.json` `sap.cloud.service` remains unchanged. The `destination-content` MTA module (which used `sap.cloud.service` on destinations) is removed entirely.

---

## Minimum UI5 Version

| Use case | Minimum `minUI5Version` |
|----------|------------------------|
| `sap.fe.templates` (current) | `1.123.1` |
| CAP OData V4 with `earlyRequests` | `1.120.0` |
| General Fiori Elements | `1.108.0` |

Verify against current Fiori Elements release notes when scaffolding new apps.
