---
name: feature-implementation
description: "End-to-end flow for implementing a new backend feature: architecture review → persistence → service → API → tests → review → atomic commits"
triggers: ["implement", "add feature", "new endpoint", "create service", "add domain", "nuova funzionalità", "implementa", "aggiungi endpoint"]
agents: [software-architect, backend-engineer, tdd-validator, test-coverage-engineer, code-reviewer]
skills: [clean-architecture, quarkus-backend, java-test-coverage, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Feature Implementation

## Purpose

Use when adding a new backend feature that spans multiple Clean Architecture layers (REST resource + application service + domain + persistence). Produces one atomic commit per layer.

**Do NOT use this workflow when:** the change is a single-class fix or a refactor within one existing class — call the relevant agent directly instead.

---

## Flow Overview

```
[Feature Request]
      │
      ▼
[Step 1: software-architect] ─── classify layers, write ADR if needed
      │
      ▼
[Step 2: backend-engineer] ─── persistence layer
      │                        COMMIT: feat(persistence): add {Entity} persistence layer
      ▼
[Step 3: backend-engineer] ─── service + domain layer
      │                        COMMIT: feat(service): add {Entity}Service with domain model and mapper
      ▼
[Step 4: backend-engineer] ─── api layer
      │                        COMMIT: feat(api): add {Entity}Resource CRUD endpoints
      ▼
[Step 5: test-coverage-engineer] ─── branch coverage for all new classes
      │                              COMMIT: test({scope}): add branch coverage for {Entity} feature
      ▼
[Step 6: code-reviewer] ─── layer boundary audit + quality check
      │
      ▼
[Done — feature ready for PR]
```

---

## Steps

### Step 1 — Architectural Review

**Agent:** `software-architect`
**Skill to load first:** `skills/clean-architecture/SKILL.md`

**Input:**
- Feature description (what it does, which domain)
- Which existing services or layers are impacted
- Whether a new domain aggregate is needed

**Output expected:**
- `architecture-analysis`: which new classes to create and which layer each belongs to
- `adrs`: ADR document if a new structural pattern is introduced
- `impact-map`: existing classes that change signature or behaviour

**Skip condition:** feature touches only one existing service with no new domain aggregate and no new layer boundary decisions.

**Escalate when:** feature crosses two bounded contexts or requires extracting a new microservice — stop and get product owner/architect sign-off before continuing.

---

### Step 2 — Persistence Layer

**Agent:** `backend-engineer`
**Skill to load first:** `skills/quarkus-backend/persistence/SKILL.md`
**Takes from Step 1:** `architecture-analysis` (entity names, relationships, DB column conventions)

**Implement in this order:**
1. `{Entity}Entity` — `@Entity`, `@Table(name="T_{ENTITY}")`, `@Index`, `@SequenceGenerator`, `@Version`
2. `{Entity}EntityRepository` — `PanacheRepository<{Entity}Entity, Long>`, named JPQL queries
3. `{Entity}AclTranslator` — `toDomain()` + `toEntity()`, only class seeing both types
4. `{Entity}PanacheRepository` — implements `{Entity}Repository` port, wraps EntityRepository

**Atomic commit after this step:**
```
feat(persistence): add {Entity} persistence layer

Includes entity, entity repository, ACL translator, and port implementation.
```

---

### Step 3 — Service + Domain Layer

**Agent:** `backend-engineer`
**Skill to load first:** `skills/quarkus-backend/service/SKILL.md`
**Takes from Step 2:** entity class names, repository port name

**Implement in this order:**
1. `{Entity}` domain model (record or class — no JPA annotations)
2. `{Entity}Id` value object wrapping the PK
3. `{Status}` enum if the entity has a state machine
4. `{Entity}Repository` port interface (in `domain/port/`)
5. `{Entity}Mapper` MapStruct interface (`unmappedTargetPolicy = ReportingPolicy.ERROR`)
6. `{Entity}Service` — `@Transactional` on writes, no annotation on reads
7. `{Entity}NotFoundException`, `DomainValidationException` if needed

**Atomic commit after this step:**
```
feat(service): add {Entity}Service with domain model and MapStruct mapper
```

---

### Step 4 — API Layer

**Agent:** `backend-engineer`
**Skill to load first:** `skills/quarkus-backend/api/SKILL.md`
**Takes from Step 3:** service class name, DTO types

**Implement in this order:**
1. `Create{Entity}Request` — `@NotBlank`, `@NotNull`, custom `@ValidDateRange` if date fields present
2. `Update{Entity}Request` — all fields optional (PATCH semantics)
3. `{Entity}Dto` — immutable response record
4. `List{Entity}Request` — `@BeanParam` with `@QueryParam`, `@DefaultValue`
5. `{Entity}Resource` — all 5 HTTP verbs, `@Operation`, `@APIResponse`, `@Tag`
6. `DomainExceptionMapper` + `ConstraintViolationExceptionMapper` if not already present

**Atomic commit after this step:**
```
feat(api): add {Entity}Resource CRUD endpoints with OpenAPI annotations
```

---

### Step 5 — Tests

**Agent:** `test-coverage-engineer`
**Skill to load first:** `skills/java-test-coverage/SKILL.md`
**Takes from Steps 2-4:** all production class paths

**Target: 100% branch coverage on service and domain classes.**

For each layer:
- **ACL Translator:** test every field mapping, null foreign key, enum conversion
- **Service:** test all branches — entity not found, conflict, happy path, date validation
- **REST Resource:** test HTTP status codes, `201 Location` header, `422` on bad input, `404` on missing

**Atomic commit after this step:**
```
test({scope}): add branch coverage for {Entity} feature

Covers all branches in {Entity}Service, {Entity}AclTranslator, and {Entity}Resource.
```

---

### Step 6 — Code Review

**Agent:** `code-reviewer`
**Input:** all files modified in Steps 2-5

**Checklist enforced:**
- [ ] No `{Entity}Entity` referenced outside `data/` package
- [ ] No `@Inject` field injection — constructor only
- [ ] `@Transactional` only on service write methods, never on resource methods
- [ ] All error responses use `application/problem+json` (RFC 7807)
- [ ] MapStruct `unmappedTargetPolicy = ReportingPolicy.ERROR` present
- [ ] Tests cover all branches (no tautology assertions)
- [ ] Log at `DEBUG` for incoming params, `INFO` for business outcomes

**Output:** `review-result` — pass or list of violations to fix.

---

## Exit Criteria

- [ ] `./mvnw compile` exits 0
- [ ] `./mvnw test` exits 0
- [ ] 3+ atomic commits with conventional messages
- [ ] Branch coverage ≥ 100% for new service and domain classes
- [ ] Code review passed (no layer boundary violations)
- [ ] PR created or branch pushed

---

## Error Paths

| Failure | Recovery |
|---------|---------|
| MapStruct compile error — unmapped field | Add `@Mapping(target = "field", ignore = true)` or map the field explicitly |
| Test red — entity not found in service | Verify `{Entity}PanacheRepository` is annotated `@ApplicationScoped` and implements the port |
| Layer boundary violation (entity leaked to API) | Move `{Entity}Entity` usage back to `data/` layer; service returns domain object |
| `@Transactional` on resource method | Move transaction boundary to service method |
| ACL Translator NPE on update | Add `entity.id == null ? new Entity() : entityRepo.getEntityManager().find(...)` |
