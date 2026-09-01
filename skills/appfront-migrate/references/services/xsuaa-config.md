# XSUAA Configuration Patterns

## Load trigger

Load during Phase 3c when the target auth service is XSUAA.

---

## Minimal xs-security.json (bookshop style)

For apps needing a single admin scope:

```json
{
  "scopes": [
    {
      "name": "$XSAPPNAME.admin",
      "description": "admin"
    }
  ],
  "attributes": [],
  "role-templates": [
    {
      "name": "admin",
      "description": "generated",
      "scope-references": [
        "$XSAPPNAME.admin"
      ],
      "attribute-references": []
    }
  ]
}
```

Source: `examples/bookshop-mta-cdm/xs-security.json`

Note: When this xs-security.json is used without a top-level `xsappname` field, the `xsappname` is provided inline in `mta.yaml`:
```yaml
config:
  xsappname: bookshop-${org}-${space}
  tenant-mode: dedicated
```

---

## xs-security.json with uaa.user + Token_Exchange (manageproducts style)

For apps that use token exchange (e.g., when the app needs to call backend services using the user's token):

```json
{
  "xsappname": "manageproductsapp-front",
  "tenant-mode": "dedicated",
  "description": "Security profile of called application",
  "scopes": [
    {
      "name": "uaa.user",
      "description": "UAA"
    }
  ],
  "role-templates": [
    {
      "name": "Token_Exchange",
      "description": "UAA",
      "scope-references": [
        "uaa.user"
      ]
    }
  ]
}
```

Source: `examples/manageproducts-mta/xs-security.json`

`uaa.user` + `Token_Exchange` is the minimum required for OAuth2UserTokenExchange flows. Required when the app routes to backend destinations with `forwardAuthToken: true`.

---

## Key Rules

| Field | Value | Notes |
|-------|-------|-------|
| `xsappname` | globally unique string | Use `<app-id>-${org}-${space}` pattern for uniqueness across CF spaces; alternatively define in `mta.yaml` `config` block |
| `tenant-mode` | `"dedicated"` | For single-tenant apps. Use `"shared"` for multitenant (SaaS) apps |
| `$XSAPPNAME` placeholder | resolved at deploy time | XSUAA replaces this with the actual `xsappname` value |
| `uaa.user` scope | required for token exchange | Needed if any backend destination uses `OAuth2UserTokenExchange` or `forwardAuthToken: true` |
| `Token_Exchange` role template | pairs with `uaa.user` | Must be assigned to users in BTP Cockpit for token exchange to work |

---

## xsappname Uniqueness

The `xsappname` must be globally unique within an XSUAA tenant. Recommended patterns:

```json
{ "xsappname": "myapp-front" }
```

Or in `mta.yaml` (preferred — automatically unique per space):
```yaml
config:
  xsappname: myapp-${org}-${space}
```

The `${org}-${space}` substitution is resolved by the MTA deployer at deploy time.

---

## xs-security.json vs. mta.yaml config block

Two ways to set `xsappname` and `tenant-mode`:

**Option A: in xs-security.json** (manageproducts pattern)
```json
{ "xsappname": "manageproductsapp-front", "tenant-mode": "dedicated", ... }
```

**Option B: override in mta.yaml** (bookshop pattern — xsappname absent from xs-security.json)
```yaml
- name: bookshop-auth
  type: org.cloudfoundry.managed-service
  parameters:
    service: xsuaa
    service-plan: application
    path: ./xs-security.json
    config:
      xsappname: bookshop-${org}-${space}
      tenant-mode: dedicated
```

Option B is preferred when the same xs-security.json is shared across environments, because `${org}-${space}` makes the xsappname unique per CF space automatically.

---

## Route authenticationType and xs-security.json

Routes in `xs-app.json` using `"authenticationType": "xsuaa"` require the corresponding scope to be defined in `xs-security.json`. For scope-guarded routes:

```json
{
  "source": "^/missing-scopes/(.*)$",
  "service": "app-front",
  "scope": ["$XSAPPNAME.read"]
}
```

The scope `$XSAPPNAME.read` must exist in `xs-security.json`:

```json
{
  "scopes": [{ "name": "$XSAPPNAME.read", "description": "read access" }]
}
```
