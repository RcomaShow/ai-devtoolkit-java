---
name: optimization
description: "Internal workflow for performance work through hotspot analysis -> optimization plan -> implementation -> validation -> review -> finalize. Invoked by team-lead."
triggers: ["optimize", "performance", "latency", "throughput", "slow", "memory", "query tuning"]
agents: [context-optimizer, orchestrator, backend-engineer, database-engineer, tdd-validator, code-reviewer]
skills: [quarkus-observability, quarkus-backend, flyway-oracle, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Optimization

## Purpose

Use this workflow when the goal is to improve performance characteristics without changing the intended behavior. The fixed outer chain remains context -> plan -> execute -> verify -> review -> fix.

## Steps

### Step 1 — Scope context and hotspot evidence

**Lead specialist:** `context-optimizer`

Capture:
- repo and module scope
- available traces, logs, metrics, or slow queries
- missing evidence still needed before planning

### Step 2 — Plan the optimization

**Lead specialist:** `orchestrator`
**Support:** `backend-engineer` and `database-engineer` when persistence is involved
**Load first:** `skills/quarkus-observability/SKILL.md`

Define:
- slow path or expensive query
- available evidence or metric
- target metric or outcome
- correctness risks introduced by the optimization

### Step 3 — Execute the optimization

**Lead specialist:** `backend-engineer` or `database-engineer`

Make the narrowest change that addresses the measured bottleneck.

### Step 4 — Validate correctness and gain

**Lead specialist:** `tdd-validator`

Verify:
- functional behavior still holds
- the optimization actually improves the target signal when evidence is available

### Step 5 — Review trade-offs

**Lead specialist:** `code-reviewer`

Check:
- readability vs gain
- hidden concurrency or transaction risks
- fallback behavior under failure conditions

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** if evidence is incomplete, return to Step 1. If the gain is unproven or the change adds excessive complexity, return to Step 2 and choose a smaller or clearer approach.

## Exit Criteria

- hotspot and target metric are explicit
- behavior remains correct
- review agrees the trade-off is justified
- the final summary states what evidence supports the optimization