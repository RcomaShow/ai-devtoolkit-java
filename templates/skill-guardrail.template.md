---
name: {skill-name}-guardrail
description: "Guardrail constraints for the {skill-name} skill. Defines scope, input/output validators, safety rules, and escalation triggers."
type: guardrail
target-skill: skills/{skill-name}/SKILL.md
---

# Guardrail — {Skill Name}

> Copy this template into `skills/{skill-name}/GUARDRAIL.md` alongside `SKILL.md`.
> Agents that invoke this skill MUST read the guardrail before executing any step.

---

## Scope Limiter

**This skill IS for:**
- {use-case-1}
- {use-case-2}
- {use-case-3}

**This skill is NOT for:**
- {out-of-scope-1} — use `{alternative-skill}` instead
- {out-of-scope-2} — requires human decision, do not automate
- {out-of-scope-3} — out of domain

If the request falls outside the IS FOR list, **stop and route to the correct resource**.

---

## Input Validators

Before executing any step in the skill, verify:

| Input | Required? | Valid Range / Format | Reject If |
|-------|-----------|----------------------|-----------|
| {input-1} | YES | {format description} | blank or null |
| {input-2} | YES | {enum values} | not in enum |
| {input-3} | NO | {description} | exceeds {limit} |

**On reject:** Respond with `GUARDRAIL_INPUT_VIOLATION: <reason>` and stop. Do not attempt to infer or default invalid inputs.

---

## Output Validators

Every output produced by this skill MUST:

- [ ] Contain `{required-output-field-1}`
- [ ] Contain `{required-output-field-2}`
- [ ] Use `{placeholder}` syntax in code patterns (never hardcode project-specific names)
- [ ] Reference the source file/line for any decision made based on existing code
- [ ] NOT include {forbidden-content} — e.g. secrets, PII, hardcoded environment values

**On failure:** Re-run the failing step once. If it fails again, emit `GUARDRAIL_OUTPUT_VIOLATION: <field> missing` and stop.

---

## Safety Rules

These rules are absolute — no exceptions, no overrides:

1. **Never overwrite** files already committed to the repository unless the user explicitly confirms the overwrite.
2. **Never delete** migration files, ADRs, or test files — these are append-only.
3. **Never generate** code that bypasses Bean Validation at the API boundary.
4. **Never connect** to production databases during skill execution — use schema MCP read-only.
5. **{domain-specific-never-rule}** — {reason}.

---

## Escalation Triggers

Stop execution and ask a human when:

| Condition | Why |
|-----------|-----|
| The skill step requires a decision affecting data schema shared by multiple services | Risk: cross-service coupling. Needs architect review. |
| The generated output conflicts with an existing ADR | ADRs are binding — a human must resolve the conflict. |
| The target file was modified within the last 24 hours by a different author | Risk: merge conflict. Confirm intent before proceeding. |
| {custom-trigger} | {reason} |

Escalation message format:
```
GUARDRAIL_ESCALATION: <trigger condition>
Context: <what the skill was doing>
Decision needed: <what the human must decide>
Suggested options: <A> / <B>
```

---

## Mutation Budget

This skill is allowed to **write** at most:

| Asset Type | Max Per Run |
|------------|-------------|
| New files | {N} |
| Modified files | {M} |
| Deleted files | 0 (deletion requires explicit user confirmation) |

If the planned output would exceed the budget, **pause and report the plan** before writing.

---

## Audit Trail

After each skill execution, append one line to `.ai/memory/skill-audit.log`:

```
{ISO-8601-timestamp} | {skill-name} | agent={agent-name} | inputs={summary} | outputs={summary} | status=OK|GUARDRAIL_VIOLATION
```

---

## Guardrail Version

`guardrail-version: 1.0`  
Update version when safety rules change. Breaking changes require re-approval by a human maintainer.
