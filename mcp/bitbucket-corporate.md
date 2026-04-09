# MCP: bitbucket-corporate

## Purpose
Provides live Bitbucket Server (Data Center) metadata to agents: PR status, branch state, open reviews, file diffs, and repository context. Enables agents to avoid proposing changes that conflict with in-progress PRs or shared branch state.

## Package
`@garc33/bitbucket-server-mcp-server` (npm community package)

```bash
npm install -g @garc33/bitbucket-server-mcp-server
```

## Configuration (.vscode/mcp.json)

```json
"bitbucket-corporate": {
  "command": "npx",
  "args": [
    "-y",
    "@garc33/bitbucket-server-mcp-server"
  ],
  "env": {
    "BITBUCKET_URL": "${env:BITBUCKET_URL}",
    "BITBUCKET_TOKEN": "${env:BITBUCKET_TOKEN}"
  }
}
```

## Environment Variables Required

| Variable | Example | Description |
|----------|---------|-------------|
| `BITBUCKET_URL` | `https://bitbucket.company.com` | Bitbucket Server base URL |
| `BITBUCKET_TOKEN` | (secret) | Personal access token — never hardcoded |

## When to Use

Use `bitbucket-corporate` MCP when:
- Proposing changes to `main`, `develop`, or any shared branch — check for open PRs first
- Reviewing PR history for a file or feature before making changes
- Identifying who last changed a file (blame context)
- Validating that a branch exists before referencing it in a plan

## Agents That Use This MCP

Add `bitbucket-corporate/*` to `tools:` in these agent types:
- `software-architect` — before proposing breaking changes to shared branches
- Domain orchestrators (Tier 2) — for cross-repo PR context
- Team leads (Tier 3) when instructed to work on a branch

## Security Rules

- Never hardcode the token in `mcp.json` — use `${env:BITBUCKET_TOKEN}`
- Use a read-only token scoped to the repositories this workspace covers
- Do not push or create PRs via MCP without explicit user confirmation

## Typical Queries

- List open PRs for a repository
- Get diff of a specific PR
- List branches matching a pattern
- Get commit history for a file
- Get PR review comments
