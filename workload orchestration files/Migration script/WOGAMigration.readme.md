# GA Migration Script
Supplemental script `WOGAMigration.ps1` migrates your existing Workload Orchestration environment to be ready for GA release.

## Prerequisites
Azure CLI's `resource-graph` model is required to be setup. Do so by running: 
```
az extension add --name resource-graph
```

## Usage
Migration script needs to be run per resource location in Azure.
```
.\WOGAMigration.ps1 -location <azure-location>
```

Sample:
```
.\WOGAMigration.ps1 -location eastus
```
