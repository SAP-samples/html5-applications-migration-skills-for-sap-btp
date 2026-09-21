# SAP Application Router - Comprehensive Troubleshooting Guide

This guide provides systematic troubleshooting approaches for SAP Application Router issues. It is designed for both LLM assistants analyzing debug logs and human support teams investigating customer problems.

## Quick Reference: Error Code Mapping

| Error Code | HTTP Status | Description | Common Causes |
|------------|-------------|-------------|---------------|
| 404 (1) | 404 | Route not found | Missing route in xs-app.json, incorrect URL pattern |
| 403 (2) | 403 | User not authorized | Missing scopes, role assignment issues |
| 500 (3) | 500 | Destination service error | Destination not found, service unavailable |
| 500 (4) | 500 | Token handling failed | OAuth configuration issues, expired tokens |
| 404 (5) | 404 | Local file not found | Missing static files, incorrect localDir path |
| 500 (6) | 500 | Token exchange failed (managed) | Service binding issues, credential problems |
| 400 (7) | 400 | Invalid session cookies | Session expired, cookie issues |
| 401 (8) | 401 | Unauthorized XHR request | Missing authentication for AJAX calls |
| 403 (9) | 403 | CSRF validation failed | Missing CSRF token, invalid token |

## Troubleshooting Decision Tree

### 1. Initial Assessment

**Step 1: Identify Approuter Type**
- **Standalone Approuter**: Deployed as separate CF app
  - URL pattern: `https://myapprouter.hana.ondemand.com/`
  - Customer manages version, environment, configuration
- **SAP Managed Approuter**: Launchpad/CPP/Workzone service
  - URL patterns:
    - `https://subaccount1.launchpad.hana.ondemand.com/`
    - `https://subaccount1.cpp.hana.ondemand.com/`
    - `https://subaccount1.workzone.hana.ondemand.com/`
  - Managed by SAP, customer accesses via HTML5 Applications UI

**Step 2: Gather Essential Information**
- Approuter version (for standalone)
- Error message and timestamp
- Complete URL that failed
- User's role assignments
- xs-app.json configuration
- Destination configurations (if applicable)

### Managed Approuter URL Format Understanding

HTML5 applications can be accessed using these URL formats:

**Format 1 - Basic:**
```
https://<tenant-subdomain>.launchpad.cfapps.<landscape-host>/<sapCloudService>.<appName>-<appVersion>/index.html
```

**Format 2 - With destination instance GUID:**
```
https://<tenant-subdomain>.launchpad.cfapps.<landscape-host>/<destination-instance-guid>.<sapCloudService>.<appName>-<appVersion>/index.html
```

**Format 3 - Portal context:**
```
https://<SubscriberSubdomain>.<PortalHost>.<PortalDomain>/<sapCloudService>.<appName>-<appVersion>/<resourcePath>
```

**Important Notes:**
- `sapCloudService`: From `sap.cloud.service` in manifest.json **without dots**
- `appName`: From `sap.app.id` in manifest.json **without dots and dashes**
- `appVersion`: From `applicationVersion.version` (optional, uses latest if omitted)

**Example:**
```
https://mysubdomain.launchpad.cfapps.eu10.hana.ondemand.com/myservice.helloworld-1.0.0/index.html
```

### 2. Standalone Approuter Troubleshooting

```
Customer Issue → Check Approuter Version → Get Debug Logs → Analyze Flow
                        ↓
                 Old Version? → Ask to Update
                        ↓
                 Analyze specific error in flow
```

**Required Information:**
1. **Version Check**: `cf app <approuter-name>` or check manifest.yml
2. **Debug Logs**: Enable debug logging and reproduce issue
3. **Configuration Files**: xs-app.json, manifest.yml, mta.yaml

**Debug Log Configuration:**
```bash
# Set debug environment variables
cf set-env <your_app> XS_APP_LOG_LEVEL DEBUG
cf set-env <your_app> REQUEST_TRACE true
cf restage <your_app>

# Reproduce issue and collect logs
cf logs <your_app> --recent
```

### 3. Managed Approuter Troubleshooting

