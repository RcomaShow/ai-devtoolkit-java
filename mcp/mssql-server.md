# MCP: mssql-server — Microsoft SQL Server

## Status: AVAILABLE (community package)

## Package

```jsonc
// Option A — community MCP server (npm)
"mssql-server": {
  "command": "npx",
  "args": ["-y", "mssql-mcp-server"],
  "env": {
    "MSSQL_HOST": "${env:MSSQL_HOST}",
    "MSSQL_PORT": "${env:MSSQL_PORT}",
    "MSSQL_DATABASE": "${env:MSSQL_DATABASE}",
    "MSSQL_USER": "${env:MSSQL_USER}",
    "MSSQL_PASSWORD": "${env:MSSQL_PASSWORD}",
    "MSSQL_ENCRYPT": "true",
    "MSSQL_TRUST_SERVER_CERTIFICATE": "${env:MSSQL_TRUST_SERVER_CERTIFICATE}"
  }
}

// Option B — Azure SQL via @azure/mcp (for Azure-hosted SQL)
"azure-mcp": {
  "command": "npx",
  "args": ["-y", "@azure/mcp@latest", "server", "start"],
  "env": {
    "AZURE_CLIENT_ID": "${env:AZURE_CLIENT_ID}",
    "AZURE_TENANT_ID": "${env:AZURE_TENANT_ID}",
    "AZURE_CLIENT_SECRET": "${env:AZURE_CLIENT_SECRET}"
  }
}
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MSSQL_HOST` | SQL Server hostname or IP | `db.company.internal` |
| `MSSQL_PORT` | TCP port (default 1433) | `1433` |
| `MSSQL_DATABASE` | Database name | `NominaDB` |
| `MSSQL_USER` | Login username | `app_user` |
| `MSSQL_PASSWORD` | Login password | *(never commit)* |
| `MSSQL_ENCRYPT` | Encrypt connection (`true`/`false`) | `true` |
| `MSSQL_TRUST_SERVER_CERTIFICATE` | Skip cert validation for local/dev | `false` (prod), `true` (dev only) |

Add to `.env` (never commit — add to `.gitignore`):

```bash
MSSQL_HOST=db.company.internal
MSSQL_PORT=1433
MSSQL_DATABASE=NominaDB
MSSQL_USER=app_user
MSSQL_PASSWORD=changeme
MSSQL_ENCRYPT=true
MSSQL_TRUST_SERVER_CERTIFICATE=false
```

## Quarkus JDBC Configuration

Add to `pom.xml`:
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jdbc-mssql</artifactId>
</dependency>
```

Add to `application.properties`:
```properties
quarkus.datasource.db-kind=mssql
quarkus.datasource.username=${MSSQL_USER}
quarkus.datasource.password=${MSSQL_PASSWORD}
quarkus.datasource.jdbc.url=jdbc:sqlserver://${MSSQL_HOST}:${MSSQL_PORT};databaseName=${MSSQL_DATABASE};encrypt=true;trustServerCertificate=false;
quarkus.datasource.jdbc.max-size=16
quarkus.datasource.jdbc.min-size=2

# Named datasource (when using Oracle + MSSQL together)
quarkus.datasource."mssql".db-kind=mssql
quarkus.datasource."mssql".username=${MSSQL_USER}
quarkus.datasource."mssql".password=${MSSQL_PASSWORD}
quarkus.datasource."mssql".jdbc.url=jdbc:sqlserver://${MSSQL_HOST}:${MSSQL_PORT};databaseName=${MSSQL_DATABASE};
```

Named datasource usage in Panache:
```java
@DataSource("mssql")
@ApplicationScoped
public class MssqlEntityRepository implements PanacheRepository<LegacyEntity, Long> {
    // queries against MSSQL
}
```

## When to Use This MCP

| Use Case | Use MCP? |
|----------|---------|
| Schema introspection (table columns, indexes, FKs) | YES |
| Running ad-hoc queries to understand data model | YES |
| Generating Flyway migration scripts from schema diff | YES |
| Legacy app analysis — map stored procedures | YES |
| Comparing Oracle vs MSSQL schema during migration | YES |
| Application queries at runtime | NO — use JDBC/Panache |

## Which Agents Use This

| Agent | Why |
|-------|-----|
| `database-engineer` | Schema inspection before writing migrations |
| `legacy-migration` | Reading legacy SQL Server schema (procedures, views, tables) |
| `software-architect` | Verifying bounded context isolation at DB level |

## Useful Queries via MCP

```sql
-- List all tables in database
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- List all columns for a table
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH,
       NUMERIC_PRECISION, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'YOUR_TABLE'
ORDER BY ORDINAL_POSITION;

-- List all stored procedures
SELECT ROUTINE_SCHEMA, ROUTINE_NAME, ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
ORDER BY ROUTINE_NAME;

-- List all foreign keys
SELECT 
    fk.name AS FK_NAME,
    tp.name AS PARENT_TABLE,
    tr.name AS REFERENCED_TABLE
FROM sys.foreign_keys fk
JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id;

-- List all indexes
SELECT 
    t.name AS TABLE_NAME,
    i.name AS INDEX_NAME,
    i.type_desc AS INDEX_TYPE,
    i.is_unique
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.name IS NOT NULL
ORDER BY t.name, i.name;

-- Get procedure definition
SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.ProcedureName'));

-- Schema comparison — columns present in MSSQL but not in Oracle target
SELECT c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME IN ('TABLE_A', 'TABLE_B')
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
```

## Security Rules

- **Never log the MCP connection URL** — it may contain credentials.
- **Use read-only SQL Server login** for schema inspection. Never connect with `sa` or `db_owner`.
- `trustServerCertificate=true` is only acceptable in developer-local environments. Always `false` in CI, UAT, and production.
- Rotate `MSSQL_PASSWORD` after any team member departure.
- Store all credentials in environment variables or a secrets manager — never in `application.properties` committed to VCS.
