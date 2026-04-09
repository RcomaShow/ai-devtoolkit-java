# ai-devtoolkit-java

Generic AI agent toolkit for Java/Quarkus microservice workspaces. Provides reusable agents, skills, MCP documentation, a project initializer script, and workspace templates — so any new Java/Quarkus project starts with a complete, deterministic AI developer team in under 10 minutes.

---

## What Is This?

This toolkit is a **submodule** you add to a multi-repo Java workspace. It gives you:

| Asset | Location | Purpose |
|-------|----------|---------|
| Generic role agents | `agents/` | 8 pre-built agents covering every development role |
| Generic skills | `skills/` | 8 deterministic procedure libraries (patterns, checklists, templates) |
| MCP documentation | `mcp/` | Setup guides for Oracle, Bitbucket, SonarQube MCP servers |
| Project initializer | `scripts/new-project.mjs` | One command bootstraps a full workspace |
| Workspace templates | `templates/` | AGENTS.md, mcp.json starting points |
| Architecture guide | `docs/architecture.md` | 2026 SOTA bootstrap model explanation |

---

## Architecture Model (2026 SOTA)

```
One canonical location per asset type. No indirection.

.github/agents/      ← workspace-level agent definitions (Copilot)
.github/skills/      ← canonical skill procedures
.github/prompts/     ← prompt entry points
.ai/memory/          ← generated inventory only (workspace-map.json)
.claude/             ← Claude Code baseline adapter (placeholders)
.gemini/antigravity/ ← Gemini baseline adapter (placeholders)
.ai-devtoolkit/      ← this submodule (generic catalog source)
```

**Agent tiers:**
```
Tier 1 — Infrastructure:  bootstrap-workspace, agent-architect
Tier 2 — Orchestrator:    {domain}-orchestrator  (generated per project)
Tier 3 — Team Leads:      {domain}-{service}     (generated per repo)
Tier 4 — Role Agents:     software-architect, backend-engineer, api-designer,
                           database-engineer, tdd-validator, code-reviewer,
                           legacy-migration
```

---

## Quick Start

### 1 — Add as Git Submodule

```bash
git submodule add https://github.com/RcomaShow/ai-devtoolkit-java.git .ai-devtoolkit
git submodule update --init --recursive
```

### 2 — Initialize a New Project

```bash
node .ai-devtoolkit/scripts/new-project.mjs \
  --name my-domain \
  --domain "My Business Domain" \
  --repos "repo-core,repo-service-a,repo-service-b" \
  --package "com.company.mydomain" \
  --stack "quarkus+oracle"
```

This command:
- Copies all 8 generic role agents to `.github/agents/`
- Copies all 8 generic skills to `.github/skills/`
- Generates a domain orchestrator agent (`my-domain-orchestrator.agent.md`)
- Generates a team lead agent per repo (`my-domain-repo-core.agent.md`, etc.)
- Generates a companion skill stub per repo (`skills/my-domain-repo-core/SKILL.md`)
- Creates `AGENTS.md` workspace instructions
- Creates `package.json` with bootstrap scripts

Preview first without writing files:
```bash
node .ai-devtoolkit/scripts/new-project.mjs --name my-domain ... --dry-run
```

### 3 — Fill In Domain-Specific Details

After generation, edit these placeholders:

| File | What to fill in |
|------|----------------|
| `.github/agents/{name}-orchestrator.agent.md` | Domain overview, routing keywords |
| `.github/agents/{name}-{repo}.agent.md` | Bounded context description, key aggregates |
| `.github/skills/{name}-{repo}/SKILL.md` | Domain vocabulary, business rules, key queries |
| `AGENTS.md` | Final workspace instructions |

### 4 — Configure MCPs

Copy `templates/mcp.json.template` to `.vscode/mcp.json` and set environment variables:

```bash
# .env (never commit — add to .gitignore)
DB_USER=app_user
DB_PASS=secret
DB_HOST=db.company.internal
DB_PORT=1521
DB_SID=XEPDB1
BITBUCKET_URL=https://bitbucket.company.com
BITBUCKET_TOKEN=your-token
```

### 5 — Run Bootstrap

```bash
npm run bootstrap:ai          # workspace adapter setup
npm run bootstrap:ai:dry-run  # preview changes only
npm run bootstrap:agents:audit # verify all agents are complete
```

---

## Generic Agents (Tier 4 Role Agents)

These agents work in any Java/Quarkus project without modification:

