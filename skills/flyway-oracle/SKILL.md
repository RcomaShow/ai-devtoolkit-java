---
name: flyway-oracle
description: 'Flyway migration patterns for Oracle DB in Quarkus microservices. Reference when writing migration scripts, designing schema changes, creating indexes, or reviewing safe migration checklists.'
argument-hint: "Migration task — e.g. 'add column to T_{TABLE}', 'create FK between {tableA} and {tableB}', 'add index for {query} query'"
user-invocable: false
---

# Flyway + Oracle — Migration Patterns

## Naming Convention

```
V<version>__<description>.sql

V001__create_table_{entity}.sql
V002__add_column_{col}_{table}.sql
V003__create_fk_{table}_{ref}.sql
V004__create_index_{table}_{purpose}.sql
V005__rename_column_{old}_to_{new}.sql
```

Rules:
- Version is zero-padded 3 digits (001..999), then extend to 4 as needed
- Double underscore `__` separator — required by Flyway
- Description in snake_case, lowercase, descriptive
- One logical change per script — never combine column add + FK + index in one file
- Scripts are **immutable once applied** — never edit an applied migration

## Oracle-Specific Patterns

### CREATE TABLE

```sql
-- V001__create_table_{entity}.sql
CREATE TABLE T_{ENTITY} (
    ID              NUMBER(19,0)     NOT NULL,
    COD_VALUE       VARCHAR2(20)     NOT NULL,
    DT_INIZIO       DATE             NOT NULL,
    DT_FINE         DATE             NOT NULL,
    QT_AMOUNT       NUMBER(15,3),
    CD_STATUS       VARCHAR2(1)      NOT NULL DEFAULT 'A',
    DT_CREATED      TIMESTAMP        DEFAULT SYSTIMESTAMP NOT NULL,
    DT_UPDATED      TIMESTAMP        DEFAULT SYSTIMESTAMP,
    VERSION         NUMBER(10,0)     DEFAULT 0 NOT NULL,
    CONSTRAINT PK_{ENTITY} PRIMARY KEY (ID),
    CONSTRAINT CK_{ENTITY}_STATUS CHECK (CD_STATUS IN ('A','I','D'))
);

CREATE SEQUENCE SEQ_{ENTITY}
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

COMMENT ON TABLE  T_{ENTITY}           IS '{Description of table}';
COMMENT ON COLUMN T_{ENTITY}.COD_VALUE IS '{Description of column}';
COMMENT ON COLUMN T_{ENTITY}.CD_STATUS IS 'A=Active I=Inactive D=Deleted';
```

### ADD COLUMN (safe pattern)

```sql
-- V002__add_column_note_{entity}.sql
-- Adding nullable column is safe — no DEFAULT or NOT NULL initially
ALTER TABLE T_{ENTITY} ADD (NOTE VARCHAR2(500));

COMMENT ON COLUMN T_{ENTITY}.NOTE IS 'Optional text notes';
```

### ADD NOT NULL COLUMN (three-step pattern — Oracle safe)

```sql
-- Step 1: Add nullable
ALTER TABLE T_{ENTITY} ADD (CD_PRIORITY VARCHAR2(1));

-- Step 2: Backfill existing rows
UPDATE T_{ENTITY} SET CD_PRIORITY = 'N' WHERE CD_PRIORITY IS NULL;
COMMIT;

-- Step 3: Add NOT NULL + DEFAULT + CONSTRAINT
ALTER TABLE T_{ENTITY} MODIFY (CD_PRIORITY VARCHAR2(1) DEFAULT 'N' NOT NULL);
ALTER TABLE T_{ENTITY} ADD CONSTRAINT CK_{ENTITY}_PRIORITY CHECK (CD_PRIORITY IN ('H','N','L'));

COMMENT ON COLUMN T_{ENTITY}.CD_PRIORITY IS 'Priority: H=High N=Normal L=Low';
```

### RENAME COLUMN (Oracle 12c+)

```sql
-- V003__rename_column_{old}_to_{new}.sql
ALTER TABLE T_{ENTITY} RENAME COLUMN OLD_COL TO NEW_COL;
```

