# SAP Application Router - Complete Flow Analysis

This document provides a comprehensive analysis of the SAP Application Router flows based on the architectural diagrams and codebase analysis.

## Flow Diagrams

### Visual Diagrams

> **Note**: The visual diagrams below are generated from the source draw.io file. To edit the diagrams, use the [approuter-flows.drawio](approuter-flows.drawio) file with draw.io.

#### 1. Approuter Request Processing Flow
![Approuter Request Processing](../images/approuter-flows-request-processing.drawio.png)

#### 2. Ticket Handling Flow  
![Ticket Handling](../images/approuter-flows-ticket-handling.drawio.png)

### Source Files

- **Editable Source**: [approuter-flows.drawio](approuter-flows.drawio)
- **How to Edit**: 
  - Open the `.drawio` file with [draw.io](https://app.diagrams.net/)
  - Or use the "Draw.io Integration" extension in VS Code
  - After editing, export new PNG images to the `doc/images/` folder

## Overview

The SAP Application Router serves as a central entry point for applications, handling authentication, authorization, routing, and request processing. This analysis covers both the main request processing flow and troubleshooting approaches.

## Main Request Processing Flow

### 1. Initial Request Reception

**Entry Point**: `End User` → `Trigger browser request`

The process begins when an end user triggers a browser request. The URL patterns vary based on the approuter type:

- **Standalone Approuter**: 
  - Single tenant: `https://myapprouter.hana.ondemand.com/index.html`
  - Multitenant: `https://subaccount1.myapprouter.hana.ondemand.com/myapp-1.0.0/index.html`
  - Multitenant + FLP: `https://subaccount1.myapprouter.hana.ondemand.com/cp.portal/site`

- **SAP Managed Approuter (launchpad/cpp)**:
  - **Subaccount level destinations**: `https://subaccount1.launchpad.hana.ondemand.com/myservice.myapp-1.0.0/index.html`
  - **Instance level destinations**: `https://subaccount1.launchpad.hana.ondemand.com/abef0b4e-0a47-4272-9a0f-d8b50d1085f2.myservice.myapp-1.0.0/index.html`
  - **Embedded credentials** (no destinations needed): 
    - `https://subaccount1.launchpad.hana.ondemand.com/myservice.myapp-1.0.0/index.html`
    - `https://subaccount1.launchpad.hana.ondemand.com/abef0b4e-0a47-4272-9a0f-d8b50d1085f2.myservice.myapp-1.0.0/index.html`
    - *(where the GUID is the html5-apps-repo/app-host instance ID)*

### 2. HTML5 Repository Integration

**Decision Point**: `is approuter bound to html5-repo?`

**Implementation**: Located in `lib/utils/html5-repo-utils.js`

- **If No**: Uses approuter's local `xs-app.json` configuration
- **If Yes**: Proceeds with HTML5 repository integration flow

### 3. Application Key Extraction & Managed Approuter Detection

**Process**: `Fetch application key from URL`

**Code Reference**: `lib/utils/dynamic-routing-utils.js:getApplicationKey()`

The system extracts application keys from the URL to identify:
- Application prefix (`sap.cloud.service`)
- Application name
- Application version
- Destination ID (for instance-level destinations)
- HTML5-apps-repo/app-host instance ID (when present in the URL)

**Decision Point**: `is Managed Approuter?`

- **If Yes**: Triggers HTML5 application caching and credential management
- **If No**: Uses approuter binding to find app-host ID

### 4. HTML5 Application Discovery

**For Managed Approuter**:
1. `Get and cache html5 applications + credentials for subaccount`
2. `Find app-host id in cached credentials (by destGuid + sap.cloud.service)`

**For Standalone Approuter**:
1. `Find app-host id in approuter binding (by sap.cloud.service)`

**Implementation**: `lib/utils/html5-repo-utils.js:cacheHTML5Applications()`

#### 4.1 Embedded Credentials Flow

**What is Embedded Credentials Flow?**

In the embedded credentials flow, HTML5 applications have their service credentials (XSUAA, IAS, dependent services) directly uploaded and stored within the HTML5 application repository service. This eliminates the need for separate destination configurations.

**Key Characteristics**:
- **No Destinations Required**: Service credentials are embedded directly in the HTML5 app
- **Simplified Configuration**: No need to configure separate destinations in BTP cockpit
- **Direct Service Access**: Credentials for XSUAA and dependent services are stored with the app
- **App-Host Instance ID**: The GUID in the URL represents the html5-apps-repo/app-host instance ID

**URL Pattern Examples**:
```
# Without instance-level routing
https://subaccount1.launchpad.hana.ondemand.com/myservice.myapp-1.0.0/index.html

# With instance-level routing  
https://subaccount1.launchpad.hana.ondemand.com/abef0b4e-0a47-4272-9a0f-d8b50d1085f2.myservice.myapp-1.0.0/index.html
```

**Code Implementation**:
- **Detection**: `lib/utils/html5-repo-utils.js:_addHTML5ApplicationsToCache()`
- **Logic**: `embeddedCredsApp = !!((credentials && (credentials.xsuaa || credentials.identity)) || html5RuntimeEnabled)`
- **Credential Storage**: Credentials are cached directly with the application metadata

**Flow Differences**:
- **Standard Flow**: Approuter → Destination Service → Backend Service
- **Embedded Flow**: Approuter → HTML5 Repo (with embedded creds) → Backend Service

### 5. XS-App.json Resolution

**Process**: `Fetch xs-app.json from html5-repo (with appHostIds if found)`

**Decision Point**: `html5-repo returns 200?`

- **If Yes**: `use html5 app xs-app.json`
- **If No**: Falls back to `use approuter xs-app.json`

**Code Reference**: `lib/utils/html5-repo-utils.js:getApplicationsMetadata()`

### 6. Route Processing

**Process**: `Perform path rewriting (request url to xs-app.json route)`

**Decision Point**: `is route found?`

- **If No**: Returns `404 (1)` - Route not found
- **If Yes**: Continues to authentication

**Implementation**: Located in middleware chain processing xs-app.json routes

### 7. Authentication & Authorization Flow

#### 7.1 Login Requirement Check

**Decision Point**: `is Login Required?`

**Implementation**: `lib/middleware/authentication-handler.js`

- **If Yes**: Checks if it's an XHR request
  - **XHR Request**: Returns `401 (8)` - Unauthorized for AJAX calls
  - **Browser Request**: Redirects to XSUAA/IAS login

#### 7.2 Authentication Process

**Process Flow**:
1. `Re-direct to XSUAA/IAS`
2. `Browser login in IAS/XSUAA`
3. `Handle Login Callback - fetch IAS/XSUAA token, create user session`

**Decision Point**: `valid cookies?`

- **If No**: Returns `400 (7)` - Bad request due to invalid session
- **If Yes**: Continues to authorization

#### 7.3 Authorization Check

**Decision Point**: `is user authorized for this route?`

**Implementation**: `lib/middleware/authorization-handler.js`

- **If No**: Returns `403 (2)` - Forbidden
- **If Yes**: Continues to CSRF validation

#### 7.4 CSRF Protection

**Decision Point**: `CSRF fetch?`

- **If Yes**: `Add csrf response header`
- **If No**: Checks `is CSRF required/valid?`
  - **Invalid**: Returns `403 (9)` - CSRF validation failed
  - **Valid**: Continues to route handling

### 8. Route Handling

#### 8.1 Route Type Determination

**Decision Point**: `is destination route?`

**Implementation**: Route matching logic in middleware

- **If Yes**: Proceeds to destination handling
- **If No**: Checks for service route

#### 8.2 Destination Route Handling

**Process**: `Fetch destination configuration from env. or destination service`

**Decision Point**: `is destination found?`

- **If No**: Returns `500 (3)` - Destination service error
- **If Yes**: Continues to backend communication

**Implementation**: `lib/utils/destination-utils.js`

#### 8.3 Service Route Handling

**Decision Point**: `is service route?`

- **If Yes**: `Trigger token exchange/create using service binding or html5 app credentials`
  - **Token Handling Success**: Proceeds to backend proxy
  - **Token Handling Failure**: Returns `500 (4)` - Token exchange failed
- **If No**: Checks for local directory route

#### 8.4 Local Directory Route Handling

**Decision Point**: `is localDir route?`

- **If Yes**: `Fetch file from local approuter directory`
  - **File Found**: Returns `file (200)` - Success
  - **File Not Found**: Returns `404 (5)` - File not found
- **If No**: Returns error

### 9. Backend Communication

**Process**: `Pipe request to application (if on premise add connectivity svc proxy)`

**Result**: `Return backend response transparently`

**Implementation**: HTTP proxy functionality with connectivity service integration for on-premise scenarios

## Error Handling

The flow includes comprehensive error handling with specific error codes:

1. **404 (1)**: Route not found in xs-app.json
2. **403 (2)**: User not authorized for route
3. **500 (3)**: Destination service unavailable
4. **500 (4)**: Token handling failed  
5. **404 (5)**: Local file/directory not found
6. **500 (6)**: Token exchange failed for managed approuter
7. **400 (7)**: Invalid session cookies
8. **401 (8)**: Unauthorized XHR request
9. **403 (9)**: CSRF validation failed

## Troubleshooting Flow

### Ticket Processing Decision Tree

The troubleshooting approach varies based on the approuter type:

#### For Standalone Approuter:
1. Get approuter version
2. Get approuter debug level logs
3. Check for old approuter version → Ask customer to update if needed

#### For Managed Approuter:
1. Get logs from HTML5 apps UI
2. If logs show error in approuter:
   - Find matching error in approuter request processing flow
   - Ask for destination configuration
3. If no approuter error:
   - Ask for backend logs
   - Ask for destination configuration

### Key Investigation Areas

1. **Version Check**: Ensure approuter version is current
2. **Log Analysis**: Review debug-level logs for error patterns
3. **Configuration Validation**: Verify destination and service configurations
4. **Flow Mapping**: Match errors to specific points in the request processing flow

## Code References

### Core Components

- **Authentication**: `lib/middleware/authentication-handler.js`
- **Authorization**: `lib/middleware/authorization-handler.js`  
- **HTML5 Repository**: `lib/utils/html5-repo-utils.js`
- **Destination Management**: `lib/utils/destination-utils.js`
- **Dynamic Routing**: `lib/utils/dynamic-routing-utils.js`
- **Service Destinations**: `lib/middleware/service-destinations-middleware.js`

### Key Functions

- `html5RepoUtils.cacheHTML5Applications()` - Caches HTML5 applications and credentials
- `html5RepoUtils.getApplicationsMetadata()` - Fetches application metadata from HTML5 repo
- `destinationUtils.findDestination()` - Locates destination configuration
- `dynamicRoutingUtils.getApplicationKey()` - Extracts application key from URL

## Environment Variables

Key environment variables affecting the flow:

- `HTML5_APPS_CACHE` - Cache TTL for HTML5 applications
- `ACCEPT_EXTERNAL_LOG_LEVEL` - Enables external log level control
- `SAAS_APPROUTER` - Identifies managed approuter mode

## Security Considerations

1. **Authentication Flow**: Secure token handling and session management
2. **Authorization**: Route-level access control based on scopes
3. **CSRF Protection**: Prevents cross-site request forgery attacks
4. **Token Exchange**: Secure credential propagation for service calls

## Performance Optimizations

1. **Caching**: HTML5 applications and credentials caching
2. **Keep-Alive**: HTTP connection reuse for backend calls
3. **Token Reuse**: Efficient token management and refresh

---

*This document was generated from the approuter flow diagrams and represents the complete request processing lifecycle of the SAP Application Router.*