---
name: postman-collections
description: 'Create and maintain Postman collections and Newman-ready request catalogs for local Quarkus smoke tests, regression checks, and remote-vs-local comparisons.'
argument-hint: "Collection scope — e.g. 'create smoke collection for /nomina', 'generate collection from request catalog', 'prepare local-vs-remote regression suite'"
user-invocable: false
---

# Postman Collections

## When To Use
- When a feature needs repeatable API smoke coverage beyond a single curl call.
- When a team wants Newman-ready regression collections.
- When local and remote behaviors must be compared with the same request catalog.
- When API validation, auth/header checks, and business-smoke scenarios need structured coverage.

## Skill Assets

- [Collection generator](./scripts/new-postman-collection.mjs)
- [Guardrails](./references/guardrails.md)
- [Request-catalog template](./assets/request-catalog.template.json)
- [Environment template](./assets/postman-environment.template.json)

## Standard Procedure

1. Define the request catalog first.
2. Generate the collection from the catalog instead of hand-editing a large JSON file from scratch.
3. Keep local variables, auth tokens, and transaction IDs parameterized.
4. Prefer smoke-safe assertions by default; make data-dependent checks opt-in.

## Example

```powershell
node .github/skills/postman-collections/scripts/new-postman-collection.mjs \
  --name "Nomina Smoke" \
  --output .\tests\component\Nomina-Smoke.postman_collection.json \
  --requests .github/skills/postman-collections/assets/request-catalog.template.json \
  --base-url http://localhost:8080 \
  --root-path /nomina-trasporto
```

## Design Targets

- Variable-driven base URL and auth headers.
- Standardized request headers for JSON APIs.
- Optional transaction ID generation.
- Newman-ready structure with deterministic expected status assertions.
- Easy diffability in Git.