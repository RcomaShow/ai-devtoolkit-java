# Fetch API Guardrails

- Use `quarkus-dev` readiness checks before hitting business endpoints.
- Prefer explicit `ExpectedStatus` values instead of vague “it works” checks.
- Keep auth tokens and endpoint base URLs in environment variables or test fixtures, never inline in source control.
- On `5xx`, do not stop at the HTTP response: attach the log excerpt and explain the likely root cause.
- In comparison mode, use the same headers and body for both targets unless the difference is intentional and documented.
- Do not call destructive remote endpoints without explicit user intent.