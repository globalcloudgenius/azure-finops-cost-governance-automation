#requires -Version 7.2

<#
.SYNOPSIS
Read-only Azure cost and resource audit used in the CloudGenius lab.
#>

$Subscriptions = @(
    @{ Name = "Dev"; Id = "<DEV-SUBSCRIPTION-ID>" },
    @{ Name = "Prod"; Id = "<PROD-SUBSCRIPTION-ID>" }
)

$OutDir = Join-Path $env:USERPROFILE "Downloads/CloudGenius-Cost-Audit"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$CostBodyFile = Join-Path $env:TEMP "cloudgenius-cost-audit-query.json"

$CostBody = @{
    type = "ActualCost"
    timeframe = "MonthToDate"
    dataset = @{
        granularity = "Monthly"
        aggregation = @{
            totalCost = @{
                name = "Cost"
                function = "Sum"
            }
        }
        grouping = @(
            @{ type="Dimension"; name="ServiceName" },
            @{ type="Dimension"; name="ResourceGroupName" },
            @{ type="Dimension"; name="ResourceId" }
        )
    }
} | ConvertTo-Json -Depth 10

$CostBody | Set-Content -Path $CostBodyFile -Encoding utf8

$AllCosts = @()
$AllResources = @()
$RiskResources = @()

$PotentiallyBillableTypes = @(
    "Microsoft.Compute/virtualMachines",
    "Microsoft.Compute/virtualMachineScaleSets",
    "Microsoft.Compute/disks",
    "Microsoft.Compute/snapshots",
    "Microsoft.ContainerService/managedClusters",
    "Microsoft.ContainerInstance/containerGroups",
    "Microsoft.ContainerRegistry/registries",
    "Microsoft.Network/azureFirewalls",
    "Microsoft.Network/virtualNetworkGateways",
    "Microsoft.Network/bastionHosts",
    "Microsoft.Network/natGateways",
    "Microsoft.Network/publicIPAddresses",
    "Microsoft.Network/applicationGateways",
    "Microsoft.Network/loadBalancers",
    "Microsoft.OperationalInsights/workspaces",
    "Microsoft.Insights/components",
    "Microsoft.Insights/dataCollectionRules",
    "Microsoft.Web/serverfarms",
    "Microsoft.Web/sites",
    "Microsoft.Storage/storageAccounts",
    "Microsoft.Sql/servers",
    "Microsoft.Sql/managedInstances",
    "Microsoft.DBforPostgreSQL/flexibleServers",
    "Microsoft.DBforMySQL/flexibleServers",
    "Microsoft.EventHub/namespaces",
    "Microsoft.ServiceBus/namespaces",
    "Microsoft.Databricks/workspaces",
    "Microsoft.CognitiveServices/accounts",
    "Microsoft.Search/searchServices",
    "Microsoft.ApiManagement/service",
    "Microsoft.RecoveryServices/vaults",
    "Microsoft.DataProtection/backupVaults"
)

foreach ($Sub in $Subscriptions) {
    Write-Host "Auditing $($Sub.Name)" -ForegroundColor Cyan
    $Url = "https://management.azure.com/subscriptions/$($Sub.Id)/providers/Microsoft.CostManagement/query?api-version=2025-03-01"
    $RawCost = az rest --method post --resource "https://management.azure.com/" --url $Url --headers "Content-Type=application/json" --body "@$CostBodyFile" -o json

    if ($LASTEXITCODE -eq 0 -and $RawCost) {
        $CostJson = $RawCost | ConvertFrom-Json
        $Cols = @($CostJson.properties.columns.name)
        $CostIndex = [Array]::IndexOf($Cols,"Cost")
        $ServiceIndex = [Array]::IndexOf($Cols,"ServiceName")
        $RGIndex = [Array]::IndexOf($Cols,"ResourceGroupName")
        $ResourceIdIndex = [Array]::IndexOf($Cols,"ResourceId")
        $CurrencyIndex = [Array]::IndexOf($Cols,"Currency")

        foreach ($Row in @($CostJson.properties.rows)) {
            $AllCosts += [PSCustomObject]@{
                Subscription = $Sub.Name
                Service = if ($ServiceIndex -ge 0) { $Row[$ServiceIndex] } else { "" }
                ResourceGroup = if ($RGIndex -ge 0) { $Row[$RGIndex] } else { "" }
                ResourceId = if ($ResourceIdIndex -ge 0) { $Row[$ResourceIdIndex] } else { "" }
                Cost = if ($CostIndex -ge 0) { [decimal]$Row[$CostIndex] } else { 0 }
                Currency = if ($CurrencyIndex -ge 0) { $Row[$CurrencyIndex] } else { "CAD" }
            }
        }
    }

    $Resources = az resource list --subscription $Sub.Id -o json | ConvertFrom-Json

    foreach ($R in $Resources) {
        $AllResources += [PSCustomObject]@{
            Subscription=$Sub.Name; Name=$R.name; ResourceGroup=$R.resourceGroup; ResourceType=$R.type; Location=$R.location; ResourceId=$R.id
        }

        if ($R.type -in $PotentiallyBillableTypes) {
            $RiskResources += [PSCustomObject]@{
                Subscription=$Sub.Name; Name=$R.name; ResourceGroup=$R.resourceGroup; ResourceType=$R.type; Location=$R.location; ResourceId=$R.id
            }
        }
    }
}

$AllCosts | Sort-Object Cost -Descending | Export-Csv (Join-Path $OutDir "MonthToDate-Costs.csv") -NoTypeInformation
$AllResources | Export-Csv (Join-Path $OutDir "All-Azure-Resources.csv") -NoTypeInformation
$RiskResources | Export-Csv (Join-Path $OutDir "Potentially-Billable-Resources.csv") -NoTypeInformation

Write-Host "Reports saved to $OutDir" -ForegroundColor Green
