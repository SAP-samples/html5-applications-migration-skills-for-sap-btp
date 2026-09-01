# IAS (Cloud Identity Service) Configuration Patterns

## Load trigger

Load during Phase 3c when the target auth service is IAS (Cloud Identity Service / Identity Authentication Service).

---

## IAS Resource in mta.yaml

The `identity` service resource replaces XSUAA for IAS-first apps:

```yaml
- name: bookshop-ias
  type: org.cloudfoundry.managed-service
  parameters:
    service: identity
    service-name: bookshop-ias
    service-plan: application
    config:
      provided-apis:
        - name: bookshop-ias-api           # name used as IASDependencyName by consuming apps
          description: API exposed by the application
      display-name: bookshop               # shown in Cloud Identity cockpit
      oauth2-configuration:
        token-policy:
          access-token-format: "jwt"       # required for JWT forwarding to backend
      xsuaa-cross-consumption: true        # allows XSUAA clients to call this IAS app
      authorization:
        enabled: true
```

Source: `examples/bookshop-mta-ias/mta.yaml`

---

## IASDependencyName in the appFront Deployer

The appFront deployer config uses `IASDependencyName` to enable IAS app2app token exchange when forwarding requests to backend destinations:

```yaml
- name: bookshop-app-content
  ...
  parameters:
    config:
      IASDependencyName: myCAPbackend      # matches the dependency name configured in IAS admin UI
      destinations:
        - name: bookshop
          url: ~{srv-api/srv-url}
          forwardAuthToken: true
```

`IASDependencyName` must match a **dependency configured manually in the IAS (Cloud Identity Service) admin UI**. This is a required manual step that cannot be automated via mta.yaml:

> **Manual step — IAS Admin UI:**
> 1. Open the SAP Cloud Identity Services admin console
> 2. Navigate to **Applications** → find the **subscribed Application Frontend** application (created automatically when appFront is subscribed)
> 3. Go to **Dependencies**
> 4. Add a dependency with the name matching `IASDependencyName` (e.g. `myCAPbackend`), pointing to the **API exposed by the customer's IAS application instance** (the `provided-apis.name` defined in the customer's `identity` resource — e.g. `bookshop-ias-api`)

The dependency restricts the audience of the exchanged token to the specific backend service, ensuring the forwarded token is only valid for that backend.

---

## xs-app.json for IAS

All authenticated routes use `"authenticationType": "ias"`:

```json
{
  "authenticationMethod": "route",
  "routes": [
    {
      "source": "^/browse/(.*)$",
      "destination": "bookshop",
      "authenticationType": "ias",
      "csrfProtection": false
    },
    {
      "source": "^/resources/(.*)$",
      "authenticationType": "none",
      "destination": "ui5"
    },
    {
      "source": "^(.*)$",
      "service": "app-front",
      "authenticationType": "ias"
    }
  ]
}
```

No `"xsuaa"` routes in a pure IAS app.

---

## No xs-security.json Needed

In a pure IAS app, `xs-security.json` is **not required** by the appFront deployer. The IAS authorization model is defined in:
1. The `identity` resource `config` block in `mta.yaml` (provisioned at deploy time)
2. The SAP Cloud Identity cockpit (application dependencies, attribute mappings)

If `xs-security.json` exists as a leftover from a previous XSUAA setup, it can be removed — no MTA module references it in a pure IAS deployment.

---

## Migration from XSUAA to IAS

| Change | XSUAA | IAS |
|--------|-------|-----|
| Auth resource | `service: xsuaa`, `path: ./xs-security.json` | `service: identity`, inline `config` block |
| Deployer `requires` | Includes XSUAA instance | Remove XSUAA from deployer `requires` |
| Deployer `config` | No special config | Add `IASDependencyName: <name>` |
| xs-app.json routes | `authenticationType: "xsuaa"` | `authenticationType: "ias"` |
| Backend `requires` | XSUAA service | IAS service |
| `xs-security.json` | Required | Not needed (can be removed) |
| IAS trust in subaccount | Optional | **Required** |

---

## IAS Trust Requirement

Before deploying an IAS-authenticated app, the subaccount must trust the IAS tenant:

1. BTP Cockpit → subaccount → **Security → Trust Configuration**
2. Add **SAP Identity Authentication Service** tenant
3. Set status to **Active**

Without trust, all `authenticationType: "ias"` routes return 401 even after successful login.

---

## xsuaa-cross-consumption

Setting `xsuaa-cross-consumption: true` on the IAS resource allows XSUAA-based clients (e.g., BTP services that still use XSUAA) to call this IAS-protected application. Recommended for mixed-auth landscapes where some backend services use XSUAA and the frontend uses IAS.

---

## oauth2-configuration: access-token-format: jwt

Required when the backend service validates JWT tokens directly. Without this, IAS issues opaque tokens which the backend cannot validate locally. Set to `"jwt"` for CAP backends and any service using token-based authorization.
