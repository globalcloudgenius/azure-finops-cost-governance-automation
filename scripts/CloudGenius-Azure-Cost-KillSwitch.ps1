#requires -Version 7.4

<#
.SYNOPSIS
Sanitized portfolio version of the CloudGenius Azure cost-control runbook.

.DESCRIPTION
Queries combined month-to-date ActualCost across configured subscriptions.
When combined cost reaches the configured threshold, the runbook can stop or
deallocate supported workloads. TestMode is enabled by default in this public version.
#>

$ErrorActionPreference = "Continue"

$SubscriptionIds = @(
    "<DEV-SUBSCRIPTION-ID>",
    "<PROD-SUBSCRIPTION-ID>"
)

[decimal]$KillAtCad = 9.00
$ExpectedCurrency = "CAD"
$TestMode = $true

function Invoke-SafeAction {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    try {
        Write-Output "ACTION: $Description"

        if ($TestMode) {
            Write-Warning "TEST MODE: Would execute: $Description"
            return
        }

        & $Action
        Write-Output "SUCCESS: $Description"
    }
    catch {
        Write-Warning "FAILED: $Description"
        Write-Warning $_.Exception.Message
    }
}

function Get-SubscriptionMonthToDateCost {
    param([Parameter(Mandatory)][string]$SubscriptionId)

    $Path = "/subscriptions/$SubscriptionId/providers/Microsoft.CostManagement/query?api-version=2025-03-01"
    $Body = @{
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
        }
    }

    try {
        $Response = $null

        for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
            $Response = Invoke-AzRestMethod -Method POST -Path $Path -Payload ($Body | ConvertTo-Json -Depth 10)

            if ($Response.StatusCode -ge 200 -and $Response.StatusCode -lt 300) {
                break
            }

            if ($Response.StatusCode -eq 429) {
                $Delay = 60 * $Attempt
                Write-Warning "Cost Management throttled subscription $SubscriptionId. Waiting $Delay seconds before retry."
                Start-Sleep -Seconds $Delay
                continue
            }

            throw "Cost Management returned HTTP $($Response.StatusCode)"
        }

        if ($null -eq $Response -or $Response.StatusCode -eq 429) {
            throw "Cost Management query failed after retry attempts."
        }

        $Data = $Response.Content | ConvertFrom-Json
        $ColumnNames = @($Data.properties.columns | ForEach-Object { $_.name })
        $CostIndex = [Array]::IndexOf($ColumnNames, "Cost")
        if ($CostIndex -lt 0) { $CostIndex = [Array]::IndexOf($ColumnNames, "PreTaxCost") }
        $CurrencyIndex = [Array]::IndexOf($ColumnNames, "Currency")

        if ($null -eq $Data.properties.rows -or $Data.properties.rows.Count -eq 0 -or $CostIndex -lt 0) {
            return [PSCustomObject]@{ SubscriptionId=$SubscriptionId; Cost=[decimal]0; Currency=$ExpectedCurrency; Success=$true }
        }

        $Row = $Data.properties.rows[0]
        return [PSCustomObject]@{
            SubscriptionId = $SubscriptionId
            Cost = [decimal]$Row[$CostIndex]
            Currency = if ($CurrencyIndex -ge 0) { [string]$Row[$CurrencyIndex] } else { $ExpectedCurrency }
            Success = $true
        }
    }
    catch {
        Write-Error "Cost query failed for subscription $SubscriptionId"
        return [PSCustomObject]@{ SubscriptionId=$SubscriptionId; Cost=[decimal]0; Currency="ERROR"; Success=$false }
    }
}

function Stop-SupportedWorkloads {
    foreach ($VM in @(Get-AzVM -ErrorAction SilentlyContinue)) {
        Invoke-SafeAction "Deallocate VM $($VM.ResourceGroupName)/$($VM.Name)" {
            Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force -NoWait
        }
    }

    foreach ($ScaleSet in @(Get-AzVmss -ErrorAction SilentlyContinue)) {
        Invoke-SafeAction "Deallocate VMSS $($ScaleSet.ResourceGroupName)/$($ScaleSet.Name)" {
            Stop-AzVmss -ResourceGroupName $ScaleSet.ResourceGroupName -VMScaleSetName $ScaleSet.Name -Force
        }
    }

    foreach ($Cluster in @(Get-AzAksCluster -ErrorAction SilentlyContinue)) {
        Invoke-SafeAction "Stop AKS $($Cluster.ResourceGroupName)/$($Cluster.Name)" {
            Stop-AzAksCluster -ResourceGroupName $Cluster.ResourceGroupName -Name $Cluster.Name -NoWait
        }
    }

    foreach ($ContainerGroup in @(Get-AzContainerGroup -ErrorAction SilentlyContinue)) {
        Invoke-SafeAction "Stop ACI $($ContainerGroup.ResourceGroupName)/$($ContainerGroup.Name)" {
            Stop-AzContainerGroup -ResourceGroupName $ContainerGroup.ResourceGroupName -Name $ContainerGroup.Name -Confirm:$false
        }
    }

    foreach ($WebApp in @(Get-AzWebApp -ErrorAction SilentlyContinue)) {
        Invoke-SafeAction "Stop Web/Function App $($WebApp.ResourceGroup)/$($WebApp.Name)" {
            Stop-AzWebApp -ResourceGroupName $WebApp.ResourceGroup -Name $WebApp.Name
        }
    }
}

function Show-PotentialResidualCosts {
    $Types = @(
        "Microsoft.Network/azureFirewalls",
        "Microsoft.Network/virtualNetworkGateways",
        "Microsoft.Network/bastionHosts",
        "Microsoft.Network/natGateways",
        "Microsoft.Network/publicIPAddresses",
        "Microsoft.Compute/disks",
        "Microsoft.Compute/snapshots",
        "Microsoft.Storage/storageAccounts",
        "Microsoft.Web/serverfarms",
        "Microsoft.OperationalInsights/workspaces",
        "Microsoft.Sql/servers"
    )

    foreach ($Resource in @(Get-AzResource -ErrorAction SilentlyContinue)) {
        if ($Resource.ResourceType -in $Types) {
            Write-Warning "POSSIBLE RESIDUAL COST | $($Resource.ResourceType) | $($Resource.ResourceId)"
        }
    }
}

Disable-AzContextAutosave -Scope Process
Connect-AzAccount -Identity | Out-Null
Write-Output "Managed identity authentication: SUCCESS"

$CostResults = @()
$CostQueryFailure = $false

foreach ($SubscriptionId in $SubscriptionIds) {
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    $Result = Get-SubscriptionMonthToDateCost -SubscriptionId $SubscriptionId
    $CostResults += $Result
    if (-not $Result.Success) { $CostQueryFailure = $true }
    Write-Output ("Cost = {0:N4} {1}" -f $Result.Cost, $Result.Currency)
}

if ($CostQueryFailure) { throw "Cost query failed. No shutdown actions were attempted." }
if ($CostResults | Where-Object Currency -ne $ExpectedCurrency) { throw "Unexpected billing currency. No shutdown actions were attempted." }

[decimal]$CombinedCost = ($CostResults | Measure-Object -Property Cost -Sum).Sum
Write-Output "Combined cost: CAD $CombinedCost"
Write-Output "Emergency threshold: CAD $KillAtCad"

if ($CombinedCost -lt $KillAtCad) {
    Write-Output "STATUS: SAFE"
    Write-Output "No workloads will be modified."
    exit 0
}

foreach ($SubscriptionId in $SubscriptionIds) {
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Stop-SupportedWorkloads
    Show-PotentialResidualCosts
}
