---
name: refactor
description: "Internal workflow for behavior-preserving restructuring through baseline analysis -> safety plan -> refactor -> review -> fix -> finalize. Invoked by team-lead."
triggers: ["refactor", "cleanup", "restructure", "simplify", "extract", "riorganizza"]
agents: [context-optimizer, orchestrator, software-architect, backend-engineer, tdd-validator, code-reviewer]
skills: [clean-architecture, java-best-practices, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Refactor

## Purpose

Use this workflow when the behavior should stay the same but the structure needs to improve. The fixed outer chain remains context -> plan -> execute -> verify -> review -> fix.

## Steps

### Step 1 — Scope context and invariants

**Lead specialist:** `context-optimizer`

Identify:
- affected repo and modules
- current hotspots or large files to inspect
- repo-memory or docs that define invariants

### Step 2 — Plan the safe refactor

**Lead specialist:** `orchestrator`
**Support:** `software-architect` and `tdd-validator`
**Load first:** `skills/clean-architecture/SKILL.md`

Define:
- current smells or structural issues
- invariants that must remain true
- test or verification boundary
- rollback or scope-reduction boundary

### Step 3 — Execute the refactor

**Lead specialist:** `backend-engineer`

Apply the refactor in coherent slices, preserving behavior and public contracts unless explicitly requested otherwise.

### Step 4 — Verify preserved behavior

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
**Loop rule:** if context is missing, return to Step 1. If the refactor drifts into feature work or breaks behavior, return to Step 2 or Step 3 and reduce scope.

## Exit Criteria

- behavior-preserving intent remains true
- complexity or duplication is measurably reduced
- tests or focused verification cover the preserved behavior
- review confirms the structure is cleaner than before