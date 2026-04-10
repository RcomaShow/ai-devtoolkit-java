---
name: domain-driven-design
description: 'Domain-Driven Design patterns for Java/Quarkus microservices. Reference when designing aggregates, value objects, bounded contexts, domain events, and port interfaces.'
argument-hint: "DDD topic — e.g. 'design aggregate for {domain}', 'identify bounded contexts', 'model domain event {event}'"
user-invocable: false
---

# Domain-Driven Design — Java/Quarkus Patterns

## Strategic Design

### Bounded Context
Each microservice is a **bounded context**. Communication is via REST or events only — no shared tables, no shared domain models.

```
Service A (Bounded Context A)    Service B (Bounded Context B)
├── domain/model/Entity.java      ├── domain/model/Entity.java  ← same name, different meaning
├── domain/port/EntityRepository  ├── domain/port/EntityRepository
└── data/entity/EntityJpaEntity   └── data/entity/EntityJpaEntity
```

### Context Map
```
{ServiceA}  → (Customer/Supplier) → {ServiceB}
             REST contract: openapi-{service-b}.yaml
             ACL in {ServiceA}: data/acl/{ServiceB}AclTranslator
```

## Tactical Design

### Aggregate

An aggregate is a cluster of domain objects that change together. One **Aggregate Root** controls access.

```java
// domain/model/{Aggregate}.java
public class {Aggregate} {
    private final {Aggregate}Id id;
    private {Status} status;
    private final List<{ChildEntity}> children;

    // Constructor enforces invariants
    public {Aggregate}({Aggregate}Id id, /* ... */) {
        Objects.requireNonNull(id, "id must not be null");
        // validate invariants
        this.id = id;
        this.status = {Status}.INITIAL;
        this.children = new ArrayList<>();
    }

    // Domain operations — enforce invariants
    public void activate() {
        if (this.status != {Status}.INITIAL) {
            throw new DomainException("Cannot activate from status: " + this.status);
        }
        this.status = {Status}.ACTIVE;
        // register domain event if needed
    }

    // Getters only — no setters
    public {Aggregate}Id getId() { return id; }
    public {Status} getStatus() { return status; }
}
```

### Value Object

Immutable, identity-free, validated at construction:

```java
// domain/model/{Concept}.java
public record {Concept}(BigDecimal value, String unit) {
    public {Concept} {
        Objects.requireNonNull(value, "value must not be null");
        Objects.requireNonNull(unit, "unit must not be null");
        if (value.compareTo(BigDecimal.ZERO) < 0) {
            throw new DomainException("{Concept} cannot be negative");
        }
        if (!Set.of("UNIT_A", "UNIT_B").contains(unit)) {
            throw new DomainException("Unknown unit: " + unit);
        }
    }
}
```

### Domain Service

Contains business logic that doesn't fit a single aggregate:

```java
// domain/service/{Operation}DomainService.java
@ApplicationScoped
public class {Operation}DomainService {

    private final {Port}Port {port}Port;

    public {Operation}DomainService({Port}Port {port}Port) {
        this.{port}Port = {port}Port;
    }

    public {Result} process({Input} input) {
        // domain logic — no Quarkus, no Panache
        var data = {port}Port.getData(input.getId());
        // apply business rules
        return new {Result}(/* computed value */);
    }
}
```

### Port (Dependency Inversion Interface)

```java
// domain/port/{Entity}Repository.java
// Only Java stdlib types — no framework imports
public interface {Entity}Repository {
    Optional<{Entity}> findById({Entity}Id id);
    {Entity} save({Entity} aggregate);
    List<{Entity}> findAll();
    List<{Entity}> findByPeriod(LocalDate from, LocalDate to);
}
```

### Domain Event

```java
// domain/event/{Something}Happened.java
public record {Something}Happened(
    {Aggregate}Id aggregateId,
    Instant occurredAt,
    /* event payload */
) {}
```

### Entity ID as Value Object

```java
// domain/model/{Entity}Id.java
public record {Entity}Id(Long value) {
    public {Entity}Id {
        Objects.requireNonNull(value, "{Entity}Id must not be null");
    }
}
```

## Ubiquitous Language

Capture domain vocabulary in a glossary. Keep it in `docs/ubiquitous-language.md`.

```markdown
| Term | Definition |
|------|-----------|
| {Term} | {Definition in business terms} |
| {Term} | {Definition in business terms} |
```

## Anti-patterns to Avoid

- **Anaemic Domain Model**: entities as data bags with no behaviour — move logic from services into aggregates
- **Fat Service**: one service does everything — split by aggregate/bounded context
- **Shared kernel without governance**: two services sharing a domain class — use ACL translators instead
- **Leaking persistence in domain**: `@Entity`, `@Column`, or Panache types in `domain/` package

## Aggregate Design Checklist

- [ ] Aggregate root identified — only root has a repository
- [ ] Invariants enforced in constructor and domain methods
- [ ] No setters — mutation via named domain operations
- [ ] Value objects used for concepts with rules (money, date range, code)
- [ ] Foreign aggregates referenced by ID only, never by object reference
- [ ] Domain events emitted for significant state changes
