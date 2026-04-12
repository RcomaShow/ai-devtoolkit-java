# Copilot-First Toolkit Architecture

## Principle

Keep the runtime surface narrow and the operating system deep.

- One public agent: `team-lead`
- Hidden specialists for architecture, implementation, review, DB, migration, and bootstrap
- Repo-context skills instead of repo-specific public agents
- `.github/` as the only active runtime root
- `.ai/memory/` as generated inventory only

---

## Canonical Layout

```text
.github/agents/      ← runtime agents
.github/skills/      ← runtime skills
.github/prompts/     ← runtime prompts
.ai/memory/          ← generated inventory and MCP registry
.ai-devtoolkit/      ← reusable source catalog
```

The toolkit is copied into `.github/` by initialization and then maintained through bootstrap and catalog audit scripts.

---

## Runtime Contract

### Public surface

`team-lead` is the only public Copilot agent.

Responsibilities:
- classify the user request
- inspect the workspace before committing to a plan
- choose the right workflow or hidden specialist
- run review and fix loops until the result is coherent
- summarize outcome, validation, and remaining risks

### Internal surface

All other agents are hidden specialists. They can be added to `team-lead` delegation lists, but they are not meant to be invoked directly by default.

### Repo knowledge model

Repository-specific context is encoded as skills:

```text
.github/skills/<workspace>-<repo>/
  SKILL.md
  references/guardrails.md
  assets/domain-rule.template.md
```

This preserves multi-repo bootstrap without multiplying the visible agent catalog.

---

## Initialization Flow

## Phase 0 — New Project Initialization

Command:

```bash
node .ai-devtoolkit/scripts/new-project.mjs --name ... --domain ... --repos ...
```

Effects:
1. Copy generic agents into `.github/agents/`
2. Copy generic self-contained skills into `.github/skills/`
3. Keep `team-lead` as the only public agent
4. Generate repo-context skills for each repository
5. Create `AGENTS.md` and `package.json`

## Phase 1 — Workspace Bootstrap

Command:

```bash
npm run bootstrap:ai
```

Effects:
1. Detect runtime mode
2. Ensure `.github/agents`, `.github/skills`, and `.github/prompts` exist
3. Prune previously managed legacy adapter paths when present
4. Refresh `.ai/memory/workspace-map.json`
5. Refresh `.ai/memory/mcp-registry.json`

## Phase 2 — Project Readiness Audit

Command:

```bash
npm run bootstrap:project
```

Checks:
1. Agent catalog completeness
2. `team-lead` is the only public agent
3. Each repository has a repo-context skill
4. Required MCP servers are configured

---

## Environment Inventory

The bootstrap inventory writes this environment shape:

```json
{
  "mode": "IDE | TERMINAL",
  "primary_tool": "copilot",
  "secondary_tools": []
}
```

The runtime is intentionally Copilot-only. Older adapter roots may still exist in historical workspaces, but the active architecture no longer depends on them.

---

## File Ownership

| File or folder | Owner | Behavior |
|----------------|-------|----------|
| `.github/agents/*.agent.md` | workspace runtime | copied from toolkit, then developer-owned |
| `.github/skills/<name>/` | workspace runtime | copied from toolkit, then developer-owned |
| `.github/skills/<workspace>-<repo>/` | developer | generated once, then repository-context owned |
| `.ai/memory/*.json` | bootstrap engine | regenerated |
| `AGENTS.md` | developer | created once, then developer-owned |
| `.vscode/mcp.json` | developer | manually configured |

---

## Validation Checklist

- [ ] `.github/agents`, `.github/skills`, and `.github/prompts` exist
- [ ] `team-lead.agent.md` exists in `.github/agents/`
- [ ] `team-lead` is the only public agent
- [ ] Hidden specialists exist for architecture, implementation, review, DB, migration, and bootstrap
- [ ] Each repository has a repo-context skill folder
- [ ] `.ai/memory/workspace-map.json` is current
- [ ] `.vscode/mcp.json` uses `mcpServers` and environment variables
- [ ] `npm run bootstrap:agents:audit` passes
- [ ] `npm run bootstrap:project` passes

---

## Why This Shape

This architecture keeps the Copilot user experience simple while preserving a strong internal operating system:

- less catalog noise for the user
- reusable specialist knowledge retained internally
- deterministic workflows for non-trivial work
- generic bootstrap preserved for new multi-repo workspaces
- no project-specific public routing model baked into the toolkit