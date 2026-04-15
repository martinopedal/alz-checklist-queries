# alz-checklist-queries

Azure Landing Zone checklist validation — 135+ Azure Resource Graph queries for automated Landing Zone assessment.

## Purpose

This repository contains KQL queries that validate Azure Landing Zone configurations against Microsoft's ALZ checklist. Each query returns a `compliant` column (boolean) indicating whether the assessed resource meets the checklist requirement.

## Usage

```powershell
# Run all queries against your subscription
./Validate-Queries.ps1
```

## Query Format

Queries are stored as JSON in `queries/` following the standard schema used by [azure-analyzer](https://github.com/martinopedal/azure-analyzer).

## License

[MIT](LICENSE)