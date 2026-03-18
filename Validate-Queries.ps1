<#
.SYNOPSIS
    Validates Azure Resource Graph queries from the ALZ checklist queries file.

.DESCRIPTION
    Runs each queryable ARG query against the current Azure subscription/tenant,
    reports success/failure/empty results, and outputs:
    - validation_results.csv: one row per checklist item with status and finding
    - validation_results_detailed.csv: one row per resource per check with compliance
    - validation_results_not_queryable.csv: items that require manual review
    - validation_results.xlsx: formatted Excel workbook with all three tabs (if ImportExcel available)

.PARAMETER QueriesFile
    Path to the alz_all_queries.json file. Defaults to ./queries/alz_all_queries.json

.PARAMETER OutputFile
    Path for the validation results CSV. Defaults to ./validation_results.csv

.PARAMETER SubscriptionId
    Optional. Scope queries to a specific subscription.

.PARAMETER ManagementGroup
    Optional. Scope queries to a management group.

.EXAMPLE
    .\Validate-Queries.ps1 -QueriesFile .\queries\alz_all_queries.json -ManagementGroup "<tenant-id>"
    .\Validate-Queries.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000"
#>

[CmdletBinding()]
param(
    [string]$QueriesFile = "$PSScriptRoot\queries\alz_all_queries.json",
    [string]$OutputFile = "$PSScriptRoot\validation_results.csv",
    [string]$SubscriptionId,
    [string]$ManagementGroup
)

$ErrorActionPreference = 'Continue'

# --- Prerequisites ---
Write-Host "=== ALZ Graph Query Validator ===" -ForegroundColor Cyan
Write-Host ""

# Check Az.ResourceGraph module
if (-not (Get-Module -ListAvailable -Name Az.ResourceGraph)) {
    Write-Host "ERROR: Az.ResourceGraph module not found. Install with:" -ForegroundColor Red
    Write-Host "  Install-Module -Name Az.ResourceGraph -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}
Import-Module Az.ResourceGraph -ErrorAction Stop

# Check login
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) { throw "No context" }
    Write-Host "Logged in as: $($context.Account.Id)" -ForegroundColor Green
    Write-Host "Tenant:       $($context.Tenant.Id)"
    Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
} catch {
    Write-Host "ERROR: Not logged into Azure. Run Connect-AzAccount first." -ForegroundColor Red
    exit 1
}

# --- Load queries ---
if (-not (Test-Path $QueriesFile)) {
    Write-Host "ERROR: Queries file not found at $QueriesFile" -ForegroundColor Red
    exit 1
}

$data = Get-Content $QueriesFile -Raw | ConvertFrom-Json
$allQueries = $data.queries
$queryable = $allQueries | Where-Object { $_.queryable -eq $true }

Write-Host ""
Write-Host "Loaded $($allQueries.Count) items ($($queryable.Count) queryable)" -ForegroundColor Cyan
Write-Host ""

# --- Build Search-AzGraph parameters ---
$graphParams = @{}
if ($SubscriptionId) {
    $graphParams['Subscription'] = $SubscriptionId
    Write-Host "Scoped to subscription: $SubscriptionId"
}
if ($ManagementGroup) {
    $graphParams['ManagementGroup'] = $ManagementGroup
    Write-Host "Scoped to management group: $ManagementGroup"
}

# --- Run queries ---
$results = [System.Collections.ArrayList]::new()
$detailedResults = [System.Collections.ArrayList]::new()
$success = 0
$failed = 0
$empty = 0
$total = $queryable.Count
$i = 0

