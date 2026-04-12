---
name: java-best-practices-docs-and-comments
description: 'Java documentation and comments discipline. Covers when to write Javadoc, Javadoc format rules, inline comment rules, self-documenting code, and relations to domain model, service API, and REST API documentation.'
argument-hint: "Doc task — e.g. 'write Javadoc for NominaRepository', 'review comments in NominaService', 'add docs to public API surface'"
user-invocable: false
---

# Java — Documentation & Comments

> **Core principle:** Code explains HOW. Comments and docs explain WHY.
> Load this whenever writing or reviewing public APIs, service interfaces, or domain model classes.

---

## When to Write Javadoc

| Element | Javadoc Required? | Notes |
|---------|-------------------|-------|
| Public interface (port/repository) | **Yes — always** | The contract users depend on |
| Public service class (`@ApplicationScoped`) | **Yes — class level** | Document the bounded responsibility |
| Public service methods | **Yes** | Especially non-obvious behavior, exceptions thrown |
| Record (DTO / value object) | **Yes — class level** | Describe the data it represents and its invariants |
| Private / package-private methods | No | Self-documenting name is sufficient |
| `@Override` methods | No | Javadoc is inherited from the interface |
| Test methods | No | The method name `should_X_when_Y` is the documentation |

---

## Javadoc Format Rules

### Interface / Port

```java
/**
 * Port for persisting and retrieving {@link Nomina} aggregates.
 *
 * <p>Implementations must guarantee that {@link #save} is idempotent
 * when called with the same {@link Nomina#id} within a single transaction.
 *
 * @see NominaPanacheRepository
 */
public interface NominaRepository {

    /**
     * Persists or updates the given nomina.
     *
     * @param nomina the aggregate root to persist; must not be {@code null}
     * @return the saved nomina with a populated {@code id}
     * @throws NominaValidationException if the nomina violates domain invariants
     */
    Nomina save(Nomina nomina);

    /**
     * Finds a nomina by its unique identifier.
     *
     * @param id the nomina identifier; must not be {@code null}
     * @return an {@link Optional} containing the nomina, or empty if not found
     */
    Optional<Nomina> findById(Long id);
}
```

### Service Class

```java
/**
 * Application service for the Nomina aggregate.
 *
 * <p>Orchestrates persistence via {@link NominaRepository} and
 * applies domain validation before persisting.
 * All write operations are transactional.
 */
@ApplicationScoped
public class NominaService { ... }
```

### Record / DTO

```java
/**
 * Immutable DTO representing a nomina returned to the API layer.
 *
 * @param id         the unique database identifier
 * @param codice     the business code assigned at creation
 * @param dataInizio the operational start date (inclusive)
 * @param stato      the current lifecycle state
 */
public record NominaDto(Long id, String codice, LocalDate dataInizio, StatoNomina stato) {}
```

---

## Inline Comment Rules

### Write a comment when:

| Situation | Example |
|-----------|---------|
| Non-obvious business rule | `// LIMIT-001: maximum 3 active nominations per carrier` |
| Work-around for known bug/constraint | `// Oracle: ROWNUM filter must be in subquery, not outer WHERE` |
| Migration target annotation | `// MIGRATION-TARGET: Java 17 record — replace once LTS upgraded` |
| Intentional deviation from convention | `// Deliberately not @Transactional: read-only, optimized for latency` |

### Never write a comment that:

```java
// Increments i by 1       ← states what the code already says
i++;

// Calls the repository    ← restates the method call
repository.save(nomina);

// Returns the list of active nominations    ← restates the return
return nomina.stream().filter(n -> n.isActive()).toList();
```

---

## Self-Documenting Code First

Before adding a comment, try renaming:

```java
// Bad — needs a comment to explain
// Check if the nomination can be sent
if (n.getStato() == Stato.BOZZA && n.getDataInizio().isAfter(LocalDate.now())) {
    ...
}

// Good — the code reads like a sentence
if (nomina.isEligibleForSubmission()) {
    ...
}
```

Extract a method named after the intent, not the mechanics.

---

## Relations to Other Layers

### Domain Model ↔ Docs

- Every domain class (`Nomina`, `Trasporto`) must have class-level Javadoc describing the aggregate root and its invariants
- Business rules embedded in the domain (validation, state transitions) must be referenced in the Javadoc: `@throws NominaIllegalStateException if stato is already CHIUSA`

### Service Interface ↔ Docs

- Every method in a service interface documents: inputs (not-null constraints), outputs (Optional or not), checked exceptions
- Transactional behavior must be documented: `<p>This method is transactional. Callers must not wrap in an outer transaction.`

### REST API ↔ Docs

- REST resources do NOT need Javadoc — they are documented by the OpenAPI spec
- Use `@Operation`, `@Parameter`, `@APIResponse` (MicroProfile OpenAPI) on resource methods instead:

```java
@Operation(summary = "Create a new nomina")
@APIResponse(responseCode = "201", description = "Nomina created")
@APIResponse(responseCode = "400", description = "Validation error")
@APIResponse(responseCode = "409", description = "Duplicate codice")
@POST
public Response create(@Valid CreateNominaRequest request) { ... }
```

### OpenAPI ↔ Schema Descriptions

- DTOs / Request classes used in OpenAPI must have `@Schema` on fields if the name is ambiguous:

```java
public record CreateNominaRequest(
    @Schema(description = "Codice univoco nomina (formato: NOM-YYYYMMDD-NNN)", example = "NOM-20260101-001")
    @NotBlank String codice,

    @Schema(description = "Data inizio operativa (ISO 8601)", example = "2026-01-01")
    @NotNull LocalDate dataInizio
) {}
```

---

## Documentation Checklist

```
[ ] Public interfaces have class-level Javadoc and per-method Javadoc
[ ] Service classes have class-level Javadoc (bounded responsibility)
[ ] Records have class-level Javadoc with @param for each component
[ ] Non-obvious business rules documented with inline comment (RULE-ID: text)
[ ] Work-arounds for DB/framework bugs have inline comment explaining why
[ ] Migration targets annotated with // MIGRATION-TARGET comment
[ ] Self-documenting method names preferred over explanatory comments
[ ] REST resources documented with @Operation / @APIResponse (not Javadoc)
[ ] OpenAPI schema fields have @Schema description where name is ambiguous
[ ] @Override methods have no Javadoc (inherited from interface)
[ ] Test methods have no Javadoc (method name is the doc)
```
