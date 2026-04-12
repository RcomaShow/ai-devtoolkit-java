# Java Flow Analysis Guardrails

- Treat AST results as evidence, not as a substitute for domain understanding.
- Never infer business behavior from names alone when code says otherwise.
- Distinguish direct callers from broader impact sets.
- Keep flow analysis read-only unless another skill explicitly handles mutations.
- When a JSF/XHTML view exists, prefer entrypoint-first tracing from the view before reasoning from DAOs upward.
- Escalate every unresolved bean or ambiguous dependency instead of silently guessing the target class.