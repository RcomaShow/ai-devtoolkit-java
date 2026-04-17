---
name: java-flow-analysis
description: 'AST-based procedure for analyzing execution flows, dependency chains, and change impact in Java codebases. Covers both legacy (JEE/JSF/EJB) and Quarkus microservices, including XHTML-first tracing across layers.'
argument-hint: "Analysis type — e.g. 'impact of changing {Entity}Repository', 'trace flow of create{Entity} use case', 'xhtml-first trace for {view}.xhtml'"
user-invocable: false
---

# Java Flow Analysis — AST · Dependency · Impact

> **When to use this skill:**
> - Before modifying a class used by many others
> - When tracing a business operation end-to-end
> - During legacy reverse-engineering from a JSF/XHTML page
> - When identifying horizontal dependencies or vertical layer crossings

---

## Key Concepts

| Term | Meaning |
|------|---------|
| **Call graph** | Directed graph: node = method, edge = calls |
| **Dependency graph** | Directed graph: node = class, edge = depends on (imports, fields, constructor parameters) |
| **Vertical dependency** | Edge that crosses layers: XHTML → Bean → Service → Repository → Entity/External |
| **Horizontal dependency** | Edge inside the same layer, often a smell when it fans out heavily |
| **Impact set** | All classes that must be reviewed or retested when class X changes |
| **Fan-in** | Number of callers of a method or class |
| **Fan-out** | Number of direct dependencies of a class |
| **Entry point** | REST resource, scheduled job, message listener, or JSF/XHTML view |
| **ACL boundary** | Translation boundary between legacy/external structures and domain model |

---

## Analysis Commands

The canonical script now lives beside this skill at `.github/skills/java-flow-analysis/scripts/analyze-java.py`. The toolkit wrapper `.ai-devtoolkit/scripts/analyze-java.py` remains available for compatibility.

```bash
# Install dependencies once
pip install tree-sitter tree-sitter-language-pack

# Windows alternative
py -3 -m pip install tree-sitter tree-sitter-language-pack

# List methods with branch count
python .github/skills/java-flow-analysis/scripts/analyze-java.py methods src/main/java/com/company/{domain}/service/{Entity}Service.java

# Find all callers of a method across a module
python .github/skills/java-flow-analysis/scripts/analyze-java.py callers src/main/java {Entity}Service.create

# Full impact set for a class
python .github/skills/java-flow-analysis/scripts/analyze-java.py impact src/main/java {Entity}Repository

# Direct dependency profile for one class
python .github/skills/java-flow-analysis/scripts/analyze-java.py deps src/main/java/com/company/{domain}/service/{Entity}Service.java

# XHTML-first JSON graph: view -> includes/composite components -> bean -> downstream layers -> DB touchpoints
python .github/skills/java-flow-analysis/scripts/analyze-java.py xhtml-db-graph src/main/java src/main/webapp/pages/{feature}/{view}.xhtml

# Compatibility alias for the same richer report
python .github/skills/java-flow-analysis/scripts/analyze-java.py legacy-xhtml src/main/java src/main/webapp/pages/{feature}/{view}.xhtml

# Branch-oriented test matrix
python .github/skills/java-flow-analysis/scripts/analyze-java.py test-matrix src/main/java/com/company/{domain}/service/{Entity}Service.java
```

---

## Patterns

### 1 — Static Impact Analysis First

Use text search before AST analysis. It is faster and often sufficient.

```bash
grep -rn "{ClassName}" src/ --include="*.java" | grep -v "test/"
grep -rn "\.{methodName}(" src/ --include="*.java"
grep -rn "implements {InterfaceName}" src/ --include="*.java"
grep -rn "@Inject\|@Autowired\|@EJB" src/ --include="*.java" -A1 | grep "{ClassName}"
grep -rn "{ClassName}" src/test --include="*.java"
```

Only move to AST mode when the grep result is too noisy, the codebase is large, or the entrypoint is an XHTML view.

### 2 — AST Dependency Profile

Run `deps` on the class you want to change before editing it.

Expected output fields:
- `layer`: inferred layer such as `backing-bean`, `service`, `repository`, `entity`
- `dependencies`: direct Java dependencies extracted from fields, constructors, and imports
- `bean_names`: JSF/CDI names that can be referenced by XHTML
- `method_count`: quick sizing signal before deeper review

Use this to decide whether the class is:
- safe to modify in isolation,
- part of a wider migration slice,
- a candidate for extraction because of high fan-out.

### 3 — Quarkus Flow Trace (top-down)

Procedure for a standard Quarkus use case:

