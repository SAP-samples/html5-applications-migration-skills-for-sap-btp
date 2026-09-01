# SAP Application Router - Service-to-Approuter Integration Flow

This document describes how programmatic (service-to-service) callers authenticate with the SAP Application Router. Two header-based flows are supported: the existing `x-approuter-authorization` flow and the newer `x-approuter-access-token` flow which uses Identity app2app token exchange with mandatory mTLS.

For the end-user browser request lifecycle, see [approuter-flows.md](approuter-flows.md).

---

## Flow Overview

| Attribute | `x-approuter-authorization` (Flow 1) | `x-approuter-access-token` (Flow 2) |
|-----------|---------------------------------------|--------------------------------------|
| **Header** | `x-approuter-authorization` | `x-approuter-access-token` |
| **Token type** | Bearer (JWT) or Basic (user:password) | Bearer – weak IAS app2app token |
| **Primary middleware** | `service-to-approuter-middleware` | `access-token-middleware` (runs first) + `service-to-approuter-middleware` |
| **mTLS required** | No | Yes – `.cert` or `.mesh` CF route |
| **Token caching** | Basic path only (per username) | Yes (keyed on incoming app2app token) |
| **Binding required** | XSUAA or IAS binding on approuter | IAS binding on approuter |

---

## Flow 1 – x-approuter-authorization Header (Existing Flow)

### How It Works

The caller places a pre-obtained token directly in the `x-approuter-authorization` header. The approuter's `service-to-approuter-middleware` intercepts the request, validates the token, and creates a security context that the rest of the middleware chain can use for authorization decisions.

### Bearer Token Path

1. `service-to-approuter-middleware` detects `Authorization: Bearer <token>` in `x-approuter-authorization`.
2. The middleware passes the token to `@sap/xssec` for validation.
3. `@sap/xssec` verifies the token signature and claims using the approuter's bound XSUAA **or** Identity (IAS) service credentials.
4. A security context object is created and attached to the request.
5. The request continues through the standard middleware chain (authentication, authorization, routing).

**Supported identity providers:**
- XSUAA – validated against the bound XSUAA service instance
- IAS – validated against the bound Identity service instance

### Basic Token Path

1. `service-to-approuter-middleware` detects `Authorization: Basic <base64(user:password)>` in `x-approuter-authorization`.
2. The middleware decodes the credentials to extract `username` and `password`.
3. A client-credentials or password-grant token request is made using the provider's `username`/`password` combined with the approuter binding credentials (client ID + secret).
4. On success, `x-approuter-authorization` is **replaced** with `Authorization: Bearer <new-token>` for the remainder of the request lifecycle.
5. The resulting token is **cached per username** to avoid repeated token requests for the same caller identity.

**Cache behaviour:** The cached token is reused until it expires. A fresh token is fetched automatically on expiry.

### Code Reference

- **Middleware**: `lib/middleware/service-to-approuter-middleware.js`
- **Validation library**: `@sap/xssec` – `createSecurityContext()`

---

## Flow 2 – x-approuter-access-token Header (New Flow)

### Concept: Weak vs Strong Tokens

An IAS **app2app token** (also called a *weak token*) is scoped to a specific IAS application dependency. It proves the caller's identity within the IAS trust domain but does **not** carry the approuter-specific scopes or audience required to authorise backend resource access.

A **strong token** is the result of exchanging the weak token against the approuter's own IAS binding credentials. It carries the correct audience and can be validated by `@sap/xssec` exactly like a directly presented Bearer token.

The `x-approuter-access-token` flow automates this exchange transparently so callers only need to obtain a weak app2app token.

### How It Works

1. **`access-token-middleware` runs before `service-to-approuter-middleware`** and checks for the `x-approuter-access-token` header.
2. The middleware extracts the Bearer value (weak app2app token) from the header.
3. A token exchange request is made to the IAS token endpoint using the approuter's bound **Identity service binding credentials** (client ID + secret + certificate for mTLS).
4. On a successful exchange, the returned **strong token** is written to `x-approuter-authorization: Bearer <strong-token>`.
5. The `x-approuter-access-token` header is **deleted** from the request before it continues.
6. `service-to-approuter-middleware` picks up the strong token from `x-approuter-authorization` and proceeds with the standard Bearer token validation path (see Flow 1).

**Result:** downstream middleware and backends see a fully validated security context. The original weak token is never forwarded.

### mTLS Requirement

mTLS (mutual TLS) is **mandatory** for the `x-approuter-access-token` flow. The IAS token exchange endpoint requires the caller to authenticate with a client certificate in addition to the client credentials.

**CF route requirement:** The approuter must be accessed via a route that includes `.cert` or `.mesh` in the hostname. These routes terminate mTLS at the Cloud Foundry router and forward the client certificate to the approuter.

| Route type | Example URL |
|------------|-------------|
| `.cert` route | `https://<approuter>.cert.cfapps.<landscape>/path` |
| `.mesh` route | `https://<approuter>.mesh.cfapps.<landscape>/path` |

**Standard routes** (without `.cert`/`.mesh`) will cause the token exchange to fail because no client certificate is presented.

