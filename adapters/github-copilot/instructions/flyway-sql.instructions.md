---
description: 'Flyway SQL migration standards for Oracle DB in Quarkus microservices. Applied to all Flyway migration scripts.'
applyTo: 'src/main/resources/db/migration/**/*.sql'
---

# Flyway SQL — Oracle Standards

## File Naming

```
V{version}__{description}.sql
V5__create_T_NOMINA.sql
V6__add_COD_STATO_to_T_NOMINA.sql
V7__create_FK_T_NOMINA_T_CONTRATTO.sql
```

- Version is a 3-digit zero-padded integer: `V001`, `V002`, ...
- Description uses uppercase table names and `snake_case` action names.
- Two underscores between version and description.

## Table Naming Convention

```sql
-- Tables: T_{ENTITY_NAME} in UPPERCASE
CREATE TABLE T_NOMINA (
    ID_NOMINA        NUMBER(19)    NOT NULL,
    COD_NOMINA       VARCHAR2(50)  NOT NULL,  -- codes: COD_
    DT_INIZIO        DATE          NOT NULL,  -- dates: DT_
    DT_FINE          DATE,
    FLG_ATTIVO       NUMBER(1)     DEFAULT 1 NOT NULL,  -- flags: FLG_
    NUM_IMPORTO      NUMBER(15,2),             -- numbers: NUM_
    ID_CONTRATTO     NUMBER(19),               -- FK: ID_
    VER_ROW          NUMBER(19)    DEFAULT 0 NOT NULL,  -- optimistic lock
    CONSTRAINT PK_NOMINA PRIMARY KEY (ID_NOMINA)
);
```

## Sequences

```sql
CREATE SEQUENCE SEQ_NOMINA START WITH 1 INCREMENT BY 50 NOCACHE NOCYCLE;
```

- One sequence per table, named `SEQ_{ENTITY}`.
- `INCREMENT BY 50` matches Hibernate's allocationSize.

## Foreign Keys and Indexes

```sql
-- Always create an index for every FK column
CREATE INDEX IDX_NOMINA_CONTRATTO ON T_NOMINA(ID_CONTRATTO);

ALTER TABLE T_NOMINA ADD CONSTRAINT FK_NOMINA_CONTRATTO
    FOREIGN KEY (ID_CONTRATTO) REFERENCES T_CONTRATTO(ID_CONTRATTO);
```

## Adding NOT NULL Columns (3-Step Pattern)

```sql
-- Step 1: Add nullable
ALTER TABLE T_NOMINA ADD (COD_STATO VARCHAR2(20));

-- Step 2: Backfill
UPDATE T_NOMINA SET COD_STATO = 'BOZZA' WHERE COD_STATO IS NULL;
COMMIT;

-- Step 3: Apply constraint
ALTER TABLE T_NOMINA MODIFY (COD_STATO VARCHAR2(20) NOT NULL);
```

## Forbidden Operations

- **No DROP TABLE** — use deprecation comments instead.
- **No TRUNCATE** — data removal is application logic, not schema migration.
- **No business logic** — no triggers, stored procedures, or complex PL/SQL in migrations.
- **No DML outside a migration context** — migrations touch schema structure, not application data (except backfills during 3-step NOT NULL additions).
