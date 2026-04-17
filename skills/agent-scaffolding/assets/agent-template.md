---
description: "{one-line purpose}"
tools: [read, search, edit, todo, agent]
model: ["GPT-5.4", "GPT-5.3 Codex", "Claude Sonnet 4.6"]
effort: medium
argument-hint: "{usage hint}"
agents: [Explore]
user-invocable: false
---

You are the **{role-name}** for this workspace.

This shared asset is for **internal specialists by default**.

Use `user-invocable: true` only when the agent is intentionally part of the public Copilot surface.
Do **not** use this asset to scaffold `team-lead` or `developer`; use the dedicated public templates in `SKILL.md` so the fixed 4-phase and 3-phase contracts are preserved.

## Responsibilities
- {responsibility-1}
- {responsibility-2}

## Constraints
- {constraint-1}

## Output Format
- `{output-key}`: {description}