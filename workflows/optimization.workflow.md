---
name: optimization
description: "Internal workflow for performance work through hotspot analysis -> optimization plan -> implementation -> validation -> review -> finalize. Invoked by team-lead."
triggers: ["optimize", "performance", "latency", "throughput", "slow", "memory", "query tuning"]
agents: [backend-engineer, database-engineer, tdd-validator, code-reviewer]
skills: [quarkus-observability, quarkus-backend, flyway-oracle, tdd-workflow, git-atomic-commit]
estimated-steps: 6
---

# Workflow: Optimization

## Purpose

Use this workflow when the goal is to improve performance characteristics without changing the intended behavior.

## Steps

### Step 1 — Identify the hotspot

**Lead specialist:** `backend-engineer`
**Load first:** `skills/quarkus-observability/SKILL.md`

Capture:
- slow path or expensive query
- available evidence or metric
- current bottleneck hypothesis

### Step 2 — Plan the optimization

**Lead specialist:** `backend-engineer`
**Support:** `database-engineer` when persistence is involved

Define:
- target metric or outcome
- minimal change set
- correctness risks introduced by the optimization

### Step 3 — Implement the optimization

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
**Loop rule:** if the gain is unproven or the change adds excessive complexity, return to Step 2 and choose a smaller or clearer approach.

## Exit Criteria

- hotspot and target metric are explicit
- behavior remains correct
- review agrees the trade-off is justified
- the final summary states what evidence supports the optimization