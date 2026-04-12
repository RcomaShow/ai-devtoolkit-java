# Repo Memory Guardrails

- Keep repo memory inside `<repo>/.github/memory/`; do not duplicate the workspace runtime there.
- Keep business rules in the companion repo skill unless they are truly repository-local operational facts.
- Keep `context.md` compact and curated by humans.
- Treat `dependencies.md` and `recent-changes.md` as generated files; refresh them instead of hand-editing them when possible.
- Do not store secrets, tokens, passwords, or raw credentials in repo memory.
- Prefer stable identifiers, topic names, artifact names, and file paths over long prose.
- If a repo already owns more `.github` assets, add memory alongside them without overwriting existing files.