
function Invoke-AzCommand {
    param (
        [string]$command
    )
    $result = Invoke-Expression $command
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $command"
    }
    return $result
}

# Functions
function deleteARMID {
    param (
        [string]$armID,
        [string]$apiVersion
    )
    $deleteURI = $armID + "?api-version=$apiVersion"
    Write-Host "##[debug] Deleting $deleteURI" -ForegroundColor Green
    $command = "az rest --method delete --uri $deleteURI"
    Write-Host "##[debug] Deleted" -ForegroundColor Red
    $result = Invoke-Expression $command
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $command"
    }
}

function deleteRTs {
    param (
        [string[]]$rtURIs,
        [string]$apiVersion
    )
    foreach ($rtURI in $rtURIs) {
        deleteARMID -armID $rtURI -apiVersion $apiVersion
    }
}

function DeleteLROAsync {
    param (
        [string]$deleteUri
    )
    Write-Host "##[debug] Deleting $deleteUri" -ForegroundColor Green
    $authToken = (az account get-access-token | ConvertFrom-Json).accessToken
    $finalUri = "https://eastus2euap.management.azure.com" + $deleteUri

    try {
        # Perform the POST request using Invoke-WebRequest
        $response = Invoke-WebRequest -Uri "$finalUri" -Method Delete -Headers @{ "Authorization" = "Bearer $authToken" } -ContentType 'application/json' -UseBasicParsing
    }
    catch {
        Write-Host "##[debug] Error: $_" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting $deleteUri" -ForegroundColor Red
        return
    }

    $azureAsyncOperation = $response.Headers["Azure-AsyncOperation"]
    if ($null -eq $azureAsyncOperation -or $azureAsyncOperation -eq "") {
        $body = $response -split "\r\n\r\n", 2 | Select-Object -Last 1
        Write-Host "##[debug] Error: $body" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting $deleteURI" -ForegroundColor Red
        return
    }
    Write-Host "##[debug] Waiting for deletion to complete for AzureAsyncOperation" -ForegroundColor Yellow
    $status = (curl.exe -s -H "Authorization: Bearer $authToken" "$azureAsyncOperation" | ConvertFrom-Json).status
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($status -ne "Succeeded") {
        Start-Sleep -Seconds 5
        $status = (curl.exe -s -H "Authorization: Bearer $authToken" "$azureAsyncOperation" | ConvertFrom-Json).status
        Write-Host "##[debug] Elapsed time: $($timer.Elapsed.TotalSeconds) seconds, Status: $status" -ForegroundColor Yellow
        if ($timer.Elapsed.TotalSeconds -gt 300 -or $status -eq "Failed") {
            Write-Host "##[debug] Deletion is taking too long or failing, skipping it, please check manually for ARMID: $deleteURI" -ForegroundColor Red
            Write-Host "##[debug] To know failure reason, try GET on this AzureAsyncOperation: $azureAsyncOperation" -ForegroundColor Red
            $timer.Stop()
            return
        }
    }
    $timer.Stop()
    Write-Host "##[debug] Elapsed time: $($timer.Elapsed.TotalSeconds) seconds, Status: $status" -ForegroundColor Yellow
    Write-Host "##[debug] Deleted" -ForegroundColor Red
}

function PutAsync {
    param (
        [string]$putUri,
        [string]$body
    )
    $body | Set-Content body.json
    Write-Host "##[debug] PUT $putUri" -ForegroundColor Green
    try {
        az rest --method Put --uri $putUri --body "@body.json"
        # Check if the file exists before deleting
        if (Test-Path body.json) {
            Remove-Item body.json
        }
    }
    catch {
        Write-Host "##[debug] Error: $_" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while PUT $postUri" -ForegroundColor Red
        # Check if the file exists before deleting
        if (Test-Path body.json) {
            Remove-Item body.json
        }
        return
    }
}

