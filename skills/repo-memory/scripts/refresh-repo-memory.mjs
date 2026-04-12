#!/usr/bin/env node

import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const WORKSPACE_ROOT = process.cwd();
const args = new Set(process.argv.slice(2));
const SKIP_DIRS = new Set([
  '.git',
  '.idea',
  '.vscode',
  'node_modules',
  'target',
  'build',
  'dist',
  'coverage',
  'Lib',
  'site-packages',
  '__pycache__',
]);

function getArg(flag) {
  for (let index = 0; index < process.argv.length; index += 1) {
    const token = process.argv[index];
    if (token.startsWith(flag + '=')) return token.slice(flag.length + 1);
    if (token === flag) return process.argv[index + 1] ?? '';
  }
  return null;
}

async function pathExists(targetPath) {
  try {
    await fsp.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function ensureDir(targetPath) {
  await fsp.mkdir(targetPath, { recursive: true });
}

async function readJsonIfExists(filePath) {
  if (!(await pathExists(filePath))) {
    return null;
  }

  try {
    return JSON.parse(await fsp.readFile(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function runGit(repoRoot, gitArgs) {
  try {
    return execFileSync('git', gitArgs, {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

async function writeIfChanged(filePath, content) {
  try {
    if ((await fsp.readFile(filePath, 'utf8')) === content) {
      return false;
    }
  } catch {
    // File does not exist.
  }

  await ensureDir(path.dirname(filePath));
  await fsp.writeFile(filePath, content, 'utf8');
  return true;
}

async function scanDirectory(rootDir, maxDepth, collector, currentDepth = 0) {
  if (currentDepth > maxDepth) {
    return;
  }

  let entries = [];
  try {
    entries = await fsp.readdir(rootDir, { withFileTypes: true });
  } catch {
    return;
  }

  for (const entry of entries) {
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) {
        continue;
      }
      await scanDirectory(path.join(rootDir, entry.name), maxDepth, collector, currentDepth + 1);
      continue;
    }

    await collector(path.join(rootDir, entry.name));
  }
}

function firstMatch(text, regex) {
  const match = text.match(regex);
  return match ? match[1].trim() : '';
}

function uniqueSorted(values) {
  return Array.from(new Set(values.filter(Boolean))).sort((left, right) => left.localeCompare(right));
}

function parsePom(xmlText, filePath) {
  const withoutParent = xmlText.replace(/<parent>[\s\S]*?<\/parent>/, '');
  const artifactId = firstMatch(withoutParent, /<artifactId>([^<]+)<\/artifactId>/);
  const dependencyBlocks = Array.from(xmlText.matchAll(/<dependency>([\s\S]*?)<\/dependency>/g));
  const dependencies = uniqueSorted(
    dependencyBlocks
      .map(match => firstMatch(match[1], /<artifactId>([^<]+)<\/artifactId>/))
      .filter(value => value && value !== artifactId)
  ).slice(0, 15);

  return {
    file: filePath,
    artifactId: artifactId || path.basename(path.dirname(filePath)),
    dependencies,
  };
}

async function collectRepoSignals(repoRoot) {
  const pomFiles = [];
  const packageFiles = [];
  const dockerfiles = [];
  const openapiFiles = [];
  const readmes = [];
  const xhtmlFiles = [];
  const infoFiles = [];
  const techSignals = new Set();
  const kafkaAnnotations = new Set();
  const kafkaChannelMap = new Map();
  const deploymentSignals = [];

  function rememberKafkaSetting(direction, channel, propertyName, propertyValue = '') {
    const key = `${direction}:${channel}`;
    const current = kafkaChannelMap.get(key) || { direction, channel, topic: '', properties: new Set() };
    current.properties.add(propertyName);
    if (propertyName === 'topic' && propertyValue) {
      current.topic = propertyValue;
    }
    kafkaChannelMap.set(key, current);
  }

  await scanDirectory(repoRoot, 5, async filePath => {
    const relativePath = path.relative(repoRoot, filePath).replaceAll('\\', '/');
    const fileName = path.basename(filePath);
    const extension = path.extname(fileName).toLowerCase();

    if (fileName === 'pom.xml') {
      const xmlText = await fsp.readFile(filePath, 'utf8');
      pomFiles.push(parsePom(xmlText, relativePath));
      if (/quarkus/i.test(xmlText)) techSignals.add('quarkus');
      if (/oracle/i.test(xmlText)) techSignals.add('oracle');
      if (/kafka/i.test(xmlText)) techSignals.add('kafka');
      if (/javax\.faces|jakarta\.faces|primefaces/i.test(xmlText)) techSignals.add('jsf');
      return;
    }

    if (fileName === 'package.json') {
      try {
        const parsed = JSON.parse(await fsp.readFile(filePath, 'utf8'));
        packageFiles.push({
          file: relativePath,
          dependencies: uniqueSorted([
            ...Object.keys(parsed.dependencies || {}),
            ...Object.keys(parsed.devDependencies || {}),
          ]).slice(0, 15),
        });
      } catch {
        packageFiles.push({ file: relativePath, dependencies: [] });
      }
      return;
    }

    if (/^Dockerfile/i.test(fileName)) {
      dockerfiles.push(relativePath);
      return;
    }

    if (/^README/i.test(fileName)) {
      readmes.push(relativePath);
      return;
    }

    if (/openapi.*\.(yaml|yml|json)$/i.test(fileName)) {
      openapiFiles.push(relativePath);
      return;
    }

    if (fileName === 'info.yaml') {
      infoFiles.push(relativePath);
      return;
    }

    if (extension === '.xhtml') {
      xhtmlFiles.push(relativePath);
      techSignals.add('jsf');
      return;
    }

    if (relativePath.startsWith('deployment/')) {
      deploymentSignals.push(relativePath);
    }

    if (!['.java', '.properties', '.yaml', '.yml'].includes(extension)) {
      return;
    }

    const text = await fsp.readFile(filePath, 'utf8');
    if (/quarkus/i.test(text)) techSignals.add('quarkus');
    if (/oracle|jdbc:oracle/i.test(text)) techSignals.add('oracle');
    if (/kafka|smallrye-kafka|mp\.messaging/i.test(text)) techSignals.add('kafka');
    if (/javax\.faces|jakarta\.faces|primefaces/i.test(text)) techSignals.add('jsf');

    for (const line of text.split(/\r?\n/)) {
      const propertyMatch = line.match(/mp\.messaging\.(incoming|outgoing)\.([^.\s=]+)\.([A-Za-z0-9._-]+)\s*[:=]\s*(.+)$/);
      if (propertyMatch) {
        rememberKafkaSetting(propertyMatch[1], propertyMatch[2], propertyMatch[3], propertyMatch[4].trim());
      }
    }

    for (const match of text.matchAll(/@(Incoming|Outgoing|Channel)\("([^"]+)"\)/g)) {
      kafkaAnnotations.add(`${match[1]}:${match[2]}`);
    }
  });

  return {
    pomFiles,
    packageFiles,
    dockerfiles: uniqueSorted(dockerfiles),
    openapiFiles: uniqueSorted(openapiFiles),
    readmes: uniqueSorted(readmes),
    xhtmlFiles: uniqueSorted(xhtmlFiles),
    infoFiles: uniqueSorted(infoFiles),
    deploymentSignals: uniqueSorted(deploymentSignals).slice(0, 20),
    techSignals: uniqueSorted(Array.from(techSignals)),
    kafkaChannels: Array.from(kafkaChannelMap.values())
      .sort((left, right) => `${left.direction}:${left.channel}`.localeCompare(`${right.direction}:${right.channel}`))
      .map(channel => ({
        direction: channel.direction,
        channel: channel.channel,
        topic: channel.topic,
        properties: uniqueSorted(Array.from(channel.properties)),
      })),
    kafkaAnnotations: uniqueSorted(Array.from(kafkaAnnotations)),
  };
}

function formatList(values, emptyLabel = '- none detected') {
  if (values.length === 0) {
    return `${emptyLabel}\n`;
  }

  return values.map(value => `- ${value}`).join('\n') + '\n';
}

function formatPomSection(pomFiles) {
  if (pomFiles.length === 0) {
    return '- none detected\n';
  }

  return pomFiles.map(pom => {
    const deps = pom.dependencies.length > 0 ? ` | deps: ${pom.dependencies.join(', ')}` : '';
    return `- ${pom.file} | artifactId: ${pom.artifactId}${deps}`;
  }).join('\n') + '\n';
}

function formatPackageSection(packageFiles) {
  if (packageFiles.length === 0) {
    return '- none detected\n';
  }

  return packageFiles.map(pkg => {
    const deps = pkg.dependencies.length > 0 ? ` | deps: ${pkg.dependencies.join(', ')}` : '';
    return `- ${pkg.file}${deps}`;
  }).join('\n') + '\n';
}

function formatKafkaChannels(channels) {
  if (channels.length === 0) {
    return '- none detected\n';
  }

  return channels.map(channel => {
    const topic = channel.topic ? ` | topic: ${channel.topic}` : '';
    const properties = channel.properties.length > 0 ? ` | props: ${channel.properties.join(', ')}` : '';
    return `- ${channel.direction}:${channel.channel}${topic}${properties}`;
  }).join('\n') + '\n';
}

function buildDependenciesContent(repoName, signals) {
  const summarySignals = signals.techSignals.length > 0 ? signals.techSignals.join(', ') : 'no strong signals detected yet';
  const xhtmlSummary = signals.xhtmlFiles.length > 0 ? `${signals.xhtmlFiles.length} XHTML file(s)` : 'no XHTML detected';

  return `# ${repoName} Dependencies

> AUTO-GENERATED by .github/skills/repo-memory/scripts/refresh-repo-memory.mjs
> Refresh this file with: npm run memory:refresh

## Summary

- Technology signals: ${summarySignals}
- Legacy UI signal: ${xhtmlSummary}
- OpenAPI files: ${signals.openapiFiles.length}
- Dockerfiles: ${signals.dockerfiles.length}

## Build And Modules

### Maven
${formatPomSection(signals.pomFiles)}
### Node
${formatPackageSection(signals.packageFiles)}

## Integration Signals

### Kafka Config And Channels
${formatKafkaChannels(signals.kafkaChannels)}
### Kafka Code Annotations
${formatList(signals.kafkaAnnotations, '- none detected')}
### Deployment Files
${formatList(signals.deploymentSignals, '- none detected')}

## Surface Files

### OpenAPI
${formatList(signals.openapiFiles, '- none detected')}
### Info Files
${formatList(signals.infoFiles, '- none detected')}
### Dockerfiles
${formatList(signals.dockerfiles, '- none detected')}
### README Files
${formatList(signals.readmes, '- none detected')}

## Legacy Entry Points

${formatList(signals.xhtmlFiles.slice(0, 15), '- none detected')}
`;
}

function buildRecentChangesContent(repoName, repoRoot) {
  const branch = runGit(repoRoot, ['rev-parse', '--abbrev-ref', 'HEAD']) || 'unknown';
  const latestCommits = runGit(repoRoot, ['log', '-5', '--date=short', '--pretty=format:%ad | %h | %s'])
    .split(/\r?\n/)
    .filter(Boolean);
  const workingTree = runGit(repoRoot, ['status', '--short'])
    .split(/\r?\n/)
    .filter(Boolean)
    .slice(0, 25);

  return `# ${repoName} Recent Changes

> AUTO-GENERATED by .github/skills/repo-memory/scripts/refresh-repo-memory.mjs
> Refresh this file with: npm run memory:refresh

## Latest Snapshot

- Branch: ${branch}
- Working tree entries: ${workingTree.length}

## Recent Commits

${formatList(latestCommits, '- no commits detected')}

## Working Tree

${formatList(workingTree, '- clean working tree')}
`;
}

function buildContextTemplate(repoName) {
  return `# ${repoName} Repository Memory

Keep this file compact. It is the stable, developer-owned memory for this repository.

## Mission

<!-- What this repository owns in the domain -->

## Primary Entry Points

<!-- REST resources, scheduled jobs, message listeners, or XHTML views -->

## Known Traps

<!-- Validation quirks, legacy mismatches, migration hazards, operational surprises -->

## Reusable Notes

<!-- Facts worth keeping across conversations -->
`;
}

async function getRepositories() {
  const explicitRepo = getArg('--repo');
  if (explicitRepo) {
    return [explicitRepo];
  }

  const workspaceMap = await readJsonIfExists(path.join(WORKSPACE_ROOT, '.ai', 'memory', 'workspace-map.json'));
  if (workspaceMap?.repositories?.length) {
    return workspaceMap.repositories.map(repo => repo.path);
  }

  const entries = await fsp.readdir(WORKSPACE_ROOT, { withFileTypes: true });
  const repos = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }

    if (await pathExists(path.join(WORKSPACE_ROOT, entry.name, '.git'))) {
      repos.push(entry.name);
    }
  }

  return repos;
}

async function refreshRepository(repoName) {
  const repoRoot = path.join(WORKSPACE_ROOT, repoName);
  if (!(await pathExists(repoRoot))) {
    console.log(`[skip] ${repoName} (missing repository path)`);
    return;
  }

  const memoryRoot = path.join(repoRoot, '.github', 'memory');
  await ensureDir(memoryRoot);

  const signals = await collectRepoSignals(repoRoot);
  const contextPath = path.join(memoryRoot, 'context.md');
  const dependenciesPath = path.join(memoryRoot, 'dependencies.md');
  const recentChangesPath = path.join(memoryRoot, 'recent-changes.md');

  if (!(await pathExists(contextPath))) {
    await writeIfChanged(contextPath, buildContextTemplate(repoName));
  }

  const dependencyUpdated = await writeIfChanged(dependenciesPath, buildDependenciesContent(repoName, signals));
  const recentChangesUpdated = await writeIfChanged(recentChangesPath, buildRecentChangesContent(repoName, repoRoot));
  const status = dependencyUpdated || recentChangesUpdated ? 'updated' : 'unchanged';

  console.log(`[${status}] ${repoName}/.github/memory`);
}

async function main() {
  if (!args.has('--all') && !getArg('--repo')) {
    console.error('Use --all or --repo <name>.');
    process.exit(1);
  }

  const repos = await getRepositories();
  for (const repoName of repos) {
    await refreshRepository(repoName);
  }
}

main().catch(error => {
  console.error(error.message || error);
  process.exit(1);
});