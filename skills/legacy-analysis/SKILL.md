---
name: legacy-analysis
description: 'Procedure for reverse-engineering legacy JEE+JSF monoliths before migrating to Quarkus microservices. Reference when analysing legacy components, mapping to Clean Architecture layers, and preparing migration plans.'
argument-hint: "Legacy component to analyse — e.g. 'reverse-engineer {LegacyBean}', 'map {LegacyEntity} to domain model'"
user-invocable: false
---

# Legacy Analysis — JEE/JSF Reverse-Engineering Procedure

## Phase 1 — Inventory

Before touching any code, produce an inventory:

```markdown
## Legacy Component Inventory

| Component | Type | Lines | Description |
|-----------|------|-------|-------------|
| {BeanName}Bean.java | JSF Backing Bean | ~400 | Handles {feature} UI logic |
| {ServiceName}EJB.java | Stateless EJB | ~600 | Business logic for {feature} |
| {EntityName}.java | JPA Entity | ~150 | Maps to T_{TABLE} |
| {DaoName}Dao.java | DAO | ~200 | DB access for {feature} |
```

## Phase 2 — Classify Each Component

Map legacy class types to Clean Architecture target layers:

| Legacy Type | Maps to New Layer | Notes |
|-------------|------------------|-------|
| JSF Backing Bean | `api/` REST Resource | Extract business logic to service first |
| Stateless EJB | `service/` Application Service | Keep only orchestration |
| EJB with business rules | `domain/service/` Domain Service | Extract rules to domain |
| JPA Entity (business model) | `domain/model/` Aggregate | Strip `@Entity`, add invariants |
| JPA Entity (persistence) | `data/entity/` Panache Entity | Keep `@Entity`, add ACL |
| DAO | `data/repository/` PanacheRepository | Implement domain port interface |

## Phase 3 — Extract Business Rules

For each EJB/Bean:

1. **List all public methods** — these become domain service operations or REST endpoints
2. **Identify invariants** — conditions that must always be true (move to domain model)
3. **Identify validation** — input checks (move to `api/` Bean Validation)
4. **Identify queries** — DB calls (move to repository port interface)
5. **Identify external calls** — services called (become port interfaces or MCP clients)

```
Legacy method signature: void approveNomination(Long id, String userId)
↓
REST endpoint:  POST /api/v1/nominations/{id}/approvazioni
Service method: nominationService.approve(NominationId id, UserId approvedBy)
Domain method:  nomination.approve(approvedBy)  ← enforces invariant: must be in BOZZA state
```

## Phase 4 — Schema Analysis

For each JPA entity:

1. Query `oracle-official` MCP for the actual table structure
2. Identify columns that map to domain concepts vs audit/technical columns
3. Identify FK relationships — these become inter-aggregate references (by ID only)
4. Identify legacy naming (abbreviated column names) — document in ACL translator

```java
// ACL Translator — maps legacy schema to clean domain model
@ApplicationScoped
public class {Entity}AclTranslator {

    public {Entity} toDomain({Entity}Entity entity) {
        return new {Entity}(
            new {Entity}Id(entity.id),
            new Code(entity.codValue),       // COD_VALUE → Code value object
            new Period(entity.dtInizio, entity.dtFine),  // legacy columns → value object
            {Status}.fromCode(entity.cdStatus)  // CD_STATO → enum
        );
    }

    public {Entity}Entity toEntity({Entity} domain) {
        var entity = new {Entity}Entity();
        entity.id = domain.getId().value();
        entity.codValue = domain.getCode().value();
        entity.dtInizio = domain.getPeriod().from();
        entity.dtFine = domain.getPeriod().to();
        entity.cdStatus = domain.getStatus().code();
        return entity;
    }
}
```

## Phase 5 — Migration Order

Recommended migration sequence (risk-ordered):

1. **Domain model** — pure Java, no framework, easiest to test
2. **Port interfaces** — define contracts before implementing
3. **Data layer** — Panache entities + ACL translators
4. **Domain services** — business logic, testable with Mockito
5. **Application services** — orchestration + `@Transactional`
6. **REST resources** — thin layer, delegates to services
7. **API spec** — formalise with OpenAPI after implementation

## Phase 6 — Divergence Analysis

When the legacy system has multiple versions or modules:

```markdown
## Divergence Report: {FeatureA} vs {FeatureB}

| Behaviour | Version A | Version B | Decision |
|-----------|-----------|-----------|----------|
| {rule} | enforces X | enforces Y | Use X — confirmed with product owner |
| {rule} | not present | enforces Z | Include Z — is a valid invariant |
| {rule} | both same | both same | Trivial — migrate as-is |
```

## Output Template

```markdown
## Legacy Analysis — {ComponentName}

### Inventory
<list of legacy classes involved>

### Business Rules Extracted
1. <rule 1>
2. <rule 2>

### Migration Mapping
| Legacy | New Location |
|--------|-------------|
| {BeanMethod} | {NewClass}.{method} |

### Schema Notes
- T_{TABLE} column {COL}: maps to {DomainConcept}
- FK T_{TABLE}.{FK_COL} → T_{REF}: aggregate reference by ID

### Open Questions
- [ ] <question requiring product owner input>

### Acceptance Criteria (for tdd-validator)
- [ ] <AC 1 in "should_<outcome>_when_<condition>" format>
- [ ] <AC 2>
```
