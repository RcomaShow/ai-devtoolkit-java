#!/usr/bin/env node
/**
 * new-project.mjs — Initialize a new Java/Quarkus multi-repo workspace from ai-devtoolkit
 *
 * Usage:
 *   node .ai-devtoolkit/scripts/new-project.mjs \
 *     --name my-domain \
 *     --domain "Gas Transport" \
 *     --repos "repo-core,repo-service-a,repo-service-b" \
 *     --package "com.company.mydomain" \
 *     --stack "quarkus+oracle"
 *
 * Flags:
 *   --name        Workspace identifier (kebab-case) — used in folder names and agent names
 *   --domain      Human-readable domain name — used in agent descriptions and README
 *   --repos       Comma-separated list of repository names
 *   --package     Java base package (com.company.domain)
 *   --stack       Technology stack tag (default: quarkus+oracle)
 *   --dry-run     Print planned changes without writing files
 */

import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TOOLKIT_ROOT = path.resolve(__dirname, '..');
const WORKSPACE_ROOT = process.cwd();

// --- Argument parsing ---
const args = new Set(process.argv.slice(2));
const getArg = (flag) => {
  for (const a of process.argv) {
    if (a.startsWith(flag + '=')) return a.slice(flag.length + 1);
    if (a === flag) {
      const idx = process.argv.indexOf(a);
      return process.argv[idx + 1] ?? '';
    }
  }
  return null;
};

const dryRun = args.has('--dry-run');
const name = getArg('--name');
const domain = getArg('--domain') ?? name;
const repos = (getArg('--repos') ?? '').split(',').map(r => r.trim()).filter(Boolean);
const javaPackage = getArg('--package') ?? `com.company.${name}`;
const stack = getArg('--stack') ?? 'quarkus+oracle';

if (!name) {
  console.error('ERROR: --name is required');
  console.error('Usage: node new-project.mjs --name <name> --domain "<domain>" --repos "<repo1,repo2>" --package "<com.company.domain>"');
  process.exit(1);
}

if (dryRun) console.log('[DRY-RUN] Reporting planned changes only — no files will be written.\n');

console.log(`Initializing workspace: ${name}`);
console.log(`  Domain:   ${domain}`);
console.log(`  Repos:    ${repos.join(', ') || '(none — add manually later)'}`);
console.log(`  Package:  ${javaPackage}`);
console.log(`  Stack:    ${stack}`);
console.log('');

const results = [];

// --- Utility functions ---
async function ensureDir(dir) {
  if (dryRun) { results.push({ path: rel(dir), status: 'dry-run-would-mkdir' }); return; }
  await fsp.mkdir(dir, { recursive: true });
}

async function writeFile(filePath, content) {
  const exists = fs.existsSync(filePath);
  if (exists && !dryRun) {
    const current = await fsp.readFile(filePath, 'utf8');
    if (current === content) { results.push({ path: rel(filePath), status: 'unchanged' }); return; }
  }
  if (dryRun) { results.push({ path: rel(filePath), status: exists ? 'dry-run-would-update' : 'dry-run-would-create' }); return; }
  await fsp.mkdir(path.dirname(filePath), { recursive: true });
  await fsp.writeFile(filePath, content, 'utf8');
  results.push({ path: rel(filePath), status: exists ? 'updated' : 'created' });
}

function rel(p) { return path.relative(WORKSPACE_ROOT, p); }

// --- Template expansion ---
function expand(text) {
  return text
    .replace(/\{name\}/g, name)
    .replace(/\{domain\}/g, domain)
    .replace(/\{package\}/g, javaPackage)
    .replace(/\{stack\}/g, stack)
    .replace(/\{repos\}/g, repos.join(', '));
}

