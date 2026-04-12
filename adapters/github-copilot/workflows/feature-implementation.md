---
name: 'Feature Implementation'
description: 'Implements a new Quarkus backend feature end-to-end: architectural review, persistence layer, service layer, API layer, tests, and code review. Produces one atomic commit per layer.'
on:
  issue-comment:
    - created
permissions:
  contents: write
  pull-requests: write
safe-outputs: true
---

# Feature Implementation Workflow

You are implementing a new backend feature for a Quarkus 3.x + Java 17/21 microservice.
Read `.ai-devtoolkit/workflows/feature-implementation.workflow.md` for the full step-by-step procedure.

## Inputs

Extract from the issue or comment:
- **Entity name**: the domain concept being added (e.g. `Nomina`, `Contratto`)
- **Feature description**: what the feature should do
- **Affected module**: which Quarkus service receives the change

## Step 1 — Architectural Review

Read `skills/clean-architecture/SKILL.md` and `skills/domain-driven-design/SKILL.md`.
Determine which new classes are needed and which layer each belongs to.
Write an ADR if a new structural pattern is introduced.

If the feature crosses two bounded contexts, add a comment asking for clarification before proceeding.

## Step 2 — Persistence Layer

Read `skills/quarkus-backend/references/persistence.md`.
Create in order:
1. `{Entity}Entity` with `@Table`, `@Index`, `@SequenceGenerator`, `@Version`
2. `{Entity}EntityRepository` (Panache) with named JPQL queries
3. `{Entity}AclTranslator` with `toDomain()` and `toEntity()`
4. `{Entity}PanacheRepository` implementing the port

Commit: `feat(persistence): add {Entity} persistence layer`

## Step 3 — Service + Domain Layer

Read `skills/quarkus-backend/references/service.md`.
Create in order:
1. `{Entity}` domain model (no JPA annotations)
2. `{Entity}Repository` port interface
3. `{Entity}Mapper` MapStruct interface (`unmappedTargetPolicy = ReportingPolicy.ERROR`)
4. `{Entity}Service` with `@Transactional` write ops, no annotation on reads
5. Domain exceptions if needed

Commit: `feat(service): add {Entity}Service with domain model and MapStruct mapper`

## Step 4 — API Layer

Read `skills/quarkus-backend/references/api.md`.
Create in order:
1. `Create{Entity}Request` and `Update{Entity}Request` with Bean Validation
2. `{Entity}Dto` response record
3. `{Entity}Resource` with all HTTP verbs and OpenAPI annotations
4. `DomainExceptionMapper` if not present

Commit: `feat(api): add {Entity}Resource CRUD endpoints`

## Step 5 — Tests

Read `skills/java-test-coverage/SKILL.md`.
Write tests for all new classes targeting 100% branch coverage.
For each method: enumerate branches first, then write one `@Test` per branch.

Commit: `test({scope}): add branch coverage for {Entity} feature`

## Step 6 — Code Review

Verify against these non-negotiable rules:
- No `*Entity` class referenced outside `data/` package
- No `@Inject` field injection — constructor only
- No `@Transactional` on resource methods
- All errors use `application/problem+json`
- `unmappedTargetPolicy = ReportingPolicy.ERROR` present on all mappers

Create a pull request with the changes if all checks pass.
