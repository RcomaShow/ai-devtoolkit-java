---
name: jsf-quarkus-port-alignment
description: 'Parity-first procedure for porting JSF/EJB legacy workflows to Quarkus while separating internal behavior gaps from external integration TODOs.'
argument-hint: "Legacy port task — e.g. 'align preview and cut semantics', 'write a gap ledger', 'compare JSF checks to REST contract'"
user-invocable: false
---

# JSF To Quarkus Port Alignment

Use this skill when the goal is not only to redesign an API, but to minimize drift from proven legacy behavior before introducing new abstractions.

---

## Outcomes

- an evidence-based gap ledger
- a target contract anchored to real legacy semantics
- explicit separation between internal parity work and external integration TODOs
- a short, ordered backlog that closes the highest-risk non-external gaps first

---

## Workflow

1. Lock the true entrypoint: XHTML, backing bean action, EJB, or batch launcher.
2. Map UI actions to command semantics and authorization differences.
3. Separate legacy pre-checks by real business scope instead of collapsing them into one abstract status.
4. Classify each gap as one of:
   - `internal-parity-gap`
   - `external-todo`
   - `intentional-divergence`
   - `blocked-by-contract`
5. Record what the legacy flow does before and after each check.
6. Derive the target REST contract from server-side semantics, not from temporary UI flags.
7. Fail explicitly on unported branches instead of returning misleading empty results.

---

## Porting Rules

| Area | Rule |
|---|---|
| vocabulary | use domain terms from the business surface, such as `remiCode`, instead of internal migration aliases |
| checks | keep distinct checks distinct when their legacy scope differs |
| commands | preview and execute must reflect real legacy branching, not generic client-driven switches |
| external data | document missing integrations as TODO or blocking dependencies, not as mocked-equivalent behavior |
| hourly branches | if hourly logic exists in legacy, port it or fail explicitly; never hide it behind silent partial responses |
| facades | a legacy facade is acceptable only if it delegates to the same canonical server path |

---

## Evidence Checklist

For each open gap, record:

- legacy source file and method
- current Quarkus source or contract point
- observed behavior difference
- classification
- impact on preview, cut, read-model, or cache
- exit condition for closing the gap

## Standard Gap Analysis File

When the requested outcome is a document, produce one evidence-based file instead of scattering the findings across chat.

Recommended destinations:

- `.github/legacy/cases/<case-id>/analysis.md` for case-based legacy investigations
- `GAP_<FEATURE>_LEGACY_VS_NEW.md` in the target repository when the comparison is repo-local and delivery-facing

Minimum sections:

1. scope and sources
2. synthetic outcome
3. evidence summary
4. classification summary
5. gap ledger table
6. ordered backlog
7. open questions and blocked items

Recommended table columns:

| Area | Legacy | New | Classification | Impact | Exit condition | Evidence |
|---|---|---|---|---|---|---|

Use the canonical classifications exactly as defined above. Do not collapse `external-todo` and `internal-parity-gap` into the same bucket.

---

## Typical Pitfalls

- turning server-side legacy checks into public client flags
- renaming a business concept in the API just because the temporary code uses another variable name
- treating external-data gaps and internal-porting gaps as if they had the same priority
- documenting a mock as if it were valid functional parity
- introducing single-REMI command scope where the legacy workflow acts on cycle scope only

---

## Related Skills

- `legacy-analysis`
- `java-flow-analysis`
- `quarkus-backend`
- `quarkus-infinispan-hotrod-protostream`

---

## Skill Assets

- `assets/gap-analysis.template.md`
- `references/guardrails.md`