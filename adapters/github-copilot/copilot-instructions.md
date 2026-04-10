---
description: 'Java 21 + Quarkus 3.x microservices workspace. Agents and skills in .ai-devtoolkit/ are the source of truth. Always load the relevant skill before implementing.'
applyTo: '**'
---

# GitHub Copilot Workspace Instructions

## Agent Catalog

Invoke agents from `.ai-devtoolkit/agents/` using `@<agent-name>`:

| Agent | When to invoke |
|-------|---------------|
| `@orchestrator` | Default entry point — describe your task in any language, auto-routes |
| `@backend-engineer` | Quarkus REST resources, services, repositories, mappers |
| `@software-architect` | ADRs, layer design, bounded context decisions |
| `@legacy-migration` | Reverse-engineer and migrate JEE/JSF to Quarkus |
| `@tdd-validator` | Write tests from acceptance criteria (TDD cycle) |
| `@test-coverage-engineer` | Achieve 100% branch coverage on existing classes |
| `@code-reviewer` | SOLID, layer boundary, OWASP, Quarkus best practices review |
| `@database-engineer` | Flyway migrations, Panache entities, Oracle queries |
| `@api-designer` | OpenAPI specs, REST contracts, DTO design |
| `@agent-architect` | Add/update agents, skills, MCPs in the toolkit |

## Skill Index

Skills in `.ai-devtoolkit/skills/` contain the authoritative patterns:

| Skill | Covers |
|-------|--------|
| `quarkus-backend` | Routing hub → load first, then pick sub-skill |
| `quarkus-backend-api` | REST resources, DTOs, Bean Validation, error mapping |
| `quarkus-backend-service` | @Transactional services, MapStruct mappers, CDI |
| `quarkus-backend-persistence` | Panache entities, repositories, ACL, multi-datasource |
| `quarkus-backend-async` | Mutiny Uni/Multi, CDI events, SSE, Kafka |
| `quarkus-observability` | Logging, Micrometer, OpenTelemetry, SmallRye Health |
| `java-test-coverage` | 100% branch coverage with JUnit 5 + Mockito 5 |
| `java-flow-analysis` | AST-based impact and call graph analysis |
| `git-atomic-commit` | Conventional commits, pre-commit checklist |
| `clean-architecture` | Layer boundary rules, ADR template |
| `domain-driven-design` | Aggregates, value objects, bounded contexts |
| `legacy-analysis` | Reverse-engineer JEE/JSF before migration |
| `flyway-oracle` | Safe Oracle schema migration patterns |
| `api-design` | OpenAPI 3.1 design and review patterns |

## Workflow Index

Workflows in `.ai-devtoolkit/workflows/` define multi-agent chains:

| Workflow | When to use |
|---------|------------|
| `feature-implementation` | Full feature: architecture → persistence → service → API → tests |
| `legacy-migration` | Migrate a legacy JEE/JSF component end-to-end |
| `test-coverage` | Achieve 100% branch coverage on an existing class |

## Non-Negotiable Rules

- Never return domain entities from API resources — use DTOs only.
- Never use `@Inject` field injection — constructor injection everywhere.
- Never use `@QuarkusTest` or `@QuarkusIntegrationTest` in unit tests.
- Never mix `@Transactional` and `Uni<T>` directly.
- Every commit follows conventional commit format (see `git-atomic-commit` skill).
