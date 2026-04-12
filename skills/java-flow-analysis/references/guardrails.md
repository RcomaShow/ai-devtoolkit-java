# Java Flow Analysis Guardrails

- Treat AST results as evidence, not as a substitute for domain understanding.
- Never infer business behavior from names alone when code says otherwise.
- Distinguish direct callers from broader impact sets.
- Keep flow analysis read-only unless another skill explicitly handles mutations.