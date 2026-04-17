# Legacy Analysis Template

## Case
- Case ID: {case-id}
- Title: {title}
- Type: {view|bean|ejb|dao|entity|external-client}
- Entrypoint: {entrypoint}
- Source root: {source-root}
- Generated evidence path: .github/legacy/cases/{case-id}/generated/{run-id}

## Entrypoint Trace
- XHTML bindings or entry signature: {binding-or-method}
- Resolved bean/resource: {class}
- Vertical flow: {entrypoint} -> {bean} -> {service} -> {repository} -> {entity/external}
- Horizontal dependencies: {same-layer-coupling}

## Key Business Rules

| Rule | Evidence | Notes |
|------|----------|-------|
| {rule-1} | {class}.{method} | {note} |

## Java Class Logic

Keep the per-class inventory in `java-class-logic.md` and summarize only the critical classes here.

| Class | Layer | Responsibility | Evidence |
|-------|-------|----------------|----------|
| {class} | {layer} | {logic-summary} | {file-or-method} |

## Oracle SQL Inventory

Keep the standard object inventory in `oracle-sql-inventory.md`.

| Object | Object Type | Source | Notes |
|--------|-------------|--------|-------|
| {table-or-view} | {table|view|sequence|query} | {java-or-xml-source} | {note} |

## Migration Mapping

| Legacy Artifact | Target Artifact | Notes |
|-----------------|-----------------|-------|
| {legacy-artifact} | {target-artifact} | {mapping-note} |

## Open Questions
- {question-1}