// --- Copy toolkit agents (generic → workspace) ---
async function copyAgents() {
  const agentSrc = path.join(TOOLKIT_ROOT, 'agents');
  const agentDst = path.join(WORKSPACE_ROOT, '.github', 'agents');
  await ensureDir(agentDst);

  const genericAgents = [
    'software-architect.agent.md',
    'backend-engineer.agent.md',
    'api-designer.agent.md',
    'database-engineer.agent.md',
    'tdd-validator.agent.md',
    'code-reviewer.agent.md',
    'legacy-migration.agent.md',
    'agent-architect.agent.md',
  ];

  for (const agentFile of genericAgents) {
    const src = path.join(agentSrc, agentFile);
    const dst = path.join(agentDst, agentFile);
    if (fs.existsSync(dst)) {
      results.push({ path: rel(dst), status: 'skipped-existing' });
      continue;
    }
    const content = await fsp.readFile(src, 'utf8');
    await writeFile(dst, content);
  }
}

// --- Copy toolkit skills ---
async function copySkills() {
  const skillSrc = path.join(TOOLKIT_ROOT, 'skills');
  const skillDst = path.join(WORKSPACE_ROOT, '.github', 'skills');
  await ensureDir(skillDst);

  const skillDirs = await fsp.readdir(skillSrc, { withFileTypes: true });
  for (const entry of skillDirs) {
    if (!entry.isDirectory()) continue;
    const srcSkill = path.join(skillSrc, entry.name, 'SKILL.md');
    const dstSkill = path.join(skillDst, entry.name, 'SKILL.md');
    if (!fs.existsSync(srcSkill)) continue;
    if (fs.existsSync(dstSkill)) {
      results.push({ path: rel(dstSkill), status: 'skipped-existing' });
      continue;
    }
    const content = await fsp.readFile(srcSkill, 'utf8');
    await writeFile(dstSkill, content);
  }
}

// --- Generate domain orchestrator agent ---
async function generateOrchestratorAgent() {
  const agentPath = path.join(WORKSPACE_ROOT, '.github', 'agents', `${name}-orchestrator.agent.md`);
  if (fs.existsSync(agentPath)) {
    results.push({ path: rel(agentPath), status: 'skipped-existing' });
    return;
  }

  const repoRows = repos.map(r => `| \`${r}\` | {description — fill in} |`).join('\n');
  const teamLeads = repos.map(r => `${name}-${r.replace(/[-_]/g, '-')}`).join(', ');

  const content = `---
name: ${name}-orchestrator
description: "Domain orchestrator for ${domain}. Routes work across repositories and delegates to role agents and team leads."
tools: [read, search, edit, todo, agent, bitbucket-corporate/*, oracle-official/*]
model: ["GPT-5.4", "Claude Sonnet 4.6"]
effort: high
argument-hint: "Domain task — e.g. '${domain} feature request', 'cross-repo impact analysis for ${name}'"
agents: [Explore, ${teamLeads}, software-architect, backend-engineer, api-designer, database-engineer, tdd-validator, code-reviewer, legacy-migration]
user-invocable: true
---
You are the **domain orchestrator** for ${domain}.

## Domain Overview

<!-- Fill in: what problem domain this covers, key business concepts -->

## Repositories In Scope

${repoRows.length ? repoRows : '| `{repo}` | {description} |'}

## Routing Table

| Keyword | Delegate to |
|---------|------------|
| architecture, ADR, layer | \`software-architect\` |
| implement, code, REST endpoint | \`backend-engineer\` |
| API, OpenAPI, contract | \`api-designer\` |
| DB, migration, schema, Oracle | \`database-engineer\` |
| test, TDD, coverage | \`tdd-validator\` |
| review, SOLID, OWASP | \`code-reviewer\` |
| legacy, migration, JSF, EJB | \`legacy-migration\` |
${repos.map(r => `| ${r.split('-').slice(-1)[0]}, ${r} | \`${name}-${r.replace(/[-_]/g, '-')}\` |`).join('\n')}

## Constraints

