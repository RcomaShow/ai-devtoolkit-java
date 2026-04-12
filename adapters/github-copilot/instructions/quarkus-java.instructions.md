---
description: 'Quarkus 3.x + Java 17/21 coding standards. Applied to all Java source files (excluding tests). Enforces Clean Architecture layer rules, CDI patterns, and RESTEasy Reactive conventions.'
applyTo: 'src/main/java/**/*.java'
---

# Quarkus Java — Coding Standards

## Layer Rules (Clean Architecture)

```
api/       → REST Resources, DTOs, Exception Mappers
service/   → Application Services, Domain Services
domain/    → Domain Models, Value Objects, Port Interfaces
data/      → Panache Entities, ACL Translators, Repository Impls
```

- `data/` types never appear outside `data/`.
- `domain/` types never import from `data/` or `api/`.
- Services depend on port interfaces, not Panache implementations.

## CDI — Constructor Injection Only

```java
// CORRECT
@ApplicationScoped
public class NominaService {
    private final NominaRepository repository;
    private final NominaMapper mapper;

    NominaService(NominaRepository repository, NominaMapper mapper) {
        this.repository = repository;
        this.mapper = mapper;
    }
}

// WRONG — never use field injection
@Inject private NominaRepository repository;
```

## REST Resources

```java
@Path("/api/v1/nominas")
@Tag(name = "Nominas")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class NominaResource {

    // POST → 201 Created with Location header
    @POST
    @ResponseStatus(201)
    public Response create(@Valid CreateNominaRequest request) { ... }

    // PUT → 200 OK with updated resource
    // DELETE → 204 No Content
    // GET single → 200 or 404
    // GET list → 200 with PagedResult
}
```

- `@Transactional` is NEVER on resource methods — only on service methods.
- All error responses use `application/problem+json` (RFC 7807).
- All input at the API boundary must be annotated `@Valid`.

## MapStruct Mappers

```java
@Mapper(componentModel = MappingConstants.ComponentModel.CDI,
        unmappedTargetPolicy = ReportingPolicy.ERROR)
public interface NominaMapper {
    NominaDto toDto(Nomina domain);
    Nomina toDomain(CreateNominaRequest request);
}
```

- `unmappedTargetPolicy = ReportingPolicy.ERROR` is mandatory — compilation fails on unmapped fields.
- Mappers are interfaces, not abstract classes.

## Application Services

```java
@ApplicationScoped
public class NominaService {
    @Transactional  // write operations only
    public NominaDto create(CreateNominaRequest request) { ... }

    // NO @Transactional on read operations
    public NominaDto findById(Long id) { ... }
}
```

## Naming Conventions

| Concept | Pattern | Example |
|---------|---------|---------|
| REST Resource | `{Entity}Resource` | `NominaResource` |
| Application Service | `{Entity}Service` | `NominaService` |
| Domain Model | `{Entity}` | `Nomina` |
| Panache Entity | `{Entity}Entity` | `NominaEntity` |
| Port Interface | `{Entity}Repository` | `NominaRepository` |
| Port Impl | `{Entity}PanacheRepository` | `NominaPanacheRepository` |
| ACL Translator | `{Entity}AclTranslator` | `NominaAclTranslator` |
| MapStruct Mapper | `{Entity}Mapper` | `NominaMapper` |
| Request DTO | `Create{Entity}Request` / `Update{Entity}Request` | `CreateNominaRequest` |
| Response DTO | `{Entity}Dto` | `NominaDto` |

## Logging

```java
private static final Logger LOG = Logger.getLogger(NominaService.class);

LOG.debugf("Creating nomina for codice=%s", request.codice());  // params
LOG.infof("Nomina created successfully, id=%d", nomina.id());   // outcomes
LOG.warnf("Conflict: codice=%s already exists", request.codice()); // expected errors
LOG.errorf(e, "Unexpected error creating nomina");              // unexpected
```

- Never log passwords, tokens, PII, or full request bodies.
