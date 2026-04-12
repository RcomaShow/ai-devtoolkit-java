---
name: agent-scaffolding
description: 'Agent catalog audit and scaffolding for Copilot-first Java/Quarkus workspaces. Validates frontmatter, public-surface rules, companion skills, and repo-context coverage.'
argument-hint: "Audit or scaffold action — e.g. 'audit agents', 'add internal specialist', 'create repo context skill'"
user-invocable: false
---

# Agent Scaffolding — Catalog and Templates

## Runtime Catalog

### Public Surface
| Agent | Effort | Role |
|-------|--------|------|
| `team-lead` | high | Single public entry point for intake, routing, review, and fix loops |

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
model: ["GPT-5.4"]
effort: high | medium | low
argument-hint: "<usage hint>"
agents: [Explore, ...]
user-invocable: true | false
---
```

## Public Agent Template

Use this only when editing `team-lead` or intentionally redefining the public surface.

```markdown
---
name: team-lead
description: "Single public entry point for the Copilot-first runtime."
tools: [read, search, edit, execute, todo, agent]
model: ["GPT-5.4"]
effort: high
argument-hint: "Describe the outcome you need"
agents: [Explore, software-architect, backend-engineer, code-reviewer]
user-invocable: true
---
```

## Internal Specialist Template

```markdown
---
name: {agent-name}
description: "{one-line internal role}"
tools: [read, search, edit, todo, agent]
model: ["GPT-5.4"]
effort: medium
argument-hint: "{short usage hint}"
agents: [Explore]
user-invocable: false
---
```

## Repo-Context Skill Template

Repository knowledge belongs in a companion skill, not in a public agent.

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
- [ ] `model` is set to `["GPT-5.4"]`
- [ ] `team-lead` is the only public agent
- [ ] Internal specialists use `user-invocable: false`
- [ ] `team-lead` references the internal specialists it should delegate to

## Repo Context Checklist

- [ ] Each repository has a context skill in `.github/skills/<workspace>-<repo>/SKILL.md`
- [ ] Each context skill has `name`, `description`, `argument-hint`, and `user-invocable: false`
- [ ] Repo knowledge is not duplicated into public agent definitions