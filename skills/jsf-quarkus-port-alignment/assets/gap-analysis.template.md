# Gap {Feature} Legacy Vs New

> Date: {yyyy-mm-dd}
> Scope: {feature-or-use-case}
> Legacy entrypoint: {xhtml-or-service}
> New surface: {resource-service-package}

## 1. Synthetic Outcome

State in 3-6 lines whether the new implementation is aligned, partially aligned, or still far from parity.

## 2. Sources

### Legacy

- {legacy-file-or-analysis-doc}
- {legacy-file-or-analysis-doc}

### New

- {new-resource-or-service}
- {new-resource-or-service}

### Verification

- {compile-test-or-runtime-check}

## 3. Classification Summary

| Classification | Count | Notes |
|---|---|---|
| `internal-parity-gap` | {n} | {notes} |
| `external-todo` | {n} | {notes} |
| `intentional-divergence` | {n} | {notes} |
| `blocked-by-contract` | {n} | {notes} |

## 4. Gap Ledger

| Area | Legacy | New | Classification | Impact | Exit condition | Evidence |
|---|---|---|---|---|---|---|
| {area} | {legacy-behavior} | {new-behavior} | `internal-parity-gap` | {impact} | {what closes it} | {file/method/doc} |

## 5. Ordered Backlog

1. {highest-value internal parity fix}
2. {next fix}
3. {external or contract dependency}

## 6. Open Questions

- {ambiguity needing product or business input}

## 7. Intentional Divergences

- {divergence accepted on purpose and why}