```
Customer Issue → Get HTML5 Apps UI Logs → Error in Approuter?
                                               ↓
                                        Yes → Analyze Flow + Destinations
                                               ↓
                                        No → Check Backend + Destinations
```

**Log Access:**
1. **HTML5 Apps UI**: BTP Cockpit → HTML5 Applications → View Logs
2. **Approuter Logs**: Check for approuter-specific errors
3. **Backend Logs**: If no approuter errors found

#### Dynamic Log Level for Managed Approuter

The managed approuter supports dynamic log level changes to debug mode for 30 minutes:

**Prerequisites:**
- User must have `Launchpad_Admin` role collection
- User must be under Default Identity Provider

**Steps:**
1. **Create Basic Authentication Header:**
   ```bash
   # Encode username:password to base64
   echo -n "username:password" | base64
   ```

2. **Set Debug Log Level:**
   ```bash
   curl --location --request POST 'https://<tenant>.cfapps.eu10.hana.ondemand.com/dynamicLogLevel/debug' \
     --header 'x-approuter-authorization: Basic <base64-encoded-credentials>' \
     --header 'x-subscriber-tenant: <subscriber-tenant>'
   ```

3. **Wait 5 minutes** for log level to take effect

4. **Reproduce the issue**

5. **Download logs** from BTP Cockpit → HTML5 Applications → View Logs

**Alternative - Application Logs API:**
```bash
# GET application logs
curl --location --request GET 'https://<providerSubdomain>.<approuterHost>.<cfDomain>/applicationLogs' \
  --header 'x-approuter-authorization: Bearer <base64-encoded-credentials>' \
  --header 'x-subscriber-tenant: <subscriber-subdomain>' \
  --header 'x-application-key: <sapCloudService.appName-appVersion>'  # Optional
```

**Managed Approuter Log Types:**
- `launchpad-rt-approuter`
- `workzone-rt-approuter` 
- `workzonehr-rt-approuter`

**Note:** Debug logs automatically revert to error-only after 30 minutes.

## HTML5 Application Repository Issues

### Uploading Applications

#### 400: Application metadata already exists
**Symptoms:**
- `"Application metadata for application xyz already exists"`
- HTML5 Application Deployment fails

**Root Cause:**
- Multiple app-host service instances contain same `app.id` in manifest.json
- Cannot have duplicate app.id values in same space

**Resolution:**
1. Delete old app-host instance: `cf delete-service <old-app-host>`
2. Or use different `app.id` in resources folder manifest.json
3. Or deploy to different CF space

#### 400: Route not found after subscription
**Symptoms:**
- Subscription succeeds but app fails with "route not found"
- URL format: `<subdomain>-<myapprouter>.<scp domain>`

**Root Cause:**
- Missing wildcard route for multi-tenant subscriptions
- No custom domain configured

**Resolution:**
1. **With custom domain**: Create route `*.<custom-domain>`
2. **Without custom domain**: Create specific route for each subscriber
   ```bash
   cf map-route <app-name> <domain> --hostname <subdomain>-<myapprouter>
   ```

#### 400: Upload content failed
**Symptoms:**
- `"Upload failed"` during content upload
- Validation errors from HTML5 repository

**Common Validation Failures:**
1. **Missing manifest.json**: Must be at root level
2. **Invalid app.id characters**: No hyphens, @, %, & allowed
3. **Invalid app.version format**: Must be `xx.xx.xx` (integers only)
4. **Duplicate app.id**: Already exists in another app-host in same space

**Resolution:**
```json
// Valid manifest.json example
{
  "sap.app": {
    "id": "com.company.myapp",
    "applicationVersion": {
      "version": "1.0.0"
    }
  }
}
```

#### 403: App-host being modified
**Symptoms:**
- `"app-host is being modified by another process"`
- Concurrent deployment failure

**Resolution:**
- Wait for other deployment to complete
- Check for parallel CI/CD pipelines
- Retry after delay

#### 409: Deploy remains in progress
**Symptoms:**
- `"Deploy in progress"` or `"Redeploy in progress"` with 409 response
- Deployment stuck for extended time

**Resolution:**
```bash
# Reset app-host state without deleting service instance
cf html5-delete --content <app-host-id>
```

