---
name: <workflow-name>
description: "<one-line description of the end-to-end flow>"
triggers: ["<keyword1>", "<keyword2>", "<italian-keyword>"]
agents: [<ordered list of agents involved>]
skills: [<skills loaded at workflow start>]
estimated-steps: <number>
---

# Workflow: <Workflow Name>

## Purpose

<When to use this workflow — the problem it solves. 2-3 sentences.>

**Do NOT use this workflow when:** <narrowing condition — e.g. single-file fix, read-only review>

---

## Flow Overview

```
[User Request]
      │
      ▼
[Step 1: <agent-a>] ─── <brief description of what it does>
      │                  COMMIT: <type>(<scope>): ...  ← if applicable
      ▼
[Step 2: <agent-b>] ◄─── takes output of Step 1
      │                  COMMIT: <type>(<scope>): ...  ← if applicable
      ▼
[Step N: Atomic Commit] ◄─── skill: git-atomic-commit
      │
      ▼
[Done]
```

---

## Steps

### Step 1 — <Step Name>

**Agent:** `<agent-name>`
**Skill to load first:** `skills/<skill-path>/SKILL.md`

**Input:**
- `<input-field>`: <description of what the agent needs>

**Output expected:**
- `<output-field>`: <description of what the agent produces>

**Skip condition:** <when this step can be skipped entirely>
**Escalate when:** <condition that requires human decision before continuing>

**Atomic commit after this step:**
```
<type>(<scope>): <subject>
```

---

### Step 2 — <Step Name>

**Agent:** `<agent-name>`
**Takes from Step 1:** `<output-field-name>`
**Skill to load first:** `skills/<skill-path>/SKILL.md`

**Input:**
- `<input-field>`: <description>

**Output expected:**
- `<output-field>`: <description>

**Skip condition:** <when this step can be skipped>

**Atomic commit after this step:**
```
<type>(<scope>): <subject>
```

---

### Step N — Code Review

**Agent:** `code-reviewer`
**Input:** all files modified in previous steps

**Checklist enforced:**
- [ ] <criterion 1>
- [ ] <criterion 2>

**Output:** `review-result` — pass or list of violations to fix before merge.

---

### Final Step — Atomic Commit (if not already committed per step)

**Skill:** `skills/git-atomic-commit/SKILL.md`
**Action:** verify pre-commit checklist, stage by explicit path, commit with conventional message.

---

## Exit Criteria

The workflow is complete when ALL of the following are true:

- [ ] <criterion 1 — e.g. "compilation green">
- [ ] <criterion 2 — e.g. "all tests pass">
- [ ] <criterion 3 — e.g. "code review passed">
- [ ] Atomic commit(s) pushed or PR created

---

## Error Paths

| Failure | Recovery action |
|---------|----------------|
| <failure scenario 1> | <recovery — specific action to take> |
| <failure scenario 2> | <recovery — specific action to take> |
| Compilation error after merge | Revert offending commit; re-run from Step N |
