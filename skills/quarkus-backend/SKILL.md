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

## Pagination Pattern

```java
// Request DTO with pagination params
public record List{Entity}Request(
    @QueryParam("page")     @DefaultValue("0")  int page,
    @QueryParam("pageSize") @DefaultValue("20") @Max(100) int pageSize,
    @QueryParam("sortBy")   @DefaultValue("id") String sortBy,
    @QueryParam("sortDir")  @DefaultValue("asc") String sortDir
) {}

// Panache paginated query
@ApplicationScoped
public class {Entity}EntityRepository implements PanacheRepository<{Entity}Entity, Long> {

    public Page<{Entity}Entity> findAll(int page, int size, String sortBy, Sort.Direction dir) {
        return findAll(Sort.by(sortBy, dir))
            .page(Page.of(page, size));
    }
}

// Response wrapper
public record PagedResponse<T>(
    List<T>  content,
    long     totalElements,
    int      totalPages,
    int      currentPage,
    int      pageSize,
    boolean  hasNext,
    boolean  hasPrevious
) {
    public static <T> PagedResponse<T> from(io.quarkus.panache.common.Page<T> panachePage) {
        return new PagedResponse<>(
            panachePage.list(),
            panachePage.count(),
            panachePage.pageCount(),
            panachePage.index(),
            panachePage.size(),
            panachePage.hasNextPage(),
            panachePage.hasPreviousPage()
        );
    }
}
```

## Async / Reactive Pattern (Mutiny)

Use when an operation may take >200ms and blocking is unacceptable:

```java
import io.smallrye.mutiny.Uni;
import io.smallrye.mutiny.Multi;

@Path("/api/v1/{entities}/async")
public class {Entity}AsyncResource {

    @GET
    @Path("/stream")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @SseElementType(MediaType.APPLICATION_JSON)
    public Multi<{Entity}Dto> stream() {
        return {entity}Service.streamAll()
            .map(mapper::toDto);
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createAsync(@Valid Create{Entity}Request request) {
        return {entity}Service.createAsync(request)
            .map(dto -> Response.accepted().entity(dto).build());
    }
}

@ApplicationScoped
public class {Entity}Service {

    @Transactional
    public Uni<{Entity}Dto> createAsync(Create{Entity}Request request) {
        return Uni.createFrom().item(() -> {
            var domain = mapper.toDomain(request);
            var saved  = {entity}Repository.save(domain);
            return mapper.toDto(saved);
        }).runSubscriptionOn(Infrastructure.getDefaultExecutor());
    }
}
```

## Event Publishing (CDI Events)

For domain events within the same service:

```java
// Domain event (record — immutable)
public record {Entity}CreatedEvent(Long id, String code, Instant occurredAt) {
    public static {Entity}CreatedEvent of({Entity} entity) {
        return new {Entity}CreatedEvent(
            entity.id().value(), entity.code(), Instant.now()
        );
    }
}

// Service — fire event after persist
@ApplicationScoped
public class {Entity}Service {

    @Inject Event<{Entity}CreatedEvent> entityCreatedEvent;

    @Transactional
    public {Entity}Dto create(Create{Entity}Request request) {
        var domain = mapper.toDomain(request);
        var saved  = {entity}Repository.save(domain);
        entityCreatedEvent.fire({Entity}CreatedEvent.of(saved));  // synchronous
        return mapper.toDto(saved);
    }
}

// Observer (in same or different bean)
@ApplicationScoped
public class {Entity}AuditListener {

    private static final Logger LOG = Logger.getLogger({Entity}AuditListener.class);

    void onCreated(@Observes {Entity}CreatedEvent event) {
        LOG.infof("Audit: {entity} created id=%d at=%s", event.id(), event.occurredAt());
        // write audit record, notify other subsystem, etc.
    }
}
```

## Structured Logging in Resources

```java
private static final Logger LOG = Logger.getLogger({Entity}Resource.class);

@POST
public Response create(@Valid Create{Entity}Request request, @Context UriInfo uriInfo) {
    LOG.debugf("POST /{entities}: code=%s", request.code());
    var dto = {entity}Service.create(request);
    LOG.infof("{entity} created: id=%d", dto.id());
    var location = uriInfo.getAbsolutePathBuilder().path(dto.id().toString()).build();
    return Response.created(location).entity(dto).build();
}
```

See `skills/quarkus-observability/SKILL.md` for full logging, metrics, and tracing patterns.

## Multi-Datasource Pattern (Oracle + MSSQL)

```java
// Named datasource for MSSQL legacy reads
@ApplicationScoped
@DataSource("mssql")
public class LegacyEntityRepository implements PanacheRepository<LegacyEntity, Long> {
    // queries against MSSQL legacy DB
}

// Default datasource (Oracle) for new domain entities
@ApplicationScoped
public class {Entity}EntityRepository implements PanacheRepository<{Entity}Entity, Long> {
    // queries against Oracle
}
```

```properties
# application.properties
quarkus.datasource.db-kind=oracle
quarkus.datasource.jdbc.url=jdbc:oracle:thin:@${DB_HOST}:${DB_PORT}/${DB_SID}

quarkus.datasource."mssql".db-kind=mssql
quarkus.datasource."mssql".jdbc.url=jdbc:sqlserver://${MSSQL_HOST}:1433;databaseName=${MSSQL_DATABASE};
```

## Anti-patterns to Reject

- `@Inject` on fields — always use constructor injection
- `@Entity` in domain layer — entities belong in `data/entity/`
- Business logic in REST resources — only delegation + HTTP mapping
- Shared database tables between services — each service owns its tables
- `Optional.get()` without checking — use `orElseThrow` with descriptive message
- `@Transactional` in REST resources — belongs only in service layer
- Returning `null` from repository methods — always return `Optional<T>` or empty list
- Catching and swallowing exceptions — log then rethrow, or convert to domain exception
