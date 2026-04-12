---
name: test-coverage
description: "Internal workflow for test and coverage work through branch analysis -> plan -> test implementation -> review -> fix -> finalize. Invoked by team-lead."
triggers: ["test", "coverage", "branch coverage", "junit", "mockito", "copertura", "100%", "write tests", "scrivi test"]
agents: [test-coverage-engineer, tdd-validator, code-reviewer]
skills: [java-test-coverage, tdd-workflow, git-atomic-commit]
estimated-steps: 5
---

# Workflow: Test Coverage

## Purpose

Use this workflow when the main outcome is better test protection or branch coverage on existing code.

## Steps

### Step 1 — Analyze the target

**Lead specialist:** `test-coverage-engineer`
**Load first:** `skills/java-test-coverage/SKILL.md`

Produce:
- target classes and methods
- branch matrix or scenario map
- required builders, mocks, and fixtures

### Step 2 — Plan the test set

**Lead specialist:** `test-coverage-engineer`
**Support:** `tdd-validator`

Define:
- minimal test cases needed
- order of implementation
- gaps that need refactoring rather than more tests

### Step 3 — Implement or update tests

**Lead specialist:** `tdd-validator`
**Load first:** `skills/tdd-workflow/SKILL.md`

Write or revise tests so they are explicit, non-brittle, and aligned to the branch plan.

### Step 4 — Review test quality

**Lead specialist:** `code-reviewer`

Check:
- tautology-free assertions
- realistic mock usage
- branch plan coverage
- maintainability of the test code

### Step 5 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** if the branch plan is incomplete, return to Step 1; if test quality is weak, return to Step 3.

## Exit Criteria

- branch or scenario plan exists
- implemented tests match that plan
- coverage work does not hide production defects behind brittle mocks
- final summary states what behavior is now protected