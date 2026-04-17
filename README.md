# ai-devtoolkit-java

Copilot-first AI development toolkit for Java 17/21 + Quarkus workspaces. It is designed around two public agents by capability tier, hidden specialist delegation, self-contained skills, file-based repository memory, and a multi-repo bootstrap that stays generic instead of baking project-specific public agents into the runtime.

**Current version:** see [`VERSION`](VERSION) — changelog in [`CHANGELOG.md`](CHANGELOG.md).

---

## What This Toolkit Provides

| Asset | Location | Purpose |
|-------|----------|---------|
| Public agents | `agents/team-lead.agent.md`, `agents/developer.agent.md` | Premium orchestration plus compact direct execution |
| Internal specialists | `agents/` | Hidden architecture, implementation, migration, DB, testing, and review specialists |
| Self-contained skills | `skills/` | Reusable procedures with colocated references, assets, and scripts |
| Workflows | `workflows/` | Analyze -> plan -> execute -> review -> fix -> finalize flows |
| Bootstrap engine | `skills/workspace-bootstrap/scripts/bootstrap-ai-workspace.mjs` | Copilot runtime setup and workspace inventory |
| Project generator | `scripts/new-project.mjs` | Multi-repo workspace initializer with repo-context skills and repo-memory scaffolding |
| Legacy workspace surface | `templates/legacy/` | Standard `.github/legacy/` layout for compact legacy reports, per-class logic, and Oracle SQL inventories |
| Toolkit health | `skills/toolkit-health/` | Self-audit: drift detection, orphan scan, broken-ref check, skill-gap analysis |
| MCP guides | `mcp/` | Oracle, Bitbucket, SonarQube setup guidance |

The source catalog keeps these assets under `templates/legacy/`; project initialization materializes them into `.github/legacy/` in the runtime catalog.

---

## Runtime Model

The active runtime is intentionally simple:

```text
.github/agents/      ← runtime agents copied into the workspace
.github/skills/      ← runtime skills copied into the workspace
.github/prompts/     ← runtime prompt entry points
.github/bootstrap/control-plane.json ← declarative shell-target and MCP policy
.github/memory/workspace-shell.md ← developer-owned shell memory for cross-repo facts
.github/legacy/      ← standard legacy-analysis workspace surface and generated case folders
.ai/memory/          ← generated inventory only
<repo>/.github/memory/ ← compact repository memory (stable facts + live technical context)
.ai-devtoolkit/      ← reusable source catalog (this submodule)
```

Key rules:
- Public surface stays minimal: `team-lead` for premium orchestration, `developer` for bounded direct execution.
- Specialist agents stay hidden and are invoked internally.
- Repository-specific knowledge is split between repo-context skills for durable rules and `<repo>/.github/memory/` for compact live context.
- Non-git services belong in `managedTargets` in `.github/bootstrap/control-plane.json`, not in the generated `repositories` list.
- Managed shell targets without repo-local memory should use `.github/memory/workspace-shell.md` and `.github/bootstrap/control-plane.json` instead of `<repo>/.github/memory/`.
- `.ai/memory/` remains generated workspace inventory only; it is not the place for repo notes or business rules.
- Bootstrap stays multi-repo, but it no longer generates a public catalog per repository.
- `.ai/memory/workspace-map.json` is root-scoped today; it does not represent a whole VS Code multi-root session.
- Shell-level durable facts live in `.github/memory/workspace-shell.md`; keep repo-specific facts in repo-local memory.
- Treat `.ai/memory/mcp-registry.json` as a generated mirror of `.vscode/mcp.json`, and refresh it after MCP configuration changes.

---

## Operational Caveats

- `team-lead` may use a fast path only for trivial read-only questions, repo-memory refresh, or bootstrap checks. Anything non-trivial should still use the fixed `context-optimizer -> orchestrator -> execution -> verification -> review` chain.
- Do not overload `repo` to mean only `folder with .git`. Non-git services should be declared as managed shell targets unless they explicitly need repo-local context.
- Separate baseline required MCPs from optional task-scoped servers. Example: `oracle-official` and `bitbucket-corporate` can be baseline, while `mssql-server` remains optional for Oracle -> T-SQL or SQL Server target validation.

