---
name: quarkus-logs-analyzer
description: 'Extract the root cause from Quarkus log files, filter noisy output, and return the most relevant excerpt for debugging startup failures and 5xx responses.'
argument-hint: "Log target — e.g. 'last 80 lines of target/quarkus.log', 'root cause for startup failure', 'analyze latest 500 stack trace'"
user-invocable: false
---

# Quarkus Logs Analyzer

## When To Use
- After a local startup failure.
- After a `5xx` returned by `fetch-api`.
- When you need the most relevant `Caused by:` chain instead of a raw log dump.

## Skill Assets

- [Log-analysis script](./scripts/read-quarkus-log.ps1)
- [Guardrails](./references/guardrails.md)
- [Known-errors template](./assets/known-errors.template.md)

## Standard Procedure

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/skills/quarkus-logs-analyzer/scripts/read-quarkus-log.ps1 \
  -LogFile .\target\quarkus.log \
  -Tail 120 \
  -JsonOutput
```

The output should be used to:
- identify the dominant exception chain
- isolate the first meaningful `Caused by:` segment
- attach a concise excerpt to the user-facing diagnosis
- propose a concrete code or config fix when the cause is actionable