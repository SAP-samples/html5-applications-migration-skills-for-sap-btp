# xs-app.json Patterns for appFront

All validated xs-app.json patterns from real appFront projects. Load during Phase 3b (xs-app.json update).

## Pattern 1: XSUAA Auth — Simple static + backend OData (manageproducts style)

Demonstrates: logout endpoint, error page, user-api route, scope-guarded route, mixed auth types.

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "logout": {
    "logoutEndpoint": "/my/logout",
    "logoutPage": "/logout-page.html"
  },
  "errorPage": [
    { "status": 403, "path": "./view/errorpages/error-auth.html" }
  ],
  "routes": [
    {
      "source": "^/northwind/(.*)$",
      "target": "$1",
      "destination": "northwind",
      "authenticationType": "none",
      "csrfProtection": false
    },
    {
      "source": "^/logout-page.html$",
      "service": "app-front",
      "authenticationType": "none"
    },
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "authenticationType": "none",
      "destination": "ui5"
    },
    {
      "source": "^/test-resources/(.*)$",
      "target": "/test-resources/$1",
      "authenticationType": "none",
      "destination": "ui5"
    },
    {
      "source": "^/user-api(.*)",
      "service": "sap-approuter-userapi"
    },
    {
      "source": "^/index.html$",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate"
    },
    {
      "source": "^/.*view/errorpages/(.*)$",
      "target": "/view/errorpages/$1",
      "service": "app-front",
      "authenticationType": "none"
    },
    {
      "source": "^/missing-scopes/(.*)$",
      "target": "/view/missing-scopes/$1",
      "authenticationType": "xsuaa",
      "service": "app-front",
      "scope": ["$XSAPPNAME.read"]
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
Source: `examples/manageproducts-mta/products/xs-app.json`

---

## Pattern 2: IAS Auth — CAP backend + fine-grained caching (bookshop style)

Demonstrates: IAS auth throughout, `no-cache` on key files (index.html, manifest.json, xs-app.json), separate routes for manifest/xs-app files, OData backend via destination, ui5.sap.com resources via destination.

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/browse/(.*)$",
      "target": "/browse/$1",
      "destination": "bookshop",
      "authenticationType": "ias",
      "csrfProtection": false
    },
    {
      "source": "^/resources/(.*)$",
      "target": "/resources/$1",
      "authenticationType": "none",
      "destination": "ui5"
    },
    {
      "source": "^/test-resources/(.*)$",
      "target": "/test-resources/$1",
      "authenticationType": "none",
      "destination": "ui5"
    },
    {
      "source": "^/manifest.json$",
      "target": "/manifest.json",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate",
      "authenticationType": "none"
    },
    {
      "source": "^/xs-app.json$",
      "target": "/xs-app.json",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate",
      "authenticationType": "none"
    },
    {
      "source": "^/index.html$",
      "target": "/index.html",
      "service": "app-front",
      "cacheControl": "no-cache, no-store, must-revalidate",
      "authenticationType": "ias"
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
Source: `examples/bookshop-mta-cdm/bookshop-ui/xs-app.json`

---

## Pattern 3: Workflow Service Routes + Reuse Library (integration-app style)

Demonstrates: `com.sap.bpm.workflow` service routes (no destination needed), reuse lib CSS via `aflib` service, scope guard, app-front catch-all with no explicit auth.

```json
{
  "welcomeFile": "/index.html",
  "authenticationMethod": "route",
  "errorPage": [
    { "status": 403, "path": "/error-pages/403-error-page.html" }
  ],
  "routes": [
    {
      "source": "^/bpmworkflowruntime/(.*)$",
      "target": "/$1",
      "service": "com.sap.bpm.workflow",
      "endpoint": "workflow_odata_url"
    },
    {
      "source": "^/workflow-app/(.*)$",
      "target": "/$1",
      "service": "com.sap.bpm.workflow",
      "application": "cross.fnd.fiori.inbox"
    },
    {
      "source": "^/css/(.*)$",
      "target": "/$1",
      "application": "css",
      "service": "aflib"
    },
    {
      "source": "^/missing-scopes/(.*)$",
      "target": "/missing-scopes/$1",
      "service": "app-front",
      "scope": ["$XSAPPNAME.read"]
    },
    {
      "source": "^(.*)$",
      "service": "app-front"
    }
  ]
}
```
Source: `examples/integration-app/integrationapp/xs-app.json`

---

## Pattern 4: Reuse Library — Public, No Auth

For a shared CSS/asset library served from its own appFront instance. No authentication required.

```json
{
  "authenticationMethod": "none",
  "routes": [
    {
      "source": "^(.*)$",
      "target": "$1",
      "service": "app-front"
    }
  ]
}
```
Source: `examples/integration-app/appfront.reuse.lib/xs-app.json`

---

## Key Rules

| Rule | Explanation |
|------|-------------|
| `"service": "app-front"` | Required on routes serving static HTML5 content. Replaces `"service": "html5-apps-repo-rt"`. |
| Route order | Specific routes (exact paths) before catch-all `^(.*)$`. HTML5 repo catch-all MUST be last. |
| `"authenticationType": "none"` on /resources | UI5 framework resources must be public — authentication breaks UI5 bootstrap. |
| `cacheControl` on index.html | `"no-cache, no-store, must-revalidate"` prevents stale login state after logout. |
| `/resources` via `"destination": "ui5"` | Routes UI5 framework files to `https://ui5.sap.com` — configured as a destination in mta.yaml `config.destinations`. |
| `csrfProtection: false` on OData routes | OData services with their own CSRF protection don't need the approuter's layer. |
| `"service": "sap-approuter-userapi"` | Built-in approuter service, no destination needed, returns current user info. |
