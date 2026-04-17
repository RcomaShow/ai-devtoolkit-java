# MCP: oracle-official

## Purpose

Provides live Oracle database schema introspection and SQL validation via SQLcl MCP mode. Use it for schema inspection, legacy DDL extraction, numeric profiling, and query verification before changing mappings or writing migration scripts.

## Package

SQLcl (Oracle official CLI) with MCP mode built in. No npm package is required.

## Configuration (.vscode/mcp.json)

```json
"oracle-official": {
  "command": "powershell.exe",
  "args": [
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "${workspaceFolder}/scripts/start-oracle-mcp.ps1"
  ],
  "env": {
    "MCP_DB_CONNECTION": "${env:MCP_DB_CONNECTION}"
  }
}
```

## Environment Variables Required

| Variable | Example | Description |
|----------|---------|-------------|
| `MCP_DB_CONNECTION` | `user/password@db-host:1521/service` | Full SQLcl connection string. Keep it in the environment only. |

The workspace wrapper prefers `.vscode/mcp.env.json` and reads the `oracle-official` section from it when present. Copy `.vscode/mcp.env.template.json` to `.vscode/mcp.env.json` for the structured JSON option, and keep the local JSON file out of source control. If that file is absent, the wrapper falls back to `.vscode/.env` for compatibility. JSON is preferred here because PowerShell can parse it natively without an extra YAML module.

## When to Use

Use `oracle-official` MCP when:
- Proposing a new Flyway migration that adds/alters/drops columns
- Checking whether an index exists before creating it
- Verifying FK constraints before adding a new one
- Inspecting current column types before writing `@Entity` mappings
- Extracting legacy Oracle DDL before converting it to another dialect
- Profiling numeric columns before choosing a SQL Server target type
- Diagnosing performance issues via execution plan

## Agents That Use This MCP

Add `oracle-official/*` to `tools:` in these agent types:
- `database-engineer` — always
- `software-architect` — for schema verification before architecture decisions
- `legacy-migration` — for legacy schema comparison
- `team-lead` when coordinating DB-affecting work across repositories

## Security Rules

- Never hardcode credentials in `mcp.json` — use `${env:VAR}` references
- Oracle user should have READ-ONLY access in CI/CD and analysis environments
- Use a dedicated schema/user with minimal privileges

## Useful Queries via MCP

```sql
-- Extract raw table DDL
SELECT DBMS_METADATA.GET_DDL('TABLE', 'T_{ENTITY}', '{SCHEMA}')
FROM dual;

-- Extract raw index DDL
SELECT DBMS_METADATA.GET_DDL('INDEX', '{INDEX_NAME}', '{SCHEMA}')
FROM dual;
```

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

-- Profile a numeric column before Oracle -> T-SQL conversion
SELECT
  MAX(LENGTH(REGEXP_SUBSTR(TO_CHAR(ABS({COLUMN}), 'TM9', 'NLS_NUMERIC_CHARACTERS=.,'), '^[0-9]+'))) AS MAX_INTEGER_DIGITS,
  MAX(NVL(LENGTH(REGEXP_SUBSTR(TO_CHAR(ABS({COLUMN}), 'TM9', 'NLS_NUMERIC_CHARACTERS=.,'), '\.([0-9]+)$', 1, 1, NULL, 1)), 0)) AS MAX_FRACTION_DIGITS,
  MIN({COLUMN}) AS MIN_VALUE,
  MAX({COLUMN}) AS MAX_VALUE
FROM {SCHEMA}.{TABLE}
WHERE {COLUMN} IS NOT NULL;

-- Check Flyway migration history
SELECT VERSION, DESCRIPTION, INSTALLED_ON, SUCCESS
FROM FLYWAY_SCHEMA_HISTORY
ORDER BY INSTALLED_RANK DESC;
```
