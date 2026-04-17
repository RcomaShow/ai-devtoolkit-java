# Legacy Analysis -- {title}

## Scope
- Case ID: {case-id}
- Entrypoint type: {entrypoint-type}
- Entrypoint: {entrypoint}
- Source root: {source-root}
- Latest generated evidence: .github/legacy/cases/{case-id}/generated/{run-id}

## Entrypoint Trace
- Resolved entry bean/resource: {class}
- Vertical flow: {entrypoint} -> {bean} -> {service} -> {repository} -> {entity/external}
- Horizontal hotspots: {same-layer-coupling}

## Business Rules

| Rule | Evidence | Notes |
|------|----------|-------|
| {rule-1} | {class}.{method} | {note} |

## Java Slice

See `java-class-logic.md` for the full per-class logic inventory.

## Oracle SQL Inventory

See `oracle-sql-inventory.md` for the standard object inventory.

## Migration Mapping

| Legacy Artifact | Target Artifact | Notes |
|-----------------|-----------------|-------|
| {legacy-artifact} | {target-artifact} | {mapping-note} |

## Open Questions
- {question-1}