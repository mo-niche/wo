# Input Prameters
param (
    [string]$subscriptionId,
    [string]$contextSubscriptionId,
    [string]$contextName="Mehoopany-Context",
    [string]$contextResourceGroupName="Mehoopany",
    [string]$resourceGroupName,
    [string]$sgSiteNames = "",
    [bool]$deleteSite = $false,
    [bool]$deleteTarget = $false,
    [bool]$deleteConfiguration = $false,
    [bool]$deleteSchema = $false,
    [bool]$deleteConfigTemplate = $false,
    [bool]$deleteSolution = $false,
    [bool]$deleteInstance = $false,
    [bool]$deleteAks = $false,
    [bool]$deleteManagedIdentity = $false,
    [bool]$deleteMicrosoftEdge = $true,
    [bool]$deleteAll = $false
)

# If deleteAll is true, set all delete parameters to true
if ($deleteAll) {
    $deleteSite = $true
    $deleteTarget = $true
    $deleteConfiguration = $true
    $deleteSchema = $true
    $deleteConfigTemplate = $true
    $deleteSolution = $true
    $deleteInstance = $true
    $deleteAks = $true
    $deleteManagedIdentity = $true
    $deleteMicrosoftEdge = $true
}

# Import RGCleanCommon.ps1 from same directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonScriptPath = Join-Path $scriptDir "RGCleanCommon.ps1"
if (Test-Path $commonScriptPath) {
    . $commonScriptPath
} else {
    Write-Host "##[error] Common script not found at $commonScriptPath" -ForegroundColor Red
    return
}

function deleteMicrosoftEdge {
    Write-Host "##[section] Deleting Microsoft Edge resources" -ForegroundColor Yellow
    az cloud update --endpoint-resource-manager "https://eastus2euap.management.azure.com"
    $baseURI = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/microsoft.edge"

    try {
        if ($deleteTarget -eq $true) {
            deleteTargets -baseURI $baseURI -apiVersion $PublicPreviewAPIVersion -nameSpace "Microsoft.Edge"
        }
        elseif ($deleteTarget -eq $false -and $deleteInstance -eq $true) {
            Write-Host "##[section] Skipping Targets Deletion, but deleting instances" -ForegroundColor Yellow
            deleteInstances -baseURI $baseURI -apiVersion $PublicPreviewAPIVersion -nameSpace "Microsoft.Edge"    
        }
        else {
            Write-Host "##[section] Skipping Targets Deletion" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting targets" -ForegroundColor Red
    }

    
    try {
        if ($deleteSolution -eq $true) {
            deleteSolutionsAndItsChildrens -baseURI $baseURI -apiVersion $PublicPreviewAPIVersion
        }
        else {
            Write-Host "##[section] Skipping Solutions Deletion" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting solutions" -ForegroundColor Red
    }
    
    try {
        if ($deleteConfigTemplate -eq $true) {
            deleteConfigTemplates -baseURI $baseURI -apiVersion $PublicPreviewAPIVersion
        }
        else {
            Write-Host "##[section] Skipping Config Templates Deletion" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting config templates" -ForegroundColor Red
    }

    try {
        if ($deleteConfiguration -eq $true) {
            deleteConfigurationsAndItsChildrens -baseURI $baseURI -apiVersion $ConfigRTAPIVersion
        }
        else {
            Write-Host "##[section] Skipping Configuration Deletion" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting configurations" -ForegroundColor Red
    }

    try {
        if ($deleteSchema -eq $true) {
            deleteSchemas -baseURI $baseURI -apiVersion $PublicPreviewAPIVersion
        }
        else {
            Write-Host "##[section] Skipping schema Deletion" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting schemas" -ForegroundColor Red
    }
    
    try {
        if ($deleteSite -eq $true) {
            # invoke if $sgSiteNames is not empty
            if ($sgSiteNames -ne "") {
                deleteSgSitesAndSiteRefsForMicrosoftEdge -sgSiteNames $sgSiteNames -contextName $contextName -contextResourceGroupName $contextResourceGroupName -contextSubscriptionId $contextSubscriptionId
            }
            else {
                Write-Host "##[section] No SG based sites provided, skipping deletion" -ForegroundColor Yellow
            }
            
            deleteRGSites -resourceGroupName $resourceGroupName -subscriptionId $subscriptionId
        }
        else {
            Write-Host "##[section] Skipping Sites Deletion" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting sites" -ForegroundColor Red
    }

    try {
        removeTestCapabilities -baseURI $contextBaseUri -apiVersion $PublicPreviewAPIVersion
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while cleaning up caabilities" -ForegroundColor Red
    }
    
}

# Script starts here
if ($resourceGroupName -eq $null -or $resourceGroupName -eq "") {
    Write-Host "##[error] Please provide a resource group name with -resourceGroupName flag" -ForegroundColor Red
    return
}

if($subscriptionId -eq $null -or $subscriptionId -eq "") {
    $subscriptionId = az account show --query id -o tsv
    if ($null -eq $subscriptionId -or $subscriptionId -eq "") {
        Write-Host "##[error] Please login to Azure CLI using 'az login'" -ForegroundColor Red
        return
    } else {
        Write-Host "##[debug] Using default Subscription ID: $subscriptionId" -ForegroundColor Green
    }
}

if($contextSubscriptionId -eq $null -or $contextSubscriptionId -eq "") {
    $contextSubscriptionId = az account show --query id -o tsv
    if ($null -eq $contextSubscriptionId -or $contextSubscriptionId -eq "") {
        Write-Host "##[error] Please login to Azure CLI 'az login'" -ForegroundColor Red
        return
    } else {
        Write-Host "##[debug] Using default Context Subscription ID: $contextSubscriptionId" -ForegroundColor Green
    }
}

$currentEp = ((az cloud show) | ConvertFrom-Json ).endpoints.resourceManager

if ($deleteMicrosoftEdge -eq $true) {
    deleteMicrosoftEdge 
}
else {
    Write-Host "##[section] Skipping Microsoft.Edge Resource Deletion" -ForegroundColor Yellow
}

deleteCommon -skipAksDeletion (-not $deleteAks) -skipManagedIdentityDeletion (-not $deleteManagedIdentity) -resourceGroup $resourceGroupName -subscriptionId $subscriptionId

az cloud update --endpoint-resource-manager "$currentEp"