**Client certificate source:** Use the certificate and private key from the approuter's IAS service binding (`VCAP_SERVICES.identity[].credentials.certificate` and `.key`). These are also the credentials the approuter uses internally for the token exchange.

> The caller must present the **same** IAS binding certificate as the mTLS client certificate. This creates a closed trust loop: only services that possess the IAS binding credentials can initiate the exchange.

### Token Caching

The exchanged strong token is cached, keyed on the **incoming app2app token value**. Subsequent requests carrying the same app2app token reuse the cached strong token until it expires, reducing IAS token endpoint calls.

### Code Reference

- **Middleware**: `lib/middleware/access-token-middleware.js`
- **Token exchange**: uses IAS token endpoint with `urn:ietf:params:oauth:grant-type:jwt-bearer` grant
- **Validation after exchange**: `lib/middleware/service-to-approuter-middleware.js` + `@sap/xssec`

---

## Middleware Execution Order

Both flows execute within the approuter's standard middleware chain. The relevant ordering is:

**Flow 1 (`x-approuter-authorization` only):**

1. Request arrives at approuter
2. `service-to-approuter-middleware` – validates Bearer or processes Basic credentials
3. Security context attached to request
4. `authentication-handler` – checks login requirement (skipped for service calls with valid context)
5. `authorization-handler` – evaluates route scope requirements against security context
6. Route handling (destination, service, localDir)
7. Backend proxy

**Flow 2 (`x-approuter-access-token`):**

1. Request arrives at approuter (must be via `.cert`/`.mesh` route)
2. **`access-token-middleware`** – exchanges weak token → strong token; sets `x-approuter-authorization`; deletes `x-approuter-access-token`
3. `service-to-approuter-middleware` – validates the strong token now in `x-approuter-authorization`
4. Security context attached to request
5. `authentication-handler`
6. `authorization-handler`
7. Route handling
8. Backend proxy

---

## Caller Setup Guide

### Setup Phase (Design-Time)

To use Flow 2, an IAS application dependency from the **consumer application** to the **provider (approuter) IAS app** must be established. This is the standard IAS app2app trust mechanism.

**Steps:**

1. In the **provider** subaccount, identify (or create) the IAS application registration for the approuter. Note its **Application Name** (or `app_tid` + `client_id`).
2. The provider IAS application must declare a **provided API** so that consumer applications can depend on it. This is configured via the IAS application's `ias-config.json`:

   ```json
   {
     "display-name": "ias-appfront-backend",
     "name": "ias-appfront-backend",
     "provided-apis": [
       {
         "name": "ias-appfront-backend",
         "description": "IAS appfront backend"
       }
     ]
   }
   ```

   The `provided-apis[].name` value is what consumers reference when adding the dependency.

3. In the **consumer** subaccount or IAS tenant, open the consumer application registration and add the provider as a dependency. The dependency name assigned here becomes the `resource` parameter value in app2app token exchange requests.

   ![IAS Dependency Configuration](../images/ias-dependency-configuration.png)

4. Ensure the consumer application has a service binding or service key that includes a certificate (`credentials.certificate` + `credentials.key`) for mTLS.

> For SAP Managed Approuter (Workzone/Launchpad), the IAS application dependency is typically established by providing the `IASDependencyName` in the MTA deploy configuration. See [../saas-approuter-creds-handling.md](../saas-approuter-creds-handling.md) for details.

### Runtime Phase

**Step 1 – Login to IAS (obtain IAS user token)**

```bash
curl -X POST "https://<ias-tenant>.accounts.ondemand.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --cert consumer-cert.pem --key consumer-key.pem \
  -d "grant_type=password" \
  -d "client_id=<consumer-client-id>" \
  -d "username=<user>" \
  -d "password=<password>"
```

**Step 2 – App2app token exchange (obtain weak token scoped to provider)**

```bash
curl -X POST "https://<ias-tenant>.accounts.ondemand.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --cert consumer-cert.pem --key consumer-key.pem \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  -d "assertion=<ias-login-token>" \
  -d "resource=urn:sap:identity:application:provider:name:<IASDependencyName>"
```

The response contains the weak app2app token (`access_token`).

**Step 3 – Build the mTLS request to the approuter**

The approuter URL **must** use the `.cert` route:

```
https://<approuter>.cert.cfapps.<landscape>/your/path
```

**Step 4 – Use the IAS binding certificate as mTLS client certificate**

Obtain `certificate` and `key` from the approuter's IAS service binding (or from your own IAS binding, if the trust is established). These are PEM-encoded strings in `VCAP_SERVICES`.

**Step 5 – Send the request with `x-approuter-access-token`**

```bash
curl -X GET "https://<approuter>.cert.cfapps.<landscape>/your/path" \
  --cert ias-binding-cert.pem --key ias-binding-key.pem \
  -H "x-approuter-access-token: Bearer <app2app-token>" \
  -H "x-subscriber-tenant: <subscriber-subdomain>"
```

The approuter exchanges the weak token internally and processes the request using the resulting strong token.

---

