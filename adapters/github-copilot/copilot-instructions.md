---
description: 'Copilot-first Java 17/21 + Quarkus 3.x workspace. Runtime agent and skill discovery happens from .github/, while .ai-devtoolkit/ remains the reusable source catalog. Use team-lead for premium orchestration and developer for bounded execution on smaller paid models.'
applyTo: '**'
---

# GitHub Copilot Workspace Instructions

## Public Agent Contract

Invoke `@team-lead` for premium orchestration or `@developer` for bounded direct execution from the workspace runtime catalog in `.github/agents/`.
The reusable toolkit lives in `.ai-devtoolkit/`, but the active source of truth for Copilot is the generated workspace catalog. `team-lead` is responsible for selecting workflows, loading skills, delegating to hidden specialists, running review/fix loops, and returning the final outcome. `developer` is the direct path for smaller paid models and should be used when the task is focused enough to avoid sub-agent delegation.

Use `@team-lead` for:
- new features and endpoints
- bug fixes and regressions
- refactors and structural cleanup
- performance investigations and optimizations
- test and coverage work
- legacy migration
- workspace bootstrap and toolkit maintenance

Use `@developer` for:
- focused code edits on a known file set
- smaller bug fixes
- local refactors
- targeted test creation or repair

## Model And Effort Selection

- Premium orchestration models on `team-lead`: `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6`, `Claude Opus 4.6`
- Smaller execution models on `developer`: `GPT-5.4 Mini`, `Claude Haiku 4.5`
- If you need a specific depth, say it explicitly in the prompt: `effort low`, `effort medium`, or `effort high`

## Skill Index

Skills in `.github/skills/` contain the authoritative runtime patterns. Their supporting references, scripts, and templates live beside each skill in the same folder.

| Skill | Covers |
|-------|--------|
| `quarkus-backend` | Routing hub → load first, then use local references for API, service, persistence, and async patterns |
| `quarkus-dev` | Local Quarkus dev lifecycle, readiness checks, and operational guardrails |
| `fetch-api` | Structured HTTP smoke/debug calls for local or remote endpoints |
| `quarkus-logs-analyzer` | Quarkus log extraction and root-cause triage for 5xx or startup failures |
| `postman-collections` | Generate Postman/Newman collections and environments from request catalogs |
| `quarkus-observability` | Logging, Micrometer, OpenTelemetry, SmallRye Health |
| `java-best-practices` | Version-aware Java guidance with local references for Java 17, 21, legacy, and docs/comments |
| `java-test-coverage` | 100% branch coverage with JUnit 5 + Mockito 5 |
| `java-flow-analysis` | AST-based impact, dependency, and XHTML-first layer tracing |
| `repo-memory` | Compact repo-local memory, dependency refresh, and recent-change rehydration |
| `git-atomic-commit` | Conventional commits, pre-commit checklist |
| `clean-architecture` | Layer boundary rules, ADR template |
| `domain-driven-design` | Aggregates, value objects, bounded contexts |
| `legacy-analysis` | Reverse-engineer JEE/JSF flows with evidence, layer mapping, and migration slices |
| `flyway-oracle` | Safe Oracle schema migration patterns |
| `api-design` | OpenAPI 3.1 design and review patterns |
| `workspace-bootstrap` | Bootstrap workspace adapters, inventory, and MCP validation |
| `bootstrap-project` | Phase 2 repo-context coverage, public-surface audit, and readiness checks |

For repo-scoped work, prefer loading the companion repo skill and `<repo>/.github/memory/` before pulling large docs into context.

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
