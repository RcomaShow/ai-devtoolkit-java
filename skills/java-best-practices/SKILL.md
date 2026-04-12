---
name: java-best-practices
description: 'Version-aware Java best practice hub. Selects the Java profile (8/11, 17, 21), applies global SOLID/DRY/KISS/YAGNI/CLEAN principles, and points to colocated reference docs for implementation and reviews.'
argument-hint: "Version + context — e.g. 'Java 21 Virtual Threads service', 'Java 17 enterprise CRUD', 'Java 8 legacy audit', 'review Javadoc on NominaService'"
user-invocable: true
---

# Java Best Practices — Version Hub

## Step 1 — Select Version Profile

### Input Classification

| Input | Values |
|-------|--------|
| Application type | `legacy` / `enterprise` / `microservice` / `greenfield` |
| Concurrency requirement | `low` / `medium` / `high` |
| Compatibility constraint | Java 8 / 11 / 17 / 21 / none |
| Team maturity | `junior` / `senior` / `mixed` |

### Version Choice Matrix

| Condition | Version | Reference |
|-----------|---------|-----------|
| Legacy enterprise system | Java 8 / 11 | `java-best-practices/references/java8-11.md` |
| Enterprise, long-term support | Java 17 | `java-best-practices/references/java17.md` |
| Microservice, high concurrency | Java 21 | `java-best-practices/references/java21.md` |
| Greenfield / no constraint | Java 17 | `java-best-practices/references/java17.md` |

> **Default when unspecified:** Java 17 for widest compatibility. Escalate to Java 21 only when the runtime target explicitly allows it or its features are required.

## Step 2 — Apply Global Principles (All Versions)

### SOLID

| Principle | Mandatory Rule |
|-----------|---------------|
| S — Single Responsibility | One class = one reason to change. Services split by business operation. |
| O — Open/Closed | Extend via new classes or interface implementations. Never modify existing stable code. |
| L — Liskov Substitution | Subtypes honor the parent contract. No `UnsupportedOperationException` overrides. |
| I — Interface Segregation | Narrow ports — one method per responsibility. No fat interfaces. |
| D — Dependency Inversion | Constructor injection only. Depend on interfaces, never on concrete implementations. |

### CLEAN CODE

- **Names are design**: `createNomina()` not `doAction()`, `isEligibleForTransport()` not `check()`
- **Method size**: one level of abstraction, ideally < 20 lines
- **No magic numbers**: `private static final int MAX_RETRY = 3`
- **Query methods must not mutate**: `findBy*` returns without side effects
- **Zero `null` returns** from domain methods — use `Optional` or throw a domain exception

### DRY

- No duplicated business logic across classes
- Tolerate structural repetition (two similar queries) over premature abstraction
- Three similar code blocks → candidate for extraction; two → leave them

### KISS

- Simpler solution wins, even if slightly more verbose
- No design pattern applied without a clear problem it solves

### YAGNI

- Do not implement features absent from the current requirement
- No `// TODO: add later` scaffolding committed to main

## Step 3 — Anti-Pattern Filter (All Versions)

Reject regardless of Java version:

```
✗ God classes (> 500 lines or > 10 dependencies)
✗ new SomeConcreteClass() in business logic (tight coupling)
✗ Shared mutable state without synchronization
✗ Stream used for imperative side-effects (forEach mutating external state)
✗ Optional.get() without isPresent() check
✗ Business logic in REST resources
✗ @Transactional on resource / controller layer
✗ @Inject on fields (field injection)
✗ Entity classes in API layer or service method signatures
✗ String concatenation in JPQL/SQL queries
✗ Catching Exception or Throwable and silently swallowing
```

## Skill Assets

- `references/java8-11.md`
- `references/java17.md`
- `references/java21.md`
- `references/docs-and-comments.md`
- `references/guardrails.md`
- `assets/code-review.template.md`

## Step 4 — Route to Reference

| Task | Load |
|------|------|
| Write or review Java 21 code | `java-best-practices/references/java21.md` |
| Write or review Java 17 code | `java-best-practices/references/java17.md` |
| Audit or migrate Java 8/11 code | `java-best-practices/references/java8-11.md` |
| Write Javadoc, comments, or README | `java-best-practices/references/docs-and-comments.md` |

Always load `references/docs-and-comments.md` when writing or reviewing public API surfaces, service interfaces, or domain model classes.