function PostLROAsync {
    param (
        [string]$postUri,
        [string]$body,
        [int]$timeout = 30
    )
    Write-Host "##[debug] Executing $postUri" -ForegroundColor Green
    $authToken = (az account get-access-token | ConvertFrom-Json).accessToken
    $finalUri = "https://eastus2euap.management.azure.com" + $postUri

    try {
        # Perform the POST request using Invoke-WebRequest
        $response = Invoke-WebRequest -Uri "$finalUri" -Method Post -Headers @{ "Authorization" = "Bearer $authToken" } -Body $body -ContentType 'application/json' -UseBasicParsing
    }
    catch {
        Write-Host "##[debug] Error: $_" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while executing $postUri" -ForegroundColor Red
        return
    }

    $azureAsyncOperation = $response.Headers["Azure-AsyncOperation"]
    if ($null -eq $azureAsyncOperation -or $azureAsyncOperation -eq "") {
        $body = $response -split "\r\n\r\n", 2 | Select-Object -Last 1
        Write-Host "##[debug] Error: $body" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while executing $postUri" -ForegroundColor Red
        return
    }
    Write-Host "##[debug] Waiting for execution to complete for AzureAsyncOperation within $timeout seconds" -ForegroundColor Yellow
    $status = (curl.exe -s -H "Authorization: Bearer $authToken" "$azureAsyncOperation" | ConvertFrom-Json).status
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($status -ne "Succeeded") {
        Start-Sleep -Seconds 5
        $status = (curl.exe -s -H "Authorization: Bearer $authToken" "$azureAsyncOperation" | ConvertFrom-Json).status
        Write-Host "##[debug] Elapsed time: $($timer.Elapsed.TotalSeconds) seconds, Status: $status" -ForegroundColor Yellow
        if ($timer.Elapsed.TotalSeconds -gt $timeout -or $status -eq "Failed") {
            Write-Host "##[debug] Execution is taking too long or failing, skipping it, please check manually for ARMID: $postUri" -ForegroundColor Red
            Write-Host "##[debug] To know failure reason, try GET on this AzureAsyncOperation: $azureAsyncOperation" -ForegroundColor Red
            $timer.Stop()
            return
        }
    }
    $timer.Stop()
    Write-Host "##[debug] Elapsed time: $($timer.Elapsed.TotalSeconds) seconds, Status: $status" -ForegroundColor Yellow
    Write-Host "##[debug] Completed LRO" -ForegroundColor Red
}

function deleteARMIDAsync {
    param (
        [string]$armID,
        [string]$apiVersion
    )
    $deleteURI = "https://management.azure.com" + $armID + "?api-version=$apiVersion"
    Write-Host "##[debug] Deleting $deleteURI" -ForegroundColor Green
    $authToken = (az account get-access-token | ConvertFrom-Json).accessToken
    $response = curl.exe -s -i -X DELETE -H "Authorization: Bearer $authToken" "$deleteURI" -UseBasicParsing
    $azureAsyncOperation = $response | Select-String -Pattern "azure-asyncoperation:\s*(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }
    if ($null -eq $azureAsyncOperation -or $azureAsyncOperation -eq "") {
        $body = $response -split "\r\n\r\n", 2 | Select-Object -Last 1
        Write-Host "##[debug] Error: $body" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting $deleteURI" -ForegroundColor Red
        return
    }
    Write-Host "##[debug] Waiting for deletion to complete for AzureAsyncOperation" -ForegroundColor Yellow
    $status = (curl.exe -s -H "Authorization: Bearer $authToken" "$azureAsyncOperation" | ConvertFrom-Json).status
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($status -eq "Deleting") {
        Start-Sleep -Seconds 5
        $status = (curl.exe -s -H "Authorization: Bearer $authToken" "$azureAsyncOperation" | ConvertFrom-Json).status
        Write-Host "##[debug] Elapsed time: $($timer.Elapsed.TotalSeconds) seconds, Status: $status" -ForegroundColor Yellow
        if ($timer.Elapsed.TotalSeconds -gt 30) {
            Write-Host "##[debug] Deletion is taking too long or failing, skipping it, please check manually for ARMID: $deleteURI" -ForegroundColor Red
            Write-Host "##[debug] To know failure reason, try GET on this AzureAsyncOperation: $azureAsyncOperation" -ForegroundColor Red
            $timer.Stop()
            return
        }
    }
    $timer.Stop()
    Write-Host "##[debug] Elapsed time: $($timer.Elapsed.TotalSeconds) seconds, Status: $status" -ForegroundColor Yellow
    Write-Host "##[debug] Deleted" -ForegroundColor Red
}

