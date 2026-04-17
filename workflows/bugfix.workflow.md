---
name: bugfix
description: "Internal workflow for defect resolution through reproduce -> root cause -> fix -> regression review -> finalize. Invoked by team-lead."
triggers: ["bug", "fix", "regression", "errore", "broken", "issue", "failing behavior"]
agents: [context-optimizer, orchestrator, backend-engineer, tdd-validator, code-reviewer]
skills: [tdd-workflow, java-flow-analysis, quarkus-backend, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Bugfix

## Purpose

Use this workflow when `team-lead` is asked to correct existing behavior. The goal is to fix the root cause, not to patch symptoms, while keeping the same fixed outer chain: context -> plan -> execute -> verify -> review -> fix.

## Steps

### Step 1 — Scope context and reproduction evidence

**Lead specialist:** `context-optimizer`

Capture:
- repo and file scope
- current evidence, failing path, or reproduction boundary
- missing discovery items that still need deeper analysis

### Step 2 — Plan the root-cause fix

**Lead specialist:** `orchestrator`
**Support:** `backend-engineer`
**Load first:** `skills/java-flow-analysis/SKILL.md`

Produce:
- observed behavior
- expected behavior
- likely failure path
- root-cause hypothesis
- verification strategy and re-entry step

### Step 3 — Execute the fix

**Lead specialist:** `backend-engineer`
**Load first:** `skills/quarkus-backend/SKILL.md`

Apply the smallest fix that resolves the root cause without broad unrelated edits.

### Step 4 — Add regression protection

**Lead specialist:** `tdd-validator`
**Load first:** `skills/tdd-workflow/SKILL.md`

Add or update tests that would fail without the fix.

### Step 5 — Review regression risk

**Lead specialist:** `code-reviewer`

Check:
- root-cause alignment
- behavior outside the failing path
- missing validation or null-handling
- risk of hidden side effects

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** if the context boundary is unclear, return to Step 1. If the plan is weak, return to Step 2. If review or tests fail, return to Step 3 or Step 4 as appropriate.

## Exit Criteria

- defect is reproducible or otherwise evidenced before the fix
- root-cause plan is documented in working notes or final summary
- regression tests exist when feasible
- review confirms no obvious follow-on defect remains