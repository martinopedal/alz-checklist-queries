# AI Agent Instructions

## Repository Purpose

Azure Resource Graph queries for validating ALZ checklist items. Merges the original 49 queries with 86 additional queries into a unified validation file with 135 automated checks.

## Repository Structure

- ✅ `Validate-Queries.ps1` - Runs all queries and reports results
- ✅ `queries/alz_all_queries.json` - Unified query file (135 queryable, 120 manual review)

## Code Quality

- ✅ All queries must be valid KQL / Azure Resource Graph syntax
- ✅ Queries must use null-safe comparisons (`iff`, `isnotempty`)
- ✅ Queries must project context columns: `name`, `resourceGroup`, `subscriptionId`, `checkItem`, `currentValue`, `expectedValue`, `compliant`
- ✅ Run `Validate-Queries.ps1` before committing
- ✅ Only use checkmarks in documentation lists, no AI language or em dashes
