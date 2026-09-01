# appFront Service Configuration

## Load trigger

Load during Phase 3a for every migration — this is the core service reference.

---

## MTA Resource Definition

```yaml
- name: business-solution-app-front
  type: org.cloudfoundry.managed-service
  parameters:
    service: app-front
    service-name: business-solution-app-front-service
    service-plan: developer            # see Service Plans below
```

The resource name is referenced in the deployer module's `requires` block:

```yaml
- name: business-solution-app-content
  type: com.sap.application.content
  requires:
    - name: business-solution-xsuaa         # credentials bound directly
    - name: business-solution-app-front
      parameters:
        content-target: true               # marks as upload target
```

---

## Service Plans

The `app-front` service always uses plan `developer`. This is the only valid plan — never use any other value.

```yaml
service-plan: developer
```

---

## Multiple appFront Instances in One MTA

The `integration-app` example shows two appFront instances in a single MTA — one for the main app, one for the reuse library:

```yaml
resources:
  - name: integration-app-app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: integration-app-app-front-service
      service-plan: app-front-omer-af2

  - name: integration-reuse-lib-app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: integration-reuse-lib-app-front-service
      service-plan: app-front-omer-af2
```

Each appFront instance hosts different HTML5 content. The reuse library has its own `xs-app.json` with `"authenticationMethod": "none"`.

Source: `examples/integration-app/mta.yaml`

---

## deploy_mode Requirement

All appFront MTAs must have this global parameter:

```yaml
parameters:
  deploy_mode: html5-repo
```

This tells the MTA deployer to use the html5-repo (now appFront) deploy mode. Without it, the content deployer module will fail.

---

## Service Binding Credentials

The appFront service binding provides credentials that the deployer uses to authenticate the content upload. These are injected automatically by the MTA deployer when `content-target: true` is set — no manual credential handling required.

---

## Known Service Naming Variants

Observed across example MTAs:

| Example | Resource name | service-name |
|---------|--------------|--------------|
| bookshop | `bookshop_app-front` | `bookshop_app-front_service` |
| manageproducts | `manageproducts-app-front` | `manageproducts-app-front-service` |
| integration-app (main) | `integration-app-app-front` | `integration-app-app-front-service` |
| integration-app (reuse lib) | `integration-reuse-lib-app-front` | `integration-reuse-lib-app-front-service` |

Convention: `<app-id>-app-front` for resource name, `<app-id>-app-front-service` for service-name.