- Always read \`workspace-bootstrap/SKILL.md\` routing guide before delegating.
- Use \`oracle-official\` before proposing DB changes.
- Use \`bitbucket-corporate\` before proposing changes to shared branches.

## Output Format

- \`analysis\`: domain state and impact
- \`plan\`: ordered implementation steps
- \`delegate-to\`: which agent handles next step
`;

  await writeFile(agentPath, content);
}

// --- Generate team lead agents per repo ---
async function generateTeamLeads() {
  for (const repo of repos) {
    const agentName = `${name}-${repo.replace(/[-_]/g, '-')}`;
    const agentPath = path.join(WORKSPACE_ROOT, '.github', 'agents', `${agentName}.agent.md`);
    if (fs.existsSync(agentPath)) {
      results.push({ path: rel(agentPath), status: 'skipped-existing' });
      continue;
    }

    const content = `---
name: ${agentName}
description: "Team lead for \`${repo}\` repository. Deep domain expertise for ${domain} — ${repo} bounded context."
tools: [read, search, edit, todo, agent, oracle-official/*]
model: ["GPT-5.4", "Claude Sonnet 4.6"]
effort: high
argument-hint: "Task for ${repo} — e.g. '${domain} feature in ${repo}', 'fix ${repo} issue'"
agents: [Explore, backend-engineer, tdd-validator, code-reviewer, database-engineer]
user-invocable: true
---
You are the **team lead** for \`${repo}\`.

## Repository Context

- **Repo**: \`${repo}\`
- **Bounded context**: <!-- Fill in: what this service is responsible for -->
- **Key aggregates**: <!-- Fill in: main domain objects -->
- **Java package root**: \`${javaPackage}.${repo.replace(/-/g, '.')}\`

## Skill References

| When you need to... | Read skill |
|---------------------|-----------|
| Write implementation code | \`quarkus-backend/SKILL.md\` |
| Write or audit tests | \`tdd-workflow/SKILL.md\` |
| Layer boundary decisions | \`clean-architecture/SKILL.md\` |
| Design aggregates or value objects | \`domain-driven-design/SKILL.md\` |
| Write or review DB migrations | \`flyway-oracle/SKILL.md\` |
| Design REST API | \`api-design/SKILL.md\` |

## Responsibilities

- Own all implementation decisions for \`${repo}\`.
- Define acceptance criteria for new features.
- Coordinate with \`backend-engineer\`, \`database-engineer\`, \`tdd-validator\`.
- Report blocking issues to \`${name}-orchestrator\`.

## Constraints

- Always check \`oracle-official\` before proposing schema changes.
- All code must pass the layer checklist in \`clean-architecture/SKILL.md\`.
- Tests must use JUnit 5 + Mockito only — no \`@QuarkusTest\`.

## Output Format

- \`analysis\`: current repository state
- \`plan\`: implementation steps with layer assignments
- \`delegate-to\`: which role agent handles each step
`;

    await writeFile(agentPath, content);

    // Companion skill stub
    const skillPath = path.join(WORKSPACE_ROOT, '.github', 'skills', agentName, 'SKILL.md');
    if (!fs.existsSync(skillPath)) {
      const skillContent = `---
name: ${agentName}
description: "Domain patterns and procedures for ${repo} bounded context in ${domain}."
argument-hint: "Domain pattern needed — e.g. '{entity} aggregate', '{feature} business rule'"
user-invocable: false
---

# ${repo} — Domain Patterns

## Context

<!-- Fill in: what business problem this bounded context solves -->

## Key Concepts

<!-- Fill in: domain vocabulary, abbreviations, key terms -->
| Term | Definition |
|------|-----------|
| \`{term}\` | {definition} |

## Aggregates

<!-- Fill in: list aggregate roots with their key invariants -->

## Business Rules

<!-- Fill in: domain rules that agents must enforce -->

## Key Queries / Operations

<!-- Fill in: most common data access patterns -->

## Checklist

- [ ] {rule 1}
- [ ] {rule 2}
`;
      await writeFile(skillPath, skillContent);
    }
  }
}

