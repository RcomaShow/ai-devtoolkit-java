# MCP: oracle-official

## Purpose
Provides live Oracle database schema introspection and SQL validation via SQLcl's MCP mode. Enables agents to inspect table structures, column definitions, indexes, FK constraints, and existing data before proposing schema changes.

## Package
SQLcl (Oracle official CLI) — MCP mode built-in. No npm package needed.

## Configuration (.vscode/mcp.json)

```json
"oracle-official": {
  "command": "sql",
  "args": [
    "${env:DB_USER}/${env:DB_PASS}@${env:DB_HOST}:${env:DB_PORT}/${env:DB_SID}",
    "-mcp"
  ]
}
```

## Environment Variables Required

| Variable | Example | Description |
|----------|---------|-------------|
| `DB_USER` | `app_user` | Oracle DB username |
| `DB_PASS` | (secret) | Oracle DB password — never hardcoded |
| `DB_HOST` | `db.company.internal` | Oracle host |
| `DB_PORT` | `1521` | Oracle listener port |
| `DB_SID` | `XEPDB1` | Oracle SID or service name |

## When to Use

Use `oracle-official` MCP when:
- Proposing a new Flyway migration that adds/alters/drops columns
- Checking whether an index exists before creating it
- Verifying FK constraints before adding a new one
- Inspecting current column types before writing `@Entity` mappings
- Diagnosing performance issues via execution plan

## Agents That Use This MCP

Add `oracle-official/*` to `tools:` in these agent types:
- `database-engineer` — always
- `software-architect` — for schema verification before architecture decisions
- `legacy-migration` — for legacy schema comparison
- Team lead agents (Tier 3) that own repositories with DB changes

## Security Rules

- Never hardcode credentials in `mcp.json` — use `${env:VAR}` references
- Oracle user should have READ-ONLY access in CI/CD environments
- Use a dedicated schema/user with minimal privileges

## Useful Queries via MCP

```sql
-- List columns of a table
SELECT COLUMN_NAME, DATA_TYPE, NULLABLE, DATA_DEFAULT
FROM ALL_TAB_COLUMNS
WHERE TABLE_NAME = 'T_{ENTITY}'
ORDER BY COLUMN_ID;

-- List indexes
SELECT INDEX_NAME, UNIQUENESS, STATUS
FROM ALL_INDEXES
WHERE TABLE_NAME = 'T_{ENTITY}';

-- List FK constraints
SELECT CONSTRAINT_NAME, R_CONSTRAINT_NAME, STATUS
FROM ALL_CONSTRAINTS
WHERE TABLE_NAME = 'T_{ENTITY}'
AND CONSTRAINT_TYPE = 'R';

-- Check Flyway migration history
SELECT VERSION, DESCRIPTION, INSTALLED_ON, SUCCESS
FROM FLYWAY_SCHEMA_HISTORY
ORDER BY INSTALLED_RANK DESC;
```
