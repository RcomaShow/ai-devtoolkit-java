# Legacy Analysis Template

## Component
- Name: {legacy-component}
- Type: {view|bean|ejb|dao|entity|external-client}
- Entrypoint: {file.xhtml|service endpoint|batch launcher}

## Entrypoint Trace
- XHTML bindings or entry signature: {binding-or-method}
- Resolved bean/resource: {class}
- Vertical flow: {entrypoint} -> {bean} -> {service} -> {repository} -> {entity/external}
- Horizontal dependencies: {same-layer-coupling}

## Business Rules
- {rule-1}

## Evidence
- Java method: {class}.{method}
- XHTML condition or action: {expression}
- SQL/table: {table-or-query}

## Data Touchpoints
- {table-or-column}

## Migration Mapping
- {legacy-artifact} -> {target-artifact}

## Open Questions
- {question-1}