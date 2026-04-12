---
name: toolkit-health
description: 'Systematic audit and self-improvement procedure for the ai-devtoolkit. Detects source↔runtime drift, orphaned assets, broken references, skill gaps, and proposes evolution steps.'
argument-hint: "Audit scope — e.g. 'full audit', 'drift check', 'skill gap analysis', 'propose missing skills'"
user-invocable: false
---

# Toolkit Health — Audit And Self-Improvement

## When To Use
- After upgrading the toolkit or adding skills/agents.
- When runtime behavior diverges from expected toolkit behavior.
- Periodically to detect drift, dead assets, or skill gaps.
- When planning the next evolution wave.

## Skill Assets

- [Audit script](./scripts/audit-toolkit-health.ps1)
- [Guardrails](./references/guardrails.md)
- [Audit report template](./assets/health-report.template.md)

## Audit Dimensions

### 1 — Source↔Runtime Drift

Compare `.ai-devtoolkit/agents/` against `.github/agents/` and `.ai-devtoolkit/skills/` against `.github/skills/`. Report:
- Agents in source but missing from runtime
- Agents in runtime but not in source (custom workspace additions — record, don't flag)
- Skills in source but missing from runtime
- Frontmatter divergences (model lists, effort levels, tool lists)

### 2 — Broken References

For each agent and skill, verify that every referenced file path actually exists:
- Skill paths in agent routing tables
- Reference paths in SKILL.md routing tables
- Script paths in skill assets sections
- Template paths in skill assets sections

### 3 — Orphaned Assets

Detect files that exist but are not referenced by any agent, skill, workflow, or script:
- Agent files not listed in any routing table or delegation list
- Skill folders not referenced by any agent or copilot-instructions
- Scripts not referenced by any skill or package.json script
- Templates not referenced by any skill

### 4 — Skill Gap Analysis

Compare the routing table in `team-lead.agent.md` and the workflow dependency lists against the available skill catalog. Report:
- Intents in the routing table that have no first-class skill
- Workflow steps that reference skills that don't exist
- Domain areas covered by agents but not by skills (e.g., security, performance profiling)

### 5 — Catalog Consistency

Verify structural invariants:
- Every agent has toolkit-required frontmatter: description, tools, effort, argument-hint, agents, user-invocable
- `name` is optional; if present, it must match the filename without `.agent.md`
- `model` is optional; if present, it must use documented Copilot aliases only
- Only `team-lead` and `developer` have `user-invocable: true`
- Every skill folder has SKILL.md, references/, and assets/ (at minimum)
- Toolkit VERSION file exists and matches CHANGELOG latest entry

### 6 — Evolution Readiness

Check for SOTA 2026 patterns:
- Structured output schemas defined where agents produce machine-parseable results
- Context window management: are skills designed for selective loading?
- Tool-use efficiency: are scripts and assets colocated with the skills that use them?
- Multi-model awareness: do agents specify fallback model options?
- Safety: are guardrails documented for every skill that modifies files?

## Procedure

1. Run the audit script: `powershell -File .github/skills/toolkit-health/scripts/audit-toolkit-health.ps1`
2. Review the generated report.
3. For each finding, classify as: BUG (fix now), DRIFT (align), GAP (propose skill), DEBT (backlog).
4. Fix BUGs and DRIFTs immediately.
5. Propose GAPs as new skill/agent proposals with a one-line justification.
6. Record DEBT in `AI_BOOTSTRAP_IMPROVEMENTS.md`.

## Evolution Workflow

When the audit reveals significant gaps:

1. **Diagnose** — read the audit report and classify findings.
2. **Propose** — for each GAP, write a one-paragraph skill/agent/workflow proposal.
3. **Prioritize** — rank proposals by: frequency of need > complexity to implement > blast radius.
4. **Implement** — create the asset in `.ai-devtoolkit/`, then materialize to `.github/`.
5. **Validate** — re-run the audit to confirm the gap is closed.
6. **Record** — update CHANGELOG.md and AI_BOOTSTRAP_IMPROVEMENTS.md.
