# Onboarding Script

## Pre-requisites

- Run `winget install -e --id Microsoft.AzureCLI` and `winget install -e --id Kubernetes.kubectl`
- Download the config-manager CLI extension WHL from [here](https://microsoftapc-my.sharepoint.com/personal/audapure_microsoft_com/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Faudapure%5Fmicrosoft%5Fcom%2FDocuments%2FBugBash%2FWHL&ga=1).
- Download JSON files for schemas, configs from [here](https://microsoftapc-my.sharepoint.com/personal/audapure_microsoft_com/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Faudapure%5Fmicrosoft%5Fcom%2FDocuments%2FBugBash&ga=1).
- Edit the `onboarding-data.json` file. You can find mock data in `mock-data.json`. Instructions about various properties are provided below.

## Common Data Section in input JSON

This is used by both scripts below. It is optional if you choose to add these fields in the `cmOnboarding` or `infraOnboarding` section.

- `subscriptionId [Optional]` : When using common subId, do not override this field in the `cmOnboarding` or `infraOnboarding` section.
- `resourceGroup [Optional]` : When using common RG, do not override this field in the `cmOnboarding` or `infraOnboarding` section.
- `location [Optional]`: When using common location, do not override this field in the `cmOnboarding` or `infraOnboarding` section.
- `customLocationFile [DO NOT MODIFY]`: This is automatically added by the onboarding script, do not modify it when running the cm onboarding script.

## 1. Infra Onboarding

The infra setup script helps you onboard to the infrastructure needed for config manager, such as creating an AKS cluster, deploying TCO on the cluster, creating Custom Location & Site, and finally installing the config-manager CLI extension.

❗ **IMPORTANT:** The Service Group name should be unique across tenants. So the site name input must be chosen carefully.

Command: `infra_onboarding.ps1 mock-data.json`
Arguments: (all of them are boolean arguments which take `$true`/`$false` as values.)

- `-skipResourceGroupCreation` (default `$false`): Skip creation of resource group
- `-skipAzLogin` (default `$true`): Skip az login.
- `-skipAzExtensions` (default `$false`): Skip installing/updating connectedk8s, k8s-extension & customlocation extensions.
- `-skipAksCreation` (default `$false`): Skip creation of AKS cluster, use when the cluster is already created.
- `-skipTcoDeployment` (default `$false`): Skip connecting AKS to Arc and creation of TCO extension, use when TCO has been deployed already.
- `-skipCustomLocationCreation` (default `$false`): Skip creation of CustomLocation, use when it has been created before.
- `-skipConnectedRegistryDeployment` (default `$true`): Skip connected registry deployment. By default, this step is skipped. Set to false when user need to deploy the connected registry on AKS cluster for staging. 
- `-skipSiteCreation` (default `$false`): Skip creation of Site and SiteAddress, use when it has been created before.
- `-skipAutoParsing` (default `$false`): Skip auto-creation of custom location file and auto-parsing of site file. By default, user does not need to set the "addressResourceId" field in the site file and does not need to pass a customLocationFile in the target data section. Set this to `$true` if you want to assign your own custom location (not created via onboarding script) or your own site address (not created via onboarding script)
- `-enableWODiagnostics` (default `$false`): Enable workload orchestration extension user-facing logs, use when users want to collect workload orchestration extension user audits and user diagnostics logs.
- `-enableContainerInsights` (default `$false`): Enable Container.Insights on arc cluster to collect container logs and k8s events, use when users want to collect container logs or k8s events.

## Prerequsite Context Creation Script (If not using an existing Context)

```powershell

# Context is Created 1 per Tenant today.
az workload-orchestration context create `
 --resource-group <Context-ResourceGroup> `
 --location <Location> `
 --name <ContextName> `
 --capabilities [0].name="$resourcePrefix-soap2" [0].description="$resourcePrefix-Soap2" [1].name="$resourcePrefix-shampoo2" [1].description="$resourcePrefix-Shampoo2" `
 --hierarchies [0].name=factory [0].description=Factory [1].name=line [1].description=Line

```
Please add the required data in onboarding-data.json after you create the context

```json
        "contextResourceGroup": "",
        "contextName": "",
        "contextSubscriptionId": "",
        "contextLocation": "",  
```

### Onboarding Data JSON

The infra-related properties fall under the `infraOnboarding` section in this file.

- `subscriptionId [Optional]` : If you want to override the common section's sub.
- `resourceGroup [Optional]` : If you want to override the common section's RG.
- `location [Optional]` (default: `eastus`) : If you want to override the common section's location.
- `arcLocation [Optional]` (default: `eastus`): Azure region where the Arc-enabled Kubernetes cluster resource will reside.
- `aksClusterIdentity [Optional]` (default: `$resourceGroup-Cluster-Identity`): Name of the managed identity used by the AKS cluster.
- `aksClusterName [Optional]` (default: `$resourceGroup-Cluster`): Name of the AKS cluster to be created or used.
- `customLocationName [Optional]` (default: `$resourceGroup-Location`): Name for the Custom Location resource created on top of the Arc-enabled AKS cluster.
- `customLocationNamespace [Optional]` (default: `mehoopany`): Kubernetes namespace associated with the Custom Location. Should be lowercase.
- `workloadOrchestrationWHL [Required]`: File path to the downloaded Workload Orchestration CLI extension `.whl` file.
- `contextResourceGroup [Required]`: Resource group where the Workload Orchestration Context exists (e.g., "Mehoopany"). This is used for setting up capabilities and site references.
- `contextName [Required]`: Name of the Workload Orchestration Context (e.g., "Mehoopany-Context").
- `contextSubscriptionId [Required]`: Subscription ID where the Workload Orchestration Context exists.
- `contextLocation [Required]`: Azure region where the Workload Orchestration Context exists (e.g., "eastus2euap").
- `diagInfo [Optional]`: An array defining the diagnostic configurations.
    - `diagnosticWorkspaceId [Optional]`: The ARM resource id of log analytics workspace.
    - `diagnosticResourceName [Optional]`: Name of the diagnostic resource.
    - `diagnosticSettingName [Optional]`: Name of the diagnostic settings.
- `acrName [Optional]`: Name of the Azure container registry.
- `connectedRegistryName [Optional]`: Name of the connected registry.
- `connectedRegistryIp [Required if skipConnectedRegistryDeployment=$false]`: Available IP address to host the connected registry service.
- `connectedRegistryClientToken [Optional]`: Name of the connected registry client token secret.
- `storageSizeRequest [Optional]`: Size of the storage used for connected registry.
- `siteHierarchy [Optional]`: An array defining the site structure and associated deployment targets.
    - `siteName [Required]`: Name of the site resource to be created. Avoid adding trailing Numbers in name
    - `parentSite [Optional]`: Name of the parent site in the hierarchy. Set to `null` for top-level sites.
    - `level [Required]`: The hierarchy level this site represents (e.g., "factory", "line"). Must match a level defined in the Context.
    - `capabilityList [Optional]`: Defines capabilities to be added to the Context if this site node is processed for capability setup.
        - `capabilities [Required]`: An array of capability names (strings) to add/update in the Context.
    - `hierarchyLevels [Optional]`: Defines hierarchy levels to be added to the Context if this site node is processed for capability setup.
        - `levels [Required]`: An array of hierarchy level names (strings) to add/update in the Context.
    - `deploymentTargets [Optional]`: Defines deployment targets associated with this site.
        - `rbac [Optional]`: Default RBAC settings for targets under this site. Can be overridden per target.
            - `role [Required]`: Azure role to assign (e.g., "Contributor").
            - `userGroup [Required]`: Object ID of the user or group to assign the role to.
        - `capabilities [Optional]`: Default capabilities for targets under this site. Can be overridden per target. Array of strings.
        - `hierarchyLevel [Optional]`: Default hierarchy level for targets under this site. Can be overridden per target. String.
        - `namespace [Optional]`: Default Kubernetes namespace for targets under this site. (Note: Currently informational, not directly used in target creation command). Can be overridden per target. String.
        - `targetSpecFile [Required if 'targets' defined]`: File path to the JSON file containing the target specification.
        - `customLocationFile [Optional]`: File path to the JSON file containing the custom location ID. If not specified here or per target, it falls back to `created file while arc cluster creation`.
        - `targets [Required]`: An array of deployment target definitions.
            - `name [Required]`: Name of the deployment target resource.
            - `displayName [Required]`: Display name for the deployment target.
            - `capabilities [Optional]`: Overrides the parent `deploymentTargets.capabilities`. Array of strings.
            - `hierarchyLevel [Optional]`: Overrides the parent `deploymentTargets.hierarchyLevel`. String.
            - `namespace [Optional]`: Overrides the parent `deploymentTargets.namespace`. String.
            - `rbac [Optional]`: Overrides the parent `deploymentTargets.rbac`. Object with `role` and `userGroup`.
            - `customLocationFile [Optional]`: Overrides the parent `deploymentTargets.customLocationFile`. File path string.
            - `targetSpecFile [Optional]`: Overrides the parent `deploymentTargets.targetSpecFile`. File path string. (Less common to override per target).





Example command run: `infra_onboarding.ps1 mock-data.json -skipAzExtensions $True -skipCustomLocationCreation $True`

## 2. Config Manager Resources Onboarding

The CM setup script creates CM resources like capabilities, hierarchy lists, deployment targets, solutions, configs, and schemas.

### For PowerShell

- `cm_onboarding.ps1 mock-data.json`

Arguments: (boolean argument which take `$true`/`$false` as values.)

- `-skipResourceGroupCreation` (default `$false`): Skip creation of resource group

### Onboarding Data JSON

The CM-related properties fall under the `cmOnboarding` section in this file.

- `resourceGroup [Optional]`: Defines the resource group for creating CM resources. Overrides the common one.
- `subscriptionId [Optional]`: Defines the subscription for creating CM resources. Overrides the common one.
- `location [Optional]` (default: `eastus`) : Defines the location for creating CM resources. Overrides the common one.

- `schemas [Optional]`: Defines the schemas to be created.
  - `name [Required]`: Name of the schema.
  - `version [Required]`: Version of the schema.
  - `schemaFile [Required]`: File path of the schema definition.

- `configs [Optional]`: Defines the configurations to be created.
  - `name [Required]`: Name of the configuration.
  - `versionName [Required]`: Version name of the configuration.
  - `configFile [Required]`: File path of the configuration file.

- `solutions [Optional]`: Defines the solutions to be created.
  - `name [Required]`: Name of the solution.
  - `description [Required]`: Description of the solution.
  - `capabilities [Required]`: Array of capabilities for the solution.
  - `version [Required]`: Version of the solution.
  - `specificationFile[Required]` : File path to Specification File
  - `configTemplate [Required]`: Configuration template for the solution.

## FAQs

- `rbac.userGroup` should be the object ID of the user/group. For a user, this can be looked up on the Portal via the Entra ID tab.





# Known Issues

## Custom Location Creation Error with Azure CLI 2.70.0

When running the infrastructure onboarding script, you may encounter the following error during custom location creation:

```
'CredentialAdaptor' object has no attribute 'signed_session'

```

This issue specifically affects Azure CLI version 2.70.0 and occurs when using the `az customlocation create` command.

### Workaround

####  Create the Custom Location via Azure Portal

1. Navigate to the [Azure Portal](https://portal.azure.com)
2. Click "+ Create a resource" and search for "custom location"
3. In the "Basics" tab:
   - Select your subscription and resource group
   - Enter a name for your custom location
   - Select your Arc-enabled cluster
   - Select the appropriate extension (either `microsoft.testsymphonyex` or `microsoft.workloadorchestreation`)
   - Specify your namespace (the same value you'd use in the script)
4. Complete the creation process

After creating the custom location through the portal, run the script with `-skipCustomLocationCreation $true` to skip this step.

#### Additional Script Parameters

The infrastructure script supports skipping various components if they've already been created or if you're troubleshooting specific parts:

```powershell
.\infra_onboarding.ps1 -onboardingFile "your-file.json" `
    -skipAzExtensions $true `         # Skip Azure CLI extensions installation/update
    -skipResourceGroupCreation $true ` # Skip resource group creation
    -skipAksCreation $true `          # Skip AKS cluster creation
    -skipTcoDeployment $true `        # Skip TCO deployment on AKS
    -skipCustomLocationCreation $true ` # Skip custom location creation
         # Skip Edge site creation
```

Use these parameters as needed based on which components you've already created or want to skip.