#### File Size Issues

**Maximum file length exceeded:**
```bash
# Increase app-host size limit
cf update-service my-app-host -c '{"sizeLimit":100}'
```

**Timeout during upload:**
```yaml
# In manifest.yaml of HTML5 Application Deployer
health-check-type: none
```

**100MB size limit exceeded:**
- Split applications across multiple app-host instances
- Optimize application bundle size
- Remove unnecessary files/dependencies

### Running Applications

#### 400: Invalid app-host ID
**Symptoms:**
- `"Invalid App Host ID. Please check with business service provider"`
- Failed to retrieve xs-app.json

**Root Cause:**
- HTML5 app belongs to business service
- App-host ID invalid or incompatible

**Resolution:**
```json
// In app manifest.json
{
  "sap.app": {
    "public": true
  }
}
```

#### 403: Unauthorized access
**Symptoms:**
- `"Unauthorized. Please check with business service UI provider"`
- xs-app.json retrieval fails

**Resolution:**
- Set `"public": true` in app manifest.json
- Or configure proper authentication

#### 404: Resource not found

**Symptoms:**
- `"Application xyz does not exist"`
- HTML5 app not served

**Common Causes & Solutions:**

**Cause 1: Incorrect application name in URL**
- **Issue**: Periods in app.id not handled correctly
- **Example**: `app.id = "country.list"` → URL should use `countrylist`
- **Solution**: Remove periods from application name in URL

**Cause 2: Missing application key in URL**
- **Issue**: Request URL lacks application key for xs-app.json fetch
- **Required format**: `/<business-service-prefix>.<app-name>-<version>/`

**For SAP Fiori Tools:**
```json
// In manifest.json - CORRECT
"dataSources": {
  "mainService": {
    "uri": "northwind/V2/Northwind.svc"  // No leading slash
  }
}

// INCORRECT - leading slash creates absolute path
"dataSources": {
  "mainService": {
    "uri": "/northwind/V2/Northwind.svc"  // Wrong!
  }
}
```

**For jQuery AJAX:**
```javascript
// CORRECT - relative path
$.ajax({
  url: "api/data",  // No leading slash
  // ...
});

// INCORRECT - absolute path
$.ajax({
  url: "/api/data",  // Wrong!
  // ...
});
```

#### 404: Service endpoint calls fail
**Symptoms:**
- Routes defined in xs-app.json return 404
- Service calls not routed properly

**Root Cause:**
- Route order in xs-app.json
- HTML5 repo route (catch-all) processed before specific routes

**Resolution:**
```json
{
  "routes": [
    {
      "source": "^/api/(.*)$",
      "target": "$1",
      "destination": "backend-service"
    },
    // Move html5-apps-repo-rt route to END
    {
      "source": "^/(.*)$",
      "target": "$1",
      "service": "html5-apps-repo-rt"
    }
  ]
}
```

#### 500: Failed to retrieve xs-app.json
**Symptoms:**
- `"Error while retrieving xsApp configuration"`
- HTML5 repository unavailable

**Resolution:**
- Wait for HTML5 repository service restart
- Check BTP service status
- Verify service binding health

#### 500: Dynamic destination failure
**Symptoms:**
- `"Destination <name> is not defined as a dynamic destination"`
- Internal server error from approuter

**Root Cause:**
- Destination not configured for dynamic use

**Resolution:**
1. **In BTP Cockpit → Destinations → Additional Properties:**
   ```
   HTML5.DynamicDestination: true
   ```

#### 500: Missing xs-app.json
**Symptoms:**
- `"Application does not have xs-app.json"`
- Content serving fails

**Resolution:**
1. Redeploy HTML5 application with xs-app.json included
2. Verify xs-app.json is at application root
3. Check file permissions and encoding

## Flow-Based Troubleshooting

### HTML5 Repository Integration Issues

**Investigation Steps:**
1. **Check HTML5 Repo Binding**: `lib/utils/html5-repo-utils.js:54`
   ```
   Is approuter bound to html5-repo service?
   → No: Uses local xs-app.json only
   → Yes: Should fetch from HTML5 repo
   ```

