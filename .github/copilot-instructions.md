This repository contains Azure Landing Zone checklist queries (KQL/ARG).
Follow KQL best practices and ensure queries are idempotent and well-documented.

## Code change workflow
- **Always validate** after changes
- Ensure KQL queries are syntactically valid before committing

### Validation checklist
| Check | How |
|---|---|
| Query syntax | Validate KQL in Azure Resource Graph Explorer |
| Security Scan | Review for secrets, PII, hardcoded creds |
| Docs | Update README.md if queries change |

## Security rules
- No secrets in code - use environment variables or GitHub Secrets
- SHA-pin all GitHub Actions to commit SHAs (e.g., `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6`)
- Target actions/checkout v6 (Node.js 24 compatible) — always pin by SHA, not tag
- No enforce_admins on branch protection
- CodeQL enabled for code scanning

## GitHub-first principle
Validate changes in GitHub Actions, not locally. Push, trigger workflow, check logs, iterate.