## Token Caching Behaviour

| Flow | What is cached | Cache key | Notes |
|------|----------------|-----------|-------|
| Flow 1 – Basic path | Bearer token obtained via password grant | `username` | Reused until token expiry; refreshed automatically |
| Flow 1 – Bearer path | Nothing | – | Caller manages token lifecycle; no approuter-side cache |
| Flow 2 – access-token | Exchanged strong token | Incoming app2app token value | Reused until strong token expires; reduces IAS round-trips |

**Implications for callers:**
- Flow 1 Basic: the same username will always reuse the cached token. If you need a fresh token (e.g. after credential rotation), restart the approuter or wait for the cached token to expire.
- Flow 2: each distinct app2app token value has its own cache entry. Long-lived app2app tokens benefit most from caching.

---

## Security Considerations

- **Weak token isolation**: The weak app2app token (`x-approuter-access-token`) is never forwarded to backends or downstream services. It is consumed and deleted by `access-token-middleware` before the request continues.
- **Strong token validation**: After token exchange, the strong token is validated by `@sap/xssec` using the approuter's IAS binding credentials. A token that cannot be validated is rejected with HTTP 401 before any route processing occurs.
- **mTLS enforcement**: Flow 2 requires a `.cert` or `.mesh` CF route. Requests arriving on standard routes cannot complete the IAS token exchange and will fail. This ensures that only callers possessing the correct IAS binding certificate can trigger the exchange.
- **Basic credential scope**: Flow 1 Basic path creates tokens using the approuter binding credentials. The resulting token scope is limited to what the binding's client configuration allows. Callers should not rely on elevated scopes beyond those explicitly granted to the service binding.

---

## Troubleshooting

### x-approuter-authorization Flow Issues

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| HTTP 401 – token validation failed | Invalid or expired Bearer token | Obtain a fresh token; verify IAS/XSUAA binding credentials on the approuter |
| HTTP 401 – Basic credentials rejected | Wrong username/password, or binding credentials incorrect | Verify provider user credentials; check XSUAA/IAS binding in `cf env <approuter>` |
| HTTP 403 – missing scope | Token does not contain required route scope | Add the required scope to the caller's token or adjust the xs-app.json route scope |
| Token created from Basic but quickly expires | Short token TTL on XSUAA/IAS | Adjust token validity in the XSUAA/IAS configuration; the approuter cache will extend effective lifetime |
| Security context `null` after middleware | `service-to-approuter-middleware` not in middleware chain | Verify approuter version supports service-to-approuter flow; check approuter configuration |

### x-approuter-access-token Flow Issues

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| HTTP 401 – token exchange failed | Approuter has no IAS binding, or IAS binding credentials are invalid | Bind an IAS service instance to the approuter; verify `cf env <approuter>` contains `identity` in `VCAP_SERVICES` |
| HTTP 401 – mTLS certificate rejected | Request sent without client certificate, or wrong certificate used | Use `.cert`/`.mesh` route; present the IAS binding certificate with `--cert`/`--key` in curl |
| HTTP 401 – weak token invalid | App2app token expired or issued for wrong audience | Refresh the app2app token; verify the `resource` parameter points to the correct IAS dependency name |
| HTTP 400 – missing IAS dependency | IAS dependency not established between consumer and provider apps | Create the IAS application dependency in the IAS admin console; see [Setup Phase](#setup-phase-design-time) |
| `x-approuter-access-token` header present in backend request | `access-token-middleware` not active or not positioned before `service-to-approuter-middleware` | Verify approuter version; ensure `access-token-middleware` is registered in the middleware chain |
| Token exchange succeeds but authorization fails | Strong token lacks required route scopes | Review xs-app.json route scope requirements; check the IAS app-to-app dependency scope configuration |
| Request works on `.cert` route but fails on standard route | Standard routes do not support mTLS | Always use `.cert` or `.mesh` route for Flow 2; map the appropriate CF route if not yet created |

---

## Code References

### Middleware Files

- `lib/middleware/service-to-approuter-middleware.js` – Bearer and Basic token handling for `x-approuter-authorization`
- `lib/middleware/access-token-middleware.js` – Weak-to-strong token exchange for `x-approuter-access-token`
- `lib/middleware/authentication-handler.js` – Login requirement check (downstream of both flows)
- `lib/middleware/authorization-handler.js` – Route scope authorization (downstream of both flows)

### Libraries

- `@sap/xssec` – `createSecurityContext()` – token validation and security context creation for both XSUAA and IAS tokens

### Related Documentation

| Topic | Link |
|-------|------|
| End-user browser request lifecycle | [approuter-flows.md](approuter-flows.md) |
| IAS dependency (IASDependencyName) and embedded credentials | [../saas-approuter-creds-handling.md](../saas-approuter-creds-handling.md) |
| Approuter troubleshooting (general) | [../troubleshooting/approuter-troubleshooting.md](../troubleshooting/approuter-troubleshooting.md) |

---

*This document covers the service-to-approuter programmatic integration flows. For end-user browser authentication, see [approuter-flows.md](approuter-flows.md).*