2. **Verify Application Key Extraction**: `lib/utils/dynamic-routing-utils.js:getApplicationKey()`
   - Check URL format matches expected pattern
   - Verify `sap.cloud.service` in application metadata
   - For managed approuter, check app-host instance ID

3. **Debug Application Discovery**:
   ```javascript
   // Check if applications are cached properly
   HTML5_APPS_CACHE environment variable
   cacheHTML5Applications() function execution
   ```

### Authentication Flow Issues

**Investigation Steps:**
1. **Login Requirement**: `lib/middleware/authentication-handler.js`
   - Check route configuration: `"authenticationMethod": "route"`
   - XHR vs browser request handling

2. **Cookie Validation**:
   - Check session cookie presence and validity
   - Verify domain/path settings
   - Check for SameSite cookie issues

3. **XSUAA/IAS Configuration**:
   - Validate OAuth configuration
   - Check redirect URIs
   - Verify service binding

### Token Exchange Issues

#### Bearer token invalid
**Symptoms:**
- `"Bearer token invalid, requesting client does not have grant_type=user_token"`
- XSUAA token exchange fails

**Root Cause:**
- Missing `uaa.user` scope in XSUAA configuration
- Target business service not subscribed

**Resolution:**
1. **Add to xs-security.json:**
   ```json
   {
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
         "scope-references": ["uaa.user"]
       }
     ]
   }
   ```

2. **Update XSUAA service:**
   ```bash
   cf update-service <xsuaa-instance> -c xs-security.json
   ```

3. **Assign role to users:**
   - BTP Cockpit → Security → Role Collections
   - Add `Token_Exchange` role to user role collection
   - Verify Application Identifier matches `xsappname`

4. **For subscription issues:**
   - Unsubscribe and resubscribe if roles missing
   - Ensure target service bound before subscription

### Caching Issues

#### Browser caching problems
**Symptoms:**
- Application doesn't work after logout/login
- Clicking links has no effect
- Main page cached by browser

**Root Cause:**
- Main application page cached without proper cache-control headers

**Resolution:**
```json
{
  "routes": [
    {
      "source": "^/ui/index.html",
      "target": "index.html",
      "service": "html5-apps-repo-rt",
      "authenticationType": "xsuaa",
      "cacheControl": "no-cache, no-store, must-revalidate"
    }
  ]
}
```

## LLM Assistant Guidelines

When analyzing approuter logs and configurations:

### 1. Information Extraction Priority
1. **Error code/HTTP status** - Map to flow diagram
2. **Timestamp and request URL** - Trace through flow
3. **User context** - Check authentication/authorization
4. **Configuration files** - Validate against flow expectations

### 2. Systematic Analysis Approach
```
1. Identify error in flow diagram (error codes 1-9)
2. Check prerequisites for that flow step
3. Validate configuration for identified issue
4. Provide specific remediation steps
```

### 3. Configuration Validation Checklist

**xs-app.json:**
- Route patterns match request URLs
- Authentication methods are appropriate
- Scope requirements align with user assignments
- Destination names exist in configuration
- Route order (specific routes before catch-all)

**Destinations:**
- Authentication type matches backend requirements
- URL/credentials are correct
- Additional properties properly configured
- `HTML5.DynamicDestination: true` if needed

**HTML5 Applications:**
- manifest.json format valid
- `app.id` uses allowed characters
- `app.version` follows `xx.xx.xx` format
- `public: true` set if needed
- xs-app.json present at root

**Service Bindings:**
- Required services are bound
- Credentials valid and not expired
- OAuth scopes include necessary permissions
- `uaa.user` scope present for token exchange

