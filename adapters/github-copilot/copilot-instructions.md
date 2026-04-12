---
description: 'Copilot-first Java 17/21 + Quarkus 3.x workspace. Runtime agent and skill discovery happens from .github/, while .ai-devtoolkit/ remains the reusable source catalog. Use the single public team-lead agent and let it route internally.'
applyTo: '**'
---

# GitHub Copilot Workspace Instructions

## Public Agent Contract

Invoke only `@team-lead` from the workspace runtime catalog in `.github/agents/`.
The reusable toolkit lives in `.ai-devtoolkit/`, but the active source of truth for Copilot is the generated workspace catalog. `team-lead` is responsible for selecting workflows, loading skills, delegating to hidden specialists, running review/fix loops, and returning the final outcome.

Use `@team-lead` for:
- new features and endpoints
- bug fixes and regressions
- refactors and structural cleanup
- performance investigations and optimizations
- test and coverage work
- legacy migration
- workspace bootstrap and toolkit maintenance

## Skill Index

Skills in `.github/skills/` contain the authoritative runtime patterns. Their supporting references, scripts, and templates live beside each skill in the same folder.

| Skill | Covers |
|-------|--------|
| `quarkus-backend` | Routing hub → load first, then use local references for API, service, persistence, and async patterns |
| `quarkus-observability` | Logging, Micrometer, OpenTelemetry, SmallRye Health |
| `java-best-practices` | Version-aware Java guidance with local references for Java 17, 21, legacy, and docs/comments |
| `java-test-coverage` | 100% branch coverage with JUnit 5 + Mockito 5 |
| `java-flow-analysis` | AST-based impact and call graph analysis |
| `git-atomic-commit` | Conventional commits, pre-commit checklist |
| `clean-architecture` | Layer boundary rules, ADR template |
| `domain-driven-design` | Aggregates, value objects, bounded contexts |
| `legacy-analysis` | Reverse-engineer JEE/JSF before migration |
| `flyway-oracle` | Safe Oracle schema migration patterns |
| `api-design` | OpenAPI 3.1 design and review patterns |
| `workspace-bootstrap` | Bootstrap workspace adapters, inventory, and MCP validation |
| `bootstrap-project` | Phase 2 repo-context coverage, public-surface audit, and readiness checks |

## Workflow Index

Workflows in `.ai-devtoolkit/workflows/` define the internal execution engine used by `team-lead`:

| Workflow | When to use |
|---------|------------|
| `feature-implementation` | Full feature: analyze → design → implement → review → fix |
| `bugfix` | Diagnose a defect, isolate the root cause, fix it, and review regression risk |
| `refactor` | Restructure code safely while preserving behavior and layer boundaries |
| `optimization` | Improve latency, throughput, query cost, or allocation hotspots |
| `legacy-migration` | Migrate a legacy JEE/JSF component end-to-end |
| `test-coverage` | Achieve 100% branch coverage on an existing class or failing area |

## Non-Negotiable Rules

- Never return domain entities from API resources — use DTOs only.
- Never use `@Inject` field injection — constructor injection everywhere.
- Never use `@QuarkusTest` or `@QuarkusIntegrationTest` in unit tests.
- Never mix `@Transactional` and `Uni<T>` directly.
- Every commit follows conventional commit format (see `git-atomic-commit` skill).
- Never keep secrets inline in `.vscode/mcp.json` — use `${env:...}` references only.