---

## Quick Start

### 1. Add the toolkit as a submodule

```bash
git submodule add https://github.com/RcomaShow/ai-devtoolkit-java.git .ai-devtoolkit
git submodule update --init --recursive
```

### 2. Initialize a workspace

```bash
node .ai-devtoolkit/scripts/new-project.mjs \
  --name my-domain \
  --domain "My Business Domain" \
  --repos "repo-core,repo-service-a,repo-service-b" \
  --managed-targets "shell-service-a,shell-service-b" \
  --package "com.company.mydomain" \
  --stack "quarkus+oracle" \
  --java 17
```

This command:
- copies the generic agent catalog into `.github/agents/`
- copies the self-contained skill catalog into `.github/skills/`
- creates `team-lead` and `developer` as the only public agents
- generates one repo-context skill per repository in `.github/skills/{name}-{repo}/`
- scaffolds `<repo>/.github/memory/` for repositories that already exist in the workspace
- scaffolds `.github/bootstrap/control-plane.json` and `.github/memory/workspace-shell.md`
- scaffolds `.github/legacy/` as the standard workspace surface for legacy analysis cases
- materializes `.vscode/mcp.env.template.json` for structured local MCP configuration
- creates `AGENTS.md` and `package.json`

Preview first:

```bash
node .ai-devtoolkit/scripts/new-project.mjs --name my-domain ... --dry-run
```

### 3. Fill in repository context

After generation, edit:

| File | What to fill in |
|------|-----------------|
| `.github/skills/{name}-{repo}/SKILL.md` | repository responsibilities, vocabulary, key rules |
| `.github/skills/{name}-{repo}/references/guardrails.md` | repository-specific guardrails |
| `<repo>/.github/memory/context.md` | compact stable facts, entry points, traps, and migration notes |
| `.github/memory/workspace-shell.md` | shell-level operating facts, managed non-repo targets, and MCP notes |
| `.github/legacy/` | standard location for compact legacy reports, Oracle inventories, and generated evidence |
| `AGENTS.md` | workspace operating rules |

Then refresh the generated repo-memory files:

```bash
npm run memory:refresh
```

That command refreshes:
- `<repo>/.github/memory/dependencies.md`
- `<repo>/.github/memory/recent-changes.md`

These files are intentionally compact so agents can load them before large tasks without wasting tokens.

### 4. Configure MCPs

Copy `.ai-devtoolkit/templates/mcp.json.template` to `.vscode/mcp.json` and keep secrets in environment variables only.
Use `.vscode/mcp.env.template.json` as the local structured JSON template for MCP secrets and connection strings.
Keep baseline required MCPs and optional task-scoped MCPs in `.github/bootstrap/control-plane.json`.
If you add or remove MCP servers, rerun `npm run bootstrap:ai` before trusting `.ai/memory/mcp-registry.json` or any readiness report that depends on it.

### 5. Initialize a legacy case when needed

```powershell
npm run legacy:case -- --case verifica-capacita --title "Verifica Capacita" --entrypoint <path-to-view>\verificaCapacita.xhtml --sourceRoot <path-to-legacy-module-root>
```

Stable case documents stay in `.github/legacy/cases/<case-id>/`. Regenerated raw artifacts go in `.github/legacy/cases/<case-id>/generated/<run-id>/`.

To force a full XHTML -> Java -> DB scan in one command and persist the raw graph in the current run folder:

```powershell
npm run legacy:analyze:xhtml -- --case verifica-capacita --title "Verifica Capacita" --entrypoint <path-to-view>\verificaCapacita.xhtml --sourceRoot <path-to-legacy-module-root>
```

### 6. Run bootstrap

```bash
npm run bootstrap:ai
npm run bootstrap:ai:dry-run
npm run bootstrap:security:audit
npm run bootstrap:agents:audit
npm run bootstrap:project
npm run memory:refresh
```

---

## Public And Internal Agents

### Public

| Agent | Role |
|-------|------|
| `team-lead` | Premium orchestration for broad or multi-step work with hidden specialist delegation |
| `developer` | Focused bounded development with a fixed Plan -> Implement -> Review protocol and mandatory review re-entry |

