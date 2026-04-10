---
description: 'Clean Architecture layer boundary enforcement for all Java source files. Flags domain entity leaks, direct data-layer imports, and business logic in REST resources.'
applyTo: 'src/**/*.java'
---

# Clean Architecture — Layer Boundary Rules

## Allowed Import Directions

```
api/        can import from: service/, domain/ (DTOs only)
service/    can import from: domain/ (models, ports)
domain/     can import from: nothing outside domain/
data/       can import from: domain/ (port interfaces to implement)
```

## What Each Package Contains

| Package | Contains | Forbidden |
|---------|----------|-----------|
| `api/` | `*Resource`, `*Request`, `*Dto`, `*Mapper` (API-side only) | `*Entity`, `@Transactional` |
| `service/` | `*Service`, `*Mapper` (MapStruct) | `*Entity`, Panache imports |
| `domain/` | Domain models, `*Repository` port interfaces, value objects | JPA annotations, Panache |
| `data/` | `*Entity`, `*EntityRepository`, `*PanacheRepository`, `*AclTranslator` | Business logic |

## Instant Red Flags

Any of these is a BLOCKER in code review:

```java
// BLOCKER: Entity returned from resource
@GET public NominaEntity findById(Long id) { ... }

// BLOCKER: Entity parameter in service
public void process(NominaEntity entity) { ... }

// BLOCKER: Panache in domain model
public class Nomina extends PanacheEntity { ... }

// BLOCKER: Transactional in resource
@POST @Transactional public Response create(...) { ... }

// BLOCKER: Field injection
@Inject private NominaRepository repo;

// BLOCKER: String concatenation in Panache query
find("codice = '" + codice + "'");  // SQL injection risk
```

## The ACL Translator Contract

`{Entity}AclTranslator` is the **only** class allowed to see both the domain type and the entity type simultaneously. Everything else receives one or the other, never both.

```java
@ApplicationScoped
public class NominaAclTranslator {
    // The only class with visibility into both worlds
    public Nomina toDomain(NominaEntity entity) { ... }
    public NominaEntity toEntity(Nomina domain) { ... }
}
```
