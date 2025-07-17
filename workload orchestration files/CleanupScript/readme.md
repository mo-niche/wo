# 1. RGCleanScript.ps1

This script is used to clean up resources in a specified Azure Resource Group. It provides options to selectively delete specific resource types. By default, no resources are deleted unless explicitly specified for safety.

## 1.1 Prerequisites

- If running the script locally then you need to have Azure CLI installed and authenticated. Necessary permissions to delete resources in the specified resource group[For most of cases, by default your alias will have permission]
- If you are using this script as a part of RGCleanup step via ADO pipeline for your private resource group, then you need to add `Contributor` permissions to your private resource group for the object id mentioned below.
- Object ID: `63a63b4c-a8d7-4aba-9d46-7dd032c7ce4e`

## 1.2 Steps to update RBAC:

1. CLI:

```powershell
az role assignment create --assignee "63a63b4c-a8d7-4aba-9d46-7dd032c7ce4e" --role "Contributor" --scope "/subscriptions/973d15c6-6c57-447e-b9c6-6d79b5b784ab/resourceGroups/<yourResourceGroupName>"
```

2. Portal:

- Go to your resource group.
- Click on `Access control (IAM)`.
- Click on `Add` -> `Add role assignment`.
- Select `Contributor` role.
- Assign access to `User, group, or service principal`.
- Enter the object id `63a63b4c-a8d7-4aba-9d46-7dd032c7ce4e`.
- Click on `Next` and then `Review + assign`.

## 1.3.1 Parameters

- `resourceGroupName` [Required] (string): The name of the resource group to clean.
- `subscriptionId` [Optional] (string): Subscription ID for resources (For Microsoft.Edge). Default is the subscription shown by az cli.
- `contextSubscriptionId` [Optional] (string): Subscription ID where context is present (For Microsoft.Edge). Default is the subscription shown by az cli.
- `contextResourceGroupName` [Optional] (string): RG of the Context (For Microsoft.Edge). Default is `Mehoopany`.
- `contextName` [Optional] (string): Name of the Context (For Microsoft.Edge). Default is `Mehoopany-Context`.
- `deleteSite` [Optional] (bool): Delete site resources. Default is `false`.
- `deleteTarget` [Optional] (bool): Delete target resources. Default is `false`.
- `deleteConfiguration` [Optional] (bool): Delete CM created configuration resources. Default is `false`.
- `deleteSchema` [Optional] (bool): Delete schema/dynamic schema resources. Default is `false`.
- `deleteConfigTemplate` [Optional] (bool): Delete user created config template resources. Default is `false`.
- `deleteSolution` [Optional] (bool): Delete solution template resources. Default is `false`.
- `deleteInstance` [Optional] (bool): Delete application instances. Default is `false`.
- `deleteAks` [Optional] (bool): Delete AKS cluster resources. Default is `false`.
- `deleteManagedIdentity` [Optional] (bool): Delete managed identity resources. Default is `false`.
- `deleteMicrosoftEdge` [Optional] (bool): Delete Microsoft Edge resources. Default is `false`.
- `deleteAll` [Optional] (bool): Delete all resources (sets all delete parameters to true). Default is `false`.

## 1.3.2 General Usage

```powershell
# Clean only specific resources (safe by default - nothing is deleted unless explicitly specified)
.\RGCleanScript.ps1 -resourceGroupName <YourResourceGroupName> [-deleteSite $true] [-deleteTarget $true] 

# Clean all resources at once
.\RGCleanScript.ps1 -resourceGroupName <YourResourceGroupName> -deleteAll $true

# Clean all deployed instances
.\RGCleanScript.ps1 -resourceGroupName <YourResourceGroupName> [-deleteInstance $true]
```
