---
name: bootstrap-project
description: 'Phase 2 project bootstrap. Verifies the public runtime surface, repo-context coverage, repo-memory coverage, agent catalog completeness, and MCP readiness. Run after workspace bootstrap to confirm the AI system is ready for delivery work.'
argument-hint: "Target: all (full check) or a specific repo name"
user-invocable: false
---

# Project Bootstrap (Phase 2)

## When To Use
- After Phase 1 workspace bootstrap completes.
- When a new repository is added to the workspace.
- Before a sprint or feature wave to verify repo-context coverage, repo-memory coverage, and MCP readiness.

## Skill Assets

- [Bootstrap project script](./scripts/bootstrap-project.ps1)
- [Guardrails](./references/guardrails.md)
- [Readiness report template](./assets/readiness-report.template.md)

## Procedure

1. Read `.ai/memory/workspace-map.json`.
2. Audit the agent catalog.
3. Verify `team-lead` and `developer` are the only public agents.
4. Verify every repository has a companion context skill.
5. Verify every repository has repo-memory files in `<repo>/.github/memory/`.
6. Verify MCP coverage and publish a readiness report.

## Execution Entry Points

```powershell
npm run bootstrap:project
.\.github\skills\bootstrap-project\scripts\bootstrap-project.ps1 -Repo <repo>
```

## Checklist

- [ ] Agent catalog audit passes
- [ ] `team-lead` and `developer` are the only public agents
- [ ] Each repository has a mapped context skill
- [ ] Each repository has `context.md`, `dependencies.md`, and `recent-changes.md` in `.github/memory/`
- [ ] Required MCP servers are configured
- [ ] Action items recorded for any uncovered repo