// --- Generate AGENTS.md ---
async function generateAgentsMd() {
  const agentsMdPath = path.join(WORKSPACE_ROOT, 'AGENTS.md');
  if (fs.existsSync(agentsMdPath)) {
    results.push({ path: rel(agentsMdPath), status: 'skipped-existing' });
    return;
  }

  const content = `# ${domain} Workspace — AI Bootstrap Rules

## Scope
- Treat this workspace root as a multi-repo shell, not as a single Git repository.
- Detect repository folders before writing repo-local agent files.
- Use [.ai/memory/workspace-map.json](.ai/memory/workspace-map.json) as the live workspace inventory.

## Source Of Truth
- \`.github/agents/\` — canonical agent definitions
- \`.github/skills/\` — canonical skills
- \`.github/prompts/\` — canonical prompt entry points
- \`.ai/memory/\` — machine-generated bootstrap inventory

## Domain
- Name: ${name}
- Domain: ${domain}
- Stack: ${stack}
- Java package: ${javaPackage}

## Repositories
${repos.map(r => `- \`${r}\``).join('\n') || '- (add repositories here)'}

## MCP Policy
- Read [.vscode/mcp.json](.vscode/mcp.json) before proposing new MCP servers.
- Reuse existing MCPs: \`bitbucket-corporate\`, \`oracle-official\`.

## Safety
- Never overwrite existing repo-local CLAUDE.md, AGENTS.md, or .github assets without explicit request.
- Do not assume every repository should inherit workspace-level adapters automatically.
`;

  await writeFile(agentsMdPath, content);
}

// --- Generate package.json scripts ---
async function generatePackageJson() {
  const pkgPath = path.join(WORKSPACE_ROOT, 'package.json');
  if (fs.existsSync(pkgPath)) {
    results.push({ path: rel(pkgPath), status: 'skipped-existing' });
    return;
  }

  const content = JSON.stringify({
    name: `${name}-workspace`,
    version: '1.0.0',
    description: `${domain} multi-repo workspace`,
    type: 'commonjs',
    scripts: {
      'bootstrap:ai': 'node scripts/bootstrap-ai-workspace.mjs',
      'bootstrap:ai:dry-run': 'node scripts/bootstrap-ai-workspace.mjs --dry-run',
      'bootstrap:ai:all': 'node scripts/bootstrap-ai-workspace.mjs --shared-skills --shared-agents',
      'bootstrap:agents:audit': 'powershell -NoProfile -NonInteractive -File .github/skills/agent-scaffolding/scripts/scaffold-agents.ps1 -AuditOnly',
    },
  }, null, 2) + '\n';

  await writeFile(pkgPath, content);
}

// --- Main ---
async function main() {
  await copyAgents();
  await copySkills();
  await generateOrchestratorAgent();
  await generateTeamLeads();
  await generateAgentsMd();
  await generatePackageJson();

  console.log('\n=== Results ===');
  for (const r of results) {
    console.log(`  [${r.status}] ${r.path}`);
  }

  const created = results.filter(r => r.status === 'created').length;
  const skipped = results.filter(r => r.status.startsWith('skipped')).length;
  const dryCount = results.filter(r => r.status.startsWith('dry-run')).length;

  console.log(`\nSummary: ${created} created, ${skipped} skipped (already exist), ${dryCount} dry-run previewed`);

  if (!dryRun && created > 0) {
    console.log('\nNext steps:');
    console.log('  1. Review generated agents in .github/agents/');
    console.log('  2. Fill in {placeholder} sections in the orchestrator and team lead agents');
    console.log('  3. Fill in domain concepts in .github/skills/{name}-*/SKILL.md');
    console.log('  4. Run: npm run bootstrap:ai');
    console.log('  5. Configure .vscode/mcp.json with oracle-official and bitbucket-corporate');
  }
}

main().catch(err => { console.error(err); process.exit(1); });
