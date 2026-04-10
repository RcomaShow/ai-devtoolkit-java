---
name: api-design
description: 'OpenAPI 3.1 and REST API design patterns for Java/Quarkus microservices. Reference when designing new endpoints, reviewing API contracts, defining DTOs, writing error responses, or aligning with legacy APIs.'
argument-hint: "API task — e.g. 'design {entity} endpoint', 'review openapi-{service}.yaml', 'define error response schema'"
user-invocable: false
---

# API Design — OpenAPI 3.1 + REST Patterns

## OpenAPI 3.1 File Structure

```yaml
openapi: 3.1.0
info:
  title: {Service Name} API
  version: 1.0.0
  description: |
    API for {service description}.
  contact:
    name: {Team Name}
    email: {team}@company.com

servers:
  - url: http://localhost:8080
    description: Local dev
  - url: https://api.{service}-dev.company.com
    description: Dev

tags:
  - name: {Entities}
    description: {Entity} management operations

paths:
  /api/v1/{entities}:
    get:
      operationId: list{Entities}
      tags: [{Entities}]
      summary: List {entities}
      parameters:
        - $ref: '#/components/parameters/DateFrom'
        - $ref: '#/components/parameters/DateTo'
      responses:
        '200':
          description: List of {entities}
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/{Entity}Dto'
        '400':
          $ref: '#/components/responses/BadRequest'
        '500':
          $ref: '#/components/responses/InternalServerError'
```

## RESTful URL Naming Rules

| Pattern | Correct | Wrong |
|---------|---------|-------|
| Resource (plural noun) | `/{entities}` | `/get{Entities}`, `/{entity}` |
| Sub-resource | `/{entities}/{id}/approvals` | `/approve{Entity}/{id}` |
| Filter via query params | `/{entities}?status=ACTIVE` | `/{entities}/byStatus/ACTIVE` |
| Actions on resources | `POST /{entities}/{id}/activate` | `POST /activate{Entity}` |
| Version prefix | `/api/v1/...` | No version |

```
GET    /api/v1/{entities}              — list (pageable)
POST   /api/v1/{entities}              — create
GET    /api/v1/{entities}/{id}         — get by id
PUT    /api/v1/{entities}/{id}         — replace (full update)
PATCH  /api/v1/{entities}/{id}         — partial update
DELETE /api/v1/{entities}/{id}         — delete
POST   /api/v1/{entities}/{id}/approve — action (state change)
```

## HTTP Status Code Strategy

| Scenario | Status |
|----------|--------|
| Create success | 201 Created + Location header |
| Read success | 200 OK |
| Update success | 200 OK (return updated resource) |
| Delete success | 204 No Content |
| Validation failure | 422 Unprocessable Entity |
| Not found | 404 Not Found |
| Business rule violation | 409 Conflict |
| Auth missing | 401 Unauthorized |
| Auth forbidden | 403 Forbidden |
| Server error | 500 Internal Server Error |

## RFC 7807 Error Schema

Every error response uses `application/problem+json`:

```yaml
components:
  schemas:
    ProblemDetail:
      type: object
      required: [type, title, status]
      properties:
        type:
          type: string
          format: uri
          example: "https://api.company.com/errors/{ERROR_CODE}"
        title:
          type: string
          example: "{Entity} not found"
        status:
          type: integer
          example: 404
        detail:
          type: string
          example: "{Entity} with id 123 not found"
        instance:
          type: string
          format: uri
          example: "/api/v1/{entities}/123"
        violations:
          type: array
          items:
            $ref: '#/components/schemas/ConstraintViolation'

    ConstraintViolation:
      type: object
      properties:
        field:    { type: string, example: "amount" }
        message:  { type: string, example: "must be greater than 0" }
        value:    { type: string, example: "-5" }
```

## DTO Design Rules

- **Request DTOs** contain only input fields — no server-generated IDs, no audit fields
- **Response DTOs** are read-only records — all fields, no mutation methods
- **Nested DTOs** for complex sub-objects (avoid flat structures beyond 6 fields)
- **No domain objects in API layer** — always map to/from DTOs

```java
// Request DTO — validation annotations belong here
public record Create{Entity}Request(
    @NotNull @Size(max = 50) String code,
    @NotNull LocalDate dateFrom,
    @NotNull LocalDate dateTo,
    @NotNull @DecimalMin("0") BigDecimal amount,
    @NotNull @Pattern(regexp = "UNIT_A|UNIT_B") String unit
) {}

// Response DTO — immutable, no validation
public record {Entity}Dto(
    Long id,
    String code,
    LocalDate dateFrom,
    LocalDate dateTo,
    BigDecimal amount,
    String unit,
    String status,
    Instant createdAt
) {}
```

## Reusable Components (define once, $ref everywhere)

```yaml
components:
  parameters:
    DateFrom:
      name: date-from
      in: query
      required: false
      schema:
        type: string
        format: date
      example: "2024-01-01"

    DateTo:
      name: date-to
      in: query
      required: false
      schema:
        type: string
        format: date
      example: "2024-01-31"

  responses:
    BadRequest:
      description: Invalid input
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetail'

    NotFound:
      description: Resource not found
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetail'

    InternalServerError:
      description: Internal server error
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetail'
```

## API Review Checklist

Before merging an API change:

- [ ] URLs use plural nouns, kebab-case, `/api/v1/` prefix
- [ ] Actions use sub-resources + POST, not verbs in path
- [ ] Every endpoint has an `operationId` (camelCase, unique)
- [ ] Every endpoint tagged with at least one `tag`
- [ ] 4xx and 5xx responses always return `application/problem+json`
- [ ] No raw primitives as request body (always a named schema)
- [ ] Response envelopes avoided — return arrays directly when listing
- [ ] Pagination with `page` + `size` query params if list could be large
- [ ] Breaking changes (new required field, removed field, changed type) = new version (`/v2/`)
- [ ] Non-breaking (new optional field, new endpoint) = compatible with `/v1/`
