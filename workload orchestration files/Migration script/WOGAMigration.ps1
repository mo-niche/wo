param (
    [Parameter(Mandatory = $true)]
    [string]
    $location
)

$namespace = "microsoft.edge"

function List-Contexts() {
    ,(az graph query -q "resources | where type =~ '$namespace/contexts'" -o json | ConvertFrom-JSON).data
}

function Summarize-Targets-By-ResourceGroup() {   
    ,(az graph query --first 1000 -q "resources | where type =~ '$namespace/targets' | where location =~ '$location' | summarize count = count() by subscriptionId, resourceGroup" -o json | ConvertFrom-JSON).data
}

function List-Targets() {
    param (
        [string]$subscriptionId,
        [string]$resourceGroup,
        [string]$apiVersion = "2025-01-01-preview"
    )

    $scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/$namespace/targets"
    $result = az rest --method get --uri $scope`?api-version=$apiVersion --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "GET $scope?api-version=$apiVersion failed with: $result"
    }
    
    ,($result | ConvertFrom-Json).value
}

function Patch-Target() {
    param (
        [string]$id,
        [string]$delta,
        [string]$apiVersion
    )

    $result = (az rest --header Content-Type=application/json --method PATCH --uri $id`?api-version=$apiVersion --body $delta 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "PATCH $id?api-version=$apiVersion failed with: $result"
    }
    
    $result | ConvertFrom-JSON 
}

function updateTargetsWithContextId {
    $contexts = List-Contexts
    Write-Host "Found $($contexts.Length) Contexts" -ForegroundColor Cyan
    
    if ($contexts.Length -eq 0) {
        Write-Host "[ERROR] No Contexts found. Unsupported" -ForegroundColor Red
        exit 1
    }

    if ($contexts.Length -gt 1) {
        Write-Host "[ERROR] Greater than 1 Context found. Unsupported" -ForegroundColor Red
        exit 1
    }
    
    $contextId = $contexts[0].id
    Write-Host "Found Context at $contextId" -ForegroundColor Cyan
    
    $subscriptionResourceGroups = Summarize-Targets-By-ResourceGroup
    foreach ($item in $subscriptionResourceGroups) {
        $subscriptionId = $item.subscriptionId
        $resourceGroup = $item.resourceGroup
        
        try {
            $targets = List-Targets -subscriptionId $subscriptionId -resourceGroup $resourceGroup -apiVersion 2025-06-01
            Write-Host "Migration Complete for Subscription $subscriptionId Resource Group $resourceGroup"
            continue
        }
        catch {
            Write-Host "Migrating targets for Subscription $subscriptionId Resource Group $resourceGroup"
        }

        $targets = List-Targets -subscriptionId $subscriptionId -resourceGroup $resourceGroup -apiVersion 2025-01-01-preview
        Write-Host "Found $($targets.Length) targets in Subscription $subscriptionId Resource Group $resourceGroup"
        foreach ($target in $targets) {
            if ($target.location -ne $location) {
                # Write-Host "Skipped target $($target.name) for Subscription $subscriptionId Resource Group $resourceGroup - Location $($target.location) not matched"
                continue
            } 
        
            try {
                Patch-Target -id $target.id -delta "{'properties': {'contextId': '$contextId'}}" -apiVersion 2025-06-01
                Write-Host "Migrated target $($target.name) for Subscription $subscriptionId Resource Group $resourceGroup"
            }
            catch {
                $errorMessage = $_.Exception.Message
                Write-Host "Fail to Migrate $($target.name) for Subscription $subscriptionId Resource Group $resourceGroup - $errorMessage"
            }
        }
        Write-Host "Migration Complete for Subscription $subscriptionId Resource Group $resourceGroup"
    }
}

$tenantId = ((az account show) | ConvertFrom-Json ).tenantId
Write-Host "Migrating $namespace/targets Resources in Tenant $tenantId" -ForegroundColor Cyan
updateTargetsWithContextId
Write-Host "Migration Complete" -ForegroundColor Cyan
