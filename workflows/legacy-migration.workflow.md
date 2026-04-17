---
name: legacy-migration
description: "Internal workflow for legacy migration through reverse-engineering -> architectural mapping -> implementation -> review -> fix -> finalize. Invoked by team-lead."
triggers: ["migrate", "legacy", "migra", "JSF", "EJB", "backing bean", "porting", "modernize"]
agents: [context-optimizer, orchestrator, xhtml-db-tracer, legacy-migration, software-architect, backend-engineer, database-engineer, tdd-validator, code-reviewer]
skills: [legacy-analysis, jsf-quarkus-port-alignment, java-flow-analysis, domain-driven-design, clean-architecture, quarkus-backend, flyway-oracle, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Legacy Migration

## Purpose

Use this workflow when `team-lead` needs to move legacy JEE or JSF behavior into the Quarkus target architecture without losing business rules. The fixed outer chain remains context -> plan -> execute -> verify -> review -> fix.

## Steps

### Step 1 — Scope context, entrypoints, and evidence

**Lead specialist:** `context-optimizer`

Produce:
- repo and entrypoint scope
- existing legacy case artifacts, repo memory, and target files to load
- whether XHTML tracing is required before broader migration work

### Step 2 — Plan the migration and parity route

**Lead specialist:** `orchestrator`
**Support:** `legacy-migration`
**Load first:** `skills/legacy-analysis/SKILL.md`

Produce:
- business rules recovered from code or documents
- comparison strategy and execution specialists
- verification strategy, including parity or gap-ledger outcomes
- open questions that still need clarification

### Step 3 — Execute the migration slice

**Lead specialists:** `legacy-migration`, `software-architect`, `backend-engineer`, and `database-engineer` as needed

Apply only the schema, persistence, service, and API work required for the current slice.

### Step 4 — Verify functional parity and gap classifications

**Lead specialist:** `tdd-validator`

Add tests and parity checks that encode the recovered business rules, and classify unresolved deltas with `jsf-quarkus-port-alignment` terms when full parity is not yet possible.

### Step 5 — Review migration risks

**Lead specialist:** `code-reviewer`

Check:
- legacy rule coverage
- leakage of old abstractions into new layers
- unsafe schema assumptions
- unresolved ambiguity

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** unresolved ambiguity returns to Step 1 or Step 2 before more implementation continues. If parity evidence is weak, return to Step 3 or Step 4.

## Exit Criteria

- migrated behavior is traced back to explicit legacy analysis
- implementation follows target architecture rather than copying legacy structure blindly
- parity or gap decisions are documented in the final summary