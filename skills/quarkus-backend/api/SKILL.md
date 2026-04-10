---
name: quarkus-backend-api
description: 'REST Resource patterns for Quarkus 3.x: JAX-RS endpoints, Bean Validation, RFC 7807 error mapping, ConfigMapping. Load this when writing or reviewing the API layer.'
argument-hint: "API pattern needed — e.g. 'POST endpoint', 'validation record', 'error mapper'"
user-invocable: false
---

# Quarkus API Layer Patterns

---

## REST Resource

```java
@Path("/api/v1/{entities}")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "{Entities}", description = "CRUD operations for {Entity}")
public class {Entity}Resource {

    private static final Logger LOG = Logger.getLogger({Entity}Resource.class);

    private final {Entity}Service {entity}Service;

    // Constructor injection — NEVER @Inject on field
    public {Entity}Resource({Entity}Service {entity}Service) {
        this.{entity}Service = {entity}Service;
    }

    @POST
    @Operation(summary = "Create a new {entity}")
    @APIResponse(responseCode = "201", description = "{Entity} created",
        content = @Content(schema = @Schema(implementation = {Entity}Dto.class)))
    @APIResponse(responseCode = "422", description = "Validation failed",
        content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
    public Response create(@Valid Create{Entity}Request request,
                           @Context UriInfo uriInfo) {
        LOG.debugf("POST /{entities}: code=%s", request.code());
        var dto      = {entity}Service.create(request);
        var location = uriInfo.getAbsolutePathBuilder().path(dto.id().toString()).build();
        LOG.infof("{entity} created: id=%d", dto.id());
        return Response.created(location).entity(dto).build();
    }

    @GET
    @Path("/{id}")
    @Operation(summary = "Find {entity} by ID")
    @APIResponse(responseCode = "200", description = "{Entity} found")
    @APIResponse(responseCode = "404", description = "Not found")
    public Response getById(@PathParam("id") Long id) {
        return {entity}Service.findById(id)
            .map(dto -> Response.ok(dto).build())
            .orElse(Response.status(Response.Status.NOT_FOUND).build());
    }

    @GET
    @Operation(summary = "List all {entities}")
    public List<{Entity}Dto> list(
            @BeanParam List{Entity}Request params) {
        return {entity}Service.list(params);
    }

    @PUT
    @Path("/{id}")
    @Operation(summary = "Update {entity}")
    public Response update(@PathParam("id") Long id,
                           @Valid Update{Entity}Request request) {
        var dto = {entity}Service.update(id, request);
        return Response.ok(dto).build();
    }

    @DELETE
    @Path("/{id}")
    @Operation(summary = "Delete {entity}")
    @APIResponse(responseCode = "204", description = "Deleted")
    @APIResponse(responseCode = "404", description = "Not found")
    public Response delete(@PathParam("id") Long id) {
        {entity}Service.delete(id);
        return Response.noContent().build();
    }
}
```

---

## Request / Response DTOs

```java
// Create request — validation at API boundary, NOT on domain objects
public record Create{Entity}Request(
    @NotBlank @Size(min = 1, max = 50)
    String code,

    @NotNull
    LocalDate dateFrom,

    @NotNull
    LocalDate dateTo,

    @NotNull @DecimalMin("0") @Digits(integer = 10, fraction = 2)
    BigDecimal amount
) {}

// Update request — all fields optional (PATCH semantics via @JsonbNillable)
public record Update{Entity}Request(
    @Size(max = 50)
    String code,         // null = no change

    LocalDate dateFrom,
    LocalDate dateTo
) {}

// Response DTO — immutable record
public record {Entity}Dto(
    Long      id,
    String    code,
    LocalDate dateFrom,
    LocalDate dateTo,
    String    status
) {}

// List request with pagination params
public record List{Entity}Request(
    @QueryParam("page")     @DefaultValue("0")   int    page,
    @QueryParam("pageSize") @DefaultValue("20")  @Max(100) int pageSize,
    @QueryParam("sortBy")   @DefaultValue("id")  String sortBy,
    @QueryParam("sortDir")  @DefaultValue("ASC") String sortDir,
    @QueryParam("status")                        String status   // optional filter
) {}
```

---

## Bean Validation — Custom Constraint

```java
// Custom date-range validator
@Constraint(validatedBy = DateRangeValidator.class)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidDateRange {
    String message() default "dateTo must be after dateFrom";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

@ApplicationScoped
public class DateRangeValidator implements ConstraintValidator<ValidDateRange, Create{Entity}Request> {
    @Override
    public boolean isValid(Create{Entity}Request req, ConstraintValidatorContext ctx) {
        if (req.dateFrom() == null || req.dateTo() == null) return true; // @NotNull handles null
        return !req.dateTo().isBefore(req.dateFrom());
    }
}

// Apply on the record
@ValidDateRange
public record Create{Entity}Request(...) {}
```

---

## RFC 7807 Error Handler

```java
// One mapper per exception hierarchy
@Provider
public class DomainExceptionMapper implements ExceptionMapper<DomainException> {

    @Context HttpServerRequest request;

    @Override
    public Response toResponse(DomainException e) {
        var problem = Map.of(
            "type",     "https://api.{domain}.company/errors/" + e.getErrorCode(),
            "title",    e.getHttpStatusReason(),
            "status",   e.getHttpStatus(),
            "detail",   e.getMessage(),
            "instance", request.absoluteURI()
        );
        return Response.status(e.getHttpStatus())
            .type("application/problem+json")
            .entity(problem)
            .build();
    }
}

// Validation failure (Bean Validation)
@Provider
public class ConstraintViolationExceptionMapper
        implements ExceptionMapper<ConstraintViolationException> {

    @Override
    public Response toResponse(ConstraintViolationException e) {
        var errors = e.getConstraintViolations().stream()
            .map(v -> Map.of(
                "field",   v.getPropertyPath().toString(),
                "message", v.getMessage()
            ))
            .toList();

        var problem = Map.of(
            "type",    "https://api.{domain}.company/errors/validation-failed",
            "title",   "Validation Failed",
            "status",  422,
            "errors",  errors
        );
        return Response.status(422)
            .type("application/problem+json")
            .entity(problem)
            .build();
    }
}
```

---

## ConfigMapping Pattern

```java
// Use @ConfigMapping for groups of properties — NEVER individual @ConfigProperty
@ConfigMapping(prefix = "{domain}.{service}")
public interface {Service}Config {
    boolean enabled();
    Duration timeout();
    int maxRetries();
    Retry retry();            // nested interface

    interface Retry {
        int maxAttempts();
        Duration delay();
    }
}

// Inject by interface type (CDI)
@ApplicationScoped
public class {Entity}Service {
    private final {Service}Config config;
    public {Entity}Service({Service}Config config, ...) { this.config = config; }
}
```

```properties
# application.properties
{domain}.{service}.enabled=true
{domain}.{service}.timeout=5s
{domain}.{service}.max-retries=3
{domain}.{service}.retry.max-attempts=3
{domain}.{service}.retry.delay=200ms
```

---

## Rules

- **Never** put `@Transactional` on a resource method — service layer only.
- **Always** annotate POST responses with `@APIResponse(responseCode = "201")`.
- **Always** return `Response.created(location)` with the URI of the new resource.
- **Always** validate at the API boundary with `@Valid` — never re-validate in the service.
- **Never** return domain objects from resource methods — always map to DTOs first.
- Log at `DEBUG` the incoming params, at `INFO` the business outcome.
