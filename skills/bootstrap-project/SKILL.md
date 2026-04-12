---
name: bootstrap-project
description: 'Phase 2 project bootstrap. Verifies single public team-lead exposure, repo-context coverage, agent catalog completeness, and MCP readiness. Run after workspace bootstrap to confirm the AI system is ready for delivery work.'
argument-hint: "Target: all (full check) or a specific repo name"
user-invocable: false
---

# Project Bootstrap (Phase 2)

## When To Use
- After Phase 1 workspace bootstrap completes.
- When a new repository is added to the workspace.
- Before a sprint or feature wave to verify repo-context coverage and MCP readiness.

## Skill Assets

- [Bootstrap project script](./scripts/bootstrap-project.ps1)
- [Guardrails](./references/guardrails.md)
- [Readiness report template](./assets/readiness-report.template.md)

## Procedure

1. Read `.ai/memory/workspace-map.json`.
2. Audit the agent catalog.
3. Verify `team-lead` is the only public agent.
4. Verify every repository has a companion context skill.
5. Verify MCP coverage and publish a readiness report.

## Execution Entry Points

```powershell
npm run bootstrap:project
.\.github\skills\bootstrap-project\scripts\bootstrap-project.ps1 -Repo <repo>
```

## Checklist

- [ ] Agent catalog audit passes
- [ ] `team-lead` is the only public agent
- [ ] Each repository has a mapped context skill
- [ ] Required MCP servers are configured
- [ ] Action items recorded for any uncovered repo