# Migration Guide: HTML5 Apps Repo to App-Front Service

This guide shows the key differences when migrating from instance-level destinations with `html5-apps-repo` service to the `app-front` service.

## Overview

The main difference is that **app-front** eliminates the need for instance-level destinations by storing service credentials directly within the app-front service instance. This simplifies the architecture and reduces configuration complexity.

## Side-by-Side Comparison

### Modules Section

| Instance-Level Destinations (html5-apps-repo) | App-Front Service |
|-----------------------------------------------|-------------------|
| **Two deployment modules required** | **One deployment module** |
| <br>1. `business-solution-destination-content` module<br>   - Creates instance-level destinations<br>   - Maps service keys to destinations<br>   - Requires destination service<br><br>2. `business-solution-app-content` module<br>   - Deploys HTML5 content<br>   - Requires html5-apps-repo | <br>1. `business-solution-app-content` module<br>   - Deploys HTML5 content<br>   - Directly requires XSUAA and Workflow services<br>   - Requires app-front service |

### Detailed Module Configuration

#### business-solution-destination-content Module

**Instance-Level Destinations (REMOVED in app-front)**

```yaml
# This entire module is NOT needed with app-front
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
```

#### business-solution-app-content Module

**Before (html5-apps-repo):**
```yaml
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
```

**After (app-front):**
```yaml
- name: business-solution-app-content
  type: com.sap.application.content
  path: .
  requires:
    - name: business-solution-xsuaa              # ← ADDED
    - name: business-solution-workflow           # ← ADDED
    - name: business-solution-app-front          # ← CHANGED from html-repo-host
      parameters:
        content-target: true
  build-parameters:
    build-result: resources
    requires:
      - artifacts:
          - html5-app.zip
        name: html5-app
        target-path: resources/
```

### Resources Section

#### Destination Service Configuration

**Before (html5-apps-repo):**
```yaml
- name: business-solution-destination-service
  type: org.cloudfoundry.managed-service
  parameters:
    config:
      HTML5Runtime_enabled: true          # ← Required for html5-apps-repo
      init_data:
        instance:
          destinations:
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
```

**After (app-front):**
```yaml
- name: business-solution-destination-service
  type: org.cloudfoundry.managed-service
  parameters:
    config:
      # HTML5Runtime_enabled removed - NOT needed with app-front
      init_data:
        subaccount:
          destinations:
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
```

#### HTML5 Repository Service

**Before (html5-apps-repo):**
```yaml
# html5-apps-repo with app-host plan
- name: business-solution-html-repo-host
  type: org.cloudfoundry.managed-service
  parameters:
    service: html5-apps-repo
    service-name: business-solution-html5-app-host-service
    service-plan: app-host
```

**After (app-front):**
```yaml
# Replaced with app-front service
- name: business-solution-app-front
  type: org.cloudfoundry.managed-service
  parameters:
    service: app-front                              # ← CHANGED
    service-name: business-solution-app-front-service
    service-plan: developer                         # ← CHANGED plan
```

#### Other Service Instances

XSUAA and Workflow service instances remain **unchanged**:

```yaml
# XSUAA - No changes needed
- name: business-solution-xsuaa
  type: org.cloudfoundry.managed-service
  parameters:
    path: ./xs-security.json
    service: xsuaa
    service-name: business-solution-xsuaa-service
    service-plan: application

# Workflow - No changes needed
- name: business-solution-workflow
  type: org.cloudfoundry.managed-service
  parameters:
    service: workflow
    service-name: business-solution-workflow-service
    service-plan: lite
```

## Migration Checklist

### ✅ Changes Required

1. **Remove** the entire `business-solution-destination-content` module
   - This module created instance-level destinations with service keys
   - No longer needed with app-front

2. **Update** `business-solution-app-content` module
   - Add direct `requires` dependencies for `business-solution-xsuaa` and `business-solution-workflow`
   - Change `business-solution-html-repo-host` to `business-solution-app-front`

3. **Replace** `html5-apps-repo` resource with `app-front`
   - Change service name from `html5-apps-repo` to `app-front`
   - Change service plan from `app-host` to `developer` (or appropriate plan)
   - Update resource name references throughout the file

4. **Update** destination service configuration
   - Remove `HTML5Runtime_enabled: true` parameter
   - This flag was only needed for html5-apps-repo integration

### 🔄 No Changes Required

- HTML5 application module (`html5-app`) - remains identical
- XSUAA service instance configuration
- Workflow service instance configuration
- Backend destinations (without `sap.cloud.service` attribute)
- Build parameters and commands

## Key Benefits of App-Front Migration

1. **Simplified Architecture**: No need for intermediate instance-level destinations
2. **Direct Service Binding**: Credentials stored directly in app-front service
3. **Reduced Complexity**: Fewer modules and configuration steps
4. **Better Security**: Credentials managed internally by app-front service
5. **Easier Maintenance**: Less configuration to manage and update

## How App-Front Handles Credentials

With **app-front**, service credentials are automatically:
- Retrieved from bound XSUAA and Workflow service instances
- Stored securely within the app-front service
- Made available to HTML5 applications without manual destination configuration
- Managed through direct service bindings rather than destination service keys

This eliminates the need for the complex destination mapping configuration that was required with html5-apps-repo.