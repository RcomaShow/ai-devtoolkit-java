# Toolkit Health Guardrails

- Never auto-delete assets flagged as orphaned without manual confirmation — they may be in-progress work.
- Drift detection is informational; runtime files intentionally diverge from source when workspace-specific customizations are applied.
- Skill gap proposals must reference a concrete task pattern that currently lacks skill coverage, not hypothetical future needs.
- Evolution changes follow the same source-first, then materialize-to-runtime flow as all toolkit changes.
- Keep audit reports compact and decision-oriented; avoid listing every file when a summary count suffices.
