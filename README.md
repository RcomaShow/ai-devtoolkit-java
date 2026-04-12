# ai-devtoolkit-java

Copilot-first AI development toolkit for Java 17/21 + Quarkus workspaces. It is designed around one public agent, hidden specialist delegation, self-contained skills, reusable workflows, and a multi-repo bootstrap that stays generic instead of baking project-specific public agents into the runtime.

---

## What This Toolkit Provides

| Asset | Location | Purpose |
|-------|----------|---------|
| Public entrypoint | `agents/team-lead.agent.md` | Single public Copilot agent for intake, routing, review, and fix loops |
| Internal specialists | `agents/` | Hidden architecture, implementation, migration, DB, testing, and review specialists |
| Self-contained skills | `skills/` | Reusable procedures with colocated references, assets, and scripts |
| Workflows | `workflows/` | Analyze -> plan -> execute -> review -> fix -> finalize flows |
| Bootstrap engine | `skills/workspace-bootstrap/scripts/bootstrap-ai-workspace.mjs` | Copilot runtime setup and workspace inventory |
| Project generator | `scripts/new-project.mjs` | Multi-repo workspace initializer with repo-context skill generation |
| MCP guides | `mcp/` | Oracle, Bitbucket, SonarQube setup guidance |

---

## Runtime Model

The active runtime is intentionally simple:

```text
.github/agents/      ← runtime agents copied into the workspace
.github/skills/      ← runtime skills copied into the workspace
.github/prompts/     ← runtime prompt entry points
.ai/memory/          ← generated inventory only
.ai-devtoolkit/      ← reusable source catalog (this submodule)
```

Key rules:
- `team-lead` is the only public agent.
- Specialist agents stay hidden and are invoked internally.
- Repository-specific knowledge lives in repo-context skills, not in extra public agents.
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
- keeps `team-lead` as the only public agent
- generates one repo-context skill per repository in `.github/skills/{name}-{repo}/`
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
| `AGENTS.md` | workspace operating rules |

### 4. Configure MCPs

Copy `templates/mcp.json.template` to `.vscode/mcp.json` and keep secrets in environment variables only.

### 5. Run bootstrap

```bash
npm run bootstrap:ai
npm run bootstrap:ai:dry-run
npm run bootstrap:security:audit
npm run bootstrap:agents:audit
npm run bootstrap:project
```

---

## Public And Internal Agents

### Public

| Agent | Role |
|-------|------|
| `team-lead` | Single public entrypoint for features, bugfixes, refactors, optimization, migration, testing, bootstrap, and toolkit maintenance |

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
- `clean-architecture`
- `tdd-workflow`
- `java-test-coverage`
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
4. Store repo-specific context in skills, not in public agents.
5. Preserve multi-repo bootstrap without reintroducing public agent sprawl.

---

## Updating The Toolkit

```bash
git submodule update --remote .ai-devtoolkit
npm run bootstrap:ai
```

When the toolkit changes, re-run bootstrap and the agent audit to keep the workspace runtime aligned.