---
name: repo-memory
description: 'File-based repository memory for compact stable facts, dependency refresh, and recent-change rehydration in multi-repo Java/Quarkus workspaces.'
argument-hint: "Repo memory action — e.g. 'refresh all repos', 'refresh service-a', 'review repo memory contract'"
user-invocable: false
---

# Repo Memory

## When To Use
- Before a multi-step task in a specific repository when you need fast context rehydration.
- After structural changes, dependency updates, interface changes, or migration discoveries.
- When chat history is getting noisy and you need compact repo-local memory instead of repeating the same context.

## Memory Contract

Each repository may own a compact memory surface under `<repo>/.github/memory/`:

- `context.md` — stable developer-owned facts, traps, and entry points.
- `dependencies.md` — generated technical map for modules, integrations, Kafka signals, DB signals, and legacy UI traces.
- `recent-changes.md` — generated compact summary of recent commits and current working-tree changes.

This layer complements, not replaces, the companion repo-context skill in `.github/skills/<workspace>-<repo>/`.

Use the split consistently:
- Repo-context skill = durable rules and vocabulary.
- Repo memory = compact operational context that changes more often.
- `.ai/memory/` = generated workspace inventory only.

## Execution Entry Points

```bash
npm run memory:refresh
node .github/skills/repo-memory/scripts/refresh-repo-memory.mjs --all
node .github/skills/repo-memory/scripts/refresh-repo-memory.mjs --repo service-a
```

## Procedure

1. Identify the repository from `.ai/memory/workspace-map.json` or the task scope.
2. Read the companion repo skill first for durable business rules.
3. Read only the repo-memory files needed for the current task.
4. Refresh repo memory if the files are missing or stale.
5. Update `context.md` only for stable facts that should survive the next conversation.

## Token-Economy Rules

- Prefer repo-memory summaries over pulling large analysis documents into context.
- Keep `context.md` short enough to scan in one pass.
- Keep `recent-changes.md` newest-first and compact.
- Do not paste generic Quarkus, Java, Kafka, or testing rules into repo memory when a shared skill already owns them.
- If a fact only matters for the active task and will age quickly, keep it in `recent-changes.md`, not in `context.md`.

## Skill Assets

- [Refresh script](./scripts/refresh-repo-memory.mjs)
- [Guardrails](./references/guardrails.md)
- [Context template](./assets/context.template.md)

## Checklist

- [ ] Repo skill exists for the repository
- [ ] `context.md` exists and stays compact
- [ ] `dependencies.md` reflects the current technical surface
- [ ] `recent-changes.md` reflects recent commits and working-tree deltas
- [ ] Repo memory does not duplicate shared skill content