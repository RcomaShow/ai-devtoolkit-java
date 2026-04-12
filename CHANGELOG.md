# Changelog

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
