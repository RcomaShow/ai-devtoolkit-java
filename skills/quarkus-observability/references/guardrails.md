# Quarkus Observability Guardrails

- Never log PII, credentials, or full sensitive payloads.
- Keep metric tag cardinality low and intentional.
- Correlate logs and traces with explicit correlation identifiers.
- Prefer operationally actionable signals over vanity metrics.