# MCP Guide

Baseline required and optional MCP servers are declared in `.github/bootstrap/control-plane.json`.

## Default Servers

- `oracle-official` for Oracle schema and SQL introspection
- `bitbucket-corporate` for PR and repository metadata

The Oracle MCP wrapper loads `.vscode/.env` and resolves SQLcl from the Oracle extension when `sql` is not on PATH.

## Optional Servers

- `mssql-server` when the task includes Oracle-to-T-SQL validation or SQL Server target introspection

## Rules

- Reuse existing MCPs before proposing new ones.
- Update `.github/bootstrap/control-plane.json` when the workspace baseline or optional MCP set changes.
- Add `mssql-server` only when target-dialect validation is part of the workflow.
- Store all secrets in environment variables.
- Keep `.vscode/mcp.json` on the `mcpServers` schema.
- `sql` must be available via PATH or the Oracle wrapper script before the MCP server can start.
- Run `npm run bootstrap:security:audit` after editing MCP configuration.