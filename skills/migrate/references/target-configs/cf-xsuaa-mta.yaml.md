# Target Config: CF + XSUAA appFront mta.yaml

Canonical annotated `mta.yaml` for appFront deployment on Cloud Foundry with XSUAA.
See `../../examples/canonical-app-front-mta.yaml` for the minimal template and `../../examples/manageproducts-mta/mta.yaml` for a real-world example.

## Minimal Template (`canonical-app-front-mta.yaml`)

```yaml
_schema-version: "3.2"
ID: business-solution-id
version: 0.0.1

modules:
  # Content deployer — uploads HTML5 zip to appFront service
  - name: business-solution-app-content
    type: com.sap.application.content
    path: .
    requires:
      # Direct service bindings — no destination-content module needed
      - name: business-solution-xsuaa         # credentials injected into appFront
      - name: business-solution-workflow       # any other reuse service bindings
      - name: business-solution-app-front
        parameters:
          content-target: true                # marks this as the appFront upload target
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - html5-app.zip
          name: html5-app
          target-path: resources/

  # HTML5 source module — builds the app to a zip
  - name: html5-app
    type: html5
    path: html5-app
    build-parameters:
      build-result: dist
      builder: custom
      commands:
        - npm install
        - npm run build:cf
      supported-platforms: []

resources:
  # appFront service — replaces html5-apps-repo app-host
  - name: business-solution-app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: business-solution-app-front-service
      service-plan: developer

  # Destination service — keep if backend OData routes needed; remove HTML5Runtime_enabled
  - name: business-solution-destination-service
    type: org.cloudfoundry.managed-service
    parameters:
      config:
        # HTML5Runtime_enabled: true   ← REMOVE THIS — only needed for html5-apps-repo
        init_data:
          subaccount:
            destinations:
              - Authentication: NoAuthentication
                Name: backend-api
                URL: https://backend-api.example.com
            existing_destinations_policy: update
        version: 1.0.0
      service: destination
      service-plan: lite

  - name: business-solution-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      path: ./xs-security.json
      service: xsuaa
      service-plan: application

  - name: business-solution-workflow
    type: org.cloudfoundry.managed-service
    parameters:
      service: workflow
      service-plan: lite

parameters:
  deploy_mode: html5-repo
```

## Key Rules

| Rule | Detail |
|------|--------|
| `deploy_mode: html5-repo` | Required at MTA level — tells the MTA deployer to use the html5-repo (now appFront) deploy mode |
| `content-target: true` | Required on the appFront resource in the deployer module's `requires` block |
| No `destination-content` module | Completely absent — appFront credentials come from direct `requires` bindings |
| No `HTML5Runtime_enabled: true` | Removed from destination service — this flag is only for html5-apps-repo |
| `service-plan: developer` | Always use `developer` — this is the only valid plan for `app-front` |

## Real-World Variants

- **bookshop (CAP backend + CDM)**: `../../examples/bookshop-mta-cdm/mta.yaml`
- **manageproducts (Northwind backend + CDM)**: `../../examples/manageproducts-mta/mta.yaml`
- **integration-app (two appFront instances + reuse lib)**: `../../examples/integration-app/mta.yaml`
