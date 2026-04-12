# Flyway Oracle Guardrails

- Avoid destructive DDL in normal migrations.
- Use the three-step ADD/BACKFILL/CONSTRAINT pattern for new NOT NULL columns.
- Check indexes and constraints before recreating them.
- Keep migrations idempotent with production-like data in mind.