function deleteRTsAsync {
    param (
        [string[]]$rtURIs,
        [string]$apiVersion
    )
    foreach ($rtURI in $rtURIs) {
        deleteARMIDAsync -armID $rtURI -apiVersion $apiVersion
    }
}

function deleteInstances {
    param (
        [string]$baseURI,
        [string]$apiVersion,
        [string]$nameSpace
    )
    Write-Host "##[section] Starting Deletion of Instances" -ForegroundColor Yellow
    $getTargetsURI = $baseURI + "/targets?api-version=$apiVersion"
    $response = az rest --method get --uri $getTargetsURI --output json | ConvertFrom-Json
    $deploymentTargetsDeleteURIs = $response.value | Select-Object -ExpandProperty id
    $instanceDeleteUrIs = @()
    # Iterate through deploymentTargetsDeleteURIs and construct target solution Uri
    foreach ($targetId in $deploymentTargetsDeleteURIs) {
        $targetSolutionsUri = "$targetId/solutions?api-version=$apiVersion"
        $response = az rest --method get --uri $targetSolutionsUri --output json | ConvertFrom-Json
        $targetSolutionsDeleteURIs = $response.value | Select-Object -ExpandProperty id
        # Iterate through targetSolutionsDeleteURIs and construct target instance Uri
        foreach ($targetSolutionId in $targetSolutionsDeleteURIs) {
            $targetInstancesUri = "$targetSolutionId/instances?api-version=$apiVersion"
            $response = az rest --method get --uri $targetInstancesUri --output json | ConvertFrom-Json
            $targetInstancesDeleteURIs = $response.value | Select-Object -ExpandProperty id
            # Add targetInstancesDeleteURIs to instanceDeleteUrIs
            $instanceDeleteUrIs += $targetInstancesDeleteURIs
        }
    }
    Write-Host "Instances to delete:" -ForegroundColor Yellow
    $instanceDeleteUrIs | ForEach-Object { Write-Host $_ -ForegroundColor Green }
    # Iterate through instanceDeleteUrIs and delete each instance
    $failedUninstallations = @()
    foreach ($instanceUri in $instanceDeleteUrIs) {
        Write-Host "Uninstalling instance: $instanceUri" -ForegroundColor Green
        $targetUri = $instanceUri.Substring(0, $instanceUri.LastIndexOf("/solutions/"))
        # extract solution name from instanceUri
        $solutionName = $instanceUri.Split("/")[-3]
        $uninstallUri = $targetUri + "/uninstallSolution?api-version=$apiVersion"
        # extract instance name from instanceUri
        $instanceName = $instanceUri.Split("/")[-1]
        try 
        {
            $body = @{
                SolutionInstanceName = $instanceName
                SolutionName = $solutionName
            } | ConvertTo-Json

            PostLROAsync -postUri $uninstallUri -body $body -timeout 300
        }
        catch 
        {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] An error occurred while uninstalling target: $targetUri with instance: $instanceName" -ForegroundColor Red
            $failedUninstallations += $instanceUri
            continue
        }
        Write-Host "##[debug] Deleted" -ForegroundColor Red
    }
    Write-Host "Uninstallation completed." -ForegroundColor Yellow
    if ($failedUninstallations.Count -gt 0) {
        Write-Host "##[warning] The following instances had errors during uninstallation and will be skipped:" -ForegroundColor Yellow
        $failedUninstallations | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    } else {
        Write-Host "All instances uninstalled successfully." -ForegroundColor Green
    }
}