### Model Profiles

| Agent | Model family | Default effort | Notes |
|-------|--------------|----------------|-------|
| `team-lead` | `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6`, `Claude Opus 4.6` | `high` | Premium models for orchestration |
| `developer` | Inherits active picker/default | `medium` | Best for focused coding; fixed Plan -> Implement -> Review flow with mandatory review re-entry |
| Specialists | `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6` | varies | Internal agents for focused domain work |

If you need a specific depth, ask explicitly for `effort low`, `effort medium`, or `effort high` in the prompt.

Contract semantics for public agents are defined by `.github/copilot-instructions.md` in the runtime catalog and by `.ai-devtoolkit/adapters/github-copilot/copilot-instructions.md` in the source catalog.

### Internal Specialists

| Agent | Role |
|-------|------|
| `memory-manager` | Repository memory refresh and staleness detection |
| `context-optimizer` | Context compression and selective loading |
| `software-architect` | Architecture analysis, ADRs, boundary decisions |
| `backend-engineer` | Quarkus implementation |
| `api-designer` | API contracts and DTO design |
| `database-engineer` | Flyway, Oracle, persistence design |
| `legacy-migration` | Legacy reverse-engineering and migration |
| `tdd-validator` | TDD and regression protection |
| `test-coverage-engineer` | Branch-coverage closure |
| `code-reviewer` | Review and risk detection |
| `bootstrap-workspace` | Workspace bootstrap and inventory repair |
| `agent-architect` | Catalog, workflow, MCP maintenance, and self-evolution |
| `orchestrator` | Hidden planner-router for the fixed development phase chain |

---

## Skills And Workflows

Skills remain self-contained deployment units:

```text
skills/<skill-name>/
├── SKILL.md
├── references/
├── assets/
└── scripts/
```

Representative skills:
- `quarkus-backend`
- `quarkus-dev`
- `fetch-api`
- `quarkus-logs-analyzer`
- `postman-collections`
- `clean-architecture`
- `tdd-workflow`
- `java-test-coverage`
- `java-flow-analysis`
- `repo-memory`
- `flyway-oracle`
- `legacy-analysis`
- `workspace-bootstrap`
- `bootstrap-project`
- `toolkit-health`
- `agent-scaffolding`

Core workflows used by `team-lead`:
- `feature-implementation`
- `bugfix`
- `refactor`
- `optimization`
- `legacy-gap-analysis`
- `legacy-migration`
- `test-coverage`

---

## Tech Stack Compatibility

| Technology | Version |
|-----------|---------|
| Java | 17 baseline, 21 optimized profile |
| Quarkus | 3.x |
| Kafka | SmallRye Reactive Messaging / Kafka-ready patterns |
| RESTEasy | Reactive |
| Panache | Repository pattern |
| MapStruct | 1.6 |
| Flyway | Oracle-compatible migrations |
| Oracle DB | 12c+ |
| Testing | JUnit 5 + Mockito 5 |

---

## Design Principles

1. Keep the public surface minimal.
2. Keep deep knowledge in skills, not in agent bodies.
3. Use workflows for multi-step operating loops.
4. Split repo context cleanly: skills hold durable rules, repo memory holds compact live context.
5. Use file-based context compression before widening the prompt: read the smallest useful memory set first.
6. Preserve multi-repo bootstrap without reintroducing public agent sprawl.
7. Separate generated topology from curated shell context.
8. Make fast-path exceptions and optional MCPs explicit instead of implicit.

---

## Updating The Toolkit

```bash
git submodule update --remote .ai-devtoolkit
npm run bootstrap:ai
npm run memory:refresh
```

When the toolkit changes, re-run bootstrap and the agent audit to keep the workspace runtime aligned.

Agent naming note: toolkit agents now rely on filename-based names by default. Avoid custom `name:` aliases in shared assets unless the alias exactly matches the filename.

To run a toolkit self-audit:

```bash
.ai-devtoolkit/skills/toolkit-health/scripts/audit-toolkit-health.ps1 -Full
```