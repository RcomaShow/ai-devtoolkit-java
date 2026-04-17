---
description: 'Copilot-first Java 17/21 + Quarkus 3.x workspace. Runtime agent and skill discovery happens from .github/, while .ai-devtoolkit/ remains the reusable source catalog. Use team-lead for premium orchestration and developer for focused bounded development with a fixed 3-phase flow.'
applyTo: '**'
---

# GitHub Copilot Workspace Instructions

## Public Agent Contract

Invoke `@team-lead` for premium orchestration or `@developer` for focused bounded development from the workspace runtime catalog in `.github/agents/`.
The reusable toolkit lives in `.ai-devtoolkit/`, but the active source of truth for Copilot is the generated workspace catalog. `team-lead` runs a fixed 4-phase protocol: (1) Context & Classification via `context-optimizer`, (2) Planning & Routing via `orchestrator` which loads the workflow file, (3) Dynamic Execution via task-specific specialists including verification, (4) Review Loop via `code-reviewer` with max 2 iterations and blocker triage. `developer` runs a fixed 3-phase protocol: (1) Plan via `context-optimizer` and an explicit local plan, (2) Implement with bounded helper delegation and focused verification, (3) Review with mandatory self-review and re-entry to implementation when needed.

Use `@team-lead` for:
- new features and endpoints
- bug fixes and regressions
- refactors and structural cleanup
- performance investigations and optimizations
- test and coverage work
- legacy migration
- legacy vs new gap analysis
- workspace bootstrap and toolkit maintenance

Use `@developer` for:
- focused feature implementation with clear bounded scope
- focused bug fixes with verification
- local refactors with context awareness
- test creation on existing code
- bounded implementation tasks that do not cross architectural boundaries

## Model And Effort Selection

- `team-lead` uses 4 premium models: `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6`, `Claude Opus 4.6`
- `developer` intentionally does not hardcode a `model:` alias because smaller-model names vary by tenant; use `developer` for focused bounded work and choose your approved model in the picker when available
- Internal specialists use 3 models: `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6`
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
| `quarkus-infinispan-hotrod-protostream` | Remote Infinispan/Hot Rod cache design, ProtoStream schemas, normalized keys, TTL, invalidation, and migration away from JSON payload envelopes |
| `java-best-practices` | Version-aware Java guidance with local references for Java 17, 21, legacy, and docs/comments |
| `java-test-coverage` | 100% branch coverage with JUnit 5 + Mockito 5 |
| `java-flow-analysis` | AST-based impact, dependency, XHTML include/composite tracing, and XML-aware XHTML-to-DB graph output |
| `legacy-ddl-conversion` | Oracle schema extraction, numeric profiling, and reviewed Oracle-to-T-SQL conversion workflow |
| `repo-memory` | Compact repo-local memory, dependency refresh, and recent-change rehydration |
| `git-atomic-commit` | Conventional commits, pre-commit checklist |
| `clean-architecture` | Layer boundary rules, ADR template |
| `domain-driven-design` | Aggregates, value objects, bounded contexts |
| `legacy-analysis` | Reverse-engineer JEE/JSF flows with evidence, layer mapping, and migration slices |
| `jsf-quarkus-port-alignment` | Parity-first porting of JSF/EJB legacy workflows to Quarkus, with explicit gap ledgers that separate internal parity work from external TODOs |
| `flyway-oracle` | Safe Oracle schema migration patterns |
| `api-design` | OpenAPI 3.1 design and review patterns |
| `tdd-workflow` | TDD red-green-refactor with JUnit 5 + Mockito 5, no @QuarkusTest in unit tests |
| `agent-scaffolding` | Agent catalog audit, frontmatter validation, companion-skill and repo-memory coverage |
| `toolkit-health` | Systematic self-audit: source↔runtime drift, orphaned assets, broken refs, skill gaps |
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
| `legacy-gap-analysis` | Produce an evidence-based legacy-vs-new gap ledger before implementation or parity closure |
| `legacy-ddl-conversion` | Recover Oracle legacy DDL, profile numeric columns, and convert schema toward T-SQL |
| `legacy-migration` | Migrate a legacy JEE/JSF component end-to-end |
| `test-coverage` | Achieve 100% branch coverage on an existing class or failing area |

## Non-Negotiable Rules

- Never return domain entities from API resources — use DTOs only.
- Never use `@Inject` field injection — constructor injection everywhere.
- Never use `@QuarkusTest` or `@QuarkusIntegrationTest` in unit tests.
- Never mix `@Transactional` and `Uni<T>` directly.
- Every commit follows conventional commit format (see `git-atomic-commit` skill).
- Never keep secrets inline in `.vscode/mcp.json` — use `${env:...}` references only.
