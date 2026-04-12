---
name: bugfix
description: "Internal workflow for defect resolution through reproduce -> root cause -> fix -> regression review -> finalize. Invoked by team-lead."
triggers: ["bug", "fix", "regression", "errore", "broken", "issue", "failing behavior"]
agents: [backend-engineer, tdd-validator, code-reviewer]
skills: [tdd-workflow, java-flow-analysis, quarkus-backend, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Bugfix

## Purpose

Use this workflow when `team-lead` is asked to correct existing behavior. The goal is to fix the root cause, not to patch symptoms.

## Steps

### Step 1 — Reproduce and analyze

**Lead specialist:** `backend-engineer`
**Load first:** `skills/java-flow-analysis/SKILL.md`

Capture:
- observed behavior
- expected behavior
- likely failure path
- files, modules, or data involved

### Step 2 — Isolate the root cause

**Lead specialist:** `backend-engineer`

Produce a minimal explanation of why the defect exists and what change boundary is required.

### Step 3 — Implement the fix

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
**Loop rule:** if reproduction is unclear, return to Step 1. If review or tests fail, return to Step 3 or Step 4 as appropriate.

## Exit Criteria

- defect is reproducible or otherwise evidenced before the fix
- root cause is documented in working notes or final summary
- regression tests exist when feasible
- review confirms no obvious follow-on defect remains