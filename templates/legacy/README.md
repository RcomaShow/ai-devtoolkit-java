# Legacy Workspace Surface

Use this workspace-level folder for compact legacy analysis artifacts that should remain visible to Copilot and reproducible across sessions.

## Structure

```text
.github/legacy/
  templates/              canonical case templates and run metadata templates
  cases/<case-id>/        one stable folder per legacy feature slice
    case.json             stable manifest for the slice
    analysis.md           compact executive report
    java-class-logic.md   per-class logic inventory
    oracle-sql-inventory.md standard Oracle object inventory
    generated/<run-id>/   timestamped raw outputs for each regeneration pass
      run.json
      ...json / ddl / transient evidence...
```

## Rules

- Keep one stable `cases/<case-id>/` folder per legacy feature slice.
- Put regenerated raw outputs under `generated/<run-id>/` so multiple runs do not overwrite each other.
- Keep `analysis.md` compact and decision-oriented; move detailed class and Oracle inventories into their dedicated markdown files.
- Use lowercase `kebab-case` for `case-id` values.
- Keep secrets and credentials out of case files and generated evidence.