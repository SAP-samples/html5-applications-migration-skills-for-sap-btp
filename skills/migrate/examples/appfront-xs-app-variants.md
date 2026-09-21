# appFront xs-app.json Pattern Reference

All xs-app.json variants for appFront applications in one place. Load during Phase 3b (xs-app.json update).

## Pattern 1: XSUAA Auth — Static Content + Backend OData

Most common pattern: UI5 app served from appFront, backend calls proxied via destination service.

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/odata/v4/(.*)$",
      "target": "/odata/v4/$1",
      "destination": "srv-api",
      "authenticationType": "xsuaa"
    },
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "authenticationType": "none"
    },
    {
      "source": "^/test-resources/(.*)$",
      "target": "/test-resources/$1",
      "authenticationType": "none"
    },
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front",
      "authenticationType": "xsuaa"
    }
  ]
}
```

## Pattern 2: IAS Auth — Static Content + Backend OData

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/odata/v4/(.*)$",
      "target": "/odata/v4/$1",
      "destination": "srv-api",
      "authenticationType": "ias"
    },
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "authenticationType": "none"
    },
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front",
      "authenticationType": "ias"
    }
  ]
}
```

> ⚠️ Verify the exact `authenticationType` value for IAS in your appFront version. Populate `references/target-configs/xs-app-patterns.md` with the validated value.

## Pattern 3: Static-Only App (No Backend)

Public UI5 app with no backend calls. Authentication on the static content only.

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "authenticationType": "none"
    },
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front",
      "authenticationType": "xsuaa"
    }
  ]
}
```

## Pattern 4: Public App (No Authentication)

All content publicly accessible, no login required.

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "none",
  "routes": [
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front",
      "authenticationType": "none"
    }
  ]
}
```

## Pattern 5: Multi-destination App

App with multiple backend services (e.g., OData + SAP S/4HANA).

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/cap-api/(.*)$",
      "target": "/cap-api/$1",
      "destination": "cap-srv-api",
      "authenticationType": "xsuaa"
    },
    {
      "source": "^/s4/(.*)$",
      "target": "/s4/$1",
      "destination": "s4-backend",
      "authenticationType": "xsuaa"
    },
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "authenticationType": "none"
    },
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front",
      "authenticationType": "xsuaa"
    }
  ]
}
```

## Key Rules for appFront xs-app.json

| Rule | Explanation |
|------|-------------|
| `"service": "app-front"` | Required on the catch-all route. This tells appFront to serve static content. The **only change** needed when migrating from html5-apps-repo-rt. |
| `authenticationMethod` at root | `"route"` = per-route auth control; `"none"` = all routes public |
| Route order matters | Routes are matched top-to-bottom; put specific routes before catch-all |
| `authenticationType: "none"` for /resources | UI5 framework resources must be public (no auth) for UI5 bootstrap to work |
| `welcomeFile` | Must point to an existing file served by appFront |
