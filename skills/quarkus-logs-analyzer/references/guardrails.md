# Quarkus Logs Analyzer Guardrails

- Prefer a focused excerpt over dumping the whole log.
- Include the root cause and one short surrounding context block, not unrelated noise.
- Distinguish startup/configuration errors from request-time exceptions.
- If the log is missing, say so explicitly and fall back to console logs or the dev-session logs.
- Do not hide ambiguity: if multiple `Caused by:` chains are plausible, state that clearly.