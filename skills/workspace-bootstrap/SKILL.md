---
name: workspace-bootstrap
description: 'Phase 1 workspace bootstrap for Copilot-first Java/Quarkus multi-repo workspaces. Creates or repairs the .github runtime, inventories repositories, and audits MCP safety. Use after adding the toolkit to a workspace.'
argument-hint: "Bootstrap action — e.g. 'workspace init', 'adapter repair', 'mcp security audit'"
user-invocable: false
---

# Workspace Bootstrap (Phase 1)

## When To Use
- First-time workspace initialization after adding `.ai-devtoolkit/`.
- Repairing the `.github` runtime baseline or pruning previously managed legacy adapter folders.
- Refreshing `.ai/memory/workspace-map.json` after repositories change.
- Auditing `.vscode/mcp.json` for missing env indirection or inline secrets.

## Skill Assets

- [Bootstrap engine](./scripts/bootstrap-ai-workspace.mjs)
- [MCP security audit](./scripts/audit-mcp-secrets.ps1)
- [Guardrails](./references/guardrails.md)
- [MCP guide](./references/mcp-guide.md)
- [Workspace readiness template](./assets/workspace-readiness.template.md)

## Procedure

1. Run the bootstrap engine.
2. Review the environment JSON, repository count, and any removed legacy paths.
3. Run the MCP security audit.
4. If repositories were added, follow with `bootstrap-project` Phase 2.
5. Record findings in `AI_BOOTSTRAP_IMPROVEMENTS.md`.

## Execution Entry Points

```bash
npm run bootstrap:ai
npm run bootstrap:ai:dry-run
npm run bootstrap:security:audit
```

## Checklist

- [ ] `.github/agents`, `.github/skills`, and `.github/prompts` exist
- [ ] `team-lead.agent.md` and `developer.agent.md` are the only public agents in `.github/agents/`
- [ ] `.ai/memory/workspace-map.json` is current
- [ ] `.vscode/mcp.json` uses `${env:...}` references for secrets
- [ ] `AI_BOOTSTRAP_IMPROVEMENTS.md` updated after review