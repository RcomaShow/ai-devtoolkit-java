# Changelog

## 0.9.1 — 2026-04-16

### Changed
- `context-optimizer` now distinguishes repositories from managed shell targets and loads `.github/memory/workspace-shell.md` plus `.github/bootstrap/control-plane.json` for shell-scoped work instead of assuming repo-local memory.
- Architecture and README guidance now reflect that workspace shell memory and the declarative control-plane policy are operational, while inventory remains root-scoped and shell memory stays developer-curated.

## 0.9.0 — 2026-04-14

### Added
- `legacy-gap-analysis` workflow for evidence-based legacy-vs-new delta and parity-gap documents
- `gap-analysis.template.md` asset under `jsf-quarkus-port-alignment` so parity reviews can produce a stable file shape

### Changed
- `orchestrator.agent.md` is now the active hidden planner-router for the fixed development control plane instead of a deprecated compatibility shim
- `team-lead` now drives non-trivial work through the fixed hidden chain `context-optimizer -> orchestrator -> execution specialist -> verifier -> code-reviewer`
- Core development workflows now make the fixed context/plan/execute/verify/review/fix phases explicit
- `legacy-migration` and Copilot instructions now route legacy-vs-new comparison work through a dedicated workflow and the parity-gap skill
- `developer` contract now clearly allows only bounded helper delegation (`context-optimizer`, `memory-manager`, `Explore`)

## 0.8.0 — 2026-04-13

### Added
- Standard `.github/legacy/` workspace surface via source templates for stable legacy case folders, per-class logic inventories, Oracle SQL inventories, and timestamped generated evidence runs
- `new-legacy-case.ps1` scaffolder under `legacy-analysis` so case folders can be created without colliding with previous generations
- `run-legacy-xhtml-analysis.ps1` one-session runner so XHTML-first traces always scan down to DB touchpoints and persist the raw graph in the case run folder

### Changed
- `legacy-analysis` guidance and templates now require a compact top-level report plus dedicated Java-class and Oracle-inventory markdown files
- `new-project.mjs` now materializes `.github/legacy/`, exposes `npm run legacy:case` and `npm run legacy:analyze:xhtml`, and writes `.vscode/mcp.env.template.json` into the workspace

## 0.7.0 — 2026-04-13

### Added
- XML/native-query artifact discovery and XHTML include or composite-component traversal in `java-flow-analysis`
- `legacy-ddl-conversion` skill and workflow for Oracle DDL extraction, numeric profiling, and Oracle-to-T-SQL conversion
- Optional `mssql-server` MCP template wiring for target-side SQL Server validation

### Changed
- `team-lead` now routes legacy Oracle DDL extraction and Oracle-to-T-SQL work through a dedicated reusable workflow
- `database-engineer`, `legacy-analysis`, and Copilot instructions now cover numeric profiling and cross-dialect schema conversion
- `oracle-official` MCP guidance now matches the `MCP_DB_CONNECTION` runtime style and includes DDL plus numeric profiling queries

## 0.6.0 — 2026-04-13

### Added
- `xhtml-db-graph` command in `java-flow-analysis` for generic XHTML -> Java -> DB JSON graphs
- `xhtml-db-tracer` internal specialist for XHTML/JSF entrypoints that need a machine-readable dependency graph

### Changed
- `legacy-xhtml` is now a compatibility alias that emits the richer XHTML-to-DB graph report
- `java-flow-analysis` now tracks flow-oriented dependencies, reachable files, DB touchpoints, and JSON graph nodes/edges for downstream tooling
- `team-lead`, `legacy-analysis`, `agent-scaffolding`, and Copilot instructions now route XHTML-first tracing through the new graph workflow

## 0.5.1 — 2026-04-12

### Fixed
- Removed frontmatter `name:` aliases from shared agents so runtime discovery now resolves to stable filename-based agent names
- Replaced non-canonical model aliases with documented Copilot aliases where a shared `model:` pin is useful
- Stopped hardcoding tenant-specific smaller-model aliases on `developer`; it now inherits the active picker/default model
- Tightened tool grants for routing and review specialists (`orchestrator`, `code-reviewer`) and added shell access to `test-coverage-engineer` for local verification
- Updated agent scaffolding templates, audits, prompts, and Copilot instructions so future generated assets keep valid names, models, and tools

## 0.5.0 — 2026-04-12

### Added
- `VERSION` file for toolkit version tracking
- `CHANGELOG.md` for tracking toolkit evolution
- Self-evolution capabilities in `agent-architect`: toolkit health audit, source↔runtime drift detection, skill gap analysis, and structured evolution workflow
- `skills/toolkit-health/` — new skill for systematic toolkit auditing and self-improvement
- `tdd-workflow` and `agent-scaffolding` added to copilot-instructions skill index

### Fixed
- Removed dead nested sub-skills from `java-best-practices/` (java17/, java21/, java8-11/, docs-and-comments/ were duplicates of references/)
- Removed dead nested sub-skills from `quarkus-backend/` (api/, async/, persistence/, service/ were duplicates of references/)
- Cleaned up empty adapter stubs (claude-code, cursor, gemini-antigravity) with explicit README status
- Moved orphaned `copilot-agent-mode-full-operating-system.md` into `docs/` as archived design doc

### Changed
- `orchestrator.agent.md` simplified — marked as deprecated compatibility shim, body trimmed
- `agent-architect.agent.md` upgraded with toolkit evolution responsibilities and skill references
- `copilot-instructions.md` skill index now complete

## 0.4.0 — 2026-04-12

### Added
- Repo-local memory architecture (`<repo>/.github/memory/`)
- `skills/repo-memory/` with refresh script
- Context compression rules in agents
- Kafka-aware dependency capture in memory refresh

## 0.3.0 — 2026-04-12

### Added
- Operational skills: `quarkus-dev`, `fetch-api`, `quarkus-logs-analyzer`, `postman-collections`
- XHTML-first legacy analysis in `java-flow-analysis`
- `deps` and `legacy-xhtml` commands in analyze-java.py

## 0.2.0 — 2026-04-12

### Added
- Two-tier public agent model: `team-lead` + `developer`
- Model families: premium + compact
- Runtime profile prompt

## 0.1.0 — 2026-04-10

### Added
- Initial toolkit structure
- Generic agents, skills, workflows
- Multi-repo bootstrap engine
