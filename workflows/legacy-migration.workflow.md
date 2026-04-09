---
name: legacy-migration
description: "End-to-end flow for migrating a legacy JEE+JSF component to Quarkus: reverse-engineer → map layers → implement → test → commit"
triggers: ["migrate", "legacy", "migra", "JSF", "EJB", "backing bean", "reingegnerizza", "porting", "portare su quarkus"]
agents: [legacy-migration, software-architect, backend-engineer, database-engineer, tdd-validator, api-designer]
skills: [legacy-analysis, java-flow-analysis, domain-driven-design, clean-architecture, quarkus-backend, flyway-oracle, java-test-coverage, git-atomic-commit]
estimated-steps: 7
---

# Workflow: Legacy Migration

## Purpose

Use when migrating a legacy JEE+JSF+PrimeFaces component (EJB, backing bean, DAO) to a Quarkus microservice following Clean Architecture. Covers reverse-engineering, domain mapping, DB schema migration, and implementation.

**Do NOT use this workflow when:** the legacy code has already been reverse-engineered and documented — skip Step 1-2 and start from Step 3.

---

## Flow Overview

```
[Legacy Component to Migrate]
      │
      ▼
[Step 1: legacy-migration] ─── reverse-engineer business logic from docs/code
      │
      ▼
[Step 2: software-architect] ─── map to Clean Architecture layers, write ADR
      │
      ▼
[Step 3: database-engineer] ─── Flyway migration for schema changes
      │                          COMMIT: chore(db): add V{n}__migrate_{TABLE} schema
      ▼
[Step 4: backend-engineer] ─── implement persistence layer
      │                        COMMIT: feat(persistence): add {Entity} persistence layer
      ▼
[Step 5: backend-engineer] ─── implement service + domain layer
      │                        COMMIT: feat(service): add {Entity}Service with domain model
      ▼
[Step 6: backend-engineer] ─── implement api layer
      │                        COMMIT: feat(api): add {Entity}Resource replacing {LegacyEndpoint}
      ▼
[Step 7: test-coverage-engineer] ─── branch coverage for all new classes
      │                              COMMIT: test({scope}): add branch coverage for migrated {Entity}
      ▼
[Done — migration complete, legacy can be decommissioned]
```

---

## Steps

### Step 1 — Reverse-Engineer Legacy Logic

**Agent:** `legacy-migration`
**Skill to load first:** `skills/legacy-analysis/SKILL.md`
**Also load:** `skills/java-flow-analysis/SKILL.md` for AST-based call graph analysis

**Input:**
- Legacy class path (e.g. `LegacyNominaBean.java`, `NominaEjb.java`)
- Existing technical docs in `/docs/technical/` (if any)
- Oracle DB schema via `oracle-official` MCP

**Actions:**
1. Run `python scripts/analyze-java.py impact <LegacyClassName> .` to map call graph
2. Read all methods in the backing bean + EJB
3. Document every business rule, validation, and side effect
4. Identify DB tables and columns touched

**Output expected:**
- `legacy-analysis`: business rules derived from code (not assumptions)
- `open-questions`: ambiguities that require product owner clarification
- `db-tables-used`: list of Oracle tables and columns accessed
- `legacy-api-surface`: HTTP endpoints or JSF actions exposed

**Escalate when:** business rules are ambiguous or legacy code has multiple conflicting paths — list open questions and wait for product owner input.

---

### Step 2 — Architectural Mapping

**Agent:** `software-architect`
**Skill to load first:** `skills/domain-driven-design/SKILL.md`
**Takes from Step 1:** `legacy-analysis`, `db-tables-used`

**Actions:**
1. Map legacy classes to Clean Architecture layers:
   - JSF backing bean → REST Resource + Application Service
   - EJB service method → Application Service method or Domain Service
   - Legacy DAO → Panache Repository + ACL Translator
   - Legacy JPA Entity → Panache Entity + Domain Model
2. Define the bounded context and aggregate root
3. Write ADR for any structural pattern decision

**Output expected:**
- `mapping`: legacy class → new layer and class name
- `aggregate-root`: which domain class is the aggregate root
- `adrs`: ADR document for the bounded context decision

---

### Step 3 — Database Schema Migration

