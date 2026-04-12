-- V{version}__{description}.sql

ALTER TABLE {table_name}
    ADD {column_name} {column_type};

UPDATE {table_name}
   SET {column_name} = {backfill_expression}
 WHERE {column_name} IS NULL;

ALTER TABLE {table_name}
    MODIFY {column_name} NOT NULL;