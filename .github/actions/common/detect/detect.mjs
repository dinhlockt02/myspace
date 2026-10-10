import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

/**
 * Execute a command safely, suppressing errors and returning fallback if it fails.
 */
function safeExec(command, fallback = '') {
  try {
    return execSync(command, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, CI: 'true', NX_DAEMON: 'false' },
    }).trim();
  } catch {
    return fallback;
  }
}

/**
 * Discover all top-level service directories under apps/
 */
function getAvailableServices() {
  const appsDir = path.resolve('apps');
  if (!fs.existsSync(appsDir)) return [];
  return fs.readdirSync(appsDir, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => dirent.name);
}

/**
 * Fetch all Nx projects in the workspace.
 */
function getAllNxProjects() {
  const raw = safeExec('pnpm --silent nx show projects --json', '[]');
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/**
 * Map each Nx project to its project root directory.
 */
function getProjectRoots(projects) {
  const map = {};
  for (const proj of projects) {
    const raw = safeExec(`pnpm --silent nx show project ${proj} --json`, '{}');
    try {
      const parsed = JSON.parse(raw);
      if (parsed.root) {
        map[proj] = parsed.root;
      }
    } catch {}
  }
  return map;
}

/**
 * Check if a git reference exists and can be resolved.
 */
function isValidGitRef(ref) {
  if (!ref) return false;
  const result = safeExec(`git rev-parse --verify "${ref}"`, '');
  return Boolean(result);
}

/**
 * Resolve base and head git refs for comparison.
 */
function resolveRefs() {
  let headRef = process.env.INPUT_HEAD || process.env.NX_HEAD || 'HEAD';
  if (!isValidGitRef(headRef)) {
    headRef = 'HEAD';
  }

  let baseRef = process.env.INPUT_BASE || process.env.NX_BASE;
  if (!baseRef || !isValidGitRef(baseRef)) {
    if (process.env.GITHUB_BASE_REF && isValidGitRef(`origin/${process.env.GITHUB_BASE_REF}`)) {
      baseRef = `origin/${process.env.GITHUB_BASE_REF}`;
    } else if (isValidGitRef('origin/main')) {
      baseRef = 'origin/main';
    } else if (isValidGitRef('HEAD~1')) {
      baseRef = 'HEAD~1';
    } else {
      baseRef = '';
    }
  }

  return { baseRef, headRef };
}

/**
 * Get changed files between two git references.
 */
function getChangedFiles(baseRef, headRef) {
  if (baseRef && headRef && isValidGitRef(baseRef) && isValidGitRef(headRef)) {
    try {
      const diffTriple = execSync(`git diff --name-only "${baseRef}...${headRef}"`, {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
      }).trim();
      return diffTriple ? diffTriple.split('\n').map(l => l.trim()).filter(Boolean) : [];
    } catch {
      try {
        const diffDouble = execSync(`git diff --name-only "${baseRef}" "${headRef}"`, {
          encoding: 'utf8',
          stdio: ['pipe', 'pipe', 'pipe'],
        }).trim();
        return diffDouble ? diffDouble.split('\n').map(l => l.trim()).filter(Boolean) : [];
      } catch {
        // Fall through to fallback
      }
    }
  }

  if (isValidGitRef('HEAD~1')) {
    const diff = safeExec('git diff --name-only HEAD~1 HEAD', '');
    if (diff) {
      return diff.split('\n').map(l => l.trim()).filter(Boolean);
    }
  }

  const show = safeExec('git show --name-only --format="" HEAD', '');
  return show ? show.split('\n').map(l => l.trim()).filter(Boolean) : [];
}

/**
 * Get affected Nx projects using Nx's graph engine.
 */
function getNxAffectedProjects(baseRef, headRef) {
  let cmd = 'pnpm --silent nx show projects --affected --json';
  if (baseRef && headRef && isValidGitRef(baseRef) && isValidGitRef(headRef)) {
    cmd += ` --base="${baseRef}" --head="${headRef}"`;
  }
  const raw = safeExec(cmd, '[]');
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function main() {
  const availableServices = getAvailableServices();
  const allProjects = getAllNxProjects();
  const projectRoots = getProjectRoots(allProjects);

  const inputServices = (process.env.INPUT_SERVICES || '').trim();
  const inputAll = (process.env.INPUT_ALL || '').toLowerCase() === 'true';

  const targetSet = new Set();

  function addServiceWithVariants(serviceName) {
    targetSet.add(serviceName);
    if (serviceName === 'idea-collector') {
      targetSet.add('idea-collector');
      targetSet.add('idea-collector-infra');
      targetSet.add('idea-collector-frontend');
    } else if (serviceName === 'idea-collector-infra') {
      targetSet.add('idea-collector');
      targetSet.add('idea-collector-infra');
    } else if (serviceName === 'idea-collector-frontend') {
      targetSet.add('idea-collector');
      targetSet.add('idea-collector-frontend');
    }
    if (serviceName === 'commifra') {
      targetSet.add('commifra');
    }
  }

  let detectionMode = '';

  if (inputAll) {
    detectionMode = 'manual (all services forced)';
    console.log('Force triggering all services and projects (--all).');
    for (const s of availableServices) addServiceWithVariants(s);
    for (const p of allProjects) targetSet.add(p);
  } else if (inputServices) {
    detectionMode = `manual (explicit services: "${inputServices}")`;
    console.log(`Triggering explicitly specified services: ${inputServices}`);
    const list = inputServices
      .split(',')
      .map(s => s.trim())
      .filter(Boolean);
    for (const item of list) {
      addServiceWithVariants(item);
    }
  } else {
    detectionMode = 'automatic (diff & Nx affected)';
    const { baseRef, headRef } = resolveRefs();
    console.log(`Analyzing changes between base: "${baseRef}" and head: "${headRef}"`);

    const changedFiles = getChangedFiles(baseRef, headRef);
    console.log(`Found ${changedFiles.length} changed file(s) via git diff.`);

    const sharedConfigs = [
      'nx.json',
      'package.json',
      'pnpm-lock.yaml',
      'pnpm-workspace.yaml',
    ];

    let hasGlobalChanges = false;
    for (const file of changedFiles) {
      if (file.startsWith('.github/actions/common/') || sharedConfigs.includes(file)) {
        hasGlobalChanges = true;
        console.log(`Global change detected in: ${file}`);
        break;
      }
    }

    if (hasGlobalChanges) {
      console.log('Shared configuration/action change detected. Triggering all services.');
      for (const s of availableServices) addServiceWithVariants(s);
      for (const p of allProjects) targetSet.add(p);
    } else {
      for (const file of changedFiles) {
        // Specific checks for idea-collector sub-projects
        if (
          file.startsWith('apps/idea-collector/infra/') ||
          file.startsWith('apps/idea-collector/backend/') ||
          file.startsWith('.github/actions/idea-collector/dependencies') ||
          file.startsWith('.github/actions/idea-collector/setup')
        ) {
          targetSet.add('idea-collector');
          targetSet.add('idea-collector-infra');
        } else if (
          file.startsWith('apps/idea-collector/frontend/') ||
          file.startsWith('.github/workflows/idea-collector.deploy-frontend.yml')
        ) {
          targetSet.add('idea-collector');
          targetSet.add('idea-collector-frontend');
        } else if (
          file.startsWith('apps/idea-collector/') ||
          file.startsWith('.github/actions/idea-collector/') ||
          file.startsWith('.github/workflows/idea-collector.')
        ) {
          targetSet.add('idea-collector');
          targetSet.add('idea-collector-infra');
          targetSet.add('idea-collector-frontend');
        }

        // Commifra specific paths
        if (
          file.startsWith('apps/commifra/') ||
          file.startsWith('.github/actions/commifra/') ||
          file.startsWith('.github/workflows/commifra.')
        ) {
          targetSet.add('commifra');
        }
      }

      const affectedNx = getNxAffectedProjects(baseRef, headRef);
      console.log('Nx affected projects:', affectedNx);
      for (const proj of affectedNx) {
        targetSet.add(proj);
        const root = projectRoots[proj] || '';
        for (const s of availableServices) {
          if (root.startsWith(`apps/${s}`)) {
            targetSet.add(s);
          }
        }
      }
    }
  }

  const resultList = Array.from(targetSet).sort();
  const jsonServices = JSON.stringify(resultList);
  const hasChanges = resultList.length > 0;
  const isCommifra = resultList.includes('commifra');
  const isIdeaCollector =
    resultList.includes('idea-collector') ||
    resultList.includes('idea-collector-infra') ||
    resultList.includes('idea-collector-frontend');

  console.log('\n==================================================');
  console.log(`Detection Mode : ${detectionMode}`);
  console.log(`Affected Count : ${resultList.length}`);
  console.log(`Services List  : ${jsonServices}`);
  console.log('==================================================\n');

  // Export to GITHUB_OUTPUT
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `services=${jsonServices}\n`);
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `has-changes=${hasChanges}\n`);
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `commifra=${isCommifra}\n`);
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `idea-collector=${isIdeaCollector}\n`);
  }

  // Export step summary if running in GitHub Actions
  if (process.env.GITHUB_STEP_SUMMARY) {
    const summary = [
      '### Service Change Detection',
      `* **Mode**: \`${detectionMode}\``,
      `* **Detected Services & Projects**: ${hasChanges ? resultList.map(s => `\`${s}\``).join(', ') : '_None_'}`,
      '',
    ].join('\n');
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary);
  }
}

main();
