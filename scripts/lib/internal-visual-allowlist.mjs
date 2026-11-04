// SPDX-License-Identifier: MIT
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { realpathSync } from 'node:fs';
import { isAbsolute } from 'node:path';
import { TextDecoder } from 'node:util';

// This provisional interface is not wired to any build or real approval list.
// A reviewed caller must pin the registry digest independently; a caller-provided
// digest or registry is not itself authorization. Only small, per-item registries
// are accepted; this helper must not be used to split or re-hash a rejected list.
const MAX_REGISTRY_BYTES = 64 * 1024;
// Allows the independently reported largest approved item (357250 bytes),
// with a bounded allocation for each individually reviewed resource.
const MAX_ASSET_BYTES = 512 * 1024;
const MAX_ENTRIES = 64;
const EDITION = 'internal-acceptance';
const PREFIX = 'desktop/official-visuals/';
const SHA1 = /^[a-f0-9]{40}$/;
const SHA256 = /^[a-f0-9]{64}$/;
const SEGMENT = /^[A-Za-z0-9_-][A-Za-z0-9._-]*$/;
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fail = () => { throw new Error('internal visual request rejected'); };

function exactKeys(object, keys) {
  return object !== null && typeof object === 'object' && !Array.isArray(object) &&
    Object.keys(object).sort().join('\0') === [...keys].sort().join('\0');
}

function validPath(path) {
  if (typeof path !== 'string' || !path.startsWith(PREFIX) || path.length > 512) return false;
  const parts = path.split('/');
  return parts.length > 3 && parts.every(part => SEGMENT.test(part) && part !== '.' && part !== '..' && !part.endsWith('.'));
}

function git(repository, args, maxBuffer = MAX_REGISTRY_BYTES + 1024) {
  try {
    return execFileSync('git', ['--no-replace-objects', '-C', repository, ...args], {
      encoding: 'buffer', maxBuffer, timeout: 5000, windowsHide: true,
      env: { PATH: process.env.PATH || '/usr/bin:/bin', GIT_CONFIG_NOSYSTEM: '1',
        GIT_CONFIG_GLOBAL: '/dev/null', GIT_NO_REPLACE_OBJECTS: '1', GIT_OPTIONAL_LOCKS: '0',
        GIT_TERMINAL_PROMPT: '0', GIT_NO_LAZY_FETCH: '1', GIT_ALLOW_PROTOCOL: '', LC_ALL: 'C' },
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch { return fail(); }
}

function entryAt(repository, tree, segment) {
  // A single literal segment cannot be a pathspec expression; -z avoids quoted names.
  const bytes = git(repository, ['ls-tree', '-z', tree, '--', segment]);
  const record = bytes.toString('utf8');
  const match = /^(040000|100644|100755|120000|160000) (tree|blob|commit) ([a-f0-9]{40})\t([^\0]+)\0$/.exec(record);
  if (!match || match[4] !== segment) return fail();
  return { mode: match[1], type: match[2], sha: match[3] };
}

/**
 * Bind independently reviewed trust anchors before processing requests. The
 * assetTree is the Git tree for desktop/official-visuals, not a tree containing
 * the registry. The registry is an independent document, pinned by digest.
 * Only trusted integration code may choose these anchors. Requests cannot
 * change them; this does not stop a caller from bypassing the helper entirely.
 */
export function createInternalVisualReader({ repository, assetTree, registrySha256 }) {
  if (typeof repository !== 'string' || !isAbsolute(repository) || typeof assetTree !== 'string' || !SHA1.test(assetTree) ||
      typeof registrySha256 !== 'string' || !SHA256.test(registrySha256)) return fail();
  try { if (realpathSync(repository) !== repository) return fail(); } catch { return fail(); }
  return function readInternalVisual({ edition, path, registryBytes }) {
  if (edition !== EDITION || !validPath(path) || !Buffer.isBuffer(registryBytes) ||
      registryBytes.length === 0 || registryBytes.length > MAX_REGISTRY_BYTES) return fail();
  const registrySnapshot = Buffer.from(registryBytes);
  if (digest(registrySnapshot) !== registrySha256) return fail();
  let registry;
  try {
    const text = new TextDecoder('utf-8', { fatal: true }).decode(registrySnapshot);
    registry = JSON.parse(text);
    // Canonical compact JSON forbids duplicate keys, whitespace aliases and escaped spellings.
    if (JSON.stringify(registry) !== text) return fail();
  } catch { return fail(); }
  if (!exactKeys(registry, ['version', 'edition', 'assetTree', 'entries']) || registry.version !== 1 ||
      registry.edition !== EDITION || registry.assetTree !== assetTree || !Array.isArray(registry.entries) ||
      registry.entries.length === 0 || registry.entries.length > MAX_ENTRIES) return fail();
  const entries = new Map();
  for (const entry of registry.entries) {
    if (!exactKeys(entry, ['path', 'blob', 'sha256', 'size']) || !validPath(entry.path) ||
        typeof entry.blob !== 'string' || !SHA1.test(entry.blob) ||
        typeof entry.sha256 !== 'string' || !SHA256.test(entry.sha256) ||
        !Number.isSafeInteger(entry.size) || entry.size < 0 || entry.size > MAX_ASSET_BYTES || entries.has(entry.path)) return fail();
    entries.set(entry.path, entry);
  }
  const approved = entries.get(path);
  if (!approved) return fail();
  if (git(repository, ['cat-file', '-t', assetTree]).toString('ascii').trim() !== 'tree') return fail();
  let cursor = assetTree;
  const parts = path.slice(PREFIX.length).split('/');
  for (let i = 0; i < parts.length; i++) {
    const found = entryAt(repository, cursor, parts[i]);
    if (i < parts.length - 1) {
      if (found.mode !== '040000' || found.type !== 'tree') return fail();
    } else if (found.mode !== '100644' || found.type !== 'blob' || found.sha !== approved.blob) return fail();
    cursor = found.sha;
  }
  const sizeText = git(repository, ['cat-file', '-s', cursor]).toString('ascii').trim();
  if (!/^(0|[1-9][0-9]*)$/.test(sizeText) || Number(sizeText) !== approved.size) return fail();
  const bytes = git(repository, ['cat-file', 'blob', cursor], approved.size + 1);
  if (bytes.length !== Number(sizeText) || digest(bytes) !== approved.sha256) return fail();
  return bytes;
  };
}
