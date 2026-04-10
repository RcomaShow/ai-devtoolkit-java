---
name: java-flow-analysis
description: 'AST-based procedure for analyzing execution flows, dependency chains, and change impact in Java codebases. Covers both legacy (JEE/JSF/EJB) and Quarkus microservices. Use before any cross-layer change or legacy migration.'
argument-hint: "Analysis type — e.g. 'impact of changing {Entity}Repository', 'trace flow of create{Entity} use case', 'legacy EJB dependency graph'"
user-invocable: false
---

# Java Flow Analysis — AST · Dependency · Impact

> **When to use this skill:**
> - Before modifying a class used by many others (impact analysis)
> - When tracing a business operation end-to-end (flow tracing)
> - During legacy reverse-engineering (call graph of EJBs/DAOs)
> - When identifying what breaks if an interface changes

---

## Key Concepts

| Term | Meaning |
|------|---------|
| **Call graph** | Directed graph: node = method, edge = calls |
| **Dependency graph** | Directed graph: node = class, edge = depends on (imports, field, parameter type) |
| **Impact set** | All classes that must be reviewed or retested when class X changes |
| **Fan-in** | Number of callers of a method — high fan-in = high impact when changed |
| **Fan-out** | Number of dependencies of a class — high fan-out = complex, hard to test |
| **Leaf method** | A method that calls no other domain methods — easiest to test in isolation |
| **Entry point** | REST Resource method, MDB listener, Scheduled job — where flows start |
| **ACL boundary** | Anti-Corruption Layer between legacy/external data model and domain model |

---

## Patterns

### 1 — Static Impact Analysis (grep-based, no tooling required)

Use when you need to find callers quickly without installing tree-sitter.

```bash
# Step 1: Find all direct callers of a class
grep -rn "{ClassName}" src/ --include="*.java" | grep -v "test/"

# Step 2: Find all direct callers of a specific method
grep -rn "\.{methodName}(" src/ --include="*.java"

# Step 3: Find all implementations of an interface (ports)
grep -rn "implements {InterfaceName}" src/ --include="*.java"

# Step 4: Find all injections of a type (CDI, Spring, field injection)
grep -rn "@Inject\|@Autowired" src/ --include="*.java" -A1 | grep "{ClassName}"

# Step 5: Find all usages in test code
grep -rn "{ClassName}" src/test --include="*.java"
```

**Impact matrix output** — fill after grep:

```markdown
## Impact Matrix — Changing {ClassName}

| Impacted Class | File | Impact Type | Action Needed |
|---------------|------|-------------|---------------|
| {CallerA} | service/{CallerA}.java | direct caller | retest |
| {CallerB} | api/{CallerB}Resource.java | indirect (via service) | review signature |
| {CallerC}Test | test/.../{CallerA}Test.java | test — mock of this class | update mock |
```

### 2 — AST-Based Analysis (tree-sitter Python script)

For large codebases (100+ files), use the Python script:

```bash
# Install dependencies
pip install tree-sitter tree-sitter-language-pack

# List all methods in a class with branch count
python .ai-devtoolkit/scripts/analyze-java.py methods src/main/java/com/company/{domain}/service/{Entity}Service.java

# Find all callers of a method across a module
python .ai-devtoolkit/scripts/analyze-java.py callers src/main/java {Entity}Service.create

# Find all classes that reference {ClassName} (full impact set)
python .ai-devtoolkit/scripts/analyze-java.py impact src/main/java {Entity}Repository

# Generate a test coverage matrix (branches per method)
python .ai-devtoolkit/scripts/analyze-java.py test-matrix src/main/java/com/company/{domain}/service/{Entity}Service.java
```

### 3 — Quarkus Flow Trace (top-down)

Procedure for tracing a complete business operation:

```
Step 1 — Identify the REST entry point
  Read: api/{Entity}Resource.java
  Find: method name that handles the use case (e.g. POST /create)
  Note: request type, validation annotations

Step 2 — Follow the service call
  Read: service/{Entity}Service.java (or DomainService)
  Find: business logic, conditional branches, calls to repositories/ports
  Note: @Transactional boundary

Step 3 — Follow each port call
  Read: domain/port/{Entity}Repository.java (interface)
  Find: implementation in data/repository/{Entity}PanacheRepository.java
  Note: database operations, ACL usage

Step 4 — Follow the ACL
  Read: data/acl/{Entity}AclTranslator.java
  Note: entity fields mapped, format conversions, null handling

Step 5 — Build the flow diagram

  POST /api/v1/{entities}
       │
       ▼ Create{Entity}Request (Bean Validation)
  {Entity}Resource.create()
       │
       ▼ mapper.toDomain(request) → {Entity}
  {Entity}Service.create()   [@Transactional]
       │
       ├─▶ {Entity}Repository.save(domain)       [port interface]
       │         │
       │         ▼  ACL: {Entity}AclTranslator.toEntity()
       │    {Entity}PanacheRepository.save()
       │         │
       │         ▼  Panache: persist({Entity}Entity)
       │    Oracle DB: INSERT INTO T_{ENTITY}
       │
       └─▶ mapper.toDto(saved) → {Entity}Dto
       │
       ▼
  Response 201 Created + Location header
```

