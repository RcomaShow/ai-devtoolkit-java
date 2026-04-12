# MCP Guide

## Default Servers

- `oracle-official` for Oracle schema and SQL introspection
- `bitbucket-corporate` for PR and repository metadata

## Rules

- Reuse existing MCPs before proposing new ones.
- Store all secrets in environment variables.
- Keep `.vscode/mcp.json` on the `mcpServers` schema.
- Run `npm run bootstrap:security:audit` after editing MCP configuration.