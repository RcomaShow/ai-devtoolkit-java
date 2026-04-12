# Quarkus Dev Guardrails

- Prefer an existing VS Code task when the workspace already defines the correct `quarkus:dev` command.
- Never call business endpoints before readiness returns `UP`.
- Track dev sessions through the pid file; do not guess by killing random Java processes.
- Keep secrets in `.env`, `application.properties`, or environment variables, never inline in the skill invocation.
- If startup fails, capture the log excerpt and diagnose the root cause before retrying.
- Do not start a second dev session on the same port unless the first one was stopped explicitly.