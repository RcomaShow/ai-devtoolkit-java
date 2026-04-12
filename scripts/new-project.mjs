#!/usr/bin/env node
/**
 * new-project.mjs — Initialize a new Copilot-first Java/Quarkus multi-repo workspace from ai-devtoolkit.
 *
 * Usage:
 *   node .ai-devtoolkit/scripts/new-project.mjs \
 *     --name my-domain \
 *     --domain "Gas Transport" \
 *     --repos "repo-core,repo-service-a,repo-service-b" \
 *     --package "com.company.mydomain" \
 *     --stack "quarkus+oracle" \
 *     --java 17
 *
 * Flags:
 *   --name        Workspace identifier (kebab-case) — used in folder names and repo-context skills
 *   --domain      Human-readable domain name — used in generated documentation
 *   --repos       Comma-separated list of repository names
 *   --package     Java base package (com.company.domain)
 *   --stack       Technology stack tag (default: quarkus+oracle)
 *   --java        Java profile to target (17 or 21, default: 21)
 *   --dry-run     Print planned changes without writing files
 *
 * The generated workspace exposes one public Copilot agent: `team-lead`.
 * Repository-specific context is captured in `.github/skills/{name}-{repo}/` skill folders.
 */

import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TOOLKIT_ROOT = path.resolve(__dirname, '..');
const WORKSPACE_ROOT = process.cwd();

// --- Argument parsing ------------------------------------------------------

const args = new Set(process.argv.slice(2));

function getArg(flag) {
  for (let index = 0; index < process.argv.length; index += 1) {
    const token = process.argv[index];
    if (token.startsWith(flag + '=')) return token.slice(flag.length + 1);
    if (token === flag) return process.argv[index + 1] ?? '';
  }
  return null;
}

const dryRun = args.has('--dry-run');
const name = getArg('--name');
const domain = getArg('--domain') ?? name;
const repos = (getArg('--repos') ?? '').split(',').map(value => value.trim()).filter(Boolean);
const javaPackage = getArg('--package') ?? `com.company.${name}`;
const stack = getArg('--stack') ?? 'quarkus+oracle';
const javaVersion = getArg('--java') ?? '21';

if (!name) {
  console.error('ERROR: --name is required');
  console.error('Usage: node new-project.mjs --name <name> --domain "<domain>" --repos "<repo1,repo2>" --package "<com.company.domain>"');
  process.exit(1);
}

if (!['17', '21'].includes(javaVersion)) {
  console.error('ERROR: --java must be 17 or 21');
  process.exit(1);
}

if (dryRun) {
  console.log('[DRY-RUN] Reporting planned changes only — no files will be written.\n');
}

console.log(`Initializing workspace: ${name}`);
console.log(`  Domain:   ${domain}`);
console.log(`  Repos:    ${repos.join(', ') || '(none — add manually later)'}`);
console.log(`  Package:  ${javaPackage}`);
console.log(`  Stack:    ${stack}`);
console.log(`  Java:     ${javaVersion}`);
console.log('');

const results = [];

// --- Utility helpers -------------------------------------------------------

function rel(targetPath) {
  return path.relative(WORKSPACE_ROOT, targetPath).replaceAll('\\', '/');
}

async function ensureDir(dirPath) {
  if (dryRun) return;
  await fsp.mkdir(dirPath, { recursive: true });
}

async function writeFile(filePath, content, options = {}) {
  const overwrite = options.overwrite ?? false;
  const exists = fs.existsSync(filePath);

  if (exists) {
    const current = await fsp.readFile(filePath, 'utf8');
    if (current === content) {
      results.push({ path: rel(filePath), status: 'unchanged' });
      return;
    }
    if (!overwrite) {
      results.push({ path: rel(filePath), status: 'skipped-existing' });
      return;
    }
  }

  if (dryRun) {
    results.push({ path: rel(filePath), status: exists ? 'dry-run-would-update' : 'dry-run-would-create' });
    return;
  }

  await fsp.mkdir(path.dirname(filePath), { recursive: true });
  await fsp.writeFile(filePath, content, 'utf8');
  results.push({ path: rel(filePath), status: exists ? 'updated' : 'created' });
}