Step 6 — Identify cross-cutting concerns in the flow:
```
[ ] Where is the transaction boundary? (exactly one @Transactional, in service layer)
[ ] Where is validation? (API boundary only, not domain)
[ ] Where is error mapping? (ExceptionMapper, not scattered)
[ ] Where is logging? (service + resource, not in ACL/mapper)
[ ] Where is metrics instrumentation? (service methods)
```

### 4 — Legacy JEE/EJB Flow Trace (bottom-up)

For legacy systems without Clean Architecture, start from the data:

```
Step 1 — Map the database tables
  Query: SELECT TABLE_NAME FROM USER_TABLES WHERE TABLE_NAME LIKE 'T_{ENTITY}%'
  Identify: primary table, lookup tables, child tables

Step 2 — Find DAO/Repository classes
  Search: grep -rn "SELECT.*FROM T_{ENTITY}" src/ --include="*.java"
  Identify: DAO classes, named queries, stored procedure calls

Step 3 — Find EJB/Service callers of the DAO
  grep -rn "inject.*{DaoClass}\|@EJB.*{DaoClass}" src/ --include="*.java"

Step 4 — Find UI/WS callers of the EJB
  grep -rn "{EjbClass}" src/ --include="*.java"
  Search for: @ManagedBean, @Named (JSF), @WebService, @Path (JAX-RS)

Step 5 — Build legacy call chain

  JSF Page ({entity}List.xhtml)
       │
       ▼ @ManagedBean / @Named
  {Entity}BackingBean.search()
       │ @EJB
       ▼
  {Entity}EjbService.findByCriteria()
       │ @EJB
       ▼
  {Entity}Dao.findByCriteria(Connection)
       │
       ▼
  SQL: SELECT ... FROM T_{ENTITY} WHERE ...

Step 6 — Identify migration targets
  For each legacy class, record:
  [ ] Does it contain business logic that must move to domain service?
  [ ] Does it combine multiple concerns (UI + business + data)?
  [ ] What tables does it own vs read from other services?
  [ ] Are there stored procedures that need to move to Flyway migrations?
```

### 5 — Dependency Fan-in / Fan-out Analysis

Classify every class in the module before planning a refactor:

```markdown
## Dependency Profile — {Module Name}

| Class | Fan-in (callers) | Fan-out (deps) | Risk Category |
|-------|-----------------|----------------|---------------|
| {Entity}Repository | 8 | 1 | HIGH FAN-IN — test thoroughly before changing |
| {Entity}Service | 3 | 4 | MEDIUM — standard service shape |
| {Entity}Resource | 1 | 2 | LOW — entry point, safe to modify |
| {Complex}DomainService | 2 | 7 | HIGH FAN-OUT — refactor candidate |

Risk Categories:
- HIGH FAN-IN (>5 callers): Changes break many callers. Require full test sweep + migration plan.
- HIGH FAN-OUT (>5 deps): Hard to unit test. Consider extracting responsibilities.
- HIGH BOTH: architectural smell — class is doing too much.
```

### 6 — Interface Change Impact Protocol

When changing a port interface (e.g., adding a method to `{Entity}Repository`):

```
1. Find all implementations:
   grep -rn "implements {InterfaceName}" src/ --include="*.java"

2. Find all test mocks of this interface:
   grep -rn "@Mock.*{InterfaceName}\|mock({InterfaceName}" src/test/ --include="*.java"

3. Find all callers expecting the current signature:
   grep -rn "\.{oldMethodName}(" src/ --include="*.java"

4. Assess:
   [ ] Breaking change? (removed/renamed method) → update all impls + tests
   [ ] Additive change? (new method with default impl) → only new impl needed
   [ ] Signature change? (different param types) → update all call sites

5. Plan the migration order:
   a. Add new method to interface (with default implementation if possible)
   b. Update real implementation first
   c. Update test mocks
   d. Update callers
   e. Remove deprecated signature
```

---

## Rules

- Always run grep-based analysis FIRST — it requires no tooling and covers 80% of cases.
- Use tree-sitter script for modules with 50+ files where grep output is unmanageable.
- Build the impact matrix before writing a single line of code for a cross-cutting change.
- Never modify a class with fan-in > 5 without a complete test sweep of callers.
- Document the flow diagram in the PR description for any change affecting 3+ layers.

---

## Checklist

```
[ ] Impact matrix built (grep or tree-sitter) before starting changes
[ ] All direct callers identified and reviewed
[ ] All test mocks of changed class/interface updated
[ ] Fan-in + fan-out assessed for changed classes
[ ] Flow diagram drawn for any use case that crosses 3+ layers
[ ] Legacy flow documented with table ownership before migration
[ ] Transactional boundary confirmed (one @Transactional in service layer)
[ ] ACL boundaries confirmed (no domain objects leaking into data layer)
[ ] No circular dependencies introduced (A→B→C→A is forbidden)
```
