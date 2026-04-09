# Bootstrap Architecture — 2026 SOTA

## Principle

**One canonical location per asset type. No indirection layers.**

| Asset | Canonical Location | Owner |
|-------|--------------------|-------|
| Agents | `.github/agents/*.agent.md` | Workspace (Copilot-first) |
| Skills | `.github/skills/<name>/SKILL.md` | Workspace |
| Prompts | `.github/prompts/*.prompt.md` | Workspace |
| Bootstrap memory | `.ai/memory/*.json` | Bootstrap script (generated) |
| Toolkit source | `.ai-devtoolkit/` | This submodule |
| Claude adapter | `.claude/` | Baseline — placeholders unless Claude is active |
| Gemini adapter | `.gemini/antigravity/` | Baseline — placeholders unless Gemini is active |

---

## Two-Phase Bootstrap

### Phase 1 — Workspace Bootstrap

**Scope**: workspace root, adapter baselines, agent catalog.  
**Command**: `npm run bootstrap:ai`

1. Detect environment (active processes + adapter folders present).
2. Detect repositories (`.git/` in top-level folders).
3. Ensure `.ai/memory/` exists.
4. Ensure `.github/` canonical directories exist.
5. Ensure `.claude/` and `.gemini/antigravity/` baseline adapters exist.
6. Scaffold missing catalog agents from toolkit source.
7. Mirror agents/skills to active adapters or create placeholders.
8. Write inventory to `.ai/memory/workspace-map.json`.
9. Report detection JSON and all filesystem changes.

### Phase 2 — Project Bootstrap

**Scope**: per-repo team lead assignment, SonarQube context, MCP coverage.  
**Command**: `npm run bootstrap:project`

1. Read `workspace-map.json` to enumerate repos.
2. Verify agent catalog (all Tier 3 team leads present).
3. Map each repo to its team lead agent.
4. Verify MCP coverage for project needs.
5. Generate project readiness report.

---

## New Project Initialization

**Command**: `node .ai-devtoolkit/scripts/new-project.mjs --name ... --domain ... --repos ...`

This is a **one-time** initialization that runs before Phase 1. It:
1. Copies generic role agents (Tier 4) from toolkit to `.github/agents/`.
2. Copies generic skills from toolkit to `.github/skills/`.
3. Generates the domain orchestrator agent (Tier 2).
4. Generates team lead agents per repo (Tier 3) with placeholder companion skills.
5. Creates `AGENTS.md` and `package.json`.

After initialization, run Phase 1 bootstrap to wire up adapter baselines.

---

## Environment Detection

```json
{
  "mode": "IDE | TERMINAL | HYBRID",
  "primary_tool": "copilot | claude | cursor | gemini | codex",
  "secondary_tools": []
}
```

**Rules:**
- Active processes take priority over installed adapter folders.
- Detection runs **before** adapter creation (never measure what you are about to mutate).
- `primary_tool` drives which adapters get full mirroring.
- If no active process is detectable, installed adapter folders are the fallback hint.

---

## Adapter Behavior

| Adapter | Default (Copilot-first) | When Claude active | When Gemini active |
|---------|------------------------|--------------------|--------------------|
| `.github/agents/` | Canonical `.agent.md` | Same | Same |
| `.claude/agents/` | `README.md` placeholder | Real copies from `.github/agents/` | Placeholder |
| `.gemini/antigravity/agents/` | `README.md` placeholder | Placeholder | Real copies |

Mirroring is triggered by:
- `primary_tool` or `secondary_tools` containing the adapter's tool.
- Explicit `--shared-agents` flag on the bootstrap command.

---

## Agent Body Contract

Every `.agent.md` file must follow this structure:

```
Frontmatter (YAML between --- markers)
  name, description, tools, model, effort, argument-hint, agents, user-invocable

Body sections (in order):
  1. Role statement (one sentence: "You are the X for Y")
  2. Skill References table (when to read which skill)
  3. Responsibilities (bullet list)
  4. Constraints (hard rules — "never", "always")
  5. Output Format (structured keys callers can depend on)
```

**Key design rule**: Agent bodies stay lean. Deep knowledge (code patterns, checklists, SQL templates) lives in companion skills, not in the agent body.

---

## Skill Contract

Every `SKILL.md` follows this structure:

```
Frontmatter (YAML between --- markers)
  name, description, argument-hint, user-invocable

Body sections:
  ## Context       — what problem domain this covers
  ## Key Concepts  — vocabulary, abbreviations
  ## Patterns      — code patterns, templates (with {placeholders})
  ## Rules         — hard constraints
  ## Checklist     — [ ] items for validation
```

Skills use `{placeholder}` syntax in code patterns so they work generically. When a project uses them, the agent fills placeholders with real names.

---

## MCP Decision Tree

```
Is live external data needed before making the decision?
  NO  → Use built-in read/search/execute tools
  YES ↓
Does the data change frequently (schema, PRs, metrics)?
  NO  → Document it in a skill reference file
  YES ↓
Can built-in tools access it?
  YES → Use built-in tools
  NO  ↓
Is an MCP server available for this system?
  YES → Add to .vscode/mcp.json, document in mcp/ folder
  NO  → Build or find a community MCP server
```

Available MCPs: `oracle-official`, `bitbucket-corporate`  
Proposed: `sonarqube` (see `mcp/sonarqube.md`)

---

## Validation Checklist

After any bootstrap run, verify:

- [ ] All 8 generic role agents present in `.github/agents/`
- [ ] Domain orchestrator agent present in `.github/agents/`
- [ ] One team lead agent per repo present in `.github/agents/`
- [ ] One companion skill per team lead present in `.github/skills/`
- [ ] No agents in `.ai/agents/` (only `.github/agents/` is canonical)
- [ ] Instructions use `AGENTS.md` at root — no `.github/copilot-instructions.md`
- [ ] `.claude/agents/` contains README placeholder (not real agents, unless Claude is active)
- [ ] `.gemini/antigravity/agents/` contains README placeholder
- [ ] Environment detection reflects active processes, not just adapter folders
- [ ] `oracle-official` configured in `.vscode/mcp.json`
- [ ] `bitbucket-corporate` configured in `.vscode/mcp.json`

---

## Updating the Toolkit

```bash
# Pull latest toolkit changes from GitHub
git submodule update --remote .ai-devtoolkit

# Re-run bootstrap to sync new agents or skills
npm run bootstrap:ai

# Preview what would change before running
npm run bootstrap:ai:dry-run
```

When this toolkit is updated with new generic agents or skills, the bootstrap script detects which workspace agents are missing and adds them. Existing customized agents are never overwritten (they appear as `skipped-existing`).

---

## File Ownership Model

| File | Owned By | Bootstrap Behavior |
|------|----------|--------------------|
| `.github/agents/*.agent.md` (generic) | Toolkit → copied once | Never overwritten after first copy |
| `.github/agents/{name}-*.agent.md` (domain) | Developer | Bootstrap never touches these |
| `.github/skills/<name>/SKILL.md` (generic) | Toolkit → copied once | Never overwritten after first copy |
| `.github/skills/{name}-*/SKILL.md` (domain) | Developer | Bootstrap never touches these |
| `.ai/memory/*.json` | Bootstrap script | Always regenerated |
| `AGENTS.md` | Developer | Created once, then developer owns |
| `.vscode/mcp.json` | Developer | Template provided, developer configures |
