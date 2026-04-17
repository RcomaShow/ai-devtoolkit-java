---
name: legacy-ddl-conversion
description: 'Reusable procedure for extracting legacy Oracle DDL, profiling numeric columns, and producing reviewed T-SQL conversion scripts with MCP-backed evidence.'
argument-hint: "Schema migration task — e.g. 'extract Oracle DDL for NOM_* and convert to T-SQL', 'profile NUMBER columns before SQL Server migration'"
user-invocable: false
---

# Legacy DDL Conversion — Oracle to T-SQL

## When to Use

- Oracle legacy schema must be recovered from the live catalog.
- The target platform is SQL Server or another T-SQL-compatible runtime.
- Numeric column mapping must be justified with both metadata and actual data.

## Inputs

- source schema or table list
- Oracle connection through `oracle-official`
- optional SQL Server connection through `mssql-server`
- optional `xhtml-db-graph` report when the migration starts from an application entrypoint

## Procedure

### 1 — Build the source inventory

- Collect tables from application traces, XML/native-query artifacts, or explicit table lists.
- Query Oracle catalog metadata before drafting any conversion script.
- Record tables, views, sequences, triggers, indexes, and FK dependencies separately.

### 2 — Extract the authoritative DDL

- Prefer `DBMS_METADATA.GET_DDL` for tables, indexes, views, sequences, and constraints.
- Normalize storage clauses and environment-specific noise out of the extracted script.
- Keep the raw Oracle DDL as evidence beside the converted script.

### 3 — Profile numeric columns before mapping

Never map Oracle `NUMBER` columns on metadata alone when precision or scale are nullable, omitted, or clearly wider than the observed data.

Use metadata first:

```sql
SELECT column_name, data_type, data_precision, data_scale, nullable
FROM all_tab_columns
WHERE owner = UPPER('{SCHEMA}')
AND table_name = UPPER('{TABLE}')
ORDER BY column_id;
```

Then measure real data shape:

```sql
SELECT
    MAX(LENGTH(REGEXP_SUBSTR(TO_CHAR(ABS({COLUMN}), 'TM9', 'NLS_NUMERIC_CHARACTERS=.,'), '^[0-9]+'))) AS max_integer_digits,
    MAX(NVL(LENGTH(REGEXP_SUBSTR(TO_CHAR(ABS({COLUMN}), 'TM9', 'NLS_NUMERIC_CHARACTERS=.,'), '\.([0-9]+)$', 1, 1, NULL, 1)), 0)) AS max_fraction_digits,
    MIN({COLUMN}) AS min_value,
    MAX({COLUMN}) AS max_value
FROM {SCHEMA}.{TABLE}
WHERE {COLUMN} IS NOT NULL;
```

- Use metadata as the ceiling.
- Use observed data to choose the narrowest safe T-SQL type.
- Flag low-confidence columns when sampled data may be incomplete.

### 4 — Apply type mapping rules

- `NUMBER(p,0)`:
  - Use `tinyint`, `smallint`, `int`, or `bigint` only when observed values and sign fit safely.
  - Otherwise use `decimal(p,0)`.
- `NUMBER(p,s)` with `s > 0`: use `decimal(p,s)`.
- `NUMBER` without declared precision or scale: derive a safe `decimal(p,s)` from metadata plus data profiling; do not guess an integer type.
- `DATE`: usually `datetime2(0)`.
- `TIMESTAMP(n)`: `datetime2(n)`.
- `VARCHAR2` and `NVARCHAR2`: preserve character semantics; prefer `nvarchar(n)` when Unicode must be retained.
- `CLOB`: `nvarchar(max)`.
- `BLOB`: `varbinary(max)`.

### 5 — Convert structural features explicitly

- Convert sequences and triggers to SQL Server identity or sequence patterns deliberately; never silently drop them.
- Translate Oracle-specific defaults, `dual`, synonyms, and function-based indexes explicitly.
- Rebuild PK, UK, FK, and supporting indexes in the target script with deterministic names.

### 6 — Validate the target script

- If `mssql-server` MCP is available, verify that the generated T-SQL parses and the target catalog stays consistent.
- If it is not available, mark validation as pending instead of assuming the script is correct.
- Review every lossy or heuristic mapping before finalizing.

## Expected Outputs

- raw Oracle DDL evidence
- numeric profiling evidence for converted numeric columns
- final T-SQL DDL script
- open questions and low-confidence mappings