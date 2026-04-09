# MCP: sonarqube (Proposed)

## Status
**PROPOSED** — not yet configured in this workspace. Evaluate when SonarQube quality gate data needs to be surfaced to `tdd-validator` or `code-reviewer` agents.

## Purpose
Provides live SonarQube quality metrics: coverage percentages, code smells, duplications, security hotspots, and quality gate status. Enables `tdd-validator` and `code-reviewer` to reference actual quality data instead of estimates.

## Package
`mcp-server-sonarqube` (npm community package)

```bash
npm install -g mcp-server-sonarqube
```

## Configuration (.vscode/mcp.json)

```json
"sonarqube": {
  "command": "npx",
  "args": [
    "-y",
    "mcp-server-sonarqube"
  ],
  "env": {
    "SONAR_URL": "${env:SONAR_URL}",
    "SONAR_TOKEN": "${env:SONAR_TOKEN}"
  }
}
```

## Environment Variables Required

| Variable | Example | Description |
|----------|---------|-------------|
| `SONAR_URL` | `https://sonar.company.com` | SonarQube Server base URL |
| `SONAR_TOKEN` | (secret) | User/project token — never hardcoded |

## Project Keys

<!-- Fill in per-workspace at initialisation -->
| Repository | SonarQube Project Key |
|------------|----------------------|
| `{repo-a}` | `{sonar-key-a}` |
| `{repo-b}` | `{sonar-key-b}` |

## When to Use

Use `sonarqube` MCP when:
- `tdd-validator` needs to check current coverage before accepting a feature as done
- `code-reviewer` wants to compare new smells against baseline before recommending merge
- Planning a refactor and needing to measure starting quality gate status
- Sprint reviews where quality metrics need to be surfaced

## Agents That Would Use This MCP

Add `sonarqube/*` to `tools:` in:
- `tdd-validator` — for coverage gate validation
- `code-reviewer` — for smell baseline comparison
- Domain orchestrators — for project health overview

## Security Rules

- Never hardcode the token — use `${env:SONAR_TOKEN}`
- Use a read-only analysis token scoped to project keys
- Do not trigger new SonarQube analyses via MCP — use CI pipeline only

## Justification Checklist (before adding)

- [ ] SonarQube is actively used and CI publishes results regularly
- [ ] Quality gate coverage threshold is configured per project
- [ ] `tdd-validator` has been asked to reference real coverage data
- [ ] Built-in tools (`read`, `search`) cannot satisfy the need
