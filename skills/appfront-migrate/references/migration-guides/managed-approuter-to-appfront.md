# WorkZone Managed Approuter → appFront Migration Guide

**Status: 🔲 PLACEHOLDER — populate with WorkZone-integrated migration steps.**

## Load trigger

Load during Phase 1 when `sap.cloud.service` is found in the source `destination-content` module, indicating WorkZone managed approuter integration.

## What to put here

- What the WorkZone managed approuter pattern is: how `sap.cloud.service` destinations enable WorkZone to route to the app
- How appFront handles WorkZone integration differently (CDM-based vs destination-based)
- **CDM changes required**: how to update or create `cdm.json` for appFront
- **Site assignment**: how to assign the migrated appFront app to a WorkZone site
- **Role collections**: whether role collection names change after migration
- **SAP Build Work Zone integration checklist**
- The `sap.cloud.service` destination removal: what breaks if removed without CDM update, and the correct sequence

## Current Knowledge (built-in fallback)

Until populated, Claude will flag `sap.cloud.service` detection to the user and ask for manual guidance on the CDM steps. The `troubleshooting/workzone-integration.md` file contains additional context.
