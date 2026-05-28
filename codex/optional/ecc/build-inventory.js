#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);

function readArg(name, fallback = '') {
  const index = args.indexOf(name);
  if (index === -1) return fallback;
  if (index + 1 >= args.length) {
    throw new Error(`${name} requires a value`);
  }
  return args[index + 1];
}

function walk(root, prefix = '') {
  const entries = [];
  for (const dirent of fs.readdirSync(path.join(root, prefix), { withFileTypes: true })) {
    const relative = path.posix.join(prefix, dirent.name);
    entries.push({ path: relative, type: dirent.isDirectory() ? 'tree' : 'blob' });
    if (dirent.isDirectory()) {
      entries.push(...walk(root, relative));
    }
  }
  return entries;
}

function readTree() {
  const treeFile = readArg('--tree');
  const source = readArg('--source');
  if (treeFile) {
    const parsed = JSON.parse(fs.readFileSync(treeFile, 'utf8'));
    return parsed.tree || parsed;
  }
  if (source) {
    return walk(path.resolve(source));
  }
  throw new Error('provide --tree <github-tree-json> or --source <ECC clone>');
}

function namesFrom(paths, pattern, replace) {
  return paths
    .filter((entry) => pattern.test(entry.path) && entry.type !== 'tree')
    .map((entry) => entry.path.replace(replace, '$1'))
    .sort();
}

const tree = readTree();
const skills = namesFrom(tree, /^skills\/[^/]+\/SKILL\.md$/, /^skills\/([^/]+)\/SKILL\.md$/);
const commands = namesFrom(tree, /^commands\/[^/]+\.md$/, /^commands\/([^/]+)\.md$/);
const codexAgents = namesFrom(
  tree,
  /^\.codex\/agents\/[^/]+\.toml$/,
  /^\.codex\/agents\/([^/]+)\.toml$/,
);
const rulesFiles = tree.filter((entry) => entry.type !== 'tree' && entry.path.startsWith('rules/'));
const scriptsFiles = tree.filter((entry) => entry.type !== 'tree' && entry.path.startsWith('scripts/'));
const mcpServers = readArg('--mcp', '')
  .split(',')
  .map((name) => name.trim())
  .filter(Boolean)
  .sort();
const hookBundles = [];

if (tree.some((entry) => entry.path === 'hooks/hooks.json')) {
  hookBundles.push({
    name: 'runtime',
    path: 'hooks/hooks.json',
    status: 'stage-only',
    reason: 'ECC hook graph is runtime-specific and must be audited before Codex enablement.',
  });
}

if (tree.some((entry) => entry.path === 'hooks/memory-persistence/hooks.json')) {
  hookBundles.push({
    name: 'memory-persistence',
    path: 'hooks/memory-persistence/hooks.json',
    status: 'stage-only',
    reason: 'Lifecycle memory hooks are useful but need explicit Codex adapter review.',
  });
}

const checkedAt = readArg('--checked-at', new Date().toISOString().slice(0, 10));
const commit = readArg('--commit');
const version = readArg('--version', 'unknown');
const outDir = __dirname;

const inventory = {
  schema_version: 1,
  upstream: {
    name: 'ECC',
    repository: 'https://github.com/affaan-m/ECC',
    branch: 'main',
    commit,
    version,
    checked_at: checkedAt,
  },
  counts: {
    skills: skills.length,
    commands: commands.length,
    codex_agents: codexAgents.length,
    mcp_servers: mcpServers.length,
    hook_bundles: hookBundles.length,
    rule_files: rulesFiles.length,
    script_files: scriptsFiles.length,
  },
  plugin_surfaces: {
    codex_plugin_manifest: '.codex-plugin/plugin.json',
    codex_marketplace: '.agents/plugins/marketplace.json',
    shared_skills: 'skills/',
    mcp_config: '.mcp.json',
    codex_agents: '.codex/agents/',
    commands: 'commands/',
    hooks: 'hooks/',
    rules: 'rules/',
    scripts: 'scripts/',
  },
  mcp_servers: mcpServers,
  hook_bundles: hookBundles,
  codex_agents: codexAgents,
  skills,
  commands,
};

const lock = {
  schema_version: 1,
  name: 'ECC',
  repository: 'https://github.com/affaan-m/ECC',
  branch: 'main',
  commit,
  version,
  checked_at: checkedAt,
  local_clone: 'upstream/ECC',
};

fs.writeFileSync(path.join(outDir, 'inventory.json'), `${JSON.stringify(inventory, null, 2)}\n`);
fs.writeFileSync(path.join(outDir, 'upstream.lock'), `${JSON.stringify(lock, null, 2)}\n`);

