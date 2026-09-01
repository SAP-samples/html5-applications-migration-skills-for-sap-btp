# Target Config: Kyma Deployment

**Status: 🔲 PLACEHOLDER — populate with your team's Kyma deployment guide for appFront.**

## Load trigger

Load during Phase 0c and Phase 3d when the target runtime is Kyma.

## What to put here

- **ServiceInstance.yaml**: creating the appFront service instance in Kyma namespace
- **ServiceBinding.yaml**: binding the appFront service to the deployment, credential secret name
- **APIRule.yaml**: routing external traffic to the app, JWT access strategy for XSUAA or IAS
- **Function.yaml or Deployment.yaml**: where the app content deployer runs
- Kyma vs CF differences in MTA: which MTA parameters do not apply in Kyma, what replaces them
- Namespace configuration requirements
- How Kyma handles `xs-app.json` routing vs CF approuter
- Kyma-specific appFront CLI commands (`afctl deploy --target kyma`)
- Example `kubectl` commands to verify deployment

## Current Knowledge (built-in fallback)

Until populated, Claude will produce a best-effort Kyma yaml based on its training knowledge of SAP BTP Kyma appFront patterns. The user should review Kyma-specific files carefully before deploying.
