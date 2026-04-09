---
name: quarkus-backend
description: "Quarkus 3.x + Java 21 implementation patterns for microservices. Reference when writing REST resources, application services, MapStruct mappers, Bean Validation, error handling, and CDI configuration."
argument-hint: "Code pattern needed — e.g. 'REST resource', 'ApplicationService pattern', 'MapStruct mapper'"
user-invocable: false
---

# Quarkus 3.x + Java 21 Backend Patterns

## Tech Stack

| Component | Technology |
|-----------|------------|
| Runtime | Quarkus 3.x |
| Language | Java 21 (records, pattern matching, sealed types) |
| REST | RESTEasy Reactive + SmallRye OpenAPI |
| Persistence | Hibernate ORM with Panache (Repository pattern — NOT active record) |
| Mapping | MapStruct 1.6 |
| Validation | Jakarta Bean Validation 3.x |
| Error Format | RFC 7807 (Problem Details) via Quarkus `ExceptionMapper` |
| Observability | Micrometer + SmallRye Health |
| Testing | **JUnit 5 + Mockito 5 ONLY** — see tdd-workflow skill |

## REST Resource Pattern

```java
@Path("/api/v1/{entities}")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "{Entities}")
public class {Entity}Resource {

    private final {Entity}Service {entity}Service;

    // Constructor injection — never @Inject on field
    public {Entity}Resource({Entity}Service {entity}Service) {
        this.{entity}Service = {entity}Service;
    }

    @POST
    @Operation(summary = "Create a new {entity}")
    @APIResponse(responseCode = "201", description = "{Entity} created")
    @APIResponse(responseCode = "422", description = "Invalid data")
    public Response create(@Valid Create{Entity}Request request, @Context UriInfo uriInfo) {
        var dto = {entity}Service.create(request);
        var location = uriInfo.getAbsolutePathBuilder().path(dto.id().toString()).build();
        return Response.created(location).entity(dto).build();
    }

    @GET
    @Path("/{id}")
    public Response getById(@PathParam("id") Long id) {
        return {entity}Service.findById(id)
            .map(dto -> Response.ok(dto).build())
            .orElse(Response.status(Response.Status.NOT_FOUND).build());
    }

    @GET
    public List<{Entity}Dto> list() {
        return {entity}Service.list();
    }
}
```

## Application Service Pattern

```java
@ApplicationScoped
public class {Entity}Service {

    private final {Entity}Repository {entity}Repository; // domain port interface
    private final {Entity}Mapper mapper;

    public {Entity}Service({Entity}Repository {entity}Repository,
                           {Entity}Mapper mapper) {
        this.{entity}Repository = {entity}Repository;
        this.mapper = mapper;
    }

    @Transactional
    public {Entity}Dto create(Create{Entity}Request request) {
        var domain = mapper.toDomain(request);
        var saved = {entity}Repository.save(domain);
        return mapper.toDto(saved);
    }

    public Optional<{Entity}Dto> findById(Long id) {
        return {entity}Repository.findById(new {Entity}Id(id))
            .map(mapper::toDto);
    }
}
```

## MapStruct Mapper

```java
@Mapper(componentModel = "cdi",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
public interface {Entity}Mapper {

    @Mapping(target = "id", ignore = true)
    {Entity} toDomain(Create{Entity}Request request);

    {Entity}Dto toDto({Entity} domain);

    // Entity mapping happens in the ACL — MapStruct maps DTO <-> Domain only
}
```

## Panache Repository Implementation

```java
@ApplicationScoped
public class {Entity}PanacheRepository
        implements {Entity}Repository {        // domain port interface

    @Inject
    {Entity}EntityRepository entityRepo;       // PanacheRepository<{Entity}Entity, Long>

    @Inject
    {Entity}AclTranslator translator;          // ACL — keeps entity/domain separate

    @Override
    public Optional<{Entity}> findById({Entity}Id id) {
        return entityRepo.findByIdOptional(id.value()).map(translator::toDomain);
    }

    @Override
    public {Entity} save({Entity} domain) {
        var entity = translator.toEntity(domain);
        entityRepo.persist(entity);
        return translator.toDomain(entity);
    }
}

@ApplicationScoped
public class {Entity}EntityRepository implements PanacheRepository<{Entity}Entity, Long> {
    // Panache query methods here
}
```

## Panache Entity (Data Layer Only)

```java
@Entity
@Table(name = "T_{ENTITY}")
public class {Entity}Entity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "{entity}_seq")
    @SequenceGenerator(name = "{entity}_seq", sequenceName = "SEQ_{ENTITY}", allocationSize = 1)
    public Long id;

    @Column(name = "COD_VALUE", nullable = false, length = 20)
    public String codValue;

    @Column(name = "DT_INIZIO", nullable = false)
    public LocalDate dtInizio;

    @Column(name = "DT_FINE", nullable = false)
    public LocalDate dtFine;

    @Version
    public Long version;
}
```

## Bean Validation at API Boundary

```java
// Validation belongs on DTO (API boundary), NOT on domain objects
public record Create{Entity}Request(
    @NotNull @Size(min = 1, max = 50) String code,
    @NotNull LocalDate dateFrom,
    @NotNull LocalDate dateTo,
    @NotNull @DecimalMin("0") BigDecimal amount
) {}
```

## RFC 7807 Error Handler

```java
@Provider
public class DomainExceptionMapper implements ExceptionMapper<DomainException> {

    @Override
    public Response toResponse(DomainException e) {
        var problem = new ProblemDetail(
            URI.create("https://api.{domain}.company/errors/" + e.getErrorCode()),
            e.getMessage(),
            e.getHttpStatus(),
            e.getHttpStatusReason(),
            URI.create(request.getRequestURI())
        );
        return Response.status(e.getHttpStatus())
            .type("application/problem+json")
            .entity(problem)
            .build();
    }
}
```

## ConfigMapping Pattern

```java
// Use @ConfigMapping — never @ConfigProperty for groups of properties
@ConfigMapping(prefix = "{domain}.{service}")
public interface {Service}Config {
    boolean enabled();
    Duration timeout();
    int maxRetries();
}
```

## Health Check Pattern

```java
@Liveness
@ApplicationScoped
public class {Service}HealthCheck implements HealthCheck {
    private final {External}Client client;

    @Override
    public HealthCheckResponse call() {
        try {
            client.ping();
            return HealthCheckResponse.up("{service}-external");
        } catch (Exception e) {
            return HealthCheckResponse.down("{service}-external");
        }
    }
}
```

## Package + Naming Conventions

| Layer | Package | Suffix Convention |
|-------|---------|-------------------|
| API | `api/` | `Resource`, `Request`, `Response`, `Dto` |
| Service | `service/` | `Service` |
| Domain Model | `domain/model/` | No suffix (the noun: `{Entity}`) |
| Domain Service | `domain/service/` | `DomainService` |
| Port | `domain/port/` | Repository or Port — e.g. `{Entity}Repository` |
| Data Entity | `data/entity/` | `Entity` |
| Panache Repo | `data/repository/` | `PanacheRepository` |
| ACL | `data/acl/` | `AclTranslator` |
| Mapper | `mapping/` | `Mapper` |

## Anti-patterns to Reject

- `@Inject` on fields — always use constructor injection
- `@Entity` in domain layer — entities belong in `data/entity/`
- Business logic in REST resources — only delegation + HTTP mapping
- Shared database tables between services — each service owns its tables
- `Optional.get()` without checking — use `orElseThrow` with descriptive message
