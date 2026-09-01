# Online Documentation Index

SAP Help Portal URLs for the Application Frontend service. Fetch these pages when the corresponding local reference file is a placeholder or when more authoritative detail is needed.

All URLs are on `help.sap.com` and do not require authentication to read.

---

## URL Index

| Topic | URL | Load When |
|-------|-----|-----------|
| What is Application Frontend | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/what-is-application-frontend-service` | Phase 0, unfamiliar with appFront or when overview is needed |
| Getting Started | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/getting-started` | Phase 0, first migration in a new landscape |
| Application Configuration (`xs-app.json`) | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/application-configuration` | Phase 3b, updating xs-app.json routes |
| Security Configuration (`xs-security.json`) | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/security-configuration` | Phase 3c, updating auth config |
| MTA Configuration | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/mta-configuration` | Phase 3a, updating mta.yaml |
| afctl CLI Reference | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/application-frontend-service-cli` | Phase 5, deploy/login/list commands |
| Logging in to CLI | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/logging-in-to-application-frontend-service-cli` | Phase 5, afctl login instructions |
| Deploying an Application | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/deploying-application` | Phase 5, deployment guidance |
| Roles and Authorizations | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/roles-and-authorizations` | Phase 5, af_rc role collection setup |
| Troubleshooting | `https://help.sap.com/docs/application-frontend-service/application-frontend-service/troubleshooting` | Phase 4 / Phase 5, when critic flags issues or deploy fails |

---

## Usage Notes

- Fetch **only the page relevant to the current phase** — do not fetch all URLs upfront.
- Use fetched content in-context only; do not write it to disk.
- If a fetched page redirects or returns no content (SAP Help Portal requires auth for some pages), fall back to the local reference file or training knowledge and note the limitation to the user.
