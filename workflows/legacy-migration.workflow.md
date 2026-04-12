---
name: legacy-migration
description: "Internal workflow for legacy migration through reverse-engineering -> architectural mapping -> implementation -> review -> fix -> finalize. Invoked by team-lead."
triggers: ["migrate", "legacy", "migra", "JSF", "EJB", "backing bean", "porting", "modernize"]
agents: [legacy-migration, software-architect, backend-engineer, database-engineer, tdd-validator, code-reviewer]
skills: [legacy-analysis, java-flow-analysis, domain-driven-design, clean-architecture, quarkus-backend, flyway-oracle, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Legacy Migration

## Purpose

Use this workflow when `team-lead` needs to move legacy JEE or JSF behavior into the Quarkus target architecture without losing business rules.

## Steps

### Step 1 — Reverse-engineer the legacy behavior

**Lead specialist:** `legacy-migration`
**Load first:** `skills/legacy-analysis/SKILL.md`

Produce:
- business rules recovered from code or documents
- touched tables, integrations, and side effects
- open questions that still need clarification

### Step 2 — Map the target architecture

**Lead specialist:** `software-architect`
**Load first:** `skills/clean-architecture/SKILL.md`

Define:
- target layers and responsibilities
- aggregate and boundary mapping
- migration plan by slice

### Step 3 — Implement the migrated slice

**Lead specialists:** `database-engineer` and `backend-engineer`

Apply only the schema, persistence, service, and API work required for the current slice.

### Step 4 — Verify functional parity

**Lead specialist:** `tdd-validator`

Add tests that encode the recovered business rules and protect the migrated behavior.

### Step 5 — Review migration risks

**Lead specialist:** `code-reviewer`

Check:
- legacy rule coverage
- leakage of old abstractions into new layers
- unsafe schema assumptions
- unresolved ambiguity

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** unresolved ambiguity returns to Step 1 or Step 2 before more implementation continues.

## Exit Criteria

- migrated behavior is traced back to explicit legacy analysis
- implementation follows target architecture rather than copying legacy structure blindly
- parity or gap decisions are documented in the final summary