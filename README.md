# ai-devtoolkit-java

Copilot-first AI development toolkit for Java 17/21 + Quarkus workspaces. It is designed around two public agents by capability tier, hidden specialist delegation, self-contained skills, file-based repository memory, and a multi-repo bootstrap that stays generic instead of baking project-specific public agents into the runtime.

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
| MCP guides | `mcp/` | Oracle, Bitbucket, SonarQube setup guidance |

---

## Runtime Model

The active runtime is intentionally simple:

```text
.github/agents/      ← runtime agents copied into the workspace
.github/skills/      ← runtime skills copied into the workspace
.github/prompts/     ← runtime prompt entry points
.ai/memory/          ← generated inventory only
<repo>/.github/memory/ ← compact repository memory (stable facts + live technical context)
.ai-devtoolkit/      ← reusable source catalog (this submodule)
```

Key rules:
- Public surface stays minimal: `team-lead` for premium orchestration, `developer` for bounded direct execution.
- Specialist agents stay hidden and are invoked internally.
- Repository-specific knowledge is split between repo-context skills for durable rules and `<repo>/.github/memory/` for compact live context.
- `.ai/memory/` remains generated workspace inventory only; it is not the place for repo notes or business rules.
- Bootstrap stays multi-repo, but it no longer generates a public catalog per repository.

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

Copy `templates/mcp.json.template` to `.vscode/mcp.json` and keep secrets in environment variables only.

### 5. Run bootstrap

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
| `developer` | Direct execution for smaller paid models on bounded tasks without sub-agent delegation |

### Model Profiles

| Agent | Model family | Default effort | Notes |
|-------|--------------|----------------|-------|
| `team-lead` | `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6`, `Claude Opus 4.6` | `high` | Best for architecture, routing, deep review/fix loops |
| `developer` | `GPT-5.4 Mini`, `Claude Haiku 4.5` | `medium` | Best for focused coding and local verification |

If you need a specific depth, ask explicitly for `effort low`, `effort medium`, or `effort high` in the prompt.

### Internal Specialists

| Agent | Role |
|-------|------|
| `software-architect` | Architecture analysis, ADRs, boundary decisions |
| `backend-engineer` | Quarkus implementation |
| `api-designer` | API contracts and DTO design |
| `database-engineer` | Flyway, Oracle, persistence design |
| `legacy-migration` | Legacy reverse-engineering and migration |
| `tdd-validator` | TDD and regression protection |
| `test-coverage-engineer` | Branch-coverage closure |
| `code-reviewer` | Review and risk detection |
| `bootstrap-workspace` | Workspace bootstrap and inventory repair |
| `agent-architect` | Catalog, workflow, and MCP maintenance |
| `orchestrator` | Hidden compatibility router |

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

Core workflows used by `team-lead`:
- `feature-implementation`
- `bugfix`
- `refactor`
- `optimization`
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

---

## Updating The Toolkit

```bash
git submodule update --remote .ai-devtoolkit
npm run bootstrap:ai
npm run memory:refresh
```

When the toolkit changes, re-run bootstrap and the agent audit to keep the workspace runtime aligned.