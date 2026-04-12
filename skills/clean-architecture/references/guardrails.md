# Clean Architecture Guardrails

- Never let `data/` types leak into `service/`, `domain/`, or `api/`.
- Keep transactions and framework wiring out of the domain layer.
- Record structural exceptions as ADRs instead of burying them in code comments.
- Prefer ports and adapters over direct infrastructure coupling.