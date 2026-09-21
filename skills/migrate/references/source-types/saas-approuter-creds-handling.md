# SAP Managed Approuter Credentials Handling

## Table of Contents

- [Overview](#overview)
  - [Business Solution Concept](#business-solution-concept)
  - [Business Solution Cardinality Diagram](#business-solution-cardinality-diagram)
- [Background](#background)
- [Current Modeling Types](#current-modeling-types)
  - [1. Subaccount-Level Destinations](#1-subaccount-level-destinations)
    - [Configuration Details](#configuration-details)
    - [Runtime Processing](#runtime-processing)
    - [Limitation](#limitation)
    - [MTA.yaml Example](#mtayaml-example)
  - [2. Instance-Level Destinations](#2-instance-level-destinations)
    - [Configuration Details](#configuration-details-1)
    - [Design-Time Integration](#design-time-integration)
    - [Runtime Processing](#runtime-processing-1)
    - [MTA.yaml Example](#mtayaml-example-1)
  - [3. HTML5 Repo Embedded Credentials Flow](#3-html5-repo-embedded-credentials-flow)
    - [Configuration Details](#configuration-details-2)
    - [Runtime URLs](#runtime-urls)
    - [Runtime Processing](#runtime-processing-2)
    - [MTA.yaml Example (Single Tenant with Workzone Integration)](#mtayaml-example-single-tenant-with-workzone-integration)
    - [MTA.yaml Example (Multitenant with CAP Backend and MTX)](#mtayaml-example-multitenant-with-cap-backend-and-mtx)
- [Misconfigurations](#misconfigurations)
  - [General (All Modeling Types)](#general-all-modeling-types)
  - [Subaccount-Level Destinations (Reuse Services)](#subaccount-level-destinations-reuse-services)
  - [Subaccount-Level Destinations (Customer Applications)](#subaccount-level-destinations-customer-applications)
  - [Instance-Level Destinations](#instance-level-destinations)
  - [HTML5 Repo Embedded Credentials Flow](#html5-repo-embedded-credentials-flow)
- [Migration to Application Frontend Service](#migration-to-application-frontend-service)

---

## Overview

This document describes the credential handling mechanisms for customer applications when using SAP Managed Approuter (also referred to as saas-approuter). Understanding these mechanisms is critical for proper application configuration and troubleshooting customer misconfigurations.

**Migration Path**: Existing SAP Managed Approuter applications may be migrated to the [Application Frontend Service](https://help.sap.com/docs/application-frontend-service/application-frontend-service/what-is-application-frontend-service). See the [Migration to Application Frontend Service](#migration-to-application-frontend-service) section for details.

### Business Solution Concept

A **Business Solution** is a customer or SAP reuse service (such as Document Service) that is commercialized as a whole. The business solution ID is defined by the `sap.cloud.service` property.

A Business Solution may contain:
- An XSUAA or IAS instance that contain authorization scopes/roles and policies
- One or more HTML5 applications
- Zero to n backend applications
- Zero to n reuse service instances
- Destination configurations
- Other components

**Deployment:**
A Business Solution can be deployed by one or more MTA (Multi-Target Application) objects.

**Multitenancy:**
A Business Solution may also be multitenant. In such cases, it should use the saas-registry service instance.

**Runtime URL Structure:**
The business solution ID (`sap.cloud.service`) is always part of the application runtime URL along with the application name.

### Business Solution Cardinality Diagram

```
                                    Business Solution
                                   (sap.cloud.service)
                                           |
                    _______________________|_______________________
                   |           |           |           |           |
                   |           |           |           |           |
              MTA Objects   XSUAA/IAS   HTML5 Apps  Backend   Reuse Services
                           Instance                  Apps
                   |           |           |           |           |
              Cardinality:    1           1..*        0..*        0..*
                  1..*

                   |
         Destination Configurations
                   |
              Cardinality:
                  0..*

Legend:
  1     = exactly one
  1..*  = one or more
  0..*  = zero or more
```

## Background

The SAP Managed Approuter is maintained by the Workzone team and requires access to credentials for various services created in subscriber subaccounts:
- html5-repo (HTML5 Application Repository)
- XSUAA (User Account and Authentication)
- IAS (Identity Authentication Service)
- Reuse services (e.g., Workflow, Document Service)

Until now, these credentials were accessed via destination configurations pointing to service instance keys. Recently, the html5-repo service introduced a capability to store credentials directly in html5-repo, which is a prerequisite for the Golden Path application modeling paradigm.

---

## Current Modeling Types

SAP Managed Approuter supports three types of modeling:

### 1. Subaccount-Level Destinations

Relies on subaccount-level destinations containing the `sap.cloud.service` property. These destinations may reference html5-repo/app-host, XSUAA, or reuse services (e.g., Workflow, Document Service).

#### Configuration Details

**When created from a reuse service instance:**
- The destination configuration contains XSUAA credentials
- An `html5-apps-repo` property containing html5-apps-repo/app-host-id instance IDs

**For local HTML5 applications, there are two options:**

1. **Single Destination Approach**: One subaccount-level destination with `sap.cloud.service` property containing both XSUAA and app-host credentials

2. **Split Destination Approach**: Two subaccount destinations with the same `sap.cloud.service` value:
   - First destination contains XSUAA credentials
   - One or more destination containing app-host credentials

#### Runtime Processing
- URLs include the `sap.cloud.service` value and the HTML5 application name
- Approuter fetches all subaccount destinations and filters by `sap.cloud.service` 
- Application metadata is fetched from html5-repo

#### Limitation
For reuse services cannot use the same `sap.cloud.service` more than once in a subaccount.

#### MTA.yaml Example

<details>
<summary>Click to expand MTA.yaml example</summary>

```yaml
_schema-version: "3.2"
ID: business-solution-id
version: 0.0.1

modules:
  # Module that creates subaccount-level destinations
  - name: business-solution-destination-content
    type: com.sap.application.content
    requires:
      - name: business-solution-destination-service
        parameters:
          content-target: true
      - name: business-solution-html-repo-host
        parameters:
          service-key:
            name: business-solution-html-repo-host-key
      - name: business-solution-xsuaa
        parameters:
          service-key:
            name: business-solution-xsuaa-key
    parameters:
      content:
        subaccount:
          destinations:
            # Destination with app-host credentials
            - Name: business-solution-html-repo-host-destination
              ServiceInstanceName: business-solution-html5-app-host-service
              ServiceKeyName: business-solution-html-repo-host-key
              sap.cloud.service: business.solution.service
            # Destination with XSUAA credentials
            - Authentication: OAuth2UserTokenExchange
              Name: business-solution-xsuaa-destination
              ServiceInstanceName: business-solution-xsuaa-service
              ServiceKeyName: business-solution-xsuaa-key
              sap.cloud.service: business.solution.service
          existing_destinations_policy: ignore
    build-parameters:
      no-source: true

  # Module that deploys HTML5 application content
  - name: business-solution-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: business-solution-html-repo-host
        parameters:
          content-target: true
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - html5-app.zip
          name: html5-app
          target-path: resources/

  # HTML5 application module
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
  # Destination service instance
  - name: business-solution-destination-service
    type: org.cloudfoundry.managed-service
    parameters:
      config:
        HTML5Runtime_enabled: false
        init_data:
          instance:
            destinations:
              # Backend destination without sap.cloud.service
              - Authentication: NoAuthentication
                Name: backend-api
                ProxyType: Internet
                Type: HTTP
                URL: https://backend-api.example.com
            existing_destinations_policy: update
        version: 1.0.0
      service: destination
      service-name: business-solution-destination-service
      service-plan: lite

  # HTML5 app-host service instance
  - name: business-solution-html-repo-host
    type: org.cloudfoundry.managed-service
    parameters:
      service: html5-apps-repo
      service-name: business-solution-html5-app-host-service
      service-plan: app-host

  # XSUAA service instance
  - name: business-solution-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      path: ./xs-security.json
      service: xsuaa
      service-name: business-solution-xsuaa-service
      service-plan: application

parameters:
  deploy_mode: html5-repo
```

</details>

---

### 2. Instance-Level Destinations

Relies on destination instance IDs. This approach provides better integration with the MTA lifecycle and supports multiple instances of the same `sap.cloud.service` via unique `destinationId`.

#### Configuration Details

When instance-level subaccount destinations are used, there can be:

1. **Reuse Service**: A single destination configuration pointing to a reuse service instance

2. **Local HTML5 Applications**: One destination configuration containing XSUAA credentials and one or more containing app-host credentials (with the same `sap.cloud.service`)

**Important Notes:**
- It is NOT recommended to have different `sap.cloud.service` property values in the context of the same service instance unless these are dependencies
- If there are additional destination configurations that point to a backend, they should NOT contain the `sap.cloud.service` property

#### Design-Time Integration
When `HTML5Runtime_enabled = true`, the destination service creates a subaccount-level destination with the destination instance service key in the Portal subaccount.

#### Runtime Processing
- URLs include `destinationId`, `sap.cloud.service`, and HTML5 application name
- Approuter fetches Portal subaccount destinations, generates a token, and retrieves credentials for html5-repo, XSUAA, or reuse services
- Metadata is fetched from html5-repo

#### MTA.yaml Example

<details>
<summary>Click to expand MTA.yaml example</summary>

```yaml
_schema-version: "3.2"
ID: business-solution-id
version: 0.0.1

modules:
  # Module that creates instance-level destinations
  - name: business-solution-destination-content
    type: com.sap.application.content
    requires:
      - name: business-solution-destination-service
        parameters:
          content-target: true
      - name: business-solution-html-repo-host
        parameters:
          service-key:
            name: business-solution-html-repo-host-key
      - name: business-solution-xsuaa
        parameters:
          service-key:
            name: business-solution-xsuaa-key
      - name: business-solution-workflow
        parameters:
          service-key:
            name: business-solution-workflow-key
    parameters:
      content:
        instance:
          destinations:
            # Destination with app-host credentials
            - Name: business-solution-html-repo-host-destination
              ServiceInstanceName: business-solution-html5-app-host-service
              ServiceKeyName: business-solution-html-repo-host-key
              sap.cloud.service: business.solution.service
            # Destination with XSUAA credentials
            - Authentication: OAuth2UserTokenExchange
              Name: business-solution-xsuaa-destination
              ServiceInstanceName: business-solution-xsuaa-service
              ServiceKeyName: business-solution-xsuaa-key
              sap.cloud.service: business.solution.service
            # Destination pointing to Workflow reuse service instance
            - Name: business-solution-workflow-destination
              Authentication: OAuth2UserTokenExchange
              ServiceInstanceName: business-solution-workflow-service
              ServiceKeyName: business-solution-workflow-key
          existing_destinations_policy: ignore
    build-parameters:
      no-source: true

  # Module that deploys HTML5 application content
  - name: business-solution-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: business-solution-html-repo-host
        parameters:
          content-target: true
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - html5-app.zip
          name: html5-app
          target-path: resources/

  # HTML5 application module
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
  # Destination service instance with HTML5Runtime_enabled: true
  # This creates subaccount-level destination with destination instance service key in Portal subaccount
  - name: business-solution-destination-service
    type: org.cloudfoundry.managed-service
    parameters:
      config:
        HTML5Runtime_enabled: true
        init_data:
          instance:
            destinations:
              # Backend destination without sap.cloud.service
              - Authentication: NoAuthentication
                Name: backend-api
                ProxyType: Internet
                Type: HTTP
                URL: https://backend-api.example.com
            existing_destinations_policy: update
        version: 1.0.0
      service: destination
      service-name: business-solution-destination-service
      service-plan: lite

  # HTML5 app-host service instance
  - name: business-solution-html-repo-host
    type: org.cloudfoundry.managed-service
    parameters:
      service: html5-apps-repo
      service-name: business-solution-html5-app-host-service
      service-plan: app-host

  # XSUAA service instance
  - name: business-solution-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      path: ./xs-security.json
      service: xsuaa
      service-name: business-solution-xsuaa-service
      service-plan: application

  # Workflow reuse service instance
  - name: business-solution-workflow
    type: org.cloudfoundry.managed-service
    parameters:
      service: workflow
      service-name: business-solution-workflow-service
      service-plan: lite

parameters:
  deploy_mode: html5-repo
```

</details>

---

### 3. HTML5 Repo Embedded Credentials Flow

Dependencies are provided via the "required" statement in the mta.yaml deploy module. Credentials are encrypted and stored directly in html5-repo.
Properties are added in the mta.yaml deploy module.

#### Configuration Details

The following properties may be provided:

1. **XSUAA credential**: Approuter will exchange the login token using these credentials

2. **IASDependencyName**: Approuter will trigger app2app token exchange

3. **HTML5Runtime_enabled**: Approuter will share the login token

**Important Note:** When using `IASDependencyName`, the `HTML5Runtime_enabled` property should also be provided.

#### Runtime URLs
Include `sap.cloud.service` + application name or html5-repo instance ID for uniqueness.

#### Runtime Processing
Optimized queries, database indexes, and runtime (NGINX-based) cache support this flow.

#### MTA.yaml Example (Single Tenant with Workzone Integration)

<details>
<summary>Click to expand MTA.yaml example</summary>

```yaml
_schema-version: "3.2"
ID: business-solution-id
version: 0.0.1

build-parameters:
  before-all:
    - builder: custom
      # Copy CDM (Common Data Model) file to resources folder for Workzone integration
      commands:
        - mkdir -p resources
        - cp configurations/cdm.json resources/cdm.json

modules:
  # Destination deployer module - creates CDM design-time destination
  - name: business-solution-destination-content
    type: com.sap.application.content
    requires:
      - name: business-solution-destination-service
        parameters:
          content-target: true
      - name: business-solution-html-repo-runtime
        parameters:
          service-key:
            name: business-solution-html5-app-runtime-key
      - name: business-solution-xsuaa
        parameters:
          service-key:
            name: business-solution-xsuaa-key
    parameters:
      content:
        subaccount:
          destinations:
            # CDM destination pointing to html5-apps-repo runtime
            - Name: business-solution-cdm-destination
              ServiceInstanceName: business-solution-html5-app-runtime-service
              ServiceKeyName: business-solution-html5-app-runtime-key
              URL: https://html5-apps-repo-rt.${default-domain}/applications/cdm/business.solution.service
          existing_destinations_policy: update
    build-parameters:
      no-source: true

  # HTML5 app deployer module - stores XSUAA credentials and backend destinations in html5-repo
  - name: business-solution-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: business-solution-xsuaa
      - name: business-solution-html-repo-host
        parameters:
          content-target: true
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - html5-app.zip
          name: html5-app
          target-path: resources/
    parameters:
      config:
        # Backend destinations stored in html5-repo (no sap.cloud.service property)
        destinations:
          - name: backend-api
            URL: https://backend-api.example.com
            HTML5.ForwardAuthToken: true
          - name: ui5
            url: https://ui5.sap.com

  # HTML5 application module
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
  # HTML5 app-runtime resource for CDM design-time destination
  - name: business-solution-html-repo-runtime
    type: org.cloudfoundry.managed-service
    parameters:
      service: html5-apps-repo
      service-name: business-solution-html5-app-runtime-service
      service-plan: app-runtime

  # HTML5 app-host resource - credentials and destinations are encrypted and stored here
  - name: business-solution-html-repo-host
    type: org.cloudfoundry.managed-service
    parameters:
      service: html5-apps-repo
      service-name: business-solution-html5-app-host-service
      service-plan: app-host

  # Destination service instance
  - name: business-solution-destination-service
    type: org.cloudfoundry.managed-service
    parameters:
      config:
        HTML5Runtime_enabled: false
        init_data:
          subaccount:
            destinations:
              # Launchpad runtime destination
              - Authentication: NoAuthentication
                Name: launchpad-runtime-destination
                ProxyType: Internet
                Type: HTTP
                URL: https://launchpad.example.com
            existing_destinations_policy: update
        version: 1.0.0
      service: destination
      service-name: business-solution-destination-service
      service-plan: lite

  # XSUAA service instance - credentials are stored in html5-repo via "requires" statement
  - name: business-solution-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      path: ./xs-security.json
      service: xsuaa
      service-name: business-solution-xsuaa-service
      service-plan: application

parameters:
  deploy_mode: html5-repo
```

</details>

#### MTA.yaml Example (Multitenant with CAP Backend and MTX)

<details>
<summary>Click to expand MTA.yaml example</summary>

```yaml
_schema-version: '3.1'
ID: business-solution-id
version: 1.0.0
description: "Multitenant business solution with CAP backend"

build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm install
        - npx cds build --production
        - cp -R db/data gen/srv/srv/
        - mkdir -p resources
        - cp configurations/cdm.json resources/cdm.json

modules:
  # HTML5 app deployer module - stores XSUAA credentials and backend destinations in html5-repo
  - name: business-solution-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: business-solution-backend-api
      - name: business-solution-xsuaa
      - name: business-solution-html-repo-host
        parameters:
          content-target: true
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - html5-app.zip
          name: html5-app
          target-path: resources/
    parameters:
      config:
        # Backend destinations stored in html5-repo (no sap.cloud.service property)
        destinations:
          - name: backend-api
            url: ~{business-solution-backend-api/srv-url}
            forwardAuthToken: true
          - name: ui5
            url: https://ui5.sap.com

  # HTML5 application module
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

  # CAP-based backend module
  - name: business-solution-backend
    type: nodejs
    path: gen/srv
    parameters:
      buildpack: nodejs_buildpack
      readiness-health-check-type: http
      readiness-health-check-http-endpoint: /health
    build-parameters:
      builder: npm
      ignore:
        - "node_modules/"
    provides:
      - name: business-solution-backend-api
        properties:
          srv-url: ${default-url}
    requires:
      - name: business-solution-xsuaa

  # Multitenancy handler module - handles subscription callbacks
  - name: business-solution-multitenancy-handler
    type: nodejs
    path: multitenancy-handler
    parameters:
      buildpack: nodejs_buildpack
      env:
        APP_URL: ${default-url}
    build-parameters:
      builder: npm
      ignore:
        - "node_modules/"
    provides:
      - name: business-solution-multitenancy-api
        properties:
          srv-url: ${default-url}
    requires:
      - name: business-solution-html-repo-host

resources:
  # HTML5 app-host resource - credentials and destinations are encrypted and stored here
  - name: business-solution-html-repo-host
    type: org.cloudfoundry.managed-service
    parameters:
      service: html5-apps-repo
      service-name: business-solution-html5-app-host-service
      service-plan: app-host

  # XSUAA service instance with multitenant mode
  - name: business-solution-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: ./xs-security.json
      config:
        xsappname: business-solution-${org}-${space}
        tenant-mode: shared

  # SaaS Registry service for multitenant subscription management
  - name: business-solution-saas-registry
    type: org.cloudfoundry.managed-service
    requires:
      - name: business-solution-multitenancy-api
    parameters:
      service: saas-registry
      service-plan: application
      config:
        xsappname: business-solution-${org}-${space}
        appName: business-solution-app
        displayName: Business Solution Application
        description: Multitenant business solution
        category: 'Business Applications'
        appUrls:
          getDependencies: ~{business-solution-multitenancy-api/srv-url}/callback/v1.0/dependencies
          onSubscription: ~{business-solution-multitenancy-api/srv-url}/callback/v1.0/tenants/{tenantId}
          callbackTimeoutMillis: 300000

parameters:
  deploy_mode: html5-repo
  enable-parallel-deployments: true
```

</details>

---

## Misconfigurations

### General (All Modeling Types)

1. **Backend Destinations Contain sap.cloud.service Property**
   - **Issue**: Destinations that point to backend services contain the `sap.cloud.service` property
   - **Impact**: This can cause routing conflicts and incorrect credential resolution
   - **Resolution**: Remove the `sap.cloud.service` property from all destinations that point to backend services. Only destinations pointing to XSUAA, appHost, or reuse services should contain this property

### Subaccount-Level Destinations (Reuse Services)

1. **Multiple Destinations with Same sap.cloud.service**
   - **Issue**: It is NOT allowed to have multiple subaccount-level destinations that have the same `sap.cloud.service` value
   - **Resolution**: Consolidate or remove duplicate destinations, ensuring only one destination per `sap.cloud.service` value exists in the subaccount

2. **Missing html5-apps-repo Section**
   - **Issue**: When the destination points to a reuse service, the `html5-apps-repo` section is mandatory but may be missing
   - **Resolution**: Add the required `html5-apps-repo` property containing the html5-apps-repo/app-host-id instance IDs to the destination configuration

3. **Destination Points to Deleted Service**
   - **Issue**: The destination may point to a service instance that was accidentally deleted
   - **Resolution**: Replace the service instance credentials in the destination with valid credentials from an existing service instance

### Subaccount-Level Destinations (Customer Applications)

1. **Mismatched sap.cloud.service Between XSUAA and appHost**
   - **Issue**: The XSUAA and appHost destinations contain different `sap.cloud.service` values
   - **Impact**: Approuter won't be able to match them together
   - **Resolution**: Ensure both XSUAA and appHost destinations have the same `sap.cloud.service` value

2. **XSUAA Destination Points to Deleted Instance**
   - **Issue**: The XSUAA destination points to a service instance that was deleted
   - **Impact**: Processing will fail
   - **Resolution**: Replace the XSUAA service instance credentials in the destination with valid credentials from an existing XSUAA instance

3. **appHost Destination Points to Deleted Instance**
   - **Issue**: The appHost destination points to a service instance that was deleted
   - **Impact**: Processing will fail
   - **Resolution**: Replace the appHost service instance credentials in the destination with valid credentials from an existing appHost instance

4. **appHost Instance Contains No HTML5 Applications**
   - **Issue**: The appHost instance does not contain any HTML5 application
   - **Impact**: Processing will fail
   - **Resolution**: Check the MTA html5 app deployer module configuration and re-deploy if needed to ensure HTML5 applications are properly uploaded to the appHost instance

### Instance-Level Destinations

1. **Reuse Service Destination Points to Deleted Instance**
   - **Issue**: The destination points to a reuse service instance that was deleted
   - **Impact**: Processing will fail
   - **Resolution**: Replace the reuse service instance credentials in the destination with valid credentials from an existing instance

2. **XSUAA Destination Points to Deleted Instance**
   - **Issue**: The XSUAA destination points to a service instance that was deleted
   - **Impact**: Processing will fail
   - **Resolution**: Replace the XSUAA service instance credentials in the destination with valid credentials from an existing XSUAA instance

3. **appHost Destination Points to Deleted Instance**
   - **Issue**: The appHost destination points to a service instance that was deleted
   - **Impact**: Processing will fail
   - **Resolution**: Replace the appHost service instance credentials in the destination with valid credentials from an existing appHost instance

4. **Multiple sap.cloud.service Values in Same Destination**
   - **Issue**: The destination contains multiple `sap.cloud.service` values that are not dependencies of each other
   - **Impact**: Can cause confusion and incorrect routing/credential resolution
   - **Resolution**: It is strongly NOT recommended to have multiple `sap.cloud.service` values under the same destination unless some `sap.cloud.service` values are dependencies of the main `sap.cloud.service`. Review and restructure destinations to have a clear primary service with valid dependencies only

### HTML5 Repo Embedded Credentials Flow

1. **Missing Required Configuration Properties**
   - **Issue**: Missing XSUAA credential, IASDependencyName, or HTML5Runtime_enabled configuration in the mta.yaml deploy module
   - **Impact**: HTML5 applications won't show up in the HTML5 applications UI
   - **Resolution**: Add one of the required properties (XSUAA credential, IASDependencyName, or HTML5Runtime_enabled) to the mta.yaml deploy module and re-deploy

2. **IAS Dependency Deleted**
   - **Issue**: The IAS dependency referenced by IASDependencyName was deleted
   - **Impact**: Processing will fail, app2app token exchange cannot be performed
   - **Resolution**: Recreate the IAS dependency or update the IASDependencyName to reference a valid existing IAS instance

3. **XSUAA Instance Deleted**
   - **Issue**: The XSUAA instance whose credentials are stored in html5-repo was deleted
   - **Impact**: Processing will fail, token exchange cannot be performed
   - **Resolution**: Recreate the XSUAA instance with the same configuration and update the credentials in html5-repo by re-deploying the application

4. **IASDependencyName Without HTML5Runtime_enabled**
   - **Issue**: `IASDependencyName` is provided but `HTML5Runtime_enabled` is missing in the mta.yaml deploy module
   - **Impact**: Configuration is incomplete, may cause authentication or token exchange issues
   - **Resolution**: Add the `HTML5Runtime_enabled` property to the mta.yaml deploy module when using `IASDependencyName` and re-deploy

---

## Migration to Application Frontend Service

Existing SAP Managed Approuter applications can be migrated to the [Application Frontend Service](https://help.sap.com/docs/application-frontend-service/application-frontend-service/what-is-application-frontend-service).

### Deployment Modeling Similarities

Application Frontend Service deployment modeling is very similar to the HTML5 Repo Embedded Credentials modeling approach (see [Section 3](#3-html5-repo-embedded-credentials-flow)). The main differences are:

### Key Differences from HTML5 Repo Embedded Credentials

1. **Service Name Change**:
   - **HTML5 Repo**: Service name is `html5-apps-repo`
   - **Application Frontend**: Service name is `app-front`

2. **Service Plan Change**:
   - **HTML5 Repo**: Service plan is `app-host`
   - **Application Frontend**: Service plan is `developer`

3. **xs-app.json Configuration** (not shown in this document):
   - Routes that have `"service": "html5-apps-repo-rt"` should be changed to `"service": "app-front"`

### IAS Trust Requirement

**Important**: For Application Frontend Service subscriptions, the subscriber subaccount **must** establish IAS (SAP Cloud Identity) trust before the subscription can work properly.

### Migration Steps Summary

1. Update service name from `html5-apps-repo` to `app-front` in mta.yaml
2. Update service plan from `app-host` to `developer` in mta.yaml
3. Update xs-app.json routes: change `"service": "html5-apps-repo-rt"` to `"service": "app-front"`
4. Ensure subscriber subaccounts have IAS trust established
5. Undeploy the html5-apps-repo based MTA:
   - Run: `cf undeploy <yourMTAId> --delete-services --delete-service-keys`
   - **Important**: If there are subaccount-level destinations, they must be deleted manually
6. Deploy the app-front based MTA

### MTA.yaml Example (Application Frontend Service with CAP Backend)

<details>
<summary>Click to expand MTA.yaml example</summary>

```yaml
_schema-version: '3.1'
ID: business-solution-id
version: 1.0.0
description: "Business solution with Application Frontend Service"

build-parameters:
  before-all:
    - builder: custom
      commands:
        - npm install
        - npx cds build --production
        - cp -R db/data gen/srv/srv/
        - mkdir -p resources
        - cp configurations/cdm.json resources/cdm.json

modules:
  # AppFront app deployer module - stores XSUAA credentials and backend destinations
  - name: business-solution-app-content
    type: com.sap.application.content
    path: .
    requires:
      - name: business-solution-backend-api
      - name: business-solution-xsuaa
      - name: business-solution-app-front
        parameters:
          content-target: true
    build-parameters:
      build-result: resources
      requires:
        - artifacts:
            - html5-app.zip
          name: html5-app
          target-path: resources/
    parameters:
      config:
        # Backend destinations stored in app-front (no sap.cloud.service property)
        destinations:
          - name: backend-api
            url: ~{business-solution-backend-api/srv-url}
            forwardAuthToken: true
          - name: ui5
            url: https://ui5.sap.com

  # HTML5 application module
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

  # CAP-based backend module
  - name: business-solution-backend
    type: nodejs
    path: gen/srv
    parameters:
      buildpack: nodejs_buildpack
      readiness-health-check-type: http
      readiness-health-check-http-endpoint: /health
    build-parameters:
      builder: npm
      ignore:
        - "node_modules/"
    provides:
      - name: business-solution-backend-api
        properties:
          srv-url: ${default-url}
    requires:
      - name: business-solution-xsuaa

resources:
  # Application Frontend Service resource - credentials are stored here
  - name: business-solution-app-front
    type: org.cloudfoundry.managed-service
    parameters:
      service: app-front
      service-name: business-solution-app-front-service
      service-plan: developer

  # XSUAA service instance
  - name: business-solution-xsuaa
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: ./xs-security.json
      config:
        xsappname: business-solution-${org}-${space}
        tenant-mode: dedicated

parameters:
  deploy_mode: html5-repo
  enable-parallel-deployments: true
```

</details>