async function copyTextFile(srcFile, dstFile) {
  const content = await fsp.readFile(srcFile, 'utf8');
  await writeFile(dstFile, content);
}

async function copyDirectoryTree(srcDir, dstDir, rootDir = srcDir) {
  if (srcDir !== rootDir && fs.existsSync(path.join(srcDir, 'SKILL.md'))) {
    return;
  }

  if (!dryRun) {
    await fsp.mkdir(dstDir, { recursive: true });
  }

  const entries = await fsp.readdir(srcDir, { withFileTypes: true });
  for (const entry of entries) {
    const src = path.join(srcDir, entry.name);
    const dst = path.join(dstDir, entry.name);
    if (entry.isDirectory()) {
      await copyDirectoryTree(src, dst, rootDir);
      continue;
    }
    await copyTextFile(src, dst);
  }
}

function generateDomainSkillContent(repoName) {
  return `---
name: ${name}-${repoName.replace(/[-_]/g, '-')}
description: "Repository context, vocabulary, and business guardrails for ${repoName} in ${domain}."
argument-hint: "Repository context detail — e.g. '{entity} aggregate', '{feature} rule', 'key query'"
user-invocable: false
---

# ${repoName} — Repository Context

## Context

<!-- Fill in: what business problem this repository solves -->

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
}

function generateDomainGuardrails(repoName) {
  return `# ${repoName} Guardrails

- Keep this skill bounded to the ${repoName} context only.
- Validate any DB-facing rule against oracle-official before codifying it here.
- Record domain invariants before generating code or scaffolding templates.
- Do not duplicate generic Quarkus, Java, or testing rules already covered by shared skills.
`;
}

function generateDomainRuleTemplate() {
  return `# Domain Rule Template

## Rule
- Name: {rule-name}
- Trigger: {trigger}
- Expected outcome: {expected-outcome}

## Validation
- Source system: {source}
- Oracle check: {query-or-table}
- Test scenario: {scenario}
`;
}

// --- Copy toolkit agents ---------------------------------------------------

async function copyAgents() {
  const agentSrc = path.join(TOOLKIT_ROOT, 'agents');
  const agentDst = path.join(WORKSPACE_ROOT, '.github', 'agents');
  await ensureDir(agentDst);

  const genericAgents = (await fsp.readdir(agentSrc, { withFileTypes: true }))
    .filter(entry => entry.isFile() && entry.name.endsWith('.agent.md'))
    .map(entry => entry.name)
    .sort();

  for (const agentFile of genericAgents) {
    await copyTextFile(path.join(agentSrc, agentFile), path.join(agentDst, agentFile));
  }
}

// --- Copy toolkit skills ---------------------------------------------------

async function copySkills() {
  const skillSrc = path.join(TOOLKIT_ROOT, 'skills');
  const skillDst = path.join(WORKSPACE_ROOT, '.github', 'skills');
  await ensureDir(skillDst);

  const skillDirs = await fsp.readdir(skillSrc, { withFileTypes: true });
  for (const entry of skillDirs) {
    if (!entry.isDirectory()) continue;
    const srcSkillDir = path.join(skillSrc, entry.name);
    if (!fs.existsSync(path.join(srcSkillDir, 'SKILL.md'))) continue;
    await copyDirectoryTree(srcSkillDir, path.join(skillDst, entry.name));
  }
}

// --- Generate repository context skills -----------------------------------

async function generateRepositoryContexts() {
  for (const repo of repos) {
    const contextSkillName = `${name}-${repo.replace(/[-_]/g, '-')}`;
    const skillRoot = path.join(WORKSPACE_ROOT, '.github', 'skills', contextSkillName);
    await writeFile(path.join(skillRoot, 'SKILL.md'), generateDomainSkillContent(repo));
    await writeFile(path.join(skillRoot, 'references', 'guardrails.md'), generateDomainGuardrails(repo));
    await writeFile(path.join(skillRoot, 'assets', 'domain-rule.template.md'), generateDomainRuleTemplate());
  }
}

// --- Generate AGENTS.md ----------------------------------------------------

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
- \`.github/agents/\` — canonical runtime agent definitions
- \`.github/skills/\` — canonical runtime skills and colocated assets
- \`.github/prompts/\` — canonical prompt entry points
- \`.ai/memory/\` — machine-generated bootstrap inventory

Tooling assets originate from \`.ai-devtoolkit/\`, but runtime discovery happens from the workspace-local \`.github/\` and root instruction files only.

## Public Copilot Surface
- \`@team-lead\` — the only public agent. It owns analysis, planning, internal specialist delegation, review, and fix loops.

## Repository Context Skills
${repos.map(repo => `- \`.github/skills/${name}-${repo.replace(/[-_]/g, '-')}/SKILL.md\``).join('\n') || '- Add repository context skills as repositories are onboarded.'}

