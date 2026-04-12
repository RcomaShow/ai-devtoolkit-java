---
name: fetch-api
description: 'Execute structured HTTP calls against local or remote endpoints, compare behaviors, and auto-collect Quarkus log excerpts on 5xx failures.'
argument-hint: "Request + target — e.g. 'GET local health', 'compare local POST with remote gateway', 'debug 500 on /nomina'"
user-invocable: false
---

# HTTP Fetch And Diagnosis

## When To Use
- To smoke-test a local Quarkus endpoint after a code change.
- To compare local behavior with an external gateway or legacy service.
- To turn a 5xx response into an actionable diagnosis without asking the user for logs.
- To run deterministic checks before or after a Postman/Newman collection.

## Skill Assets

- [HTTP invocation script](./scripts/invoke-http-case.ps1)
- [Guardrails](./references/guardrails.md)
- [Request template](./assets/http-case.template.json)

## Standard Procedure

1. Ensure the app is ready first with `quarkus-dev`.
2. Call the endpoint through the script so status, timing, and response body are recorded consistently.
3. If the status is `5xx`, read the attached log excerpt immediately and diagnose the root cause.
4. When useful, compare the same request against a remote URL to identify environment drift or business-rule divergence.

## Local Smoke Example

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/skills/fetch-api/scripts/invoke-http-case.ps1 \
  -Method GET \
  -Uri http://localhost:8080/q/health/ready \
  -ExpectedStatus 200 \
  -JsonOutput
```

## Local Vs Remote Comparison Example

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/skills/fetch-api/scripts/invoke-http-case.ps1 \
  -Method POST \
  -Uri http://localhost:8080/nomina-trasporto/bilancio-utente \
  -CompareUri https://gateway.example.com/nba/nomina-trasporto/bilancio-utente \
  -HeadersJson '{"Authorization":"Bearer ${env:AUTH_TOKEN}","X-jarvis-transactionId":"tx-local","Content-Type":"application/json","Accept":"application/json"}' \
  -BodyFile .\tests\component\balance-request.json \
  -LogFile .\target\quarkus.log \
  -JsonOutput
```

## Result Expectations

- Every run reports method, URL, status code, duration, and parsed response body when possible.
- On `5xx`, the script returns a log excerpt from `target/quarkus.log` or the supplied log file.
- Comparison mode highlights status/body drift between local and external executions.
- The agent should use the output to explain the problem and, when requested, fix it.