### 4. Response Structure Template
```markdown
## Issue Analysis
- Error: [Specific error with code]
- Flow Location: [Reference to flow diagram step]
- Root Cause: [Technical explanation]

## Investigation Required
- [ ] Check [specific configuration]
- [ ] Verify [specific setting]  
- [ ] Test [specific functionality]

## Resolution Steps
1. [Specific action with code/config example]
2. [Next step with validation method]
3. [Final verification step]

## Validation Commands
```bash
# Commands to verify fix
cf logs <app-name> --recent
cf env <app-name>
```

## Common Error Patterns & Solutions

### Upload and Deployment Errors

#### Invalid file format - zip file contains non-zip files
**Symptoms:**
- `"Invalid file format. The request body must include a zip file that contains a zip file for each HTML5 application"`
- Upload failure during MTA deployment

**Root Cause:**
- `resources/data.zip` contains files other than zip files
- Hidden files (especially on Mac) in data.zip
- Incorrect folder structure

**Resolution:**
1. **Check data.zip contents:**
   ```bash
   unzip -l resources/data.zip
   ```
2. **Remove hidden files** (Mac users):
   ```bash
   # Remove .DS_Store and other hidden files
   find resources/ -name "._*" -delete
   find resources/ -name ".DS_Store" -delete
   ```
3. **Ensure only zip files in data.zip**
4. **Recreate data.zip with only application zip files**

#### MTA deployment size limit issues
**Symptoms:**
- `"Maximum file length exceeded"` during MTA deployment
- Error code 1001 validation error

**Resolution:**
```yaml
# In mta.yaml - correct indentation
resources:
  - name: myapp-app-host
    type: org.cloudfoundry.managed-service
    parameters:
      service: html5-apps-repo
      service-plan: app-host
      config:
        sizeLimit: 100  # Increase size limit (max 100MB)
```

**Common mistakes:**
```yaml
# WRONG - missing 'config' parameter
parameters:
  sizeLimit: 100

# CORRECT - with 'config' parameter  
parameters:
  config:
    sizeLimit: 100
```

#### Missing Zone information - IAS configuration
**Symptoms:**
- `"Failed to exchange login token - Missing Zone information"`
- Occurs in SAP Build Apps runtime scenarios

**Root Cause:**
- Missing IAS configuration in SAP Build Work Zone
- IAS tenant not configured with application dependencies

**Resolution:**
1. **Enable IAS in SAP Build Work Zone**
2. **Configure IAS tenant** with application IAS dependency
3. **Follow SAP Build Work Zone IAS configuration guide**

**Reference:** [SAP Build Apps Enhanced Fusion Development](https://community.sap.com/t5/sap-builders-blog-posts/what-s-new-for-sap-build-apps-enhanced-fusion-development/ba-p/13591981)

### Authentication and Authorization Errors

#### Authorization Request Error - Invalid redirect URI
**Symptoms:**
- `"The redirect_uri has an invalid domain"`
- Authentication flow fails

**Root Cause:**
- Missing or incorrect redirect URIs in xs-security.json
- Required for custom domains and extension landscapes

**Resolution:**
```json
{
  "redirect-uris": [
    "https://*.cfapps.eu10-004.hana.ondemand.com/login/callback"
  ]
}
```

**Special Cases:**
- **Extension landscapes:** cfapps domain not added by default
- **Ali Cloud:** No default cfapps domain exists
  ```json
  {
    "redirect-uris": [
      "https://*.apiportal.canaryac.apps.vlab-sapcloudplatformdev.cn/login/callback"
    ]
  }
  ```

#### Subdomain issues in XSUAA redirect
**Symptoms:**
- Redirect to XSUAA has missing/wrong subdomain
- Authentication loop or fails

**Investigation:**
1. **Check TENANT_HOST_PATTERN** environment variable
2. **Verify approuter URL** is prefixed with correct subdomain
3. **Validate XSUAA service binding** configuration

### Application Access Errors

#### Missing application key causing 404
**Detailed Example:**

**Problem URL:**
```
https://xyz.launchpad.cfapps.eu10.hana.ondemand.com/odata/v2/countryservice
```

**manifest.json with issue:**
```json
{
  "sap.app": {
    "id": "country.list",
    "applicationVersion": {
      "version": "1.0.0"
    }
  },
  "dataSources": {
    "mainService": {
      "uri": "/odata/v2/countryservice",  // Leading slash is WRONG
      "type": "OData"
    }
  },
  "sap.cloud": {
    "public": true,
    "service": "country.service"
  }
}
```

**Root Cause:**
- Leading slash in dataSource URI creates absolute path
- Prevents browser from concatenating application key

**Correct URL should be:**
```
https://xyz.launchpad.cfapps.eu10.hana.ondemand.com/countryservice.countrylist-1.0.0/odata/v2/countryservice
```

**Resolution:**
```json
{
  "dataSources": {
    "mainService": {
      "uri": "odata/v2/countryservice",  // Remove leading slash
      "type": "OData"
    }
  }
}
```

**Alternative solution for dynamic application key:**
```javascript
// Get application key dynamically
var id = this.getOwnerComponent().getMetadata().getManifest()["sap.app"].id;
var callUrl = jQuery.sap.getModulePath(id + '/your/path');
```

### Server and Infrastructure Errors

#### 401 Error - Session timeout and browser caching
**Symptoms:**
- User can't login after logout
- XHR requests return 401
- Application appears unresponsive

**Root Cause:**
- Browser caches main page
- Session timeout not handled properly

**Resolution:**
1. **Configure cache control** for main page (see previous examples)
2. **Handle 401 in XHR calls:**
   ```javascript
   // In your application's error handler
   if (xhr.status === 401) {
     // Save any user data
     // Trigger new login flow
     window.location.reload(); // Or redirect to login
   }
   ```

#### 403 Error scenarios
**From Approuter:**
- Route requires scope but user token doesn't contain it
- Check xs-app.json route scope requirements

**From Backend:**
- Token not forwarded correctly
- Check destination configuration
- Verify token forwarding settings

#### 500 Errors - Infrastructure issues

**OAuth2 "clientid" option error:**
- **Reference:** [SAP Note 2949591](https://me.sap.com/notes/2949591)
- Invalid OAuth client configuration

**Certificate errors:**
- **mac verify failure:** Wrong Key Store Password for client certificate
- **sslv3 alert certificate expired:** Client certificate expired

**Certificate validation commands:**
```bash
# Test Key Store Password
openssl pkcs12 -in <P12-file> -out testpublic.crt.pem -clcerts -nokeys