## Domain
- Name: ${name}
- Domain: ${domain}
- Stack: ${stack}
- Java version: ${javaVersion}
- Java package: ${javaPackage}

## Repositories
${repos.map(repo => `- \`${repo}\``).join('\n') || '- (add repositories here)'}

## MCP Policy
- Read [.vscode/mcp.json](.vscode/mcp.json) before proposing new MCP servers.
- Reuse existing MCPs: \`bitbucket-corporate\`, \`oracle-official\`.
- Never keep secrets inline in \`.vscode/mcp.json\` — use environment variable references only.

## Safety
- Never overwrite existing repo-local AGENTS.md or .github assets without explicit request.
- Do not assume every repository should inherit workspace-level adapters automatically.
`;

  await writeFile(agentsMdPath, content);
}

// --- Generate package.json scripts ----------------------------------------

async function generatePackageJson() {
  const pkgPath = path.join(WORKSPACE_ROOT, 'package.json');
  if (fs.existsSync(pkgPath)) {
    results.push({ path: rel(pkgPath), status: 'skipped-existing' });
    return;
  }

  const content = JSON.stringify({
    name: `${name}-workspace`,
    version: '1.0.0',
    description: `${domain} Copilot-first multi-repo workspace (Java ${javaVersion})`,
    type: 'commonjs',
    scripts: {
      'bootstrap:ai': 'node .github/skills/workspace-bootstrap/scripts/bootstrap-ai-workspace.mjs',
      'bootstrap:ai:dry-run': 'node .github/skills/workspace-bootstrap/scripts/bootstrap-ai-workspace.mjs --dry-run',
      'bootstrap:security:audit': 'powershell -NoProfile -NonInteractive -File .github/skills/workspace-bootstrap/scripts/audit-mcp-secrets.ps1',
      'bootstrap:agents': 'powershell -NoProfile -NonInteractive -File .github/skills/agent-scaffolding/scripts/scaffold-agents.ps1',
      'bootstrap:agents:audit': 'powershell -NoProfile -NonInteractive -File .github/skills/agent-scaffolding/scripts/scaffold-agents.ps1 -AuditOnly',
      'bootstrap:project': 'powershell -NoProfile -NonInteractive -File .github/skills/bootstrap-project/scripts/bootstrap-project.ps1'
    }
  }, null, 2) + '\n';

  await writeFile(pkgPath, content);
}

// --- Main -----------------------------------------------------------------

async function main() {
  await copyAgents();
  await copySkills();
  await generateRepositoryContexts();
  await generateAgentsMd();
  await generatePackageJson();

  console.log('\n=== Results ===');
  for (const result of results) {
    console.log(`  [${result.status}] ${result.path}`);
  }

  const created = results.filter(result => result.status === 'created').length;
  const skipped = results.filter(result => result.status.startsWith('skipped')).length;
  const dryCount = results.filter(result => result.status.startsWith('dry-run')).length;

  console.log(`\nSummary: ${created} created, ${skipped} skipped (already exist), ${dryCount} dry-run previewed`);

  if (!dryRun && created > 0) {
    console.log('\nNext steps:');
    console.log('  1. Review .github/agents/team-lead.agent.md and keep it as the only public entry point');
    console.log('  2. Fill in repository concepts, templates, and guardrails in .github/skills/{name}-*/');
    console.log('  3. Review AGENTS.md for workspace-specific operating rules');
    console.log('  4. Run: npm run bootstrap:ai');
    console.log('  5. Run: npm run bootstrap:security:audit');
    console.log('  6. Configure .vscode/mcp.json with oracle-official and bitbucket-corporate');
  }
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});