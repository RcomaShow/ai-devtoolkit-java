---
name: java-best-practices-java21
description: 'Java 21 Modern Runtime Mode. Covers Virtual Threads, Structured Concurrency, Records, Sealed Classes, Pattern Matching, switch expressions, and modern concurrency anti-patterns.'
argument-hint: "Java 21 task — e.g. 'design Virtual Thread executor for I/O service', 'model domain with Records and Sealed Classes', 'review concurrency in NominaService'"
user-invocable: false
---

# Java 21 — Modern Runtime Mode

> **Philosophy:** Concurrency-first, immutability-first, simplicity always.
> Load this after the hub (`java-best-practices/SKILL.md`) confirms Java 21 as the target.

---

## Data Modeling

### Records — Value Objects and DTOs

```java
// Immutable DTO — never a mutable class
public record NominaDto(Long id, String codice, LocalDate dataInizio) {}

// Value object in domain layer
public record CodiceFiscale(String value) {
    public CodiceFiscale {
        if (value == null || value.length() != 16) throw new IllegalArgumentException("Invalid CF");
    }
}
```

Rules:
- Use `record` for any class that is purely data (DTOs, value objects, query results)
- Never add mutable state to a record
- Validation in the compact constructor (`public CodiceFiscale { ... }`)

### Sealed Classes — Controlled Polymorphism

```java
// Model a closed domain with sealed + permits
public sealed interface EsitoNomina permits EsitoNomina.Accettata, EsitoNomina.Rifiutata, EsitoNomina.InAttesa {
    record Accettata(Long id, LocalDateTime timestamp) implements EsitoNomina {}
    record Rifiutata(String motivo) implements EsitoNomina {}
    record InAttesa(String riferimento) implements EsitoNomina {}
}
```

Use when:
- A type has a fixed, known set of subtypes
- Pattern matching will exhaustively switch over variants

---

## Control Flow

### Switch Expressions (mandatory over switch statements)

```java
// Old style — forbidden
String label;
switch (stato) {
    case ATTIVA: label = "Attiva"; break;
    case CHIUSA: label = "Chiusa"; break;
    default: label = "Sconosciuto";
}

// Modern style — required
String label = switch (stato) {
    case ATTIVA  -> "Attiva";
    case CHIUSA  -> "Chiusa";
    default      -> "Sconosciuto";
};
```

### Pattern Matching

```java
// instanceof pattern matching
if (esito instanceof EsitoNomina.Rifiutata rifiutata) {
    log.warn("Rifiutata: {}", rifiutata.motivo());
}

// Exhaustive switch with sealed types
String messaggio = switch (esito) {
    case EsitoNomina.Accettata a -> "OK id=" + a.id();
    case EsitoNomina.Rifiutata r -> "KO: " + r.motivo();
    case EsitoNomina.InAttesa i  -> "WAIT: " + i.riferimento();
};
```

---

## Concurrency

### Concurrency Model

| Model | Use case |
|-------|----------|
| Virtual Threads (`Thread.ofVirtual()`) | I/O-bound tasks: HTTP calls, DB queries, file reads |
| `ExecutorService` (virtual) | Parallel fan-out of I/O operations |
| Structured Concurrency (`StructuredTaskScope`) | Multiple subtasks that must all succeed or all fail together |
| Platform Threads | CPU-bound computation only |

### Virtual Threads — Correct Usage

```java
// I/O-bound parallel calls
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    var limiti    = scope.fork(() -> limitiService.calcolaLimiti(nomina));
    var trasporti = scope.fork(() -> trasportoService.cercaTrasporti(nomina));
    scope.join().throwIfFailed();
    return new RisultatoComposito(limiti.get(), trasporti.get());
}
```

Anti-patterns with Virtual Threads:
```
✗ synchronized block inside a virtual thread (pins the carrier thread)
✗ ThreadLocal used as cache in virtual threads (high memory pressure)
✗ CPU-heavy work on virtual threads — use platform threads for computation
✗ Creating a new virtual thread per request without scope management
```

### Scoped Values (replaces ThreadLocal)

```java
// Declare
private static final ScopedValue<String> REQUEST_ID = ScopedValue.newInstance();

// Bind for a scope
ScopedValue.where(REQUEST_ID, requestId).run(() -> service.process(request));

// Read inside the scope
String id = REQUEST_ID.get();
```

---

## Collections

- Use `List.of()`, `Map.of()`, `Set.of()` for immutable collections (default)
- Use `SequencedCollection` / `SequencedMap` when insertion order and first/last access matter
- Prefer `stream()` for transformation pipelines; avoid `stream()` for simple loops

---

## Anti-Patterns (Java 21 Specific)

```
✗ synchronized block on virtual threads (use ReentrantLock instead)
✗ CPU-bound computation on virtual threads
✗ ThreadLocal in virtual thread contexts (use ScopedValue)
✗ Nested streams for complex logic — extract to named methods
✗ Optional as method parameter or field type
✗ switch statement (use switch expression)
✗ Raw types (List instead of List<T>)
```

---

## Checklist

```
[ ] Records used for all DTOs and value objects
[ ] Sealed classes used for closed domain hierarchies
[ ] switch expressions used everywhere (no switch statements)
[ ] Pattern matching used for type checks
[ ] Virtual threads used for all I/O-bound concurrency
[ ] Structured Concurrency used for fan-out (not bare thread pools)
[ ] No synchronized blocks on virtual threads
[ ] No ThreadLocal in virtual thread contexts
[ ] Immutable collections as default (List.of, Map.of)
[ ] Docs loaded: java-best-practices/docs-and-comments/SKILL.md for public APIs
```