function deleteTargets {
    param (
        [string]$baseURI,
        [string]$apiVersion,
        [string]$nameSpace
    )
    Write-Host "##[section] Starting Deletion of Targets" -ForegroundColor Yellow
    $getURI = $baseURI + "/targets?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $deploymentTargetsDeleteURIs = $response.value | Select-Object -ExpandProperty id
    $failedTargets = @()
   
    $configApiVersion = $ConfigRTAPIVersion
    if ($nameSpace -eq "Private.Edge") {
		$configApiVersion = $ConfigRTPrivateAPIVersion
	}
		
    foreach ($targetId in $deploymentTargetsDeleteURIs) {
        $hasError = $false

        Write-Host "Removing configuration ref for $targetId" -ForegroundColor Green
        try {
            deleteARMID "$targetId/providers/$nameSpace/configurationreferences/default" -apiVersion $configApiVersion
        }
        catch {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] Failed to delete configuration ref for target: $targetId" -ForegroundColor Red
            $hasError = $true
        }

        Write-Host "Removing schema ref for $targetId" -ForegroundColor Green
        try {
            deleteARMID "$targetId/providers/$nameSpace/schemareferences/default" -apiVersion $PublicPreviewAPIVersion
        }
        catch {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] Failed to delete schema ref for target: $targetId" -ForegroundColor Red
            $hasError = $true
        }

        Write-Host "Removing SG Relationship for $targetId" -ForegroundColor Green
        try {
            deleteARMID "$targetId/providers/Microsoft.Relationships/serviceGroupMember/SGRelation" -apiVersion $SGRelationshipAPIVersion
        }
        catch {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] Failed to delete SG relationship for target: $targetId" -ForegroundColor Red
            $hasError = $true
        }

        if ($hasError) {
            $failedTargets += $targetId
        }
    }

    # deploymentTarget delete -> will delete target, targetSolutions, targetInstances, targetVersions
    Write-Host "Deleting deployment targets, resolved solution versions and instances: " -ForegroundColor Yellow

    if ($failedTargets.Count -gt 0) {
        Write-Host "##[warning] The following targets had errors during related resource deletion and will be skipped:" -ForegroundColor Yellow
        $failedTargets | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }

    foreach ($targetUri in $deploymentTargetsDeleteURIs | Where-Object { $failedTargets -notcontains $_ })
    {
        Write-Host "##[debug] Deleting $targetUri" -ForegroundColor Green
        $deleteUri = $targetUri + "?forceDelete=true&api-version=$apiVersion"
        try 
        {
            DeleteLROAsync -deleteUri $deleteUri
        }
        catch 
        {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] An error occurred while deleting target: $targetUri" -ForegroundColor Red
            $failedTargets += $targetUri
            continue
        }
        Write-Host "##[debug] Deleted" -ForegroundColor Red
    } 
    if ($failedTargets.Count -gt 0) {
        Write-Host "##[warning] Deletion failed for the following targets:" -ForegroundColor Yellow
        $failedTargets | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
    Write-Host "##[section] Finished Deletion of Targets" -ForegroundColor Yellow
}

# Not needed for now, but keeping it for future reference
function deleteTargetSolutionsAndInstances {
    param (
        [string]$targetId,
        [string]$apiVersion,
        [string]$resourceGroupName,
        [string]$subscriptionId
    )
    Write-Host "##[section] Starting Deletion of Target Solution and versions" -ForegroundColor Yellow
    $getURI = $targetId + "/solutions?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $solutionsDeleteURIs = $response.value | Select-Object -ExpandProperty id

    $targetName = $targetId.Split("/")[-1]

    foreach ($solutionURI in $solutionsDeleteURIs) {
        $solutionName = $solutionURI.Split("/")[-1]
        $getURI = $solutionURI + "/versions?api-version=$apiVersion"
        $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
        $solutionVersionsDeleteNames = $response.value | Select-Object -ExpandProperty name

        Write-Host "Removing instance for $solutionName" -ForegroundColor Green
        Invoke-AzCommand "az workload-orchestration target uninstall -g $resourceGroupName --subscription $subscriptionId --target-name $targetName --solution-name $solutionName"

        foreach ($solutionVersionName in $solutionVersionsDeleteNames)
        {
            Write-Host "Removing revision for $solutionVersionName" -ForegroundColor Green
            Invoke-AzCommand "az workload-orchestration target remove-revision -g $resourceGroupName --subscription $subscriptionId --target-name $targetName --solution-name $solutionName --solution-version-name $solutionVersionName"   
        }

        # solution delete
        Write-Host "Deleting solution: $solutionURI"
        deleteARMID -armID $solutionURI -apiVersion $apiVersion
    }
}