| Agent | File | Role |
|-------|------|------|
| `software-architect` | `agents/software-architect.agent.md` | Clean Architecture, ADRs, layer enforcement |
| `backend-engineer` | `agents/backend-engineer.agent.md` | Quarkus resources, services, mappers, validators |
| `api-designer` | `agents/api-designer.agent.md` | OpenAPI 3.1 spec + REST contract review |
| `database-engineer` | `agents/database-engineer.agent.md` | Flyway migrations, Panache entities, Oracle schema |
| `tdd-validator` | `agents/tdd-validator.agent.md` | TDD workflow, JUnit 5 + Mockito, coverage audit |
| `test-coverage-engineer` | `agents/test-coverage-engineer.agent.md` | 100% branch coverage — path matrix + targeted tests |
| `code-reviewer` | `agents/code-reviewer.agent.md` | SOLID, OWASP Top 10, Quarkus best practices |
| `legacy-migration` | `agents/legacy-migration.agent.md` | JEE/JSF → Quarkus migration analysis |
| `agent-architect` | `agents/agent-architect.agent.md` | Creates new agents, skills, MCP configs |

---

## Generic Skills

Deterministic procedure libraries — no reasoning required, just follow the steps:

| Skill | File | Content |
|-------|------|---------|
| `quarkus-backend` | `skills/quarkus-backend/SKILL.md` | REST Resource, Service, MapStruct, Panache, Pagination, Async, Events, Multi-datasource |
| `clean-architecture` | `skills/clean-architecture/SKILL.md` | Layer rules, Port pattern, ADR template, violation checklist |
| `tdd-workflow` | `skills/tdd-workflow/SKILL.md` | JUnit 5 + Mockito 5, TDD cycle, ArgumentCaptor, Spy, Strict Stubs, Test Builders |
| `java-test-coverage` | `skills/java-test-coverage/SKILL.md` | Path enumeration matrix, 100% branch coverage, phase-by-phase test writing |
| `flyway-oracle` | `skills/flyway-oracle/SKILL.md` | Oracle migration patterns, 3-step NOT NULL, indexes, safe checklist |
| `api-design` | `skills/api-design/SKILL.md` | OpenAPI 3.1 structure, REST URL rules, RFC 7807 error schema |
| `domain-driven-design` | `skills/domain-driven-design/SKILL.md` | Aggregate, Value Object, Domain Service, Port, Domain Event patterns |
| `legacy-analysis` | `skills/legacy-analysis/SKILL.md` | 6-phase legacy reverse-engineering procedure |
| `agent-scaffolding` | `skills/agent-scaffolding/SKILL.md` | Agent catalog, templates for all 4 tiers, audit checklist |
| `quarkus-observability` | `skills/quarkus-observability/SKILL.md` | Structured logging, Micrometer metrics, OpenTelemetry tracing, SmallRye Health |
| `java-flow-analysis` | `skills/java-flow-analysis/SKILL.md` | AST-based impact analysis, call graph tracing, legacy EJB flow mapping |

---

## MCP Servers

Documentation for integrating live external systems:

| MCP | File | Status |
|-----|------|--------|
| `oracle-official` | `mcp/oracle-official.md` | Ready — SQLcl `-mcp` mode |
| `mssql-server` | `mcp/mssql-server.md` | Ready — `mssql-mcp-server` or `@azure/mcp` |
| `bitbucket-corporate` | `mcp/bitbucket-corporate.md` | Ready — `@garc33/bitbucket-server-mcp-server` |
| `sonarqube` | `mcp/sonarqube.md` | Proposed — `mcp-server-sonarqube` |

---

## Routing Decision Framework

```
Use an AGENT when:
  - Task requires domain reasoning or trade-off analysis
  - Multiple dependent steps (each output feeds the next)
  - Cross-service or cross-layer impact analysis
  - Expert judgment: architecture, legacy analysis, algorithm design

Read a SKILL when:
  - Task is a well-defined repeatable procedure
  - Scaffolding from templates (new agent, new migration)
  - Running an audit or verification checklist
  - Deterministic steps with known outcomes

Use an MCP when:
  - Live data needed before making a decision (DB schema, PR state, quality gate)
  - Validation against a real external system is required
  - oracle-official: before any DB schema change
  - bitbucket-corporate: before changes to shared branches
```

---

## Tech Stack Compatibility

This toolkit targets:

| Technology | Version |
|-----------|---------|
| Java | 21 (records, pattern matching, sealed types) |
| Quarkus | 3.x |
| RESTEasy | Reactive |
| Panache | Repository pattern (not Active Record) |
| MapStruct | 1.6 |
| Flyway | Oracle-compatible migrations |
| Oracle DB | 12c+ (sequence + NUMBER types) |
| Jakarta | Bean Validation 3.x, Persistence 3.x |
| Testing | JUnit 5 + Mockito 5 (NO @QuarkusTest) |

---

## Keeping the Toolkit Up to Date

```bash
# Pull latest from this repo into your workspace
git submodule update --remote .ai-devtoolkit

# After updating — re-run bootstrap to sync any new agents/skills
npm run bootstrap:ai
```

---

## Contributing

1. Generic agents and skills go here. Domain-specific content (project names, table names, business rules) stays in the workspace that uses this toolkit.
2. Keep agent bodies lean — deep knowledge belongs in companion skills.
3. All code patterns in skills must use `{placeholder}` syntax so they work in any project.
4. Test changes with `--dry-run` before committing.

---

## Scripts

| Script | Language | Purpose |
|--------|----------|---------|
| `scripts/new-project.mjs` | Node.js | Bootstrap a new workspace (copies agents/skills, generates orchestrator + team leads) |
| `scripts/analyze-java.py` | Python 3 | AST-based Java analysis: methods, branches, callers, impact set, test matrix |

### analyze-java.py

Requires: `pip install tree-sitter tree-sitter-language-pack`

```bash
# List all methods + branch count in a service class
python .ai-devtoolkit/scripts/analyze-java.py methods src/main/java/.../OrderService.java

# Find all callers of a method across the module
python .ai-devtoolkit/scripts/analyze-java.py callers src/main/java OrderService.create

# Change impact — what files reference OrderRepository?
python .ai-devtoolkit/scripts/analyze-java.py impact src/main/java OrderRepository

# Generate test coverage matrix — how many tests does each method need?
python .ai-devtoolkit/scripts/analyze-java.py test-matrix src/main/java/.../OrderService.java
```

## Guardrail Template

`templates/skill-guardrail.template.md` — use this to define constraints for any skill:
- Scope limiters (what the skill is NOT for)
- Input validators (required fields, rejected values)
- Output validators (what the output must contain)
- Safety rules (absolute never-do rules)
- Escalation triggers (when to stop and ask a human)
- Mutation budget (how many files the skill may write per run)

## Repository Structure

```
ai-devtoolkit-java/
├── agents/                       Generic role agent definitions (9 agents)
│   ├── software-architect.agent.md
│   ├── backend-engineer.agent.md
│   ├── api-designer.agent.md
│   ├── database-engineer.agent.md
│   ├── tdd-validator.agent.md
│   ├── test-coverage-engineer.agent.md   ← NEW: 100% branch coverage
│   ├── code-reviewer.agent.md
│   ├── legacy-migration.agent.md
│   └── agent-architect.agent.md
├── skills/                       Generic skill procedure libraries (11 skills)
│   ├── quarkus-backend/SKILL.md          REST, Service, Pagination, Async, Events
│   ├── clean-architecture/SKILL.md
│   ├── tdd-workflow/SKILL.md             + ArgumentCaptor, Spy, Strict Stubs, Builders
│   ├── java-test-coverage/SKILL.md       ← NEW: path matrix + systematic coverage
│   ├── flyway-oracle/SKILL.md
│   ├── api-design/SKILL.md
│   ├── domain-driven-design/SKILL.md
│   ├── legacy-analysis/SKILL.md
│   ├── agent-scaffolding/SKILL.md
│   ├── quarkus-observability/SKILL.md    ← NEW: logging, Micrometer, OpenTelemetry
│   └── java-flow-analysis/SKILL.md       ← NEW: AST impact + call graph analysis
├── mcp/                          MCP server setup guides
│   ├── oracle-official.md
│   ├── mssql-server.md                   ← NEW: SQL Server + Azure SQL
│   ├── bitbucket-corporate.md
│   └── sonarqube.md
├── scripts/
│   ├── new-project.mjs           Project initializer CLI
│   └── analyze-java.py           ← NEW: AST analysis (tree-sitter)
├── templates/
│   ├── AGENTS.md.template
│   ├── mcp.json.template
│   └── skill-guardrail.template.md       ← NEW: guardrail constraints template
├── docs/
│   └── architecture.md           Detailed architecture guide
└── README.md
```
