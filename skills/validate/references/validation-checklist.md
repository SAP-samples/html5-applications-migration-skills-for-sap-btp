# appFront Validation Checklist

**Status: 🔲 PLACEHOLDER — populate with your team's complete validation rules.**

## Purpose

Extended validation rules beyond what is in SKILL.md. Load when the SKILL.md checks are insufficient or when doing a deep-dive validation of a production-bound app.

## What to put here

### MTA Validation Rules

Extended mta.yaml checks specific to your landscapes:
- Which appFront service plan names are valid in which landscape (dev vs prod subaccount)
- Required `parameters` on the app-front resource for your setup
- Whether `deployed-after` ordering constraints are required between deployer and other modules
- Build-result directory naming conventions your team uses
- Any MTA extensions (`.mtaext`) that must accompany the base MTA

### xs-app.json Rules

Your team's specific routing requirements:
- Required route patterns for CSP/CORS compliance
- Specific destination names that must exist (validated against your landscape's destination service)
- Required `cacheControl` headers for static assets
- Session timeout configuration

### Authentication Rules

XSUAA/IAS configuration requirements for your landscapes:
- `xsappname` uniqueness conventions (what naming pattern your team uses)
- Required role templates for WorkZone integration
- Token validity settings

### WorkZone Integration Checks

If apps integrate with SAP Build Work Zone:
- Required `sap.cloud.service` in manifest.json
- CDM file format validation rules
- Site assignment verification steps

### Kyma-Specific Checks

If target is Kyma:
- Namespace existence check
- APIRule host naming conventions
- Service plan availability in Kyma

## Current Knowledge (built-in fallback)

Until populated, Claude uses the validation rules defined in SKILL.md phases 2–5.