**Agent:** `database-engineer`
**Skill to load first:** `skills/flyway-oracle/SKILL.md`
**Takes from Steps 1-2:** `db-tables-used`, `mapping`

**Actions:**
1. Compare legacy Oracle schema against what the new entity needs
2. Write Flyway migration script(s) for any schema additions or changes
3. Never drop or rename legacy columns — add new columns alongside existing ones
4. Use `ADD COLUMN` + `ALTER TABLE` patterns; never `DROP`

**Atomic commit after this step:**
```
chore(db): add V{n}__migrate_{TABLE} schema for {Entity}

Adds columns needed by the new Quarkus entity.
Legacy columns preserved for parallel-run compatibility.
```

---

### Step 4 — Persistence Layer

**Agent:** `backend-engineer`
**Skill to load first:** `skills/quarkus-backend/persistence/SKILL.md`
**Takes from Steps 2-3:** mapping table, Flyway column names

**Implement in this order:**
1. `{Entity}Entity` — columns matching Flyway migration, `@Version` for optimistic lock
2. `{Entity}EntityRepository` — JPQL queries mapping legacy SQL
3. `{Entity}AclTranslator` — translates legacy column conventions (`COD_`, `FLG_`, `DT_`)
4. `{Entity}PanacheRepository` — port implementation

**Atomic commit after this step:**
```
feat(persistence): add {Entity} persistence layer from legacy {LegacyDaoClass}
```

---

### Step 5 — Service + Domain Layer

**Agent:** `backend-engineer`
**Skill to load first:** `skills/quarkus-backend/service/SKILL.md`
**Takes from Steps 1-2:** business rules from `legacy-analysis`, domain model from `mapping`

**Implement in this order:**
1. `{Entity}` domain model — encodes legacy business invariants as methods
2. `{Entity}Id` value object
3. `{Entity}Repository` port interface
4. `{Entity}Mapper` MapStruct interface
5. `{Entity}Service` — each legacy EJB method becomes a service method
6. Domain exceptions replacing legacy `EJBException` wrapping

**Atomic commit after this step:**
```
feat(service): add {Entity}Service migrated from {LegacyEjbClass}
```

---

### Step 6 — API Layer

**Agent:** `backend-engineer`
**Skill to load first:** `skills/quarkus-backend/api/SKILL.md`
**Also consult:** `api-designer` if REST contract needs design review

**Actions:**
1. Map each legacy JSF action or SOAP endpoint to a REST verb
2. Map legacy form fields to `Create{Entity}Request` validation annotations
3. Implement `{Entity}Resource` with equivalent behaviour

**Atomic commit after this step:**
```
feat(api): add {Entity}Resource replacing {LegacyEndpointOrBean}

REST API equivalent of the legacy {LegacyClass} behaviour.
```

---

### Step 7 — Tests

**Agent:** `test-coverage-engineer`
**Skill to load first:** `skills/java-test-coverage/SKILL.md`

**Priority:** test business rules documented in `legacy-analysis` — these are the migration acceptance criteria.

For each legacy business rule:
- Write a test case that verifies the new code produces the same outcome
- Cover edge cases found in legacy code (date boundary, null fields, status transitions)

**Atomic commit after this step:**
```
test({scope}): add branch coverage for migrated {Entity}

Tests derived from legacy business rules in legacy-analysis output.
```

---

## Exit Criteria

- [ ] All business rules from `legacy-analysis` are covered by tests
- [ ] `./mvnw compile` exits 0
- [ ] `./mvnw test` exits 0
- [ ] Flyway migration script applied cleanly
- [ ] No legacy class imported in any new Quarkus class
- [ ] `open-questions` from Step 1 resolved or tracked in backlog
- [ ] PR created or branch pushed

---

## Error Paths

| Failure | Recovery |
|---------|---------|
| Ambiguous legacy business rule | Stop, add to `open-questions`, get product owner sign-off |
| Legacy entity has composite PK | Use `@EmbeddedId` in Panache entity; discuss simplification with architect |
| Flyway migration fails on existing data | Add `DEFAULT` value for new `NOT NULL` columns; test with production data copy |
| Legacy DAO uses native SQL | Convert to JPQL in EntityRepository; use native query as fallback only |
| Parallel run needed (legacy + new coexist) | Add feature flag in `application.properties`; route by flag in Resource |
