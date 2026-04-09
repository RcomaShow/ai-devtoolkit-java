---
name: agent-scaffolding
description: "Agent catalog audit and scaffolding for Java/Quarkus workspaces. Validates frontmatter completeness, ensures companion skills exist, and scaffolds missing agents from templates."
argument-hint: "Audit or scaffold action — e.g. 'audit all agents', 'scaffold team-lead for {repo}', 'add companion skill for {agent}'"
user-invocable: true
---

# Agent Scaffolding — Catalog and Templates

## Agent Catalog

### Tier 1 — Infrastructure & Meta
| Agent | Effort | Role |
|-------|--------|------|
| `bootstrap-workspace` | high | Phase 1: workspace/adapter scaffolding |
| `agent-architect` | high | Creates agents, skills, MCPs from requirements |

### Tier 2 — Domain Orchestrator
| Agent | Effort | Role |
|-------|--------|------|
| `{domain}-orchestrator` | high | Main router across all repos and role agents |

### Tier 3 — Repository Team Leads
| Agent | Repo | Effort |
|-------|------|--------|
| `{domain}-{service-a}` | `{repo-service-a}` | high |
| `{domain}-{service-b}` | `{repo-service-b}` | medium |

### Tier 4 — Cross-Cutting Role Agents
| Agent | Effort | Role |
|-------|--------|------|
| `software-architect` | high | Clean Architecture, ADRs, layer enforcement |
| `legacy-migration` | high | Monolith → Quarkus migration |
| `api-designer` | medium | OpenAPI 3.1 spec + REST contract review |
| `backend-engineer` | medium | Quarkus resources, services, mappers |
| `database-engineer` | medium | Flyway, Panache, Oracle schema |
| `tdd-validator` | high | TDD workflow, test coverage audit |
| `code-reviewer` | medium | SOLID, OWASP, Quarkus best practices |

## Required Frontmatter Fields

Every `.agent.md` file must have:

```yaml
---
name: <kebab-case matching filename>
description: "<one-line purpose>"
tools: [<tool list>]
model: ["GPT-5.4", "Claude Sonnet 4.6"]
effort: high | medium | low
argument-hint: "<usage hint>"
agents: [Explore, ...]
user-invocable: true | false
---
```

## Tier 1 Agent Template (Infrastructure)

```markdown
---
name: {name}
description: "{What this agent does at workspace level}"
tools: [read, search, edit, execute, todo, agent]
model: ["GPT-5.4", "Claude Sonnet 4.6"]
effort: high
argument-hint: "{Short usage hint}"
agents: [Explore]
user-invocable: true
---
You are the **{role}** for this workspace.

## Responsibilities
- {responsibility 1}
- {responsibility 2}

## Constraints
- {constraint 1}

## Output Format
- `{output-key}`: {description}
```

## Tier 2 Agent Template (Domain Orchestrator)

```markdown
---
name: {domain}-orchestrator
description: "Domain orchestrator for {domain}. Routes work across repositories and delegates to role agents."
tools: [read, search, edit, todo, agent, bitbucket-corporate/*, oracle-official/*]
model: ["GPT-5.4", "Claude Sonnet 4.6"]
effort: high
argument-hint: "Domain task — e.g. '{domain} feature request', 'cross-repo impact analysis'"
agents: [Explore, {domain}-{service-a}, software-architect, backend-engineer, api-designer, database-engineer, tdd-validator, code-reviewer, legacy-migration]
user-invocable: true
---
You are the **domain orchestrator** for {domain}.

## Domain Overview
{Brief domain description}

## Repositories In Scope
| Repo | Role |
|------|------|
| `{repo-a}` | {description} |
| `{repo-b}` | {description} |

## Routing Table
| Keyword | Delegate to |
|---------|------------|
| architecture, ADR, layer | `software-architect` |
| implement, code, REST | `backend-engineer` |
| API, OpenAPI, contract | `api-designer` |
| DB, migration, schema | `database-engineer` |
| test, TDD, coverage | `tdd-validator` |
| review, SOLID, OWASP | `code-reviewer` |
| legacy, migration, JSF | `legacy-migration` |
| {domain-keyword} | `{domain}-{service-a}` |

## Constraints
- Always read `workspace-bootstrap/SKILL.md` routing guide before delegating.
- Use `oracle-official` before proposing DB changes.
- Use `bitbucket-corporate` before proposing changes to shared branches.

## Output Format
- `analysis`: domain state and impact
- `plan`: ordered implementation steps
- `delegate-to`: which agent handles next step
```

## Tier 3 Agent Template (Team Lead)

```markdown
---
name: {domain}-{service}
description: "Team lead for {repo-name} repository. Deep expertise in {service domain}."
tools: [read, search, edit, todo, agent, oracle-official/*]
model: ["GPT-5.4", "Claude Sonnet 4.6"]
effort: high
argument-hint: "Task for {service} — e.g. '{domain feature}', 'fix {domain issue}'"
agents: [Explore, backend-engineer, tdd-validator, code-reviewer, database-engineer]
user-invocable: true
---
You are the **team lead** for `{repo-name}`.

## Repository Context
- Repo: `{repo-name}`
- Bounded context: {description}
- Key aggregates: {Aggregate1}, {Aggregate2}

## Skill References
| When you need to... | Read skill |
|---------------------|-----------|
| Write implementation code | `quarkus-backend/SKILL.md` |
| Write tests | `tdd-workflow/SKILL.md` |
| Layer decisions | `clean-architecture/SKILL.md` |
| Domain design | `domain-driven-design/SKILL.md` |
| DB changes | `flyway-oracle/SKILL.md` |

## Responsibilities
- Own all implementation decisions for `{repo-name}`.
- Define acceptance criteria for new features.
- Coordinate with `backend-engineer`, `database-engineer`, `tdd-validator`.

## Constraints
- Always check `oracle-official` before proposing schema changes.
- All code must pass the layer checklist in `clean-architecture/SKILL.md`.

## Output Format
- `analysis`: current repo state
- `plan`: implementation steps with layer assignments
- `delegate-to`: which role agent handles each step
```

## Tier 4 Agent Template (Role Agent)

See individual agent files: `software-architect.agent.md`, `backend-engineer.agent.md`, etc.

## Audit Checklist

Run before declaring the agent catalog complete:

- [ ] All catalog agents have `.agent.md` files in `.github/agents/`
- [ ] All `.agent.md` files have required frontmatter fields
- [ ] `name` matches filename (without `.agent.md`)
- [ ] `model` is set to `["GPT-5.4", "Claude Sonnet 4.6"]`
- [ ] `effort` is one of: `high`, `medium`, `low`
- [ ] Tier 3 and Tier 4 agents reference a companion skill in their skill table
- [ ] Parent orchestrator's `agents:` list includes all team lead agents
- [ ] `user-invocable: true` for all directly-callable agents

## Companion Skill Checklist

- [ ] Every Tier 3 team lead has a companion skill in `.github/skills/{domain}-{service}/SKILL.md`
- [ ] Companion skill has frontmatter: `name`, `description`, `argument-hint`, `user-invocable: false`
- [ ] Agent body references the companion skill in its skill table
