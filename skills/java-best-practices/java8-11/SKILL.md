---
name: java-best-practices-java8-11
description: 'Java 8/11 Legacy Foundation Mode. Covers Streams discipline, Optional safety rules, immutability patterns, boilerplate reduction, and migration readiness hints toward Java 17/21.'
argument-hint: "Java 8/11 task — e.g. 'audit Streams usage in NominaDao', 'Optional discipline in legacy service', 'migration readiness for Java 17'"
user-invocable: false
---

# Java 8 / 11 — Legacy Foundation Mode

> **Philosophy:** It works, but it is not modern. Apply discipline to compensate for missing language features.
> Load this after the hub (`java-best-practices/SKILL.md`) confirms Java 8 or 11 as the target.

---

## Streams — Correct Usage

### When to Use Streams

| Use case | Use Streams? |
|----------|-------------|
| Transform a collection (map/filter/reduce) | Yes |
| Find an element | Yes (`findFirst()`) |
| Aggregate (count, sum, group) | Yes |
| Imperative loop with mutation of external state | No — use `for` loop |
| Sequential side effects (logging every item) | No — use `for` loop |
| Complex multi-step logic | No — extract named methods |

### Stream Rules

```java
// Correct — pure transformation pipeline
List<NominaDto> attive = nomine.stream()
    .filter(n -> n.getStato() == Stato.ATTIVA)
    .map(mapper::toDto)
    .collect(Collectors.toList());

// Forbidden — mutation inside forEach
nomine.stream()
    .forEach(n -> {
        n.setStato(Stato.CHIUSA);   // ← mutates stream element
        repository.save(n);          // ← side effect in stream
    });
// Required replacement:
for (Nomina n : nomine) {
    n.setStato(Stato.CHIUSA);
    repository.save(n);
}
```

---

## Optional — Discipline Rules

### When to Use Optional

| Allowed | Forbidden |
|---------|-----------|
| Return type of a method that may not find a value | Field type in a class |
| Return type of a repository `findById` | Method parameter type |
| Chaining `map`/`flatMap` in a pipeline | Serializable DTO field |

### Correct Optional Patterns

```java
// Required — orElseThrow with specific exception
Nomina nomina = repository.findById(id)
    .orElseThrow(() -> new NominaNotFoundException(id));

// Correct — map before consuming
String codice = repository.findById(id)
    .map(Nomina::getCodice)
    .orElse("SCONOSCIUTO");

// Forbidden — Optional.get() without check
Optional<Nomina> opt = repository.findById(id);
return opt.get();  // ← NullPointerException risk
```

---

## Immutability

Java 8/11 has no `record`, so enforce immutability manually:

```java
// Immutable value object pattern (Java 8/11)
public final class CodiceFiscale {
    private final String value;

    public CodiceFiscale(String value) {
        if (value == null || value.length() != 16) {
            throw new IllegalArgumentException("CF non valido: " + value);
        }
        this.value = value;
    }

    public String getValue() { return value; }

    @Override public boolean equals(Object o) { ... }
    @Override public int hashCode() { ... }
    @Override public String toString() { return "CF[" + value + "]"; }
}
```

Rules:
- `final` class
- `private final` fields only
- No setters
- Validate in constructor

---

## Boilerplate Reduction

Java 8/11 is inherently verbose. Compensate without over-abstracting:

| Boilerplate | Mitigation |
|-------------|-----------|
| Null checks | `Objects.requireNonNull(x, "x must not be null")` |
| Default map values | `map.getOrDefault(key, defaultValue)` |
| List creation | `Arrays.asList(a, b, c)` or `new ArrayList<>(List.of(...))` for mutable |
| String joining | `String.join(", ", list)` |
| Primitive streams | `IntStream.range(0, n)` instead of indexed `for` |

---

## SOLID Constraints in Java 8/11

- No `default` method abuse in interfaces (one `default` per interface maximum)
- No functional interface chains so long they become unreadable (extract named methods)
- Lambdas should be < 3 lines; longer lambdas → named method reference

---

## Migration Readiness Hints

Identify these patterns as migration targets to Java 17/21:

| Java 8/11 Pattern | Java 17/21 Replacement |
|-------------------|----------------------|
| Mutable DTO class (getters + setters) | `record` |
| Long `instanceof` + cast chains | Pattern matching `instanceof` |
| `switch` statement | `switch` expression |
| String concatenation for multi-line | Text block `"""..."""` |
| `ThreadLocal` | `ScopedValue` (Java 21) |
| `Thread` + `ExecutorService` for I/O | Virtual Threads (Java 21) |

Mark each pattern with `// MIGRATION-TARGET: Java 17 record` as a comment for tracking.

---

## Anti-Patterns (Java 8/11)

```
✗ Stream with forEach mutating external state
✗ Optional as field type or method parameter
✗ Optional.get() without isPresent()
✗ Mutable "DTO" classes passed across layers
✗ Static utility classes with mutable state
✗ synchronized on arbitrary object monitors
✗ new Thread() for each request
✗ Raw types (List instead of List<T>)
✗ Exception swallowing in catch (empty catch block)
```

---

## Checklist

```
[ ] Streams used only for pure transformation (no mutation inside forEach)
[ ] Optional used only as return type (never as field or parameter)
[ ] Optional.get() never called without isPresent() or map/orElse chain
[ ] Immutable value objects: final class, final fields, no setters
[ ] Objects.requireNonNull for all constructor parameters
[ ] Migration targets annotated with // MIGRATION-TARGET comments
[ ] No ThreadLocal for concurrency state (or at least documented)
[ ] Docs loaded: java-best-practices/docs-and-comments/SKILL.md for public APIs
```