function deleteConfigurationsAndItsChildrens {
    param (
        [string]$baseURI,
        [string]$apiVersion
    )
    Write-Host "##[section] Starting Deletion of Configurations and its childrens" -ForegroundColor Yellow
    $getURI = $baseURI + "/configurations?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $configurationsDeleteURIs = $response.value | Select-Object -ExpandProperty id

    foreach ($configurationURI in $configurationsDeleteURIs) {
        $getURI = $configurationURI + "/dynamicConfigurations?api-version=$apiVersion"
        $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
        $dynamicConfigurationsDeleteURIs = $response.value | Select-Object -ExpandProperty id
        
        foreach ($dynamicConfigurationURI in $dynamicConfigurationsDeleteURIs) {
            $getURI = $dynamicConfigurationURI + "/versions?api-version=$apiVersion"
            $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
            $dynamicConfigurationVersionsDeleteURIs = $response.value | Select-Object -ExpandProperty id
            # dynamicConfigurationVersion delete
            Write-Host "Deleting dynamic config versions: "
            $dynamicConfigurationVersionsDeleteURIs | ForEach-Object { Write-Host $_ -ForegroundColor Green }
            deleteRTs -rtURIs $dynamicConfigurationVersionsDeleteURIs -apiVersion $apiVersion

            # dynamicConfiguration delete
            Write-Host "Deleting dynamic config $dynamicConfigurationURI"
            deleteARMID -armID $dynamicConfigurationURI -apiVersion $apiVersion
        }
        # configuration delete
        Write-Host "Deleting configuration $configurationURI"
        deleteARMID -armID $configurationURI -apiVersion $apiVersion
    }
    Write-Host "##[section] Finished Deletion of Configurations and its childrens" -ForegroundColor Yellow
}

function deleteConfigTemplates {
    param (
        [string]$baseURI,
        [string]$apiVersion
    )
    Write-Host "##[section] Starting Deletion of config templates" -ForegroundColor Yellow
    $getURI = $baseURI + "/configTemplates?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $configurationsDeleteURIs = $response.value | Select-Object -ExpandProperty id
    $configurationsDeleteURIs | ForEach-Object  { Write-Host $_ -ForegroundColor Green }
    deleteRTs -rtURIs $configurationsDeleteURIs -apiVersion $apiVersion

    Write-Host "##[section] Finished Deletion of Configurations and its childrens" -ForegroundColor Yellow
}

function deleteSolutionsAndItsChildrens {
    param (
        [string]$baseURI,
        [string]$apiVersion
    )
    Write-Host "##[section] Starting Deletion of Solutions and its childrens" -ForegroundColor Yellow
    $getURI = $baseURI + "/solutionTemplates?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $solutionsDeleteURIs = $response.value | Select-Object -ExpandProperty id

    foreach ($solutionURI in $solutionsDeleteURIs) {
        $getURI = $solutionURI + "/versions?api-version=$apiVersion"
        $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
        $solutionVersionsDeleteNames = $response.value | Select-Object -ExpandProperty name
        # solutionVersion delete
        foreach ($solutionVersionName in $solutionVersionsDeleteNames)
        {
            $postUri = $solutionUri + "/removeVersion"
            $body = @{
                version = $solutionVersionName
            } | ConvertTo-Json

            $deleteURI = $postUri + "?api-version=$apiVersion"

            PostLROAsync -postUri $deleteURI -body $body

            Write-Host "##[debug] Deleted" -ForegroundColor Red
        }

        try {
            Write-Host "Deleting solution: $solutionURI"
            deleteARMID -armID $solutionURI -apiVersion $apiVersion
        } catch {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] An error occurred while deleting solution" -ForegroundColor Red
        }
    }
    Write-Host "##[section] Finished Deletion of Solutions and its childrens" -ForegroundColor Yellow
}

