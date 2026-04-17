# Legacy Analysis Guardrails

- Derive business rules from code, docs, or schema evidence only.
- Track ambiguities explicitly instead of silently resolving them.
- Separate proven behavior from migration assumptions.
- Record tables, columns, and side effects before proposing replacement APIs.
- When a JSF/XHTML page exists, start from the view and trace downward before proposing a migration slice.
- Distinguish vertical layer flow from horizontal same-layer coupling; both matter for migration risk.
- Keep one stable `.github/legacy/cases/<case-id>/` folder per feature slice and write regenerated raw outputs under `generated/<run-id>/`.
- Keep `analysis.md` compact by moving the detailed class inventory to `java-class-logic.md` and the Oracle inventory to `oracle-sql-inventory.md`.