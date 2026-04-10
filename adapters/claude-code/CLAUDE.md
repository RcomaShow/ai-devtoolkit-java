# Claude Code — Toolkit Usage Guide

## How This Toolkit Maps to Claude Code

| Standard tool concept | Claude Code equivalent | Location |
|----------------------|----------------------|---------|
| Agent files | `.agent.md` (same format) | `agents/` |
| Skill files | `SKILL.md` (same format) | `skills/` |
| Workflows | Orchestration `.workflow.md` | `workflows/` |
| Instructions | CLAUDE.md (project-level) | project root |
| Hooks | Claude Code hooks in `settings.json` | `.claude/settings.json` |

## Invoking Agents

With Claude Code, reference agents directly:

```
@orchestrator implementa il servizio NominaService con CRUD completo
@backend-engineer aggiungi il POST endpoint per le nominas
@test-coverage-engineer copertura al 100% per NominaService.java
```

Or use the orchestrator as the universal entry point — it reads your request and routes automatically.

## Configuring Hooks

To wire the atomic-commit hook in Claude Code, add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash .ai-devtoolkit/adapters/github-copilot/hooks/atomic-commit/scripts/atomic-commit-check.sh"
          }
        ]
      }
    ]
  }
}
```

## Skill Loading Pattern

Claude Code loads skills by path reference. The recommended pattern:

1. Agent reads the routing hub: `skills/quarkus-backend/SKILL.md`
2. Hub returns the sub-skill path for the task
3. Agent loads the sub-skill: `skills/quarkus-backend/api/SKILL.md`

This minimizes context loaded — only the relevant sub-skill is in context.

## Model

All agents use `claude-sonnet-4-6` by default (set in agent frontmatter `model` field).
Override per session in Claude Code settings if needed.

## Workflow Execution

Workflows in `workflows/*.workflow.md` are instruction documents — not executable code.
The `orchestrator` agent reads the workflow and executes each step by briefing the correct specialist agent in sequence.

Trigger a workflow:
```
@orchestrator feature-implementation: aggiungi il dominio Nomina al servizio jrv-nomina-trasporto
@orchestrator legacy-migration: migra NominaBackingBean a Quarkus
@orchestrator test-coverage: 100% su NominaService
```
