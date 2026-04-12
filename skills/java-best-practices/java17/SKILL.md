---
name: java-best-practices-java17
description: 'Java 17 Stable Enterprise Mode. Covers Records for DTOs, Sealed Classes, switch expressions, text blocks, SOLID enforcement, clean code discipline, and Java 17 anti-patterns.'
argument-hint: "Java 17 task — e.g. 'design enterprise service with Records', 'enforce SOLID on NominaService', 'review Java 17 patterns in legacy module'"
user-invocable: false
---

# Java 17 — Stable Enterprise Mode

> **Philosophy:** Structure, safety, readability. Modern language features with LTS stability.
> Load this after the hub (`java-best-practices/SKILL.md`) confirms Java 17 as the target.

---

## Data Modeling

### Records (Java 16+, available in Java 17)

```java
// DTO — immutable, auto-generated equals/hashCode/toString
public record NominaDto(Long id, String codice, LocalDate dataInizio) {}

// Compact constructor for validation
public record Periodo(LocalDate inizio, LocalDate fine) {
    public Periodo {
        if (fine.isBefore(inizio)) throw new IllegalArgumentException("fine < inizio");
    }
}
```

Rules:
- All DTOs crossing layer boundaries must be records
- No mutable fields in records
- Use compact constructors for invariant enforcement

### Sealed Classes (Java 17)

```java
// Closed hierarchy — compiler enforces exhaustiveness
public sealed interface Risultato<T> permits Risultato.Ok, Risultato.Errore {
    record Ok<T>(T value) implements Risultato<T> {}
    record Errore<T>(String messaggio) implements Risultato<T> {}
}
```

Use when the set of subtypes is known at compile time and must be exhaustive.

---

## Control Flow

### Switch Expressions (Java 14+, required in 17)

```java
// Required style
String descrizione = switch (statoNomina) {
    case BOZZA    -> "Bozza";
    case INVIATA  -> "Inviata al corriere";
    case CHIUSA   -> "Operazione completata";
};
```

### Text Blocks (Java 15+, available in Java 17)

```java
// SQL and JSON strings
String query = """
    SELECT n.ID_NOMINA, n.COD_STATO
    FROM T_NOMINA n
    WHERE n.DT_INIZIO >= :dataInizio
    """;
```

---

## SOLID in Practice (Java 17)

### Single Responsibility — Service Split

```java
// Forbidden — one service doing too much
public class NominaService {
    public NominaDto create(...) { ... }
    public void sendEmail(...) { ... }       // ← wrong layer
    public byte[] exportExcel(...) { ... }   // ← wrong layer
}

// Required — each class has one reason to change
public class NominaService     { public NominaDto create(...) { ... } }
public class NominaNotifier    { public void notify(...) { ... } }
public class NominaExportService { public byte[] export(...) { ... } }
```

### Open/Closed — Interface Extension

```java
// Add behavior without modifying existing code
public interface NominaValidator {
    void validate(Nomina nomina);
}

// New rule → new class, existing validators untouched
public class DataInizioPrecedenteValidator implements NominaValidator {
    public void validate(Nomina nomina) { ... }
}
```

### Dependency Inversion — Constructor Injection Only

```java
// Required
@ApplicationScoped
public class NominaService {
    private final NominaRepository repository;    // interface
    private final NominaMapper mapper;

    NominaService(NominaRepository repository, NominaMapper mapper) {
        this.repository = repository;
        this.mapper = mapper;
    }
}
```

---

## Clean Code Rules (Java 17 Context)

| Rule | Example |
|------|---------|
| Meaningful names | `findNomineScadute()` not `getData()` |
| One level of abstraction per method | Service methods orchestrate; helpers compute |
| Early return over nesting | `if (invalid) throw X;` before the happy path |
| No commented-out code | Delete it; git has history |
| Constants over magic numbers | `private static final long MAX_DAYS = 90L` |

---

## Anti-Patterns (Java 17)

```
✗ Mutable fields in records
✗ Using Optional as a field type or method parameter
✗ instanceof check without pattern matching (use `obj instanceof Type t`)
✗ switch statement (use switch expression)
✗ Non-sealed subtype escaping a sealed hierarchy
✗ Inheritance for code reuse — use composition
✗ Anemic domain model (domain classes with only getters/setters)
✗ God service class (> 5 injected dependencies)
```

---

## Checklist

```
[ ] All cross-layer DTOs are records
[ ] Compact constructors used for invariant validation in records
[ ] switch expressions used (no switch statements)
[ ] Text blocks used for multi-line SQL/JSON strings
[ ] Sealed classes used for closed hierarchies
[ ] Constructor injection in all @ApplicationScoped classes
[ ] No Optional as field type or method parameter
[ ] Services have ≤ 5 injected dependencies
[ ] Docs loaded: java-best-practices/docs-and-comments/SKILL.md for public APIs
```
