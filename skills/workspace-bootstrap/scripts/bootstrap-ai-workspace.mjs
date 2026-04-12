// Executable bootstrap engine for the workspace-level AI scaffolding.
// Detects the environment, ensures the Copilot runtime baseline, prunes
// previously managed legacy adapter paths, and writes inventory.
//
// Copilot-first model:
//   .ai/memory/     -> generated bootstrap inventory
//   .github/        -> canonical runtime assets (agents, skills, prompts)
//
// Legacy adapter folders (.claude, .gemini, .cursor, agents, .agents) are no
// longer created. If they were previously managed by this bootstrap, they are
// removed during repair to keep the runtime surface clean.

import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const workspaceRoot = process.cwd();
const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');
const deprecatedFlags = ['--open-agent-compat', '--shared-skills', '--shared-agents']
  .filter(flag => args.has(flag));

const adapterFolders = ['.github'];
const processNames = ['code', 'node'];
const legacyManagedRoots = ['.claude', '.gemini', '.cursor', 'agents', '.agents'];

async function pathExists(targetPath) {
  try {
    await fsp.lstat(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function ensureDir(targetPath) {
  if (!dryRun) {
    await fsp.mkdir(targetPath, { recursive: true });
  }
}

async function readJsonIfExists(filePath) {
  if (!(await pathExists(filePath))) return null;
  try {
    return JSON.parse(await fsp.readFile(filePath, 'utf8'));
  } catch {
    return null;
  }
}

async function writeTextIfChanged(filePath, content) {
  await ensureDir(path.dirname(filePath));
  try {
    if ((await fsp.readFile(filePath, 'utf8')) === content) {
      return false;
    }
  } catch {
    // File does not exist yet.
  }

  if (!dryRun) {
    await fsp.writeFile(filePath, content, 'utf8');
  }
  return true;
}

async function writeJson(filePath, value) {
  return writeTextIfChanged(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function runPowerShell(command) {
  try {
    return execFileSync(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', command],
      { cwd: workspaceRoot, encoding: 'utf8' }
    ).trim();
  } catch (error) {
    return String(error.stdout || '').trim();
  }
}

function detectProcesses() {
  const raw = runPowerShell(
    "$names = @('code','node'); " +
    "$found = Get-Process -Name $names -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique; " +
    "if ($found) { $found | ConvertTo-Json -Compress } else { '[]' }"
  );

  if (!raw) return [];

  try {
    const parsed = JSON.parse(raw);
    return (Array.isArray(parsed) ? parsed : [parsed]).map(value => String(value).toLowerCase());
  } catch {
    return [];
  }
}

async function detectRootAdapters() {
  const found = [];
  for (const folder of adapterFolders) {
    if (await pathExists(path.join(workspaceRoot, folder))) {
      found.push(folder);
    }
  }
  return found;
}

function classifyMode(processes) {
  return new Set(processes).has('code') ? 'IDE' : 'TERMINAL';
}

async function scanTopLevelFolders() {
  const entries = await fsp.readdir(workspaceRoot, { withFileTypes: true });
  const directories = entries
    .filter(entry => entry.isDirectory())
    .map(entry => ({ name: entry.name, fullPath: path.join(workspaceRoot, entry.name) }))
    .sort((left, right) => left.name.localeCompare(right.name));

  const repositories = [];
  const utilityDirectories = [];

  for (const directory of directories) {
    const assets = {
      hasAgents: await pathExists(path.join(directory.fullPath, 'AGENTS.md')),
      hasClaude: await pathExists(path.join(directory.fullPath, 'CLAUDE.md')),
      hasGithub: await pathExists(path.join(directory.fullPath, '.github')),
    };

    const record = {
      name: directory.name,
      path: directory.name,
      localAgentAssets: assets,
    };

    if (await pathExists(path.join(directory.fullPath, '.git'))) {
      repositories.push(record);
    } else {
      utilityDirectories.push(record);
    }
  }

  return { repositories, utilityDirectories };
}

async function loadMcpRegistry() {
  const parsed = await readJsonIfExists(path.join(workspaceRoot, '.vscode', 'mcp.json'));
  return {
    source: '.vscode/mcp.json',
    servers: parsed?.mcpServers ? Object.keys(parsed.mcpServers).sort() : [],
  };
}

function rel(targetPath) {
  return path.relative(workspaceRoot, targetPath).replaceAll('\\', '/') || '.';
}

async function removePathIfExists(targetPath, results) {
  if (!(await pathExists(targetPath))) return;
  if (dryRun) {
    results.push({ path: rel(targetPath), status: 'dry-run-would-remove' });
    return;
  }

  await fsp.rm(targetPath, { recursive: true, force: true });
  results.push({ path: rel(targetPath), status: 'removed-generated-path' });
}

function collectManagedPaths(previousMap) {
  const managed = new Set();
  if (!previousMap?.adapters || !Array.isArray(previousMap.adapters)) return managed;

  for (const adapter of previousMap.adapters) {
    if (adapter?.path) {
      managed.add(adapter.path.replaceAll('\\', '/'));
    }
  }

  return managed;
}

function isManagedPath(managed, targetPath) {
  return managed.has(rel(targetPath));
}

async function pruneEmptyParents(startPath, stopPath) {
  if (dryRun) return;

  let current = startPath;
  while (current.startsWith(stopPath) && current !== stopPath) {
    try {
      if ((await fsp.readdir(current)).length > 0) return;
      await fsp.rmdir(current);
      current = path.dirname(current);
    } catch {
      return;
    }
  }
}

async function applyCopilotRuntime(managedPaths) {
  const results = [];

  await ensureDir(path.join(workspaceRoot, '.github', 'agents'));
  results.push({ path: '.github/agents', status: 'ensured-directory' });
  await ensureDir(path.join(workspaceRoot, '.github', 'skills'));
  results.push({ path: '.github/skills', status: 'ensured-directory' });
  await ensureDir(path.join(workspaceRoot, '.github', 'prompts'));
  results.push({ path: '.github/prompts', status: 'ensured-directory' });

  for (const rootName of legacyManagedRoots) {
    const absolutePath = path.join(workspaceRoot, rootName);
    if (isManagedPath(managedPaths, absolutePath)) {
      await removePathIfExists(absolutePath, results);
      await pruneEmptyParents(path.dirname(absolutePath), workspaceRoot);
    }
  }

  return results;
}

async function main() {
  if (dryRun) {
    console.log('[DRY-RUN] Reporting planned changes only — no files will be written.\n');
  }
  if (deprecatedFlags.length > 0) {
    console.log(`[WARN] Ignoring deprecated flags: ${deprecatedFlags.join(', ')}`);
  }

  await ensureDir(path.join(workspaceRoot, '.ai', 'memory'));

  const previousMap = await readJsonIfExists(path.join(workspaceRoot, '.ai', 'memory', 'workspace-map.json'));
  const managedPaths = collectManagedPaths(previousMap);
  const rootAdapters = await detectRootAdapters();
  const processes = detectProcesses();
  const environment = {
    mode: classifyMode(processes),
    primary_tool: 'copilot',
    secondary_tools: [],
  };

  const { repositories, utilityDirectories } = await scanTopLevelFolders();
  const mcp = await loadMcpRegistry();
  const adapterResults = await applyCopilotRuntime(managedPaths);

  const workspaceMap = {
    generatedAt: new Date().toISOString(),
    workspaceRoot,
    baselineAdapterRoots: ['.github'],
    environment,
    detectedRootAdapters: rootAdapters,
    detectedProcesses: processes.filter(name => processNames.includes(name)).sort(),
    repositories,
    utilityDirectories,
    mcp,
    adapters: adapterResults,
  };

  if (!dryRun) {
    await writeJson(path.join(workspaceRoot, '.ai', 'memory', 'workspace-map.json'), workspaceMap);
    await writeJson(path.join(workspaceRoot, '.ai', 'memory', 'mcp-registry.json'), {
      generatedAt: workspaceMap.generatedAt,
      source: mcp.source,
      servers: mcp.servers,
    });
  }

  console.log(JSON.stringify(environment, null, 2));
  console.log('repositories=' + repositories.length);
  console.log('adapter_changes=' + adapterResults.length);
  if (dryRun) {
    console.log('\n[DRY-RUN] workspace-map.json and mcp-registry.json were NOT updated.');
  }
}

main().catch(error => {
  console.error(error.message || error);
  process.exitCode = 1;
});