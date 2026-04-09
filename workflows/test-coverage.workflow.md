---
name: test-coverage
description: "Flow for achieving 100% branch coverage on an existing class: enumerate paths → build test data → write tests → verify → atomic commit"
triggers: ["test", "coverage", "branch coverage", "junit", "mockito", "copertura", "100%", "write tests", "scrivi test", "test class"]
agents: [test-coverage-engineer, code-reviewer]
skills: [java-test-coverage, git-atomic-commit]
estimated-steps: 4
---

# Workflow: Test Coverage

## Purpose

Use when writing a test class to achieve 100% branch coverage on an existing production class. Follows a systematic path-enumeration-first approach — no test is written until every branch is mapped.

**Do NOT use this workflow when:** the production class does not yet exist — use `feature-implementation` workflow instead, which includes test writing as Step 5.

---

## Flow Overview

```
[Target Class Path]
      │
      ▼
[Step 1: test-coverage-engineer] ─── run analyze-java.py, enumerate all branches
      │
      ▼
[Step 2: test-coverage-engineer] ─── write test builders + skeleton + test methods
      │
      ▼
[Step 3: test-coverage-engineer] ─── verify all branches covered, run tests
      │                              COMMIT: test({scope}): add branch coverage for {ClassName}
      ▼
[Step 4: code-reviewer] ─── quality check: no tautologies, no brittle mocks
      │
      ▼
[Done]
```

---

## Steps

### Step 1 — Enumerate All Branches

**Agent:** `test-coverage-engineer`
**Skill to load first:** `skills/java-test-coverage/SKILL.md` (Phase 1 — Path Enumeration)

**Actions:**
1. Run the AST analysis script to get branch count:
   ```bash
   python scripts/analyze-java.py branches path/to/TargetClass.java
   python scripts/analyze-java.py test-matrix path/to/TargetClass.java
   ```
2. Build a Path Matrix table for every method:

| Method | Branch | Condition | Expected |
|--------|--------|-----------|---------|
| `create()` | 1 — HAPPY | entity saved successfully | returns `EntityDto` |
| `create()` | 2 — CONFLICT | `existsByCode` returns true | throws `ConflictException` |
| `findById()` | 1 — FOUND | repository returns entity | returns `Optional<Dto>` filled |
| `findById()` | 2 — NOT_FOUND | repository returns empty | returns `Optional.empty()` |

3. Count branches per method: `min_tests_needed` = number of branches + 1 for each multi-case switch
4. Identify which Mockito pattern each branch requires (stubbing, captor, inOrder, Answer)

**Output expected:**
- `path-matrix`: completed table of all branches
- `mockito-patterns`: list of advanced patterns needed
- `test-class-skeleton`: class header + constants + @ExtendWith

**Escalate when:** the class has > 20 branches — consider splitting the test class by inner concern group.

---

### Step 2 — Write Test Class

**Agent:** `test-coverage-engineer`
**Skill to load first:** `skills/java-test-coverage/SKILL.md` (Phases 2-6)
**Takes from Step 1:** `path-matrix`, `mockito-patterns`, `test-class-skeleton`

**Actions — in order:**

**A. Test Data Builders** (if multiple test scenarios share similar objects):
```java
static NominaBuilder nomina() {
    return new NominaBuilder().defaults();
}
```

**B. Test skeleton:**
```java
@ExtendWith(MockitoExtension.class)
class {ClassName}Test {
    @Mock {Dependency} dep;
    @InjectMocks {ClassName} sut;
    // constants for test data
}
```

**C. For each row in the path matrix, write one `@Test` method:**
- Name: `should_{expected}_when_{condition}()`
- Arrange: stub only what the branch under test actually calls
- Act: call the SUT method
- Assert: verify the expected outcome AND any side effects (captures, interactions)

**D. Apply advanced Mockito when needed:**
- `@Captor` as method parameter (not field) for ArgumentCaptor
- `inOrder.verify()` for sequence-sensitive interactions
- `thenReturn(v1).thenReturn(v2)` for consecutive call scenarios
- `Answer<T>` for dynamic return based on argument

**Output expected:**
- `test-class`: complete Java test class with all branches covered

---

### Step 3 — Verify and Commit

**Agent:** `test-coverage-engineer`
**Skill to load first:** `skills/git-atomic-commit/SKILL.md`

**Actions:**
1. Run: `./mvnw test -pl <module> -Dtest={ClassName}Test`
2. Run: `./mvnw test-compile` — verify no MapStruct or import errors
3. Verify path matrix is fully covered — every row has a corresponding `@Test`
4. Check: no `assertTrue(true)`, no `assertNotNull(dto)` without following field assertions
5. Stage and commit:

```bash
git add src/test/java/com/company/domain/.../TargetClassTest.java
git commit -m "test({scope}): add branch coverage for {ClassName}

Covers all branches: {list key scenarios}.
"
```

---

### Step 4 — Test Quality Review

**Agent:** `code-reviewer`
**Input:** the test class from Step 2

**Checklist:**
- [ ] Every `@Test` method name follows `should_{expected}_when_{condition}()` pattern
- [ ] No tautology assertions (`assertTrue(true)`, `assertNotNull(result)` without further checks)
- [ ] Mocks are strict (MockitoExtension default) — no unnecessary stubs
- [ ] `ArgumentCaptor.getValue()` called after `verify()`, not before
- [ ] `inOrder.verify()` used when method call order matters
- [ ] `@Disabled` tests have a linked ticket number in the reason string
- [ ] Test data builders used instead of repeating `new Entity(...)` inline

---

## Exit Criteria

- [ ] Path matrix complete — every branch has a test method
- [ ] `./mvnw test` exits 0
- [ ] No tautology assertions in the test class
- [ ] Atomic commit created with conventional message
- [ ] Code review passed

---

## Error Paths

| Failure | Recovery |
|---------|---------|
| `UnnecessaryStubbingException` | Remove stub that is not called in this test method |
| `NullPointerException` in test | Check that `@InjectMocks` constructor receives all mocked dependencies |
| `VerificationInOrderFailure` | Reorder `inOrder.verify()` calls to match actual invocation order |
| Branch not reachable in isolation | The class may need refactoring — flag to `code-reviewer` before writing the test |
| Compilation error — MapStruct impl not found | Run `./mvnw compile` first to trigger annotation processing |
