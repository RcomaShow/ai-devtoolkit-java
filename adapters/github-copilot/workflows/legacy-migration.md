---
name: 'Legacy Migration'
description: 'Migrates a legacy JEE+JSF component to Quarkus: reverse-engineers business logic, maps to Clean Architecture layers, writes Flyway migration, implements all layers, and adds tests.'
on:
  issue-comment:
    - created
permissions:
  contents: write
  pull-requests: write
safe-outputs: true
---

# Legacy Migration Workflow

You are migrating a legacy JEE+JSF+PrimeFaces component to a Quarkus 3.x microservice.
Read `.ai-devtoolkit/workflows/legacy-migration.workflow.md` for the full step-by-step procedure.

## Inputs

Extract from the issue or comment:
- **Legacy class**: the class to migrate (e.g. `LegacyNominaBean`, `NominaEjb`)
- **Target module**: the Quarkus service that will receive the new code
- **Docs path**: path to existing technical analysis docs (if any)

## Step 1 — Reverse-Engineer Legacy Logic

Read `skills/legacy-analysis/SKILL.md` and `skills/java-flow-analysis/SKILL.md`.

1. Read all methods of the legacy class.
2. Run: `python scripts/analyze-java.py impact <LegacyClassName> .`
3. Document every business rule, validation, and DB table touched.
4. List all open questions — do not assume behaviour.

If any business rule is ambiguous, add a comment to the issue listing the open questions before continuing.

## Step 2 — Architectural Mapping

Read `skills/domain-driven-design/SKILL.md` and `skills/clean-architecture/SKILL.md`.

Map each legacy class to the new layer:
- JSF backing bean → REST Resource + Application Service
- EJB method → Application Service method
- Legacy DAO → Panache Repository + ACL Translator
- Legacy JPA Entity → Panache Entity + Domain Model

Write an ADR for the bounded context decision.

## Step 3 — Flyway Migration

Read `skills/flyway-oracle/SKILL.md`.
Write Flyway SQL migration for any new or changed columns.
Never drop or rename legacy columns — add new ones alongside.

Commit: `chore(db): add V{n}__migrate_{TABLE} schema`

## Step 4 — Persistence + Service + API Layers

Follow Steps 2-4 of the `feature-implementation` workflow, using the mapping from Step 2 as input.

## Step 5 — Tests

Tests must cover every business rule documented in Step 1.
Each legacy business rule is a test acceptance criterion.

Commit: `test({scope}): add branch coverage for migrated {Entity}`

## Step 6 — Pull Request

Create a PR with:
- Title: `feat({scope}): migrate {LegacyClass} to Quarkus`
- Body: list of migrated business rules, open questions resolved, and any deliberate behaviour changes.