# Check certificate expiration
openssl x509 -in testpublic.crt.pem -text -noout
```

#### 400/431 Errors - Token size issues
**Symptoms:**
- `"Header too large"` error
- Bad Request with large JWT tokens

**Root Cause:**
- JWT tokens with many roles exceed 6-8KB limit
- Some servers (Express, Java) refuse large headers

**Resolution:**
1. **Reduce role collections** - make them smaller and more specific
2. **Adjust server settings** to allow larger headers
3. **Review role assignment strategy**

### iFrame Integration Issues

**Symptoms:**
- Approuter doesn't work when called from iFrame
- CSP violations

**Resolution:**
```javascript
// Environment variable httpHeaders configuration
[{
  "Content-Security-Policy": "frame-ancestors http://my347922-sso.crm.ondemand.com http://my347922.crm.ondemand.com; default-src * 'unsafe-inline' 'unsafe-eval' data: blob:; script-src * 'unsafe-inline' 'unsafe-eval' data: blob:; connect-src * 'unsafe-inline' data: blob:; img-src * data: blob: 'unsafe-inline'; frame-src * data: blob:; style-src * 'unsafe-inline' data: blob:; font-src * data: blob: 'unsafe-inline'; worker-src * 'unsafe-inline' 'unsafe-eval' data: blob:"
}]
```

**Additional for IE:**
```
X-FRAME: allow-from <domain>
```

**IAS login in iFrame:**
- Additional IDP configuration required
- **Reference:** [SAP Note 2912358](https://launchpad.support.sap.com/#/notes/2912358)

### Configuration Inconsistencies

#### Multiple CF routes mapped to same approuter
**Symptoms:**
- Inconsistent behavior
- Different responses for same request

**Investigation:**
```bash
cf routes | grep <app-name>
```

#### Same business service bound multiple times
**Symptoms:**
- Unpredictable service behavior
- Configuration conflicts

**Investigation:**
```bash
cf env <app-name> | grep -i vcap_services
```

### Subscription and Multi-tenancy Issues

#### Subscription validation checklist
**VCAP_SERVICES validation:**
1. **XSUAA tenant_mode:** Must be "shared"
2. **TENANT_HOST_PATTERN:** Correctly configured
3. **saas-registry URLs:** Properly populated with provider subdomain

**xs-security.json requirements:**
```json
{
  "xsappname": "my-approuter",
  "tenant-mode": "shared",
  "scopes": [
    {
      "name": "$XSAPPNAME.Callback",
      "description": "Callback scope for tenant operations",
      "grant-as-authority-to-apps": [
        "$XSAPPNAME(application,sap-provisioning,tenant-onboarding)"
      ]
    }
  ],
  "role-templates": [
    {
      "name": "MultitenancyCallbackRoleTemplate",
      "description": "Call callback-services of applications",
      "scope-references": ["$XSAPPNAME.Callback"]
    },
    {
      "name": "Token_Exchange",
      "description": "UAA",
      "scope-references": ["uaa.user"]
    }
  ]
}
```

#### Grant type errors in token exchange
**Symptoms:**
- Token exchange fails with grant_type error
- Dependent service access denied

**Resolution:**
1. **Check dependent service subscription status**
2. **Verify saasregistryenabled: true** in business service VCAP
3. **Ensure login token has uaa.user scope**

## Advanced Troubleshooting

### Embedded Credentials Flow Debug

**Key Indicators:**
- URL contains HTML5-apps-repo instance GUID
- No destination configuration needed
- Credentials stored with HTML5 application

**Debug Code Reference:**
```javascript
// lib/utils/html5-repo-utils.js:_addHTML5ApplicationsToCache()
embeddedCredsApp = !!((credentials && (credentials.xsuaa || credentials.identity)) || html5RuntimeEnabled)
```

**Validation Steps:**
1. Check if credentials are embedded in app metadata
2. Verify XSUAA/IAS configuration in embedded credentials
3. Test direct service access without destinations

### Multi-Tenant Scenarios

**URL Patterns:**
- `https://tenant1.myapprouter.hana.ondemand.com/` (standalone)
- `https://tenant1.launchpad.hana.ondemand.com/` (managed)

