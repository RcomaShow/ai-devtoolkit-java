---
name: agent-scaffolding
description: 'Agent catalog audit and scaffolding for Copilot-first Java/Quarkus workspaces. Validates frontmatter, public-surface rules, companion skills, repo-memory coverage, and context discipline.'
argument-hint: "Audit or scaffold action — e.g. 'audit agents', 'add internal specialist', 'create repo context skill'"
user-invocable: false
---

# Agent Scaffolding — Catalog and Templates

## Runtime Catalog

### Public Surface
| Agent | Effort | Role |
|-------|--------|------|
| `team-lead` | high | Premium orchestration for intake, routing, review, and fix loops |
| `developer` | medium | Focused bounded development with a fixed Plan -> Implement -> Review protocol |

### Internal Specialists
| Agent | Effort | Role |
|-------|--------|------|
| `memory-manager` | medium | Repository memory refresh and staleness detection |
| `context-optimizer` | low | Context compression and selective loading |
| `bootstrap-workspace` | high | Workspace bootstrap and inventory repair |
| `agent-architect` | high | Catalog and toolkit maintenance |
| `orchestrator` | medium | Hidden planner-router for the fixed development phase chain |
| `software-architect` | high | Architecture, boundaries, ADRs |
| `backend-engineer` | medium | Quarkus implementation |
| `api-designer` | medium | API contracts and DTO review |
| `database-engineer` | medium | Flyway, Oracle, persistence design |
| `legacy-migration` | high | Legacy reverse-engineering and migration |
| `xhtml-db-tracer` | medium | XHTML/JSF entrypoint tracing down to DB touchpoints |
| `tdd-validator` | high | Test-first and regression protection |
| `test-coverage-engineer` | high | Systematic coverage closure |
| `code-reviewer` | medium | Quality, regression, and guardrail review |

## Required Frontmatter Fields

Every `.agent.md` file in this toolkit is expected to have:

```yaml
---
description: "<one-line purpose>"
tools: [<tool list>]
effort: high | medium | low
argument-hint: "<usage hint>"
agents: [Explore, ...]
user-invocable: true | false
---
```

Notes:
- Omit `name` unless you need a display alias. If present, it must match the filename without `.agent.md`.
- `model` is optional. When present, use the current workspace-approved aliases already used by the runtime catalog, such as `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6`, and `Claude Opus 4.6`.
- Smaller or faster model aliases vary by tenant. Do not hardcode them in shared toolkit assets unless they are already used by the public runtime contract.
- `tools` must use built-in aliases (`read`, `search`, `edit`, `execute`, `todo`, `agent`, `web`) or MCP patterns like `oracle-official/*`.

## Public Agent Templates

Use these only when editing `team-lead`, `developer`, or intentionally redefining the public surface.

```markdown
---
description: "Premium orchestration entry point for the Copilot-first runtime with a fixed 4-phase protocol."
tools: [read, search, edit, execute, todo, agent]
model: ["GPT-5.4", "GPT-5.3 Codex", "Claude Sonnet 4.6", "Claude Opus 4.6"]
effort: high
argument-hint: "Describe the outcome you need"
agents: [context-optimizer, Explore, orchestrator, software-architect, backend-engineer, legacy-migration, xhtml-db-tracer, tdd-validator, test-coverage-engineer, code-reviewer, database-engineer, api-designer, bootstrap-workspace, agent-architect, memory-manager]
user-invocable: true
---
```

`team-lead` must be scaffolded with the fixed 4-phase protocol body: Context & Classification, Planning & Routing, Dynamic Execution, and Review Loop.

```markdown
---
description: "Bounded direct execution path for focused tasks with a fixed Plan -> Implement -> Review protocol."
tools: [read, search, edit, execute, todo, agent]
effort: medium
argument-hint: "Describe the focused task you need"
agents: [context-optimizer, memory-manager, Explore]
user-invocable: true
---
```

`developer` intentionally inherits the active picker/default model so each tenant can pair it with the smaller or faster approved model they actually expose. `developer` must not be scaffolded as an open-ended iterative loop; the public contract is a fixed 3-phase protocol with mandatory review.

## Internal Specialist Template

```markdown
---
description: "{one-line internal role}"
tools: [read, search, edit, todo, agent]
model: ["GPT-5.4", "GPT-5.3 Codex", "Claude Sonnet 4.6"]
effort: medium
argument-hint: "{short usage hint}"
agents: [Explore]
user-invocable: false
---
```

## Repo-Context Skill Template

Repository knowledge belongs in a companion skill plus repo-local memory, not in a public agent.

```markdown
---
name: {workspace}-{repo}
description: "Repository context, vocabulary, and guardrails for {repo}."
argument-hint: "Repository context detail — e.g. 'aggregate', 'rule', 'key query'"
user-invocable: false
---
```

## Skill Assets

- Script: `./scripts/scaffold-agents.ps1`
- Guardrails: `./references/guardrails.md`
- Template: `./assets/agent-template.md` for internal specialists only; public agents must use the dedicated templates above

## Audit Checklist

- [ ] All baseline agents have `.agent.md` files in `.github/agents/`
- [ ] All `.agent.md` files have required frontmatter fields
- [ ] `name` is omitted or matches the filename without `.agent.md`
- [ ] `model` is omitted or uses documented Copilot aliases only
- [ ] `tools` use built-in aliases or valid `<server>/*` MCP patterns
- [ ] `team-lead` and `developer` are the only public agents
- [ ] Internal specialists use `user-invocable: false`
- [ ] `team-lead` references the internal specialists it should delegate to
- [ ] `team-lead` delegates to `orchestrator` for the non-trivial planning stage
- [ ] `developer` defines a fixed Plan -> Implement -> Review protocol
- [ ] `developer` makes Review mandatory and re-enters Implement when issues are found

## Repo Context Checklist

- [ ] Each repository has a context skill in `.github/skills/<workspace>-<repo>/SKILL.md`
- [ ] Each context skill has `name`, `description`, `argument-hint`, and `user-invocable: false`
- [ ] Each repository has `.github/memory/context.md`, `.github/memory/dependencies.md`, and `.github/memory/recent-changes.md`
- [ ] Repo knowledge is not duplicated into public agent definitions
- [ ] Generic shared rules stay in shared skills, not in repo memory