```text
Step 1 — Identify the REST entry point
  Read: api/{Entity}Resource.java
  Note: request DTO, validation annotations, response contract

Step 2 — Follow service orchestration
  Read: service/{Entity}Service.java
  Note: branch points, transaction boundary, repository or external calls

Step 3 — Follow ports and implementations
  Read: domain/port/{Entity}Repository.java
  Read: data/repository/{Entity}PanacheRepository.java

Step 4 — Follow translators and ACL boundaries
  Read: data/acl/{Entity}AclTranslator.java
  Note: schema mapping, enum conversions, null handling

Step 5 — Record the vertical flow
  Resource -> Service -> Repository/Port -> ACL -> Entity/DB
```

### 4 — XHTML-First Legacy Flow Trace

When a legacy use case starts from a JSF page, begin from the view instead of from the database.

```text
Step 1 — Read the XHTML page
  Extract EL bindings: #{bean.property}, #{bean.action}, #{bean.subBean.value}

Step 2 — Run the XHTML trace
  analyze-java.py xhtml-db-graph <source-root> <view.xhtml>
  legacy-xhtml remains a compatibility alias for the same richer report

Step 3 — Review the output sections
  resolvedEntryBeans      -> bean names mapped to concrete Java classes
  unresolvedBeans         -> EL names without a safe Java match
  xhtmlArtifacts          -> included XHTML files, composite components, namespaces, unresolved view links
  xmlArtifacts            -> related XML/native-query artifacts discovered from the reachable slice
  verticalLayers          -> layer-by-layer nodes touched by the flow
  verticalEdges           -> boundary crossings between layers
  horizontalDependencies  -> same-layer dependencies worth reviewing
  ambiguousDependencies   -> classes with multiple possible targets
  reachableFiles          -> concrete files reached from the view
  databaseTouchpoints     -> repositories, entities, tables, and SQL touchpoints
  graph                   -> canonical JSON node/edge graph for downstream tooling

Step 4 — Validate the trace manually
  Open the resolved backing bean, then confirm:
  - invoked methods
  - injected EJB/service/DAO fields
  - repository/entity touchpoints
  - external clients and side effects
```

Use this pattern when the user asks to “partire da un file xhtml e capire ogni layer”. That is now a first-class workflow, not an ad hoc investigation.

The command returns JSON by default. Treat that JSON as the canonical machine-readable dependency graph for agent handoff or external tooling.
The graph now resolves safe XHTML includes, JSF composite component links, and relevant XML/native-query artifacts without relying on project-specific rules.

### 5 — Horizontal vs Vertical Dependency Review

Classify the trace before proposing code movement.

```markdown
## Dependency Review — {UseCase}

### Vertical Flow
- XHTML `{view}.xhtml` -> `{Bean}`
- `{Bean}` -> `{Service}`
- `{Service}` -> `{Repository}`
- `{Repository}` -> `{Entity}` / Oracle

### Horizontal Dependencies
- `{Bean}` -> `{OtherBean}`  ← smell, UI layer coupling
- `{Service}` -> `{OtherService}`  ← check orchestration overlap
- `{Repository}` -> `{OtherRepository}`  ← verify ownership and transaction scope
```

Rules of thumb:
- many horizontal edges in the UI layer usually mean the backing bean is doing orchestration work;
- many horizontal edges in the service layer often signal missing domain boundaries;
- repository-to-repository coupling requires special scrutiny because it often hides table ownership issues.

### 6 — Interface Change Impact Protocol

When changing a port or shared service contract:

```text
1. Find all implementations
2. Find all test mocks and stubs
3. Find all current callers of the method/signature
4. Mark the change as additive, breaking, or signature-shifting
5. Update in this order:
   a. implementation or adapter
   b. tests and mocks
   c. callers
   d. deprecated path removal
```

---

## Rules

- Run grep-based analysis first; use AST analysis when the scope justifies it.
- For JSF/Facelets systems, prefer XHTML-first tracing over blind DAO-first tracing.
- Treat `unresolvedBeans` and `ambiguousDependencies` as blockers until verified manually.
- Build the impact matrix before making a cross-layer change.
- Do not infer business meaning from names alone when the code or schema says otherwise.

---

## Checklist

```text
[ ] Impact matrix built before starting changes
[ ] Direct callers or dependents identified and reviewed
[ ] Fan-in and fan-out assessed for changed classes
[ ] Vertical layer flow documented for the target use case
[ ] Horizontal dependencies reviewed for coupling smells
[ ] XHTML entrypoint analyzed when a JSF/Facelets view exists
[ ] Ambiguous beans and dependencies resolved explicitly
[ ] Transactional boundary confirmed
[ ] ACL boundaries confirmed
[ ] No circular dependencies introduced
```