function deleteSchemas {
    param (
        [string]$baseURI,
        [string]$apiVersion
    )
    Write-Host "##[section] Starting Deletion of Schemas and its childrens" -ForegroundColor Yellow
    $getURI = $baseURI + "/schemas?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $schemasDeleteURIs = $response.value | Select-Object -ExpandProperty id

    foreach ($schemaURI in $schemasDeleteURIs) {
        $getURI = $schemaURI + "/dynamicSchemas?api-version=$apiVersion"
        $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
        $schemaURIs = $response.value | Select-Object -ExpandProperty id
        
        foreach ($dynSchemaURI in $schemaURIs) {
            try {
                $getURI = $dynSchemaURI + "/versions?api-version=$apiVersion"
                $response = az rest --method get --uri $getURI --output json  | ConvertFrom-Json
                $dynSchemaVersionURIs = $response.value | Select-Object -ExpandProperty id
                Write-Host "Deleting dynamic schema versions: "
                $dynSchemaVersionURIs | ForEach-Object { Write-Host $_ -ForegroundColor Green }
                deleteRTs -rtURIs $dynSchemaVersionURIs -apiVersion $apiVersion
                Write-Host "Deleting dynamic schema: $dynSchemaURI"
                deleteARMID -armID $dynSchemaURI -apiVersion $apiVersion
            } catch {
                Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "##[debug] An error occurred while deleting dynamic schema" -ForegroundColor Red
            }
        }
        try {
            Write-Host "Deleting schema: $schemaURI"
            deleteARMID -armID $schemaURI -apiVersion $apiVersion
        } catch {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] An error occurred while deleting schema" -ForegroundColor Red
        }
    }

    Write-Host "##[section] Finished Deletion of Schemas and its childrens" -ForegroundColor Yellow
}

function deleteContextsAndSiteRefs {
    param (
        [string]$baseURI,
        [string]$apiVersion
    )
    Write-Host "##[section] Starting Deletion of Contexts and it's children" -ForegroundColor Yellow
    $getURI = $baseURI + "/contexts?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $contextsDeleteURIs = $response.value | Select-Object -ExpandProperty id

    foreach ($contextUri in $contextsDeleteURIs)
    {
        $getURI = $contextUri + "/siteReferences?api-version=$apiVersion"
        $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
        $siteRefsDeleteURIs = $response.value | Select-Object -ExpandProperty id

        deleteRTs -rtURIs $siteRefsDeleteURIs -apiVersion $apiVersion
    }

    deleteRTs -rtURIs $contextsDeleteURIs -apiVersion $apiVersion
    Write-Host "##[section] Finished Deletion of Contexts and its children" -ForegroundColor Yellow
}

function removeTestCapabilities {
    param (
        [string]$baseURI,
        [string]$apiVersion
    )
    Write-Host "##[section] Cleaning up capabilities in Test context" -ForegroundColor Yellow
    $getURI = $baseURI + "/contexts?api-version=$apiVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $context = $response.value
    foreach ($context in $response.value)
    {
        # Filter the capabilities array
        $context.properties.capabilities = $context.properties.capabilities | Where-Object {
            !($_.name.ToLower() -like "test_*" -and $_.name.Length -eq 39)

        }
        # Convert the modified object back to JSON
        $modifiedContext = $context | ConvertTo-Json -Depth 10
        $contextUri = $baseURI + "/contexts/" + $context.name + "?api-version=$apiVersion"
        PutAsync -putUri $contextUri -body $modifiedContext

        Write-Host "Cleaned up capabilities for context: $contextUri"
    }
    Write-Host "##[section] Finished Cleaning up of Context capabilities" -ForegroundColor Yellow
}

