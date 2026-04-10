---
name: quarkus-backend-service
description: 'Application Service patterns for Quarkus 3.x: @Transactional, MapStruct mappers, CDI wiring, package conventions. Load this when writing the service layer or mapping code.'
argument-hint: "Service pattern needed — e.g. 'application service', 'MapStruct mapper', 'domain service'"
user-invocable: false
---

# Quarkus Service Layer Patterns

---

## Application Service Pattern

The Application Service orchestrates domain operations: it receives DTO requests, delegates to the domain, and returns DTO responses. It owns the transaction boundary.

```java
@ApplicationScoped
public class {Entity}Service {

    private final {Entity}Repository {entity}Repository; // domain port interface
    private final {Entity}Mapper      mapper;

    // Constructor injection
    public {Entity}Service({Entity}Repository {entity}Repository,
                           {Entity}Mapper mapper) {
        this.{entity}Repository = {entity}Repository;
        this.mapper = mapper;
    }

    // ── Write operations: always @Transactional ───────────────────────────

    @Transactional
    public {Entity}Dto create(Create{Entity}Request request) {
        var domain = mapper.toDomain(request);
        var saved  = {entity}Repository.save(domain);
        return mapper.toDto(saved);
    }

    @Transactional
    public {Entity}Dto update(Long id, Update{Entity}Request request) {
        var entity  = {entity}Repository.findById(new {Entity}Id(id))
            .orElseThrow(() -> new {Entity}NotFoundException(id));
        var updated = entity.applyUpdate(request.code(), request.dateFrom(), request.dateTo());
        var saved   = {entity}Repository.save(updated);
        return mapper.toDto(saved);
    }

    @Transactional
    public void delete(Long id) {
        var entity = {entity}Repository.findById(new {Entity}Id(id))
            .orElseThrow(() -> new {Entity}NotFoundException(id));
        {entity}Repository.delete(entity);
    }

    // ── Read operations: no @Transactional (no write needed) ─────────────

    public Optional<{Entity}Dto> findById(Long id) {
        return {entity}Repository.findById(new {Entity}Id(id))
            .map(mapper::toDto);
    }

    public List<{Entity}Dto> list(List{Entity}Request params) {
        return {entity}Repository.findByFilter(params)
            .stream()
            .map(mapper::toDto)
            .toList();
    }
}
```

---

## Domain Service Pattern

Domain Services contain business logic that spans multiple aggregates or cannot belong to a single entity:

```java
// In domain/service/ — NO framework annotations
public class {Domain}DomainService {

    private final {Entity}Repository {entity}Repository;   // injected by AppService
    private final {Other}Port        {other}Port;

    public {Domain}DomainService({Entity}Repository repo, {Other}Port other) {
        this.{entity}Repository = repo;
        this.{other}Port = other;
    }

    public {Result} calculate({Entity} entity, {OtherData} data) {
        // pure business logic — no I/O, no framework, easily testable
        if (entity.isExpired()) {
            throw new DomainValidationException("Cannot calculate for expired {entity}");
        }
        return {Result}.from(entity, data);
    }
}

// Application Service wires it
@ApplicationScoped
public class {Entity}Service {
    private final {Domain}DomainService domainService;
    // ...
}
```

---

## MapStruct Mapper

```java
@Mapper(
    componentModel = "cdi",
    nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE,
    unmappedTargetPolicy = ReportingPolicy.ERROR    // fail at compile if a target field is missed
)
public interface {Entity}Mapper {

    // DTO → Domain (ignore id — assigned by repository/DB)
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "status", constant = "DRAFT")   // default on create
    {Entity} toDomain(Create{Entity}Request request);

    // Domain → DTO
    {Entity}Dto toDto({Entity} domain);

    // List conversion (generated automatically)
    List<{Entity}Dto> toDtoList(List<{Entity}> domains);

    // Custom conversion method (used by MapStruct implicitly)
    default String statusToString({Status} status) {
        return status == null ? null : status.name();
    }
}
```

**Mapper rules:**
- MapStruct maps `DTO ↔ Domain` only. `Entity ↔ Domain` is the ACL Translator's job.
- `unmappedTargetPolicy = ReportingPolicy.ERROR` — missing mapping causes a **compile error**, not a silent null.
- Never call mapper methods manually in tests — test the mapper via its generated implementation with a `new {Entity}MapperImpl()`.

---

## Exception Hierarchy

```java
// Base — all domain exceptions extend this
public abstract class DomainException extends RuntimeException {
    private final String errorCode;
    private final int    httpStatus;

    protected DomainException(String errorCode, String message, int httpStatus) {
        super(message);
        this.errorCode  = errorCode;
        this.httpStatus = httpStatus;
    }

    public String errorCode()      { return errorCode; }
    public int    httpStatus()     { return httpStatus; }
    public String httpStatusReason() {
        return Response.Status.fromStatusCode(httpStatus).getReasonPhrase();
    }
}

// Concrete exceptions
public class {Entity}NotFoundException extends DomainException {
    public {Entity}NotFoundException(Long id) {
        super("{entity}-not-found",
              "{Entity} with id " + id + " not found",
              404);
    }
}

public class DomainValidationException extends DomainException {
    public DomainValidationException(String detail) {
        super("validation-failed", detail, 422);
    }
}

public class ConflictException extends DomainException {
    public ConflictException(String detail) {
        super("conflict", detail, 409);
    }
}
```

---

## CDI Wiring Rules

```java
// ✓ Correct — constructor injection
@ApplicationScoped
public class {Entity}Service {
    private final {Entity}Repository repo;
    public {Entity}Service({Entity}Repository repo) { this.repo = repo; }
}

// ✗ Wrong — field injection (hides dependencies, makes testing harder)
@ApplicationScoped
public class {Entity}Service {
    @Inject {Entity}Repository repo;   // NEVER
}

// ✓ Qualifier for multiple implementations of the same interface
@Qualifier
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD, ElementType.PARAMETER, ElementType.FIELD})
public @interface Primary {}

@Primary @ApplicationScoped
public class Real{Entity}Repository implements {Entity}Repository { ... }

// Inject by qualifier
public {Entity}Service(@Primary {Entity}Repository repo) { ... }
```

---

## Package + Naming Conventions

```
com.company.{domain}.{service}/
  api/
    {Entity}Resource.java          REST resource
    Create{Entity}Request.java     input DTO (record)
    Update{Entity}Request.java     input DTO (record)
    {Entity}Dto.java               output DTO (record)
    List{Entity}Request.java       query params (record)
  service/
    {Entity}Service.java           application service
  domain/
    model/
      {Entity}.java                domain object (record or class)
      {Entity}Id.java              value object wrapping the PK
      {Status}.java                enum for state machine
    service/
      {Domain}DomainService.java   cross-aggregate business logic
    port/
      {Entity}Repository.java      port interface (implemented in data/)
  data/
    entity/
      {Entity}Entity.java          JPA entity (@Entity)
    repository/
      {Entity}EntityRepository.java  PanacheRepository<{Entity}Entity, Long>
      {Entity}PanacheRepository.java implements {Entity}Repository (port impl)
    acl/
      {Entity}AclTranslator.java   domain ↔ entity conversion
  mapping/
    {Entity}Mapper.java            MapStruct interface (DTO ↔ Domain)
  exception/
    DomainException.java           base
    {Entity}NotFoundException.java
    DomainValidationException.java
```