**Additional Checks:**
- Tenant-specific configuration
- Subscription status
- Provider vs subscriber app access
- Wildcard route configuration

### Performance Issues

**Common Symptoms:**
- Slow response times
- Timeout errors
- High CPU/memory usage

**Investigation:**
1. **Caching Issues**: Check `HTML5_APPS_CACHE` setting
2. **Connection Pooling**: HTTP keep-alive configuration
3. **Token Refresh**: Excessive token exchange calls

## Environment Variables Reference

| Variable | Purpose | Troubleshooting Impact |
|----------|---------|----------------------|
| `LOG_LEVEL` | Controls log verbosity | Set to `debug` for detailed troubleshooting |
| `HTML5_APPS_CACHE` | Cache TTL for HTML5 apps | Adjust if apps not updating |
| `SAAS_APPROUTER` | Managed approuter flag | Affects authentication flow |
| `ACCEPT_EXTERNAL_LOG_LEVEL` | Allow runtime log level changes | Enable for production debugging |

## Common Commands Reference

### Debugging Commands
```bash
# Get application logs
cf logs <app-name> --recent

# Check environment variables
cf env <app-name>

# Check service bindings
cf services

# Reset HTML5 app-host content
cf html5-delete --content <app-host-id>

# Update service configuration
cf update-service <service-name> -c '{"param":"value"}'

# Map route for subscription
cf map-route <app-name> <domain> --hostname <subdomain>-<app-name>
```

### HTML5 Repository Commands
```bash
# List HTML5 applications
cf html5-list

# Get application info
cf html5-info <app-name>

# Delete application content
cf html5-delete --content <app-host-id>
```

## Integration Points

### Cloud Connector (On-Premise)
- Virtual host configuration
- Authentication method alignment
- Certificate validation

### Identity Authentication Service (IAS)
- Trust configuration
- Attribute mapping
- Custom domains

### XSUAA Service
- OAuth client configuration
- Role collections and assignments
- API access permissions
- Token exchange scopes

### Destination Service
- Dynamic destination configuration
- Authentication types
- Additional properties
- Connectivity service integration

## Key Concepts for Advanced Troubleshooting

