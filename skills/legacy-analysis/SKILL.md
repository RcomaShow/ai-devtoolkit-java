---
name: legacy-analysis
description: 'Procedure for reverse-engineering legacy JEE+JSF monoliths before migrating to Quarkus microservices. Includes XHTML-first tracing, layer mapping, and evidence-based business rule extraction.'
argument-hint: "Legacy component to analyse — e.g. 'reverse-engineer {LegacyBean}', 'map {LegacyEntity} to domain model', 'trace {view}.xhtml to every layer'"
user-invocable: false
---

# Legacy Analysis — JEE/JSF Reverse-Engineering Procedure

## Phase 0 — Identify the True Entrypoint

Do not assume the flow starts from the database.

Choose the real entrypoint first:
- JSF/Facelets page: start from the `.xhtml`
- SOAP/JAX-RS endpoint: start from the service contract
- Batch or scheduler: start from the launcher or timer class
- MDB/listener: start from the consumed event or queue

For JSF/Facelets systems, the preferred workflow is now:

```bash
python .github/skills/java-flow-analysis/scripts/analyze-java.py legacy-xhtml <source-root> <view.xhtml>
```

This gives you the first-pass map from view bindings to backing bean, service/EJB, repository/DAO, and entity or external clients.

## Phase 1 — Inventory

Produce an inventory before proposing any migration slice.

```markdown
## Legacy Component Inventory

| Component | Type | Lines | Layer Today | Description |
|-----------|------|-------|-------------|-------------|
| {View}.xhtml | JSF View | ~150 | view | Entry page for {feature} |
| {BeanName}Bean.java | Backing Bean | ~400 | ui-orchestration | Handles actions and view state |
| {ServiceName}EJB.java | Stateless EJB | ~600 | business/application | Business logic for {feature} |
| {DaoName}Dao.java | DAO | ~200 | persistence | DB access for {feature} |
| {EntityName}.java | JPA Entity | ~150 | persistence-model | Maps to T_{TABLE} |
```

## Phase 2 — Build the Vertical Flow

For XHTML-driven features, use both automated and manual steps.

```text
Step 1 — Extract EL bindings from the view
    Examples: #{bean.search}, #{bean.rows}, #{bean.selectedItem.code}

Step 2 — Resolve the backing bean
    Use analyze-java.py legacy-xhtml to map bean names to Java classes.

Step 3 — Review direct Java dependencies
    Run analyze-java.py deps on the resolved bean and downstream classes.

Step 4 — Confirm the full chain
    XHTML -> Backing Bean -> EJB/Service -> DAO/Repository -> Entity/Table/External system
```

Record both:
- vertical edges between layers;
- horizontal edges inside the same layer, because they often expose accidental coupling.

## Phase 3 — Classify Each Component

Map legacy types to target layers:

| Legacy Type | Typical Target | Notes |
|-------------|----------------|-------|
| JSF Backing Bean | `api/` REST resource or request facade | Extract orchestration first, then remove view state concerns |
| Stateless EJB | `service/` application service | Keep transaction and orchestration only |
| EJB with business rules | `domain/service/` | Extract invariants and decisions from framework code |
| DAO | `data/repository/` | Replace raw SQL or legacy ORM access with a port + adapter |
| JPA Entity used as business model | split into `domain/model/` + `data/entity/` | Preserve persistence mapping in data layer only |
| Legacy mapper/translator | `data/acl/` or `api/mapper/` | Depends on source and target responsibility |

## Phase 4 — Extract Business Rules

For each bean, EJB, or service:

1. List public methods and action methods invoked by the UI.
2. Identify state transitions and invariants.
3. Separate input validation from business decisions.
4. Separate queries from commands.
5. Capture external calls, emails, file operations, and side effects.

```text
Legacy method: void approveNomination(Long id, String userId)
↓
REST endpoint:  POST /api/v1/nominations/{id}/approvazioni
Service method: nominationService.approve(NominationId id, UserId approvedBy)
Domain method:  nomination.approve(approvedBy)
Invariant:      only BOZZA nominations can be approved
```

Every extracted rule must point to evidence:
- Java method
- XHTML action or rendered condition
- SQL or schema evidence
- external document or functional spec

## Phase 5 — Schema and Side-Effect Analysis

For each entity or DAO touched by the flow:

1. Query `oracle-official` MCP for the actual table structure.
2. Mark business columns versus technical/audit columns.
3. Identify FK relationships and ownership boundaries.
4. Note stored procedures, triggers, and batch side effects.
5. Document external calls made in the same use case.

```java
@ApplicationScoped
public class {Entity}AclTranslator {

        public {Entity} toDomain({Entity}Entity entity) {
                return new {Entity}(
                        new {Entity}Id(entity.id),
                        new Code(entity.codValue),
                        new Period(entity.dtInizio, entity.dtFine),
                        {Status}.fromCode(entity.cdStatus)
                );
        }
}
```

## Phase 6 — Migration Mapping

Once the current flow is proven, define the target slice.

Recommended migration order:
1. domain model and value objects
2. port interfaces
3. data adapters and ACL translators
4. domain services
5. application services with transaction boundaries
6. REST resources or integration entrypoints
7. OpenAPI contract and consumer alignment

If multiple legacy versions disagree, write a divergence report before coding.

## Output Template

Use the asset template beside this skill and include at least:
- entrypoint file
- resolved beans and unresolved beans
- vertical layer trace
- horizontal dependency hotspots
- business rules with evidence
- schema touchpoints and side effects
- migration mapping and open questions