foreach ($q in $queryable) {
    $i++
    $pct = [math]::Round(($i / $total) * 100)
    Write-Progress -Activity "Validating queries" -Status "$i/$total ($pct%) - $($q.category)" -PercentComplete $pct

    $result = [PSCustomObject]@{
        guid        = $q.guid
        category    = $q.category
        subcategory = $q.subcategory
        severity    = $q.severity
        text        = $q.text
        status      = ""
        rowCount    = 0
        compliant   = 0
        nonCompliant = 0
        review      = 0
        finding     = ""
        error       = ""
    }

    try {
        $graphResult = Search-AzGraph -Query $q.graph @graphParams -First 1000 -ErrorAction Stop
        $result.rowCount = $graphResult.Count
        if ($graphResult.Count -eq 0) {
            $result.status = "EMPTY"
            $result.finding = "No resources found in scope"
            $empty++
        } else {
            $result.status = "OK"
            $success++

            # Capture per-resource detail
            foreach ($row in $graphResult) {
                $compValue = ""
                $currentVal = ""
                $expectedVal = ""
                $checkLabel = ""
                $resName = ""
                $resGroup = ""
                $resSub = ""
                $resId = ""

                # Extract fields from result row (handles both hashtable and PSObject)
                $props = if ($row -is [hashtable]) { $row } else { $row.PSObject.Properties | ForEach-Object { @{$_.Name = $_.Value} } | ForEach-Object { $_ } }

                if ($row.PSObject.Properties['compliant']) { $compValue = "$($row.compliant)" }
                if ($row.PSObject.Properties['currentValue']) { $currentVal = "$($row.currentValue)" }
                if ($row.PSObject.Properties['expectedValue']) { $expectedVal = "$($row.expectedValue)" }
                if ($row.PSObject.Properties['checkItem']) { $checkLabel = "$($row.checkItem)" }
                if ($row.PSObject.Properties['name']) { $resName = "$($row.name)" }
                if ($row.PSObject.Properties['resourceGroup']) { $resGroup = "$($row.resourceGroup)" }
                if ($row.PSObject.Properties['subscriptionId']) { $resSub = "$($row.subscriptionId)" }
                if ($row.PSObject.Properties['id']) { $resId = "$($row.id)" }

                # Determine compliance
                $compLower = $compValue.ToLower()
                $finding = "Review required"
                if ($compLower -eq "true" -or $compLower -eq "1") {
                    $finding = "Compliant"
                    $result.compliant++
                } elseif ($compLower -eq "false" -or $compLower -eq "0") {
                    $finding = "Non-compliant"
                    $result.nonCompliant++
                } else {
                    $result.review++
                }

                [void]$detailedResults.Add([PSCustomObject]@{
                    guid           = $q.guid
                    category       = $q.category
                    subcategory    = $q.subcategory
                    severity       = $q.severity
                    checklistItem  = $q.text
                    checkItem      = $checkLabel
                    resourceId     = $resId
                    resourceName   = $resName
                    resourceGroup  = $resGroup
                    subscriptionId = $resSub
                    compliant      = $compValue
                    currentValue   = $currentVal
                    expectedValue  = $expectedVal
                    finding        = $finding
                })
            }

            # Build summary finding
            $parts = @()
            if ($result.compliant -gt 0) { $parts += "$($result.compliant) compliant" }
            if ($result.nonCompliant -gt 0) { $parts += "$($result.nonCompliant) non-compliant" }
            if ($result.review -gt 0) { $parts += "$($result.review) to review" }
            $result.finding = "$($result.rowCount) resource(s): $($parts -join ', ')"
        }
    } catch {
        $result.status = "ERROR"
        $result.error = $_.Exception.Message -replace "`n|`r", " "
        $result.finding = "Query error"
        $failed++
    }

    [void]$results.Add($result)
}

Write-Progress -Activity "Validating queries" -Completed

# --- Summary ---
Write-Host ""
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan
Write-Host "  Total queryable items: $total" -ForegroundColor White
Write-Host "  OK (returned rows):    $success" -ForegroundColor Green
Write-Host "  EMPTY (valid, 0 rows): $empty" -ForegroundColor Yellow
Write-Host "  ERROR (query failed):  $failed" -ForegroundColor Red
Write-Host ""

# --- Category breakdown ---
Write-Host "=== Results by Category ===" -ForegroundColor Cyan
$results | Group-Object -Property category | ForEach-Object {
    $catOk = ($_.Group | Where-Object { $_.status -eq 'OK' }).Count
    $catEmpty = ($_.Group | Where-Object { $_.status -eq 'EMPTY' }).Count
    $catErr = ($_.Group | Where-Object { $_.status -eq 'ERROR' }).Count
    Write-Host "  $($_.Name): OK=$catOk, Empty=$catEmpty, Error=$catErr"
}

# --- Show errors ---
$errors = $results | Where-Object { $_.status -eq 'ERROR' }
if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "=== Failed Queries ===" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "  [$($e.guid)] $($e.text.Substring(0, [Math]::Min(80, $e.text.Length)))" -ForegroundColor Yellow
        Write-Host "    Error: $($e.error.Substring(0, [Math]::Min(200, $e.error.Length)))" -ForegroundColor Red
        Write-Host ""
    }
}

# --- Export summary CSV ---
$results | Select-Object guid, category, subcategory, severity, text, status, rowCount, compliant, nonCompliant, review, finding, error |
    Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
Write-Host "Summary exported to: $OutputFile" -ForegroundColor Cyan

# --- Export detailed CSV (per-resource) ---
$detailedFile = $OutputFile -replace '\.csv$', '_detailed.csv'
$detailedResults | Export-Csv -Path $detailedFile -NoTypeInformation -Encoding UTF8
Write-Host "Detailed results exported to: $detailedFile ($($detailedResults.Count) resource rows)" -ForegroundColor Cyan

# --- Export non-queryable items ---
$nonQueryable = $allQueries | Where-Object { $_.queryable -eq $false }
$nqFile = $OutputFile -replace '\.csv$', '_not_queryable.csv'
$nonQueryable | Select-Object guid, category, subcategory, severity, text, reason |
    Export-Csv -Path $nqFile -NoTypeInformation -Encoding UTF8
Write-Host "Non-queryable items exported to: $nqFile" -ForegroundColor Cyan

# --- Export formatted Excel workbook (if ImportExcel available) ---
$hasImportExcel = $null -ne (Get-Module -ListAvailable -Name ImportExcel)
if ($hasImportExcel) {
    Import-Module ImportExcel -ErrorAction SilentlyContinue
    $xlsxFile = $OutputFile -replace '\.csv$', '.xlsx'
    Remove-Item $xlsxFile -Force -ErrorAction SilentlyContinue

    # Tab 1: Summary
    $results | Select-Object guid, category, subcategory, severity, text, status, rowCount, compliant, nonCompliant, review, finding, error |
        Export-Excel -Path $xlsxFile -WorksheetName "Summary" -AutoSize -AutoFilter -FreezeTopRow

    # Tab 2: Resource Details
    if ($detailedResults.Count -gt 0) {
        $detailedResults | Export-Excel -Path $xlsxFile -WorksheetName "Resource Details" -AutoSize -AutoFilter -FreezeTopRow
    }

    # Tab 3: Manual Review
    if ($nonQueryable.Count -gt 0) {
        $nonQueryable | Select-Object guid, category, subcategory, severity, text, reason |
            Export-Excel -Path $xlsxFile -WorksheetName "Manual Review" -AutoSize -AutoFilter -FreezeTopRow
    }

    Write-Host "Excel workbook exported to: $xlsxFile" -ForegroundColor Cyan
} else {
    Write-Host "Tip: Install ImportExcel module for formatted Excel output: Install-Module ImportExcel -Scope CurrentUser" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done! Output files:" -ForegroundColor Green
Write-Host "  - $OutputFile (summary per checklist item)" -ForegroundColor White
Write-Host "  - $detailedFile ($($detailedResults.Count) per-resource rows)" -ForegroundColor White
Write-Host "  - $nqFile ($($nonQueryable.Count) manual review items)" -ForegroundColor White
if ($hasImportExcel) {
    Write-Host "  - $xlsxFile (formatted Excel with all tabs)" -ForegroundColor White
}
Write-Host ""
Write-Host "To import into review_checklist.xlsm:" -ForegroundColor Cyan
Write-Host "  1. Open review_checklist.xlsm and load the ALZ checklist" -ForegroundColor White
Write-Host "  2. Open $($OutputFile -replace '\.csv$', '.xlsx') side-by-side" -ForegroundColor White
Write-Host "  3. Match items by GUID column to review findings" -ForegroundColor White
