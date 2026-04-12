# Quarkus Backend Guardrails

- Keep business logic out of resources.
- Keep `@Transactional` in service/application layer only.
- Do not leak JPA entities outside `data/`.
- Validate input at the boundary and map through dedicated mappers.