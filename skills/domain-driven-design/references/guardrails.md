# Domain-Driven Design Guardrails

- Keep aggregates small enough to protect one transactional consistency boundary.
- Never place persistence annotations or transport DTO logic inside domain models.
- Prefer explicit invariants over anemic getters/setters.
- Model ubiquitous language first, then code structure.