---
name: {agent-name}
description: "{one-line purpose}"
tools: [read, search, edit, todo]
model: ["GPT-5.4"]
effort: medium
argument-hint: "{usage hint}"
agents: [Explore]
user-invocable: false
---

You are the **{role-name}** for this workspace.

Use `user-invocable: true` only when the agent is intentionally part of the public Copilot surface.

## Responsibilities
- {responsibility-1}
- {responsibility-2}

## Constraints
- {constraint-1}

## Output Format
- `{output-key}`: {description}