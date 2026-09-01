# Migrating Applications in SAP BTP from the Neo Environment to the Multi-Cloud Foundation

> **Source:** [SAP Help Portal](https://help.sap.com/docs/HTML5_APPLICATIONS/b98f42a4d2cd40a9a3095e9f0492b465?locale=en-US&state=PRODUCTION&version=Cloud)
> **Scope:** HTML5 Applications | Cloud

---

## Prerequisite Steps for the Migration

To migrate your applications from the Neo environment to the multi-cloud foundation, you must complete several prerequisites.

Before you can migrate your applications, you must complete the following preparations:

- Set up a subaccount in the Cloud Foundry environment.
- Subscribe to SAP Business Application Studio if you do not already have a subscription to it.
  The **NEO HTML5 application migration tool** in SAP Business Application Studio helps you with the migration.
- Subscribe to Application Frontend Service. Alternatively, you can use SAP Build Work Zone (standard edition or advanced edition) or SAP Cloud Portal.

Here are the detailed steps and links to additional information:

### Prerequisites in Your Cloud Foundry Subaccount

You have to set up a subaccount in the multi-cloud foundation and enable the Cloud Foundry environment for the subaccount. The following prerequisites are required in the Cloud Foundry subaccount:

- The Cloud Foundry environment is enabled for your subaccount. For more information, see [Enable Environment or Create Environment Instance](https://help.sap.com/docs/).
- You have created a space in your Cloud Foundry organization using the SAP BTP cockpit. For more information, see [Managing Spaces](https://help.sap.com/docs/) and [Create Spaces Using the Cloud Foundry Command Line Interface](https://help.sap.com/docs/).
- You have entitlements for:
  - SAP Business Application Studio
  - Cloud Foundry runtime
  - SAP Cloud Identity Services
- You have a tenant of SAP Cloud Identity Services. For more information, see [Get Your Tenant](https://help.sap.com/docs/).
- Your subaccount has a trust relationship with the Identity Authentication service (IAS). For information about how to set this up, see [Establish Trust and Federation Between SAP Authorization and Trust Management Service and SAP Cloud Identity Services](https://help.sap.com/docs/).
- You've created a user for yourself in the identity provider of the SAP Cloud Identity tenant. (See [Activate Your Account](https://help.sap.com/docs/) and [Manage Administrators](https://help.sap.com/docs/) in the documentation for SAP Cloud Identity Services.)
- Your user has administrative permissions in the subaccount in the Cloud Foundry environment of the multi-cloud foundation. See [User and Member Management](https://help.sap.com/docs/) and [Working with Role Collections](https://help.sap.com/docs/).

### Prerequisites in SAP Business Application Studio

To migrate your applications, you use the **NEO HTML5 application migration tool** in SAP Business Application Studio. For more information about SAP Business Application Studio, see [SAP Business Application Studio](https://help.sap.com/docs/) and [the overview of the Business Application Studio service](https://help.sap.com/docs/).

The following prerequisites are required in SAP Business Application Studio:

- Your user has development or administrative permissions for SAP Business Application Studio. Make sure that one or both of the following role collections have been assigned to your user:
  - `Business_Application_Studio_Developer`
  - `Business_Application_Studio_Administrator`

### Prerequisites in Application Frontend Service

Application Frontend service lets you host and serve frontend applications. It serves as a single entry point for hosting web-based UI applications to extend SAP's business solutions. For more information, see [What Is Application Frontend Service?](https://help.sap.com/docs/).

If you plan to deploy and run your applications with Application Frontend service, you have to meet the following prerequisites:

- Your subaccount is entitled to Application Frontend service.
- Your subaccount has subscriptions to the **build default** and the **developer** service plan of Application Frontend service.
- You have created the role collections **Application Frontend Developer** and **Application Frontend Viewer** and have assigned these role collections to your user. For more information, see [Creating Role Collections and Assigning Them to Users](https://help.sap.com/docs/).

### Prerequisites in SAP Build Work Zone and SAP Cloud Portal

If you want to use SAP Build Work Zone (standard edition or advanced edition) or SAP Cloud Portal instead of Application Frontend service, you need to have a subscription to the respective service.

For more information about SAP Build Work Zone, standard edition or advanced edition, see:

- [What Is SAP Build Work Zone, standard edition?](https://help.sap.com/docs/)
- [What Is SAP Build Work Zone, advanced edition?](https://help.sap.com/docs/)

For more information about SAP Cloud Portal, see [What Is Cloud Portal Service?](https://help.sap.com/docs/).

> **Note:** If you plan to migrate SAP Cloud Portal sites on the Neo environment to SAP Cloud Portal service or SAP Build Work Zone on the Cloud Foundry environment, please consult also the following guide: [Migrating SAP Cloud Portal Sites (Neo Environment) to SAP Build Work Zone](https://help.sap.com/docs/).

---

## Export Applications

To export an application that you want to migrate from your subaccount in the Neo environment to the multi-cloud foundation, the **Export** function in the Neo subaccount writes the configuration content into a downloadable development descriptor file (`mta.yaml`).

### Context

To migrate an application in SAP BTP from your subaccount in the Neo environment to multi-cloud foundation, first find the application in the **Solutions** and export the components. The configuration details of the application are written into a download development descriptor file (`mta.yaml`). You have to rename this file to `neo-mta.yaml` so that the NEO HTML5 application migration tool can process it. During the migration process, this file is going to be transformed so that the Cloud Foundry subaccount in the multi-cloud foundation can read and understand the configuration.

> **Note:** After the migration, your application is configured as a multitarget application in the subaccount of the Cloud Foundry environment of the multi-cloud foundation. For more information, see [Multitarget Applications in the Cloud Foundry Environment](https://help.sap.com/docs/).

### Procedure

1. In the SAP BTP cockpit, access your subaccount in the Neo environment.
2. From the navigation pane, choose **Solutions**.
3. Choose **Export**.
4. When the **Discovering subaccount components** process is finished, make sure that the **Automatically select dependent components** checkbox is selected and select the application that you want to migrate.

   > **Note:** If you authorized groups to use your application, the group checkboxes are selected in the `com.sap.hcp.group` type section.

5. Choose **Next**.
6. The wizard checks all of the sub components of your application. Choose **Next**.
7. Enter a title, a description, a solution ID, and a version. **Solution ID** and **Version** are mandatory fields.

   > **Recommendation:** We recommend that you enter something to make it easy for you to identify the application you want to migrate.

8. Choose **Export** and keep the default export options. For more information, see [Exporting Solutions](https://help.sap.com/docs/).
9. Choose **Download Development Descriptor (mta.yaml)** and **Download MTA Archive** to download the following files:
   - Development descriptor file (`mta.yaml` file)
   - MTA archive (`.mtar` file)
10. Rename the `mta.yaml` file to `neo-mta.yaml`.

    > **Note:** The development descriptor file must be renamed to **`neo-mta.yaml`** otherwise the file will not be processed.

11. Choose **Finish**.

### Related Information

[Multitarget Applications in the Cloud Foundry Environment](https://help.sap.com/docs/)

---

## Migrate Destinations

Import all destinations from the Neo environment to the multi-cloud foundation.

### Procedure

1. From the Neo subaccount export the destinations from the subaccount as text files by using the **Export** action (download icon).
2. In the Cloud Foundry subaccount, choose **Import Destinations** and import the destination text files.
3. If your destinations have secrets, passwords, or certificates for the authentication, you must add these secrets, passwords, or certificates manually in the Cloud Foundry subaccount destination entries as described here: https://help.sap.com/docs/connectivity/sap-btp-connectivity-cf/create-destinations-from-scratch?version=Cloud
4. In the same subaccount, create a new destination for ui5 that points to https://ui5.sap.com.

---

## Mapping of the Application Descriptor File in Neo to the Routing Configuration File in Cloud Foundry

This section shows the mapping of the application descriptor file from the Neo environment to the routing configuration file in the Cloud Foundry environment.

The following table describes how to map features from the application descriptor file in the Neo environment (`neo-app.json`; see [Application Descriptor File](https://help.sap.com/docs/)) to the routing configuration file in the Cloud Foundry environment (`xs-app.json`; see [Routing Configuration File](https://help.sap.com/docs/)).

### Feature Mapping Table

| Feature | | Neo (`neo-app.json`) | Cloud Foundry (`xs-app.json`) |
|---|---|---|---|
| **Authentication** | Supported in CF? | Yes | |
| | Neo descriptor | Location: `root`<br>Syntax: `"authenticationMethod": "saml"(default) \| "none"` | |
| | CF routing config | `authenticationMethod`:<br>- Docs: [authenticationMethod](https://help.sap.com/docs/)<br>- Location: `root`<br>- Syntax: `"authenticationMethod" : "route"(default) \| "none"`<br><br>`authenticationType`:<br>- Docs: [routes-authenticationType](https://help.sap.com/docs/)<br>- Location: `root.route.authenticationType`<br>- Syntax: `"authenticationType": "xsuaa"(default) \| "basic" \| "none"` | |
| **Authorization** | Supported in CF? | Yes | |
| | Neo descriptor | Location: `root`<br>Syntax: `"securityConstraints": [{permission with included and excluded paths}]` | |
| | CF routing config | The required scope to access the target path. Scopes are defined in the security descriptor of an application.<br>- Docs: [routes-scope](https://help.sap.com/docs/)<br>- Location: `root.routes.scope` | |
| **SAPUI5 Service** | Supported in CF? | No | |
| | Neo descriptor | Service route to retrieve SAPUI5 libraries from the relevant landscape.<br>- Docs: [Accessing SAPUI5 Resources](https://help.sap.com/docs/) | |
| | CF routing config | Load SAPUI5 libraries from https://sapui5.hana.ondemand.com/resources/sap-ui-core.js.<br>In the source code, replace all indirect paths (for example, `/resouces/*` or `../../resources/`) with: `https://sapui5.hana.ondemand.com/resources/` | |
| **Destination Routes** | Supported in CF? | Yes | |
| | Neo descriptor | - Docs: [Accessing REST Services](https://help.sap.com/docs/)<br>- Location: `root`<br>- Syntax:<br>```json<br>"routes": [<br>  {<br>    "path": "<application path to be forwarded>",<br>    "target": {<br>      "type": "destination",<br>      "name": "<name of the destination>",<br>      "entryPath": "<path prepended to the request path>"<br>    },<br>    "description": "<description>" (not supported in CF)<br>  }<br>]<br>```<br><br>Additional properties:<br>- `HTML5.ConnectionTimeoutInSeconds` (supported in CF)<br>- `HTML5.SocketReadTimeoutInSeconds` (not supported in CF)<br>- `HTML5.HandleRedirects` (not supported in CF) | |
| | CF routing config | - Docs: [routes](https://help.sap.com/docs/)<br>- Location: `root`<br>- Syntax:<br>```json<br>"routes": [<br>  {<br>    "source": "<application path to be forwarded>" (RegExp format),<br>    "destination": "<name of the destination>",<br>    "target": "<rewrite the incoming request path>"<br>  }<br>]<br>```<br><br>Example (RegExp format):<br>```json<br>"routes": [<br>  {<br>    "source": "^/sap/opu/odata/sap/API_BUSINESS_PARTNER/(.*)$",<br>    "destination": "bupa_onprem_pp_fullpath",<br>    "target": "$1"<br>  },<br>  {<br>    "source": "^(.*)$",<br>    "target": "$1",<br>    "service": "html5-apps-repo-rt",<br>    "authenticationType": "xsuaa",<br>    "scope": "$XSAPPNAME.RoleReadBupa"<br>  }<br>]<br>``` | |
| **Application Routes** | Supported in CF? | Yes | |
| | Neo descriptor | Route to a specific application version in the same account.<br>- Docs: [Accessing Application Resources](https://help.sap.com/docs/)<br>- Location: `root`<br>- Syntax:<br>```json<br>"routes": [<br>  {<br>    "path": "<application path to be forwarded>",<br>    "target": {<br>      "type": "application",<br>      "name": "<name of the application or subscription>"<br>    },<br>    "description": "<description>"<br>  }<br>]<br>``` | |
| | CF routing config | This feature is supported using a new concept in the Cloud Foundry environment. You can reuse an application as a reuse library or by exposing it as a business service.<br><br>> **Tip:** We recommend consuming your application as a reuse library.<br><br>**Reuse Library**<br><br>> **Note:** Reuse libraries should be deployed to Cloud Foundry.<br><br>1. In the `webapp/manifest.json` of the calling application, include a reference to the reuse library:<br>```json<br>"sap.ui5": {<br>  "resourceRoots": {<br>    "mylib": "/servkce.mylibapp"<br>  }<br>}<br>```<br>2. In the `webapp/index.html`, include a reference to the reuse library in the bootstrap:<br>```html<br><script id="sap-ui-bootstrap"<br>  ...<br>  resourceroots='{"<namesapce>.<myapp>": "./", "mylib":"/service.mylibapp"}'<br></script><br>```<br>3. In the controllers of your application, make sure that the path is relative:<br>```js<br>sap.ui.define([<br>  "mylib/util/SomeModule1",<br>  "mylib/util/SomeModule2"<br>])<br>```<br><br>**Business Service**<br>1. Expose the reusable application as a business service.<br>2. Integrate with the business service. See [Integration with Business Services](https://help.sap.com/docs/). | |
| **User API Service** | Supported in CF? | Yes | |
| | Neo descriptor | The User API service provides an API to query the details of the user that is currently logged on.<br>- Docs: [Accessing the User API](https://help.sap.com/docs/)<br>- Syntax:<br>```json<br>"routes": [<br>  {<br>    "path": "<application path to be forwarded>",<br>    "target": {<br>      "type": "service",<br>      "name": "userapi"<br>    }<br>  }<br>]<br>``` | |
| | CF routing config | - Docs: [User API Service](https://help.sap.com/docs/)<br>- Syntax:<br>```json<br>{<br>  "source": "^/user-api(.*)",<br>  "target": "$1",<br>  "service": "sap-approuter-userapi"<br>}<br>``` | |
| **Welcome File** | Supported in CF? | Yes | |
| | Neo descriptor | - Docs: [Welcome File](https://help.sap.com/docs/)<br>- Syntax: `"welcomeFile": "<path>" (default index.html), "sendWelcomeFileRedirect": true (default) \| false` | |
| | CF routing config | - Docs: [welcomeFile](https://help.sap.com/docs/)<br>- Syntax: `"welcomeFile": "<path>"` (no default; welcome file is redirected by default)<br><br>> **Note:** `sendWelcomeFileRedirect` isn't supported in the Cloud Foundry environment. | |
| **Logout Page** | Supported in CF? | Yes | |
| | Neo descriptor | - Docs: [Logout Page](https://help.sap.com/docs/)<br>- Syntax: `"logoutPage": "<path to logout page>"` | |
| | CF routing config | - Docs: [logout](https://help.sap.com/docs/)<br>- Syntax: `"logout": {"logoutEndpoint": "<path>"}` | |
| **Cache Control** | Supported in CF? | Yes | |
| | Neo descriptor | - Docs: [Cache Control](https://help.sap.com/docs/)<br>- Location: `root`<br>- Syntax: `"cacheControl": [{"path": "<path>","directive": "none \| public \| private ..."}]` | |
| | CF routing config | - Docs: [routes-cacheControl](https://help.sap.com/docs/)<br>- Location: `root.routes.scope`<br>- Syntax: `"cacheControl":<value>` | |
| **Approving HTTP Headers** | Supported in CF? | No | |
| | Neo descriptor | For security reasons, not all HTTP headers are forwarded from the application to a backend or frontend application.<br>- Docs: [Approving HTTP Headers](https://help.sap.com/docs/)<br>- Syntax: `"headerWhiteList": [<header1> (, <header2>, ...)]` | |
| | CF routing config | In the application router, all headers are forwarded to the backend besides hop-by-hop headers.<br>- Docs: [Hop-by-Hop Headers](https://help.sap.com/docs/) | |
| **Custom Response Headers** | Supported in CF? | Yes | |
| | Neo descriptor | - Docs: [Custom Response Headers](https://help.sap.com/docs/)<br>- Syntax:<br>```json<br>"responseHeaders": [<br>  {<br>    "headers": [<br>      {<br>        "name": "header name",<br>        "value": "header value"<br>      }<br>    ]<br>  }<br>]<br>``` | |
| | CF routing config | - Docs: [responseHeaders](https://help.sap.com/docs/)<br>- Syntax:<br>```json<br>{ "responseHeaders" : [<br>    {"name": "header1", "value": "value1"},<br>    {"name": "header2", "value": "value2"}<br>  ]<br>}<br>``` | |

---

## Adapt the Application Security Descriptor File

If you configured permissions or roles to access the applications in the Neo environment, you have to migrate these permissions and roles with the `xs-security.json` file as scopes and role templates. In SAP Business Application Studio, the **NEO HTML5 application migration tool** creates a new application security descriptor file with preconfigured settings.

### Context

The NEO HTML5 application migration tool creates a new application security descriptor (`xs-security.json`). It prepares the file based on `neo-app.json` file (mandatory) and `neo-mta.yaml` file (optional). Edit this file to adapt these settings according to your application.

To use the **NEO HTML5 application migration tool** for adapting the application descriptor file (`xs-security.json`), follow these steps.

### Procedure

1. In your development space, run the **SAP - Neo Migration: Generate xs-security.json** command and follow the instructions. This overwrites the previously generated `xs-security.json` file (application security file).
2. Open the `xs-security.json` in the root folder of the migration project.
3. In the `xs-security.json` file, verify generated content. See [Application Security Descriptor Configuration Syntax](https://help.sap.com/docs/).

Here is an example for an adapted application security descriptor file (`xs-security.json`):

```json
{
    "xsappname": "migrationcf",
    "tenant-mode": "dedicated",
    "description": "Security profile of called application",
    "scopes":[
      {
        "name": "$XSAPPNAME.globalrole",
        "description": "Migrated role"
      }
    ],
    "role-templates": [
      {
        "name": "globaltemplate",
        "description": "Migrated Role Template",
        "scope-references": [
          "$XSAPPNAME.globalrole"
        ]
      }
    ],
    "role-collections": [
      {
        "name": "GobalRole",
        "description": "Global from migrated neo",
        "role-template-references": [
          "$XSAPPNAME.globaltemplate"
        ]
      }
    ]
}
```