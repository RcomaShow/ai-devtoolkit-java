#!/usr/bin/env node
/**
 * new-project.mjs — Initialize a new Copilot-first Java/Quarkus multi-repo workspace from ai-devtoolkit.
 *
 * Usage:
 *   node .ai-devtoolkit/scripts/new-project.mjs \
 *     --name my-domain \
 *     --domain "Gas Transport" \
 *     --repos "repo-core,repo-service-a,repo-service-b" \
 *     --managed-targets "shell-service-a,shell-service-b" \
 *     --package "com.company.mydomain" \
 *     --stack "quarkus+oracle" \
 *     --java 17
 *
 * Flags:
 *   --name        Workspace identifier (kebab-case) — used in folder names and repo-context skills
 *   --domain      Human-readable domain name — used in generated documentation
 *   --repos       Comma-separated list of repository names
 *   --managed-targets Comma-separated list of shell-level managed targets that are not normal git repositories
 *   --package     Java base package (com.company.domain)
 *   --stack       Technology stack tag (default: quarkus+oracle)
 *   --java        Java profile to target (17 or 21, default: 21)
 *   --dry-run     Print planned changes without writing files
 *
 * The generated workspace exposes two public Copilot agents: `team-lead` and `developer`.
 * Repository-specific context is captured in `.github/skills/{name}-{repo}/` skill folders
 * and in repo-local `.github/memory/` folders for compact live context.
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
const managedTargets = (getArg('--managed-targets') ?? '').split(',').map(value => value.trim()).filter(Boolean);
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

// Read toolkit version
const versionFile = path.join(TOOLKIT_ROOT, 'VERSION');
const toolkitVersion = fs.existsSync(versionFile)
  ? fs.readFileSync(versionFile, 'utf8').trim()
  : 'unknown';

console.log(`Initializing workspace: ${name}`);
console.log(`  Domain:   ${domain}`);
console.log(`  Repos:    ${repos.join(', ') || '(none — add manually later)'}`);
console.log(`  Targets:  ${managedTargets.join(', ') || '(none — shell targets can be declared later)'}`);
console.log(`  Package:  ${javaPackage}`);
console.log(`  Stack:    ${stack}`);
console.log(`  Java:     ${javaVersion}`);
console.log(`  Toolkit:  v${toolkitVersion}`);
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
  if (path.basename(srcDir) === '__pycache__') {
    return;
  }

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
    if (entry.name.endsWith('.pyc')) {
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

function generateRepoMemoryContext(repoName) {
  return `# ${repoName} Repository Memory

Keep this file compact. It is the stable, developer-owned memory for this repository.

## Mission

<!-- What this repository owns in the domain -->

## Primary Entry Points

<!-- REST resources, scheduled jobs, message listeners, batch entrypoints, or XHTML views -->

## Known Traps

<!-- Validation quirks, legacy mismatches, migration hazards, or operational surprises -->

## Business Notes Worth Reusing

<!-- Facts that should not be rediscovered in every conversation -->

## References

- Companion context skill: .github/skills/${name}-${repoName.replace(/[-_]/g, '-')}/SKILL.md
- Generated dependency map: .github/memory/dependencies.md
- Generated recent changes: .github/memory/recent-changes.md
`;
}

function generateRepoMemoryDependenciesPlaceholder(repoName) {
  return `# ${repoName} Dependencies

> Generated file. Refresh with: npm run memory:refresh

## Summary

- Pending refresh.

## Build And Modules

- Pending refresh.

## Integration Signals

- Pending refresh.
`;
}

function generateRepoMemoryRecentChangesPlaceholder(repoName) {
  return `# ${repoName} Recent Changes

> Generated file. Refresh with: npm run memory:refresh

## Latest Snapshot

- Pending refresh.
`;
}

function generateWorkspaceShellMemory() {
  return `# Workspace Shell Memory

Keep this file compact. It is the stable, developer-owned shell memory for this workspace.

## Active Workspace Root

- ${path.basename(WORKSPACE_ROOT)}

## Managed Shell Targets

${managedTargets.map(target => `- ${target}: workspace-level managed target; keep shell-level facts here instead of forcing repo memory`).join('\n') || '- None declared yet.'}

## MCP Policy

- Baseline required: bitbucket-corporate, oracle-official
- Optional: mssql-server
- .ai/memory/mcp-registry.json is a generated mirror; rerun npm run bootstrap:ai after .vscode/mcp.json changes.

## Known Limits

- .ai/memory/workspace-map.json is root-scoped and does not model a full VS Code multi-root session.
- Keep repo-specific facts in <repo>/.github/memory/ and only shell-level facts here.
`;
}

function generateControlPlaneConfig() {
  return `${JSON.stringify({
    version: 1,
    shellMemory: {
      path: '.github/memory/workspace-shell.md',
      owner: 'developer',
      managedByBootstrap: false,
    },
    managedTargets: managedTargets.map(target => ({
      name: target,
      path: target,
      kind: 'workspace-service',
      contextSurface: 'workspace-shell',
    })),
    mcpPolicy: {
      source: '.vscode/mcp.json',
      baselineRequired: ['bitbucket-corporate', 'oracle-official'],
      optional: ['mssql-server'],
    },
  }, null, 2)}\n`;
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

async function copyPrompts() {
  const promptSrc = path.join(TOOLKIT_ROOT, 'prompts');
  const promptDst = path.join(WORKSPACE_ROOT, '.github', 'prompts');
  await ensureDir(promptDst);

  if (!fs.existsSync(promptSrc)) {
    return;
  }

  const entries = await fsp.readdir(promptSrc, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    await copyTextFile(path.join(promptSrc, entry.name), path.join(promptDst, entry.name));
  }
}

async function copyLegacyWorkspaceSurface() {
  const legacySrc = path.join(TOOLKIT_ROOT, 'templates', 'legacy');
  const legacyDst = path.join(WORKSPACE_ROOT, '.github', 'legacy');

  if (!fs.existsSync(legacySrc)) {
    return;
  }

  await copyDirectoryTree(legacySrc, legacyDst);
}

async function copyVscodeTemplates() {
  const mcpEnvTemplateSrc = path.join(TOOLKIT_ROOT, 'templates', 'mcp.env.template.json');
  const mcpEnvTemplateDst = path.join(WORKSPACE_ROOT, '.vscode', 'mcp.env.template.json');

  if (fs.existsSync(mcpEnvTemplateSrc)) {
    await copyTextFile(mcpEnvTemplateSrc, mcpEnvTemplateDst);
  }
}

async function generateWorkspaceControlPlane() {
  await writeFile(path.join(WORKSPACE_ROOT, '.github', 'bootstrap', 'control-plane.json'), generateControlPlaneConfig());
  await writeFile(path.join(WORKSPACE_ROOT, '.github', 'memory', 'workspace-shell.md'), generateWorkspaceShellMemory());
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

async function generateRepositoryMemory() {
  for (const repo of repos) {
    const repoRoot = path.join(WORKSPACE_ROOT, repo);
    if (!fs.existsSync(repoRoot) || !fs.lstatSync(repoRoot).isDirectory()) {
      results.push({ path: rel(repoRoot), status: 'skipped-repo-missing' });
      continue;
    }

    const memoryRoot = path.join(repoRoot, '.github', 'memory');
    await writeFile(path.join(memoryRoot, 'context.md'), generateRepoMemoryContext(repo));
    await writeFile(path.join(memoryRoot, 'dependencies.md'), generateRepoMemoryDependenciesPlaceholder(repo));
    await writeFile(path.join(memoryRoot, 'recent-changes.md'), generateRepoMemoryRecentChangesPlaceholder(repo));
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
- Keep curated shell-level facts in .github/memory/workspace-shell.md and keep .ai/memory/* generated-only.
- Use repo-local \.github/memory/ only for compact repository memory, not for duplicating the workspace runtime.
- Use [.ai/memory/workspace-map.json](.ai/memory/workspace-map.json) as the live workspace inventory.

## Source Of Truth
- \`.github/agents/\` — canonical runtime agent definitions
- \`.github/skills/\` — canonical runtime skills and colocated assets
- \`.github/prompts/\` — canonical prompt entry points
- \`.github/bootstrap/control-plane.json\` — declarative bootstrap policy for shell memory, managed targets, and MCP baseline
- \`.github/memory/workspace-shell.md\` — developer-owned shell memory for cross-repo and non-repo targets
- \`.ai/memory/\` — machine-generated bootstrap inventory
- \`<repo>/.github/memory/\` — compact repo-local memory for stable facts and live technical context

Tooling assets originate from \`.ai-devtoolkit/\`, but runtime discovery happens from the workspace-local \`.github/\` and root instruction files only.

## Public Copilot Surface
- \`@team-lead\` — premium orchestration across hidden specialists and workflow-driven review/fix loops.
- \`@developer\` — bounded direct execution path for smaller paid models without sub-agent delegation.
- Repository context is split between workspace repo skills and repo-local memory files.

## Repository Context Skills
${repos.map(repo => `- \`.github/skills/${name}-${repo.replace(/[-_]/g, '-')}/SKILL.md\``).join('\n') || '- Add repository context skills as repositories are onboarded.'}

## Repository Memory
${repos.map(repo => `- \`${repo}/.github/memory/\``).join('\n') || '- Add repo-local memory folders as repositories are onboarded.'}

## Managed Shell Targets
${managedTargets.map(target => `- \`${target}\` -> workspace-shell context`).join('\n') || '- Add shell-level managed targets in .github/bootstrap/control-plane.json when needed.'}

## Domain
- Name: ${name}
- Domain: ${domain}
- Stack: ${stack}
- Java version: ${javaVersion}
- Java package: ${javaPackage}
- Toolkit version: ${toolkitVersion}

## Repositories
${repos.map(repo => `- \`${repo}\``).join('\n') || '- (add repositories here)'}

## MCP Policy
- Read [.vscode/mcp.json](.vscode/mcp.json) before proposing new MCP servers.
- Keep baseline-vs-optional policy in .github/bootstrap/control-plane.json.
- Reuse existing MCPs: \`bitbucket-corporate\`, \`oracle-official\`.
- Never keep secrets inline in \`.vscode/mcp.json\` — use environment variable references only.

## Safety
- Never overwrite existing repo-local AGENTS.md or .github assets without explicit request.
- Do not assume every repository should inherit workspace-level adapters automatically.
- Do not overwrite .github/memory/workspace-shell.md; bootstrap may scaffold it once but it is developer-owned afterward.
- Do not duplicate workspace agents or shared skills inside repo-local .github; repo-local .github/memory is the approved repo-memory surface.
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
      'bootstrap:project': 'powershell -NoProfile -NonInteractive -File .github/skills/bootstrap-project/scripts/bootstrap-project.ps1',
      'legacy:case': 'powershell -NoProfile -NonInteractive -File .github/skills/legacy-analysis/scripts/new-legacy-case.ps1',
      'legacy:analyze:xhtml': 'powershell -NoProfile -NonInteractive -File .github/skills/legacy-analysis/scripts/run-legacy-xhtml-analysis.ps1',
      'memory:refresh': 'node .github/skills/repo-memory/scripts/refresh-repo-memory.mjs --all',
      'toolkit:health': 'powershell -NoProfile -NonInteractive -File .github/skills/toolkit-health/scripts/audit-toolkit-health.ps1 -Full'
    }
  }, null, 2) + '\n';

  await writeFile(pkgPath, content);
}

// --- Main -----------------------------------------------------------------

async function main() {
  await copyAgents();
  await copySkills();
  await copyPrompts();
  await copyLegacyWorkspaceSurface();
  await copyVscodeTemplates();
  await generateWorkspaceControlPlane();
  await generateRepositoryContexts();
  await generateRepositoryMemory();
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
    console.log('  1. Review .github/agents/team-lead.agent.md for premium orchestration and .github/agents/developer.agent.md for mini-model execution');
    console.log('  2. Fill in repository concepts, templates, and guardrails in .github/skills/{name}-*/');
    console.log('  3. Fill in <repo>/.github/memory/context.md with stable repo facts and traps');
    console.log('  4. Review .github/legacy/ for the standard legacy analysis surface and use npm run legacy:case or npm run legacy:analyze:xhtml');
    console.log('  5. Review .github/prompts/choose-runtime-profile.prompt.md for model and effort selection guidance');
    console.log('  6. Review AGENTS.md for workspace-specific operating rules');
    console.log('  7. Run: npm run bootstrap:ai');
    console.log('  8. Run: npm run memory:refresh');
    console.log('  9. Run: npm run bootstrap:security:audit');
    console.log(' 10. Configure .vscode/mcp.json with oracle-official and bitbucket-corporate');
  }
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});