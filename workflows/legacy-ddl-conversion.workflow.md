---
name: legacy-ddl-conversion
description: "Internal workflow for Oracle legacy schema extraction, numeric profiling, T-SQL conversion, validation, and review. Invoked by team-lead."
triggers: ["ddl conversion", "t-sql", "sql server migration", "oracle schema", "legacy ddl", "dbms_metadata", "convert schema"]
agents: [database-engineer, legacy-migration, code-reviewer]
skills: [legacy-ddl-conversion, java-flow-analysis, legacy-analysis, flyway-oracle]
estimated-steps: 6
---

# Workflow: Legacy DDL Conversion

## Purpose

Use this workflow when `team-lead` needs to recover Oracle legacy schema evidence and produce a reviewed T-SQL conversion script without guessing column semantics.

## Steps

### Step 1 — Inventory the affected schema slice

**Lead specialist:** `legacy-migration`
**Load first:** `skills/legacy-analysis/SKILL.md`

Produce:
- source tables, views, sequences, triggers, and dependent objects
- entrypoint evidence when the request starts from XHTML, XML, or application flows
- open questions about ownership or scope

### Step 2 — Extract authoritative Oracle metadata and DDL

**Lead specialist:** `database-engineer`
**Load first:** `skills/legacy-ddl-conversion/SKILL.md`

Produce:
- Oracle catalog evidence
- raw `DBMS_METADATA.GET_DDL` output or equivalent extracted DDL
- normalized source object inventory

### Step 3 — Profile numeric and ambiguous columns

**Lead specialist:** `database-engineer`

Produce:
- metadata plus observed data ranges for numeric columns
- confidence level for each non-trivial type mapping
- explicit flags for columns that still need business confirmation

### Step 4 — Generate the target T-SQL script

**Lead specialist:** `database-engineer`

Produce:
- converted T-SQL DDL
- explicit handling for indexes, FKs, sequences, defaults, and Oracle-specific constructs
- notes for lossy or manual follow-up conversions

### Step 5 — Validate and review the conversion

**Lead specialist:** `code-reviewer`

Check:
- unsupported Oracle constructs are not silently dropped
- numeric mappings are backed by metadata and profiling evidence
- target naming and constraints stay deterministic
- MCP-backed validation is recorded when available

### Step 6 — Fix and finalize

**Owner:** `team-lead`
**Loop rule:** any unprofiled numeric mapping or unresolved Oracle-specific construct returns to Step 2 or Step 3 before finalizing.

## Exit Criteria

- Oracle source DDL is preserved as evidence
- numeric type mappings are justified explicitly
- T-SQL output is reviewed and validation status is recorded
- unresolved conversion risks are surfaced instead of hidden