---
name: legacy-gap-analysis
description: "Internal workflow for producing an evidence-based legacy-vs-new gap analysis through trace -> compare -> classify -> review -> finalize. Invoked by team-lead."
triggers: ["gap analysis", "legacy vs new", "parity gap", "delta analysis", "allineamento legacy", "gap ledger", "legacy vs nuovo"]
agents: [context-optimizer, orchestrator, xhtml-db-tracer, legacy-migration, software-architect, code-reviewer]
skills: [legacy-analysis, jsf-quarkus-port-alignment, java-flow-analysis, clean-architecture]
estimated-steps: 6
---

# Workflow: Legacy Gap Analysis

## Purpose

Use this workflow when the requested outcome is not implementation first, but an evidence-based file that explains how the new code differs from the legacy behavior.

## Steps

### Step 1 — Scope context, entrypoints, and comparison boundary

**Lead specialist:** `context-optimizer`

Produce:
- target repository and current implementation surface
- true legacy entrypoint or evidence set
- existing case artifacts, repo memory, and docs to reuse

### Step 2 — Plan the comparison route

**Lead specialist:** `orchestrator`
**Support:** `legacy-migration`
**Load first:** `skills/jsf-quarkus-port-alignment/SKILL.md`

Produce:
- ordered evidence-gathering plan
- specialists required for the execution phase
- target artifact path and expected gap-ledger shape

### Step 3 — Trace legacy and current behavior

**Lead specialists:** `xhtml-db-tracer`, `legacy-migration`, and `software-architect` as needed
**Load first:** `skills/legacy-analysis/SKILL.md`

Produce:
- legacy behavior summary
- current implementation summary
- mapped areas that can be compared directly

### Step 4 — Write the gap ledger

**Lead specialist:** `legacy-migration`
**Load first:** `skills/jsf-quarkus-port-alignment/SKILL.md`

Write the evidence-based gap file using the canonical classifications and template.

### Step 5 — Review classifications and actionability

**Lead specialist:** `code-reviewer`

Check:
- evidence supports every gap claim
- classifications are not mixed together
- action items distinguish internal parity work from external TODOs
- intentional divergences are documented explicitly

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** if evidence is weak, return to Step 3. If the ledger is unclear or misclassified, return to Step 4.

## Exit Criteria

- a stable legacy entrypoint or evidence set is identified
- legacy and new behavior are both described from code or verified docs
- every gap has a canonical classification
- the final artifact can be used as a delivery backlog, not just a narrative note