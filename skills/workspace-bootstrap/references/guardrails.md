# Workspace Bootstrap Guardrails

- Detect processes and root adapters before mutating the workspace.
- Never overwrite repo-local `AGENTS.md`, `CLAUDE.md`, or `.github` assets without explicit approval.
- Treat `.ai/memory/` as generated operational state only.
- Fail security review when `.vscode/mcp.json` contains inline credentials instead of `${env:...}`.
- Update `AI_BOOTSTRAP_IMPROVEMENTS.md` after bootstrap reviews or structural changes.