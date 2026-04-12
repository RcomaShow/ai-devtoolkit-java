---
mode: ask
description: Choose the right public agent, paid model family, and effort level for the current task.
---

# Runtime Profile Selection

Use this guide when choosing which public agent to invoke and how much depth you want.

## Public Agents

- `@team-lead`
  - Use for multi-step work, broader analysis, hidden-specialist delegation, review/fix loops, architecture work, migration, and workspace bootstrap.
  - Premium model family: `GPT-5.4`, `GPT-5.3 Codex`, `Claude Sonnet 4.6`, `Claude Opus 4.6`

- `@developer`
  - Use for bounded direct execution when the scope is already clear.
  - Smaller paid model family: `GPT-5.4 Mini`, `Claude Haiku 4.5`

## Effort Levels

- `effort low`
  - Fastest safe path, narrow checks, minimum necessary review.

- `effort medium`
  - Normal implementation depth with focused validation.

- `effort high`
  - Broader impact scan, stronger review, more verification.

## Recommended Usage

- Large feature or cross-module bug: `@team-lead effort high`
- Medium refactor or difficult defect: `@team-lead effort medium`
- Small local fix: `@developer effort medium`
- Quick targeted edit: `@developer effort low`