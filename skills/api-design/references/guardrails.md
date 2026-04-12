# API Design Guardrails

- Never invent endpoints, status codes, or error schemas that conflict with the existing contract.
- Prefer RFC 7807 for error responses.
- Validate backward compatibility before changing path, query, or payload semantics.
- Keep transport DTO concerns separate from domain model concerns.