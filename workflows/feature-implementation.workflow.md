---
name: feature-implementation
description: "Internal workflow for delivering a new capability through analyze -> plan -> implement -> review -> fix -> finalize. Invoked by team-lead."
triggers: ["implement", "add feature", "new endpoint", "create service", "add domain behavior", "nuova funzionalita", "implementa", "aggiungi endpoint"]
agents: [software-architect, backend-engineer, tdd-validator, code-reviewer]
skills: [clean-architecture, quarkus-backend, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Feature Implementation

## Purpose

Use this workflow when `team-lead` is asked to add a new backend capability. The workflow is deliberately loop-oriented: no feature is considered done until implementation, tests, and review all converge.

## Steps

### Step 1 — Analyze the request

**Lead specialist:** `software-architect`
**Load first:** `skills/clean-architecture/SKILL.md`

Produce:
- impacted layers and modules
- acceptance criteria
- open questions or constraints

### Step 2 — Plan the change set

**Lead specialist:** `software-architect`
**Support:** `backend-engineer`

Produce:
- ordered implementation plan
- class and file list to create or modify
- data, API, and migration touchpoints

### Step 3 — Implement the feature

**Lead specialist:** `backend-engineer`
**Load first:** `skills/quarkus-backend/SKILL.md`

Implement the smallest coherent vertical slice that satisfies the plan.

### Step 4 — Add or update tests

**Lead specialist:** `tdd-validator`
**Load first:** `skills/tdd-workflow/SKILL.md`

Add tests that prove the new behavior and cover the main risk paths introduced by the feature.

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
**Loop rule:** if Step 4 or Step 5 finds issues, return to the earliest failing step and iterate.

Finalize only when the change is consistent, verified, and review-clean.

## Exit Criteria

- analysis and plan are explicit
- implementation matches the agreed scope
- tests cover the new behavior
- review findings are either fixed or clearly documented
- validation commands or checks are recorded in the final summary