### ADD FOREIGN KEY

```sql
-- V004__add_fk_{table}_{ref}.sql
ALTER TABLE T_{ENTITY} ADD (
    ID_{REF} NUMBER(19,0)
);

ALTER TABLE T_{ENTITY} ADD CONSTRAINT FK_{ENTITY}_{REF}
    FOREIGN KEY (ID_{REF})
    REFERENCES T_{REF} (ID)
    ON DELETE RESTRICT;

-- MANDATORY: index every FK column
CREATE INDEX IDX_{ENTITY}_{REF} ON T_{ENTITY} (ID_{REF});

COMMENT ON COLUMN T_{ENTITY}.ID_{REF} IS 'FK to {ref description}';
```

### CREATE INDEX (performant patterns)

```sql
-- V005__create_indexes_{entity}.sql

-- Composite index for common list query
CREATE INDEX IDX_{ENTITY}_VALUE_PERIOD
    ON T_{ENTITY} (COD_VALUE, DT_INIZIO, DT_FINE);

-- Partial/function-based index for status-filtered queries
CREATE INDEX IDX_{ENTITY}_ACTIVE
    ON T_{ENTITY} (COD_VALUE, DT_INIZIO)
    WHERE CD_STATUS = 'A';
```

### DROP COLUMN (deferred pattern — Oracle safe)

```sql
-- Step 1: Mark unused (fast, metadata-only)
ALTER TABLE T_{ENTITY} SET UNUSED COLUMN OLD_COL;

-- Step 2: Drop unused in a maintenance window (physical reclaim)
ALTER TABLE T_{ENTITY} DROP UNUSED COLUMNS;
```

### CREATE VIEW (for legacy ACL)

```sql
-- V006__create_view_{entity}_legacy.sql
CREATE OR REPLACE VIEW V_{ENTITY}_LEGACY AS
SELECT
    ID         AS LEGACY_ID,
    COD_VALUE  AS LEGACY_CODE,
    DT_INIZIO  AS VALID_FROM,
    DT_FINE    AS VALID_TO,
    CD_STATUS  AS STATUS_CODE
FROM T_{ENTITY};

COMMENT ON TABLE V_{ENTITY}_LEGACY IS 'Legacy compatibility view for {entity}';
```

## Safe Migration Checklist

Before writing any migration script, verify:

- [ ] Script starts with a comment: `-- <ticket-id> <description>`
- [ ] Uses Oracle-compatible syntax (no `AUTO_INCREMENT`, no `BOOLEAN`, no `SERIAL`)
- [ ] New NOT NULL columns follow the 3-step ADD/BACKFILL/CONSTRAINT pattern
- [ ] Every new table has a `COMMENT ON TABLE` and critical columns have `COMMENT ON COLUMN`
- [ ] Every FK has a supporting index
- [ ] No `DROP TABLE` or `TRUNCATE TABLE` (irreversible)
- [ ] Tested on a scratch schema before merging
- [ ] Script ends with `COMMIT;` if it modifies data (DDL auto-commits in Oracle, DML does not)

## Flyway Configuration (application.properties)

```properties
# Flyway
quarkus.flyway.migrate-at-start=true
quarkus.flyway.baseline-on-migrate=true
quarkus.flyway.locations=classpath:db/migration
quarkus.flyway.table=FLYWAY_SCHEMA_HISTORY

# Oracle datasource
quarkus.datasource.db-kind=oracle
quarkus.datasource.username=${DB_USER}
quarkus.datasource.password=${DB_PASS}
quarkus.datasource.jdbc.url=${DB_URL:jdbc:oracle:thin:@localhost:1521/XEPDB1}
```

## Common Anti-patterns

```sql
-- WRONG: editing an already-applied migration
-- WRONG: combining multiple changes in one file
-- WRONG: MySQL syntax (AUTO_INCREMENT, INT)
-- WRONG: not indexing FK columns
-- WRONG: DROP TABLE in Flyway migration
```