### Approuter Architecture Types

#### Standalone Approuter
- **State-full frontend component** designed for direct browser interaction
- Customer manages deployment, version, configuration
- For programmatic access, use service-to-approuter flow with valid JWT in `x-approuter-authorization` header
- Acts as stateless reverse proxy in service-to-service scenarios

#### SAAS (Managed) Approuter
- **Helium replacement** in Cloud Foundry
- Portal team provides approuter as a service for subscription
- Uses "dynamic binding" - reads destination info from subscriber subaccount
- Adds credentials to statically bound service instances at runtime
- Supports all authentication flows with cached credentials

### HTML5 Applications Repository
- **Runtime repository** for storing HTML5 application versions
- Use for different frontend versions per backend version
- **No delta upload** - redeploy triggers full replacement
- Historical versions should be in customer source control system

### Service-to-Approuter Flow
When calling approuter programmatically:
1. Provide valid approuter JWT in `x-approuter-authorization` header
2. Approuter acts as stateless reverse proxy
3. No session management needed

## Related Documentation

### Official SAP Documentation
| Topic | Link |
|--------|------|
| How to Develop HTML5 Applications | [SAP Help Portal](https://help.sap.com/viewer/65de2977205c403bbc107264b8eccf4b/Cloud/en-US/11d77aa154f64c2e83cc9652a78bb985.html) |
| HTML5 Applications Troubleshooting Guide | [SAP Help Portal](https://help.sap.com/viewer/65de2977205c403bbc107264b8eccf4b/Cloud/en-US/ae1d53e5fbe14383bfafe690f52711d7.html) |
| Neo to Cloud Foundry Migration Guide | [SAP Help Portal](https://help.sap.com/docs/html5-applications/migrating-applications-in-sap-btp-from-neo-environment-to-cloud-foundry-environment/migrating-html5-applications-from-sap-btp-neo-to-sap-btp-cloud-foundry) |

### SAP Community Resources
| Topic | Link |
|--------|------|
| Programming Model in SAP BTP | [SAP Community Blog](https://blogs.sap.com/2018/12/11/programming-applications-in-sap-cloud-platform/?preview_id=751509) |
| SAP Application Router Overview | [SAP Community Blog](https://blogs.sap.com/2020/04/03/sap-application-router/) |
| SAP Build Apps Enhanced Fusion Development | [SAP Community Blog](https://community.sap.com/t5/sap-builders-blog-posts/what-s-new-for-sap-build-apps-enhanced-fusion-development/ba-p/13591981) |

### SAP Notes
| Issue | SAP Note |
|--------|----------|
| OAuth2 "clientid" option error | [SAP Note 2949591](https://me.sap.com/notes/2949591) |
| IAS login in iFrame configuration | [SAP Note 2912358](https://launchpad.support.sap.com/#/notes/2912358) |
| HTML5 apps not visible after deployment | [SAP Note 3228331](https://me.sap.com/notes/0003228331) |

## Support Information

When escalating issues to SAP Support:

### Information to Provide
1. **Detailed error messages** with timestamps
2. **Complete URL** that failed (sanitized if needed)
3. **Approuter logs** with debug level enabled
4. **Configuration files:** xs-app.json, mta.yaml, xs-security.json
5. **Environment details:** CF space, region, service versions
6. **Reproduction steps** with expected vs actual behavior

### For Managed Approuter Issues
1. **HTML5 Applications UI logs** from BTP Cockpit
2. **Dynamic log level traces** (if debug was enabled)
3. **Destination configurations** (sanitized credentials)
4. **Application manifest.json** files
5. **Service binding information**

### For Standalone Approuter Issues
1. **CF app information:** `cf app <app-name>`
2. **Environment variables:** `cf env <app-name>` (sanitized)
3. **Recent logs:** `cf logs <app-name> --recent`
4. **Service instances:** `cf services`
5. **Route mappings:** `cf routes`

---

*This comprehensive troubleshooting guide should be used in conjunction with the [approuter-flows.md](../approuter-flows/approuter-flows.md) document for complete flow understanding. For additional assistance, consult the referenced documentation or create a support ticket with SAP.*