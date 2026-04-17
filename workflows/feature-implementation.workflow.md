---
name: feature-implementation
description: "Internal workflow for delivering a new capability through analyze -> plan -> implement -> review -> fix -> finalize. Invoked by team-lead."
triggers: ["implement", "add feature", "new endpoint", "create service", "add domain behavior", "nuova funzionalita", "implementa", "aggiungi endpoint"]
agents: [context-optimizer, orchestrator, software-architect, backend-engineer, tdd-validator, code-reviewer]
skills: [clean-architecture, quarkus-backend, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Feature Implementation

## Purpose

Use this workflow when `team-lead` is asked to add a new backend capability. The outer control plane stays fixed: context -> plan -> execute -> verify -> review -> fix.

## Steps

### Step 1 — Scope context and evidence

**Lead specialist:** `context-optimizer`

Produce:
- repo and module scope
- repo-memory and skill load plan
- missing discovery items that still need `Explore`

### Step 2 — Plan and route the change set

**Lead specialist:** `orchestrator`
**Support:** `software-architect`
**Load first:** `skills/clean-architecture/SKILL.md`

Produce:
- ordered implementation plan
- execution specialists and skills to load
- verification strategy and re-entry step

### Step 3 — Execute the feature

**Lead specialists:** `software-architect` then `backend-engineer`
**Load first:** `skills/quarkus-backend/SKILL.md`

Produce:
- the smallest coherent vertical slice that satisfies the plan
- required architecture, persistence, service, and API changes

### Step 4 — Verify new behavior

**Lead specialist:** `tdd-validator`
**Load first:** `skills/tdd-workflow/SKILL.md`

Add tests that prove the new behavior and protect the main risk paths introduced by the feature.

### Step 5 — Review the result

**Lead specialist:** `code-reviewer`

Check:
- layer boundaries
- API and DTO correctness
- test quality
- regression risk
- missing validation or error handling

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** if context is incomplete, return to Step 1. If planning is weak, return to Step 2. If verification or review finds issues, return to Step 3 or Step 4 and iterate.

Finalize only when the change is consistent, verified, and review-clean.

## Exit Criteria

- context and plan are explicit
- implementation matches the agreed scope
- tests cover the new behavior
- review findings are either fixed or clearly documented
- validation commands or checks are recorded in the final summary