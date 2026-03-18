# Copilot Instructions - alz-checklist-queries

## Repository Purpose

Azure Resource Graph (ARG) queries that validate ALZ checklist items. 135 unified queries covering 53% of the ALZ checklist.

## Code Patterns

- ✅ Queries are stored in `queries/alz_all_queries.json` as a JSON array
- ✅ PowerShell script handles validation and reporting
- ✅ Results output to CSV files

## Quality Rules

- ✅ All KQL queries must be valid Azure Resource Graph syntax
- ✅ Use null-safe comparisons (`iff`, `isnotempty`, `tostring`) to prevent undefined results
- ✅ All queries must project: `id`, `name`, `resourceGroup`, `subscriptionId`, `checkItem`, `currentValue`, `expectedValue`, `compliant`
- ✅ Run `Validate-Queries.ps1` before committing new queries
- ✅ Use checkmarks in documentation, no AI language or em dashes
