---
name: refactor
description: "Internal workflow for behavior-preserving restructuring through baseline analysis -> safety plan -> refactor -> review -> fix -> finalize. Invoked by team-lead."
triggers: ["refactor", "cleanup", "restructure", "simplify", "extract", "riorganizza"]
agents: [software-architect, backend-engineer, tdd-validator, code-reviewer]
skills: [clean-architecture, java-best-practices, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Refactor

## Purpose

Use this workflow when the behavior should stay the same but the structure needs to improve.

## Steps

### Step 1 — Baseline analysis

**Lead specialist:** `software-architect`
**Load first:** `skills/clean-architecture/SKILL.md`

Identify:
- current smells or structural issues
- invariants that must remain true
- boundaries that cannot be crossed

### Step 2 — Safety plan

**Lead specialist:** `software-architect`
**Support:** `tdd-validator`

Define:
- tests that must stay green or be added first
- refactor sequence
- rollback boundary if the change grows too large

### Step 3 — Execute the refactor

**Lead specialist:** `backend-engineer`

Apply the refactor in coherent slices, preserving behavior and public contracts unless explicitly requested otherwise.

### Step 4 — Verify behavior

**Lead specialist:** `tdd-validator`
**Load first:** `skills/tdd-workflow/SKILL.md`

Run or add focused tests that prove the behavior is preserved.

### Step 5 — Review the new structure

**Lead specialist:** `code-reviewer`

Check:
- reduced complexity
- preserved contracts
- no new layer violations
- no dead abstractions or speculative generalization

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** if the refactor drifts into feature work or breaks behavior, return to Step 2 or Step 3 and reduce scope.

## Exit Criteria

- behavior-preserving intent remains true
- complexity or duplication is measurably reduced
- tests or focused verification cover the preserved behavior
- review confirms the structure is cleaner than before