# ALZ Checklist Queries

Azure Resource Graph (ARG) queries for validating [Azure Landing Zone checklist](https://github.com/Azure/review-checklists) items. Merges the original 49 queries with 86 additional queries into a single validation file.

## Coverage

| Category | Total | Automated | Coverage |
|---|:---:|:---:|:---:|
| Network Topology and Connectivity | 106 | 73 | 69% |
| Management | 26 | 20 | 77% |
| Security | 32 | 19 | 59% |
| Governance | 16 | 8 | 50% |
| Resource Organization | 22 | 8 | 36% |
| Identity and Access Management | 24 | 7 | 29% |
| Azure Billing and Microsoft Entra ID Tenants | 15 | 0 | 0% |
| Platform Automation and DevOps | 14 | 0 | 0% |
| **Total** | **255** | **135** | **53%** |

## Quick Start

### Run in Azure Cloud Shell (PowerShell)

```powershell
New-Item -ItemType Directory -Path ~/alz-check/queries -Force | Out-Null
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/martinopedal/alz-checklist-queries/main/Validate-Queries.ps1" -OutFile ~/alz-check/Validate-Queries.ps1
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/martinopedal/alz-checklist-queries/main/queries/alz_all_queries.json" -OutFile ~/alz-check/queries/alz_all_queries.json
cd ~/alz-check
.\Validate-Queries.ps1 -QueriesFile .\queries\alz_all_queries.json -ManagementGroup (Get-AzContext).Tenant.Id
```

### Run locally

```powershell
git clone https://github.com/martinopedal/alz-checklist-queries.git
cd alz-checklist-queries
Connect-AzAccount -TenantId "<your-tenant-id>"
.\Validate-Queries.ps1 -QueriesFile .\queries\alz_all_queries.json -ManagementGroup "<tenant-id>"
```

### Scoping options

```powershell
# Tenant Root Group (all subscriptions)
.\Validate-Queries.ps1 -QueriesFile .\queries\alz_all_queries.json -ManagementGroup "<tenant-id>"

# Specific management group
.\Validate-Queries.ps1 -QueriesFile .\queries\alz_all_queries.json -ManagementGroup "my-mg-name"

# Single subscription
.\Validate-Queries.ps1 -QueriesFile .\queries\alz_all_queries.json -SubscriptionId "00000000-0000-0000-0000-000000000000"
```

## Prerequisites

- ✅ PowerShell 7+
- ✅ `Az.ResourceGraph` module (`Install-Module Az.ResourceGraph`)
- ✅ `Az.Accounts` module
- ✅ Logged into Azure (`Connect-AzAccount`)
- ✅ Reader access at the scope you want to query

## Output

The script produces:

- ✅ Console summary with OK / Empty / Error counts per category
- ✅ `validation_results.csv` with full results, row counts, and error messages
- ✅ `validation_results_not_queryable.csv` with items that require manual review

## Interpreting Results

| Status | Meaning |
|---|---|
| **OK** | Query executed and returned rows. Review the `compliant` column. |
| **EMPTY** | Query returned 0 rows. Resource type may not exist in scope. |
| **ERROR** | Query syntax error or permission issue. |

## Query Enhancements

All 135 queries include:

- ✅ Null-safe comparisons using `iff()` and `isnotempty()` to prevent undefined results
- ✅ Context columns: `name`, `resourceGroup`, `subscriptionId`
- ✅ `checkItem` label identifying what is being validated
- ✅ `currentValue` showing the actual configuration found
- ✅ `expectedValue` showing the recommended setting

## Integration with Review Checklists Excel

1. Run `Validate-Queries.ps1` to produce `validation_results.csv`
2. Open the [review checklist Excel workbook](https://github.com/Azure/review-checklists/releases/latest/download/review_checklist.xlsm)
3. Import the ALZ checklist, then match results by GUID to update Comments/Status columns

## License

MIT
