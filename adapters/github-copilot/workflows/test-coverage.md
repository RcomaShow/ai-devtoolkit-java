---
name: 'Test Coverage'
description: 'Achieves 100% branch coverage on an existing Java class. Enumerates all code paths, writes one test per branch, verifies all tests pass, and commits.'
on:
  issue-comment:
    - created
permissions:
  contents: write
  pull-requests: write
safe-outputs: true
---

# Test Coverage Workflow

You are achieving 100% branch coverage on an existing Java class.
Read `.ai-devtoolkit/workflows/test-coverage.workflow.md` for the full procedure.

## Inputs

Extract from the issue or comment:
- **Target class**: the class to cover (e.g. `NominaService`, `NominaAclTranslator`)
- **Module path**: relative path to the class

## Step 1 — Enumerate All Branches

Read `skills/java-test-coverage/SKILL.md` (Phase 1 — Path Enumeration).

Run the branch analysis:
```bash
python scripts/analyze-java.py branches path/to/TargetClass.java
python scripts/analyze-java.py test-matrix path/to/TargetClass.java
```

Build a Path Matrix with one row per branch:
| # | Method | Branch condition | Expected result |
|---|--------|-----------------|-----------------|

Do not write any test until the matrix is complete.

## Step 2 — Write Test Class

Read `skills/java-test-coverage/SKILL.md` (Phases 2-6).

For each row in the Path Matrix, write one `@Test` method:
- Name: `should_{expected}_when_{condition}()`
- `@ExtendWith(MockitoExtension.class)` — no `@QuarkusTest`
- Use `ArgumentCaptor` only with `verify()` called before `getValue()`
- Never write tautology assertions

## Step 3 — Verify and Commit

1. Run `./mvnw test -pl <module> -Dtest={ClassName}Test`
2. Verify every row in the Path Matrix has a corresponding passing test.
3. Commit:

```
test({scope}): add branch coverage for {ClassName}

Covers all branches: {list key scenarios}.
```

## Step 4 — Create PR

Create a PR with:
- Title: `test({scope}): add branch coverage for {ClassName}`
- Body: the Path Matrix table showing all branches covered.
