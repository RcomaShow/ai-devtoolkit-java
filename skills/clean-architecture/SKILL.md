---
name: clean-architecture
description: "Clean Architecture patterns and ADR workflow for Java/Quarkus microservices. Reference when making architectural decisions, enforcing layer boundaries, writing ADRs, or detecting layer violations."
argument-hint: "Arch topic — e.g. 'layer boundary check', 'ADR for DB strategy', 'dependency direction audit'"
user-invocable: false
---

# Clean Architecture — Java/Quarkus Microservices

## Dependency Rule

Dependencies point **inward only**. The domain layer knows nothing of Quarkus, Panache, or REST.

```
┌──────────────────────────────────────────────────────┐
│  api/           REST Resources, DTOs                 │
│   ↓ depends on                                       │
│  service/       Application Services (@Transactional)│
│   ↓ depends on                                       │
│  domain/        Aggregates, Domain Services, Ports   │
│   ↑ implemented by                                   │
│  data/          Panache Repositories, ACL, Entities  │
└──────────────────────────────────────────────────────┘

mapping/ spans api ↔ domain ↔ data (MapStruct mappers)
config/  is infrastructure (CDI producers, Quarkus config)
```

## Layer Rules

| From layer | May import | May NOT import |
|-----------|-----------|----------------|
| `api/` | `service/`, `domain/model`, `domain/exception`, `mapping/` | `data/`, `domain/port` directly |
| `service/` | `domain/`, `mapping/` | `api/`, `data/` directly (only via port interfaces) |
| `domain/` | Java stdlib, own sub-packages | `api/`, `service/`, `data/`, Quarkus, Jakarta |
| `data/` | `domain/port`, `domain/model`, `domain/event`, Jakarta Persistence | `api/`, `service/` |
| `mapping/` | `api/` DTOs, `domain/model`, `data/entity` | Business logic of any layer |

## Port Pattern (Dependency Inversion)

```java
// domain/port/{Entity}Repository.java — interface in domain, no framework
public interface {Entity}Repository {
    Optional<{Entity}> findById({Entity}Id id);
    {Entity} save({Entity} domain);
    List<{Entity}> findAll();
}

// data/repository/{Entity}PanacheRepository.java — implements in data
@ApplicationScoped
public class {Entity}PanacheRepository implements {Entity}Repository {
    // Panache + ACL here
}

// service/{Domain}Service.java — depends on port interface, not Panache
@ApplicationScoped
public class {Domain}Service {
    private final {Entity}Repository {entity}Repository; // port interface
    // CDI resolves to {Entity}PanacheRepository at runtime
}
```

## Layer Violation Checklist

Run this mentally or with ArchUnit before each PR:

- [ ] No import of `jakarta.persistence.*` in `domain/` or `service/`
- [ ] No import of `io.quarkus.*` in `domain/`
- [ ] No `@ApplicationScoped` or CDI annotations in `domain/model/` or `domain/service/`
- [ ] No Panache entity referenced in `service/` (only domain objects)
- [ ] No DTO (API layer) passed directly to a domain service
- [ ] No repository implementation in `domain/port/` (only interfaces)
- [ ] `data/` classes never call `service/` or `api/` classes

## ADR Template

Each architecture decision is recorded in `docs/adr/ADR-NNN-title.md`.

```markdown
# ADR-001: <Title>

## Status
Proposed | Accepted | Deprecated

## Context
<Why this decision is needed>

## Decision
<What was decided>

## Consequences
- <positive consequence>
- <negative consequence / trade-off>

## Alternatives Considered
- <option rejected and why>
```

## ADR Index Convention

```
docs/
  adr/
    ADR-001-repository-port-pattern.md
    ADR-002-flyway-oracle-migration-strategy.md
    ADR-003-mapstruct-for-object-mapping.md
    ADR-004-rfc7807-problem-details.md
    ADR-005-junit5-mockito-no-quarkus-test.md
    ADR-006-ddd-bounded-contexts.md
    README.md  ← ADR index table
```

## Cross-Cutting Concern Placement

| Concern | Belongs in |
|---------|-----------|
| Request validation | `api/` — Bean Validation on DTOs |
| Business rule validation | `domain/service/` or aggregate methods |
| Transaction boundary | `service/` — `@Transactional` on application service methods |
| Error mapping to HTTP | `api/` — `ExceptionMapper` classes |
| Security (RBAC) | `api/` — `@RolesAllowed` on resources |
| Auditing fields | `data/entity/` — `@PrePersist`/`@PreUpdate` listeners |
| Metrics | `service/` — `@Counted`, `@Timed` on service methods |

## Microservice Boundary Rules

Services must NOT share:
- Database tables (each service owns its schema objects)
- Domain model classes (define equivalent value objects per bounded context)
- Panache entities (entities are private to their service)

Services MAY share:
- OpenAPI contract (published as `openapi-<service>.yaml`)
- DTOs for integration events (published as a separate `-api` artifact)

## ArchUnit Validation (optional)

```java
@ExtendWith(MockitoExtension.class)
class ArchitectureTest {

    private static JavaClasses classes = new ClassFileImporter()
        .importPackages("com.company.{domain}");

    @Test
    void domainShouldNotDependOnFrameworks() {
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..quarkus..")
            .orShould().dependOnClassesThat()
            .resideInAPackage("..jakarta.persistence..")
            .check(classes);
    }
}
```
