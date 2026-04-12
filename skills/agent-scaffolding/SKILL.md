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
| `developer` | medium | Smaller-model direct execution for bounded tasks without sub-agents |

### Internal Specialists
| Agent | Effort | Role |
|-------|--------|------|
| `bootstrap-workspace` | high | Workspace bootstrap and inventory repair |
| `agent-architect` | high | Catalog and toolkit maintenance |
| `orchestrator` | medium | Hidden compatibility router |
| `software-architect` | high | Architecture, boundaries, ADRs |
| `backend-engineer` | medium | Quarkus implementation |
| `api-designer` | medium | API contracts and DTO review |
| `database-engineer` | medium | Flyway, Oracle, persistence design |
| `legacy-migration` | high | Legacy reverse-engineering and migration |
| `tdd-validator` | high | Test-first and regression protection |
| `test-coverage-engineer` | high | Systematic coverage closure |
| `code-reviewer` | medium | Quality, regression, and guardrail review |

## Required Frontmatter Fields

Every `.agent.md` file must have:

```yaml
---
name: <kebab-case matching filename>
description: "<one-line purpose>"
tools: [<tool list>]
model: ["GPT-5.4", "GPT-5.3 Codex", "Claude Sonnet 4.6", "Claude Opus 4.6"]
effort: high | medium | low
argument-hint: "<usage hint>"
agents: [Explore, ...]
user-invocable: true | false
---
```

## Public Agent Templates

Use these only when editing `team-lead`, `developer`, or intentionally redefining the public surface.

```markdown
---
name: team-lead
description: "Premium orchestration entry point for the Copilot-first runtime."
tools: [read, search, edit, execute, todo, agent]
model: ["GPT-5.4", "GPT-5.3 Codex", "Claude Sonnet 4.6", "Claude Opus 4.6"]
effort: high
argument-hint: "Describe the outcome you need"
agents: [Explore, software-architect, backend-engineer, code-reviewer]
user-invocable: true
---
```

```markdown
---
name: developer
description: "Bounded direct execution path for smaller paid models."
tools: [read, search, edit, execute, todo]
model: ["GPT-5.4 Mini", "Claude Haiku 4.5"]
effort: medium
argument-hint: "Describe the focused task you need"
agents: []
user-invocable: true
---
```

## Internal Specialist Template

```markdown
---
name: {agent-name}
description: "{one-line internal role}"
tools: [read, search, edit, todo, agent]
model: ["GPT-5.4", "GPT-5.3 Codex", "Claude Sonnet 4.6", "Claude Opus 4.6"]
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
- Template: `./assets/agent-template.md`

## Audit Checklist

- [ ] All baseline agents have `.agent.md` files in `.github/agents/`
- [ ] All `.agent.md` files have required frontmatter fields
- [ ] `name` matches the filename without `.agent.md`
- [ ] `model` uses the approved premium or mini model families
- [ ] `team-lead` and `developer` are the only public agents
- [ ] Internal specialists use `user-invocable: false`
- [ ] `team-lead` references the internal specialists it should delegate to

## Repo Context Checklist

- [ ] Each repository has a context skill in `.github/skills/<workspace>-<repo>/SKILL.md`
- [ ] Each context skill has `name`, `description`, `argument-hint`, and `user-invocable: false`
- [ ] Each repository has `.github/memory/context.md`, `.github/memory/dependencies.md`, and `.github/memory/recent-changes.md`
- [ ] Repo knowledge is not duplicated into public agent definitions
- [ ] Generic shared rules stay in shared skills, not in repo memory