function deleteSgSitesAndSiteRefsForMicrosoftEdge {
    param (
        [string]$sgSiteNames,
        [string]$contextName,
        [string]$contextResourceGroupName,
        [string]$contextSubscriptionId
    )
    Write-Host "##[section] Starting Deletion of Sites and Site Refs" -ForegroundColor Yellow
    $sgSiteNamesArray = $sgSiteNames -split ' '
    $sitesDeleteURIs = @()
    foreach ($sgSiteName in $sgSiteNamesArray) {
        $sitesDeleteURIs += "/providers/Microsoft.Management/serviceGroups/$sgSiteName/providers/Microsoft.Edge/sites/$sgSiteName"
    }
    $sgDeleteURIs = @()
    foreach ($sgSiteName in $sgSiteNamesArray) {
        $sgDeleteURIs += "/providers/Microsoft.Management/serviceGroups/$sgSiteName"
    }

    az cloud update --endpoint-resource-manager "https://management.azure.com"

    $contextSiteRefsUri = "/subscriptions/$contextSubscriptionId/resourceGroups/$contextResourceGroupName/providers/Microsoft.Edge/contexts/$contextName/siteReferences?api-version=$PublicPreviewAPIVersion"
    $response = az rest --method get --uri $contextSiteRefsUri --output json | ConvertFrom-Json

    # Filter siteIds that are part of $sitesDeleteURIs
    $filteredSiteRefIds = @()
    foreach ($siteRef in $response.value) {
        $siteId = $siteRef.properties.siteId
        $siteRefId = $siteRef.id
        if ($sitesDeleteURIs -contains $siteId) {
            $filteredSiteRefIds += $siteRefId
        }
    }

    Write-Host "Filtered siteRefIds to delete:" -ForegroundColor Yellow
    $filteredSiteRefIds | ForEach-Object { Write-Host $_ -ForegroundColor Green }
    deleteRTs -rtURIs $filteredSiteRefIds -apiVersion $PublicPreviewAPIVersion

    foreach ($siteName in $sgSiteNamesArray) {
        Write-Host "Removing configuration ref for $siteName" -ForegroundColor Green
        deleteARMID "/providers/Microsoft.Management/serviceGroups/$siteName/providers/Microsoft.Edge/configurationreferences/default" -apiVersion $ConfigRTAPIVersion
    }

    Write-Host "siteIds to delete:" -ForegroundColor Yellow
    $sitesDeleteURIs | ForEach-Object { Write-Host $_ -ForegroundColor Green }

    # Proceed with deletion of siteIds
    deleteRTs -rtURIs $sitesDeleteURIs -apiVersion $SitesAPIVersion

    Write-Host "SGs to delete: " -ForegroundColor Yellow
    $sgDeleteURIs | ForEach-Object { Write-Host $_ -ForegroundColor Green }

    # Proceed with deletion of sgs
    deleteRTs -rtURIs $sgDeleteURIs -apiVersion $SgAPIVersion
}

function deleteRGSites {
    param (
        [string]$resourceGroupName,
        [string]$subscriptionId
    )
    Write-Host "##[section] Starting Deletion of Sites" -ForegroundColor Yellow
    az cloud update --endpoint-resource-manager "https://management.azure.com"
    $baseURI = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/microsoft.edge"

    $getURI = $baseURI + "/sites?api-version=$SitesAPIVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $sitesDeleteURIs = $response.value | Select-Object -ExpandProperty id
    # site delete
    deleteRTs -rtURIs $sitesDeleteURIs -apiVersion $SitesAPIVersion
    Write-Host "##[section] Finished Deletion of Sites" -ForegroundColor Yellow
}

function deleteAksClusters {
    param (
        [string]$resourceGroupName,
        [string]$subscriptionId
    )
    Write-Host "##[section] Starting Deletion of all AKS clusters" -ForegroundColor Yellow
    $baseURI = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.ContainerService"

    $getURI = $baseURI + "/managedClusters?api-version=$AksAPIVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $aksDeleteURIs = $response.value | Select-Object -ExpandProperty id

    deleteRTs -rtURIs $aksDeleteURIs -apiVersion $AksAPIVersion
    Write-Host "##[section] Finished Deletion of all AKS clusters" -ForegroundColor Yellow
}

function deleteAksAzureClusters {
    param (
        [string]$resourceGroupName,
        [string]$subscriptionId
    )
    Write-Host "##[section] Starting Deletion of all AKS Azure clusters" -ForegroundColor Yellow
    $baseURI = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Kubernetes"

    $getURI = $baseURI + "/connectedClusters?api-version=$AksAzureAPIVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $aksDeleteURIs = $response.value | Select-Object -ExpandProperty id

    deleteRTs -rtURIs $aksDeleteURIs -apiVersion $AksAzureAPIVersion
    Write-Host "##[section] Finished Deletion of all AKS Azure clusters" -ForegroundColor Yellow
}

function deleteManagedIdentities {
    param (
        [string]$resourceGroupName,
        [string]$subscriptionId
    )
    Write-Host "##[section] Starting Deletion of all Managed Identities" -ForegroundColor Yellow
    $baseURI = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.ManagedIdentity"

    $getURI = $baseURI + "/userAssignedIdentities?api-version=$ManagedIdentityAPIVersion"
    $response = az rest --method get --uri $getURI --output json | ConvertFrom-Json
    $managedIdentitiesDeleteURIs = $response.value | Select-Object -ExpandProperty id

    deleteRTs -rtURIs $managedIdentitiesDeleteURIs -apiVersion $ManagedIdentityAPIVersion
    Write-Host "##[section] Finished Deletion of all Managed Identities" -ForegroundColor Yellow
}


function deleteCommon {
    param (
        [bool]$skipAksDeletion,
        [bool]$skipManagedIdentityDeletion,
        [string]$resourceGroupName,
        [string]$subscriptionId
    )

    if ($skipAksDeletion -eq $false) {
        try {
            deleteAksClusters -resourceGroupName $resourceGroupName -subscriptionId $subscriptionId
        } catch {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] An error occurred while deleting AKS clusters" -ForegroundColor Red
        }
        
        try {
            deleteAksAzureClusters -resourceGroupName $resourceGroupName -subscriptionId $subscriptionId
        } catch {
            Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "##[debug] An error occurred while deleting AKS Azure clusters" -ForegroundColor Red
        }
    }
    else {
        Write-Host "##[section] Skipping AKS clusters Deletion" -ForegroundColor Yellow
    }
    
    try {
        if ($skipManagedIdentityDeletion -eq $false) {
            deleteManagedIdentities -resourceGroupName $resourceGroupName -subscriptionId $subscriptionId
        }
        else {
            Write-Host "##[section] Skipping Managed Identity Deletion" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "##[debug] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "##[debug] An error occurred while deleting managed identities" -ForegroundColor Red
    }
}


$API02Version = "2024-02-01-preview"
$API04Version = "2024-04-01-preview"
$API06Version = "2024-06-01-preview"
$API07Version = "2024-07-01-preview"
$API08Version = "2024-08-01-preview"
$API09Version = "2024-09-01-preview"
$ConfigRTAPIVersion = "2024-09-01-preview"
$ConfigRTPrivateAPIVersion = "2024-06-01-preview"
$SGRelationshipAPIVersion = "2023-09-01-preview"
$SgAPIVersion = "2024-02-01-preview"
$PublicPreviewAPIVersion = "2025-01-01-preview"
$SitesAPIVersion = "2025-04-01"
$AksAPIVersion = "2025-01-01"
$AksAzureAPIVersion = "2024-12-01-preview"
$ManagedIdentityAPIVersion = "2024-11-30"
