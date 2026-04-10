---
name: quarkus-backend
description: 'Routing hub for all Quarkus 3.x + Java 21 implementation patterns. Read this first, then load the specific sub-skill for your task.'
argument-hint: "What you're building — e.g. 'REST resource', 'Panache repository', 'async Mutiny', 'CDI event'"
user-invocable: false
---

# Quarkus Backend — Skill Router

> **Read this file first.** Find your task in the routing table below, then read only the sub-skill you need. Do not load all sub-skills at once.

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Runtime | Quarkus 3.x |
| Language | Java 21 (records, pattern matching, sealed types) |
| REST | RESTEasy Reactive + SmallRye OpenAPI |
| Persistence | Hibernate ORM with Panache (Repository pattern — NOT Active Record) |
| Mapping | MapStruct 1.6 |
| Validation | Jakarta Bean Validation 3.x |
| Error Format | RFC 7807 (Problem Details) via `ExceptionMapper` |
| Observability | Micrometer + OpenTelemetry — see `skills/quarkus-observability/SKILL.md` |
| Testing | JUnit 5 + Mockito 5 ONLY — see `skills/tdd-workflow/SKILL.md` |

---

## Routing Table

| Task | Sub-Skill |
|------|-----------|
| Writing a REST endpoint (`@GET`, `@POST`, `@PUT`, `@DELETE`) | `skills/quarkus-backend/api/SKILL.md` |
| Request/response DTOs, Bean Validation, `@Valid` | `skills/quarkus-backend/api/SKILL.md` |
| RFC 7807 error handler, `ExceptionMapper` | `skills/quarkus-backend/api/SKILL.md` |
| `@ConfigMapping` groups, config interface | `skills/quarkus-backend/api/SKILL.md` |
| Writing an Application Service, `@Transactional` | `skills/quarkus-backend/service/SKILL.md` |
| MapStruct mapper, DTO ↔ Domain conversion | `skills/quarkus-backend/service/SKILL.md` |
| Package structure, naming conventions | `skills/quarkus-backend/service/SKILL.md` |
| Writing a Panache Entity (`@Entity`, `@Table`) | `skills/quarkus-backend/persistence/SKILL.md` |
| Writing a Panache Repository implementation | `skills/quarkus-backend/persistence/SKILL.md` |
| ACL Translator (domain ↔ entity) | `skills/quarkus-backend/persistence/SKILL.md` |
| Pagination (`Page`, `PagedResponse`) | `skills/quarkus-backend/persistence/SKILL.md` |
| Multi-datasource (Oracle + MSSQL) | `skills/quarkus-backend/persistence/SKILL.md` |
| Async/reactive with Mutiny `Uni`/`Multi` | `skills/quarkus-backend/async/SKILL.md` |
| CDI domain events (`@Observes`, `Event<T>`) | `skills/quarkus-backend/async/SKILL.md` |
| SSE streaming (`@Produces(SERVER_SENT_EVENTS)`) | `skills/quarkus-backend/async/SKILL.md` |

---

## Naming Conventions (Quick Reference)

| Layer | Package | Suffix |
|-------|---------|--------|
| API | `api/` | `Resource`, `Request`, `Response`, `Dto` |
| Service | `service/` | `Service` |
| Domain Model | `domain/model/` | *(none — the noun itself)* |
| Domain Service | `domain/service/` | `DomainService` |
| Port (interface) | `domain/port/` | `Repository` or `Port` |
| Data Entity | `data/entity/` | `Entity` |
| Panache Repo | `data/repository/` | `PanacheRepository` |
| ACL | `data/acl/` | `AclTranslator` |
| Mapper | `mapping/` | `Mapper` |

---

## Anti-patterns (Always Reject)

- `@Inject` on fields — constructor injection only
- `@Entity` in domain layer — entities belong in `data/entity/`
- Business logic in REST resources — delegation only
- `@Transactional` in REST resources — service layer only
- `Optional.get()` without `isPresent()` — use `orElseThrow`
- Returning `null` from repositories — `Optional<T>` or empty list
- Shared database tables between services — each service owns its schema
- Catching and swallowing exceptions — log and rethrow or convert to domain exception
