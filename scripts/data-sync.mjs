// Mirrors Model Plan's open data into data/. The data is edited upstream; this repo gets an exact,
// checked copy of the allowlisted files (https://modelplan.ai/open-data.json), one pull request per change.
//   node scripts/data-sync.mjs [url|file] [--summary out.md]   write data/ from the export
//   node scripts/data-sync.mjs --check                          data/ matches data/manifest.json (CI)
import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = fileURLToPath(new URL("..", import.meta.url));
const DATA = path.join(root, "data");
const SOURCE = "https://modelplan.ai/open-data.json";
// Written here, never by the export.
const OWN = new Set(["data/README.md", "data/LICENSE", "data/manifest.json"]);
const sha256 = text => createHash("sha256").update(text).digest("hex");

export function validate(bundle) {
  if (bundle?.schemaVersion !== 1 || !/^\d+\.\d+\.\d+$/.test(bundle.version ?? "")) throw Error("open data: unknown format");
  if (!bundle.license?.id || !bundle.license?.url) throw Error("open data: no license");
  if (!Array.isArray(bundle.files) || !bundle.files.length) throw Error("open data: no files");
  const seen = new Set();
  for (const f of bundle.files) {
    if (typeof f.path !== "string" || !/^data\/[A-Za-z0-9._-]+(\/[A-Za-z0-9._-]+)*$/.test(f.path) || f.path.split("/").some(s => s.startsWith("."))) throw Error(`open data: bad path ${f.path}`);
    if (OWN.has(f.path) || seen.has(f.path)) throw Error(`open data: reserved or repeated path ${f.path}`);
    if (typeof f.content !== "string" || sha256(f.content) !== f.sha256) throw Error(`open data: ${f.path} does not match its sha256`);
    if (typeof f.description !== "string" || typeof f.license !== "string") throw Error(`open data: ${f.path} lacks description or license`);
    seen.add(f.path);
  }
  return bundle;
}

// Records are the objects with a string id, wherever they sit; a file's change is told in records
// added, removed and changed, or else in values changed.
function records(value, out = new Map()) {
  if (Array.isArray(value)) value.forEach(v => records(v, out));
  else if (value && typeof value === "object") {
    if (typeof value.id === "string" && !out.has(value.id)) out.set(value.id, JSON.stringify(value));
    Object.values(value).forEach(v => records(v, out));
  }
  return out;
}
function leaves(value, prefix = "", out = new Map()) {
  if (value && typeof value === "object") for (const [k, v] of Object.entries(value)) leaves(v, `${prefix}/${k}`, out);
  else out.set(prefix, JSON.stringify(value));
  return out;
}
const list = ids => ids.slice(0, 8).map(id => `\`${id}\``).join(", ") + (ids.length > 8 ? ` and ${ids.length - 8} more` : "");

export function describe(path, before, after) {
  if (before === null) return "new file";
  if (after === null) return "removed";
  if (!path.endsWith(".json")) return "text changed";
  const a = JSON.parse(before), b = JSON.parse(after), ra = records(a), rb = records(b);
  const added = [...rb.keys()].filter(id => !ra.has(id)), removed = [...ra.keys()].filter(id => !rb.has(id));
  const changed = [...rb.keys()].filter(id => ra.has(id) && ra.get(id) !== rb.get(id));
  const parts = [];
  if (added.length) parts.push(`added ${list(added)}`);
  if (removed.length) parts.push(`removed ${list(removed)}`);
  if (changed.length) parts.push(`changed ${list(changed)}`);
  if (parts.length) return parts.join("; ");
  const la = leaves(a), lb = leaves(b);
  const n = new Set([...la.keys(), ...lb.keys()].filter(k => la.get(k) !== lb.get(k))).size;
  return n ? `${n} value${n === 1 ? "" : "s"} changed` : "formatting only";
}

async function read(file) {
  try { return await readFile(file, "utf8"); } catch (e) { if (e.code === "ENOENT") return null; throw e; }
}
async function load(source) {
  if (!/^https:\/\//.test(source)) return JSON.parse(await readFile(source, "utf8"));
  const res = await fetch(source, { headers: { "user-agent": "modelplan-data-sync" } });
  if (!res.ok) throw Error(`${source}: ${res.status}`);
  return res.json();
}
async function walk(dir) {
  const out = [];
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...await walk(p));
    else out.push(path.relative(root, p).split(path.sep).join("/"));
  }
  return out;
}

function readme(text, bundle) {
  const rows = bundle.files.map(f => `| [\`${f.path.slice(5)}\`](${f.path.slice(5)}) | ${f.description} | ${f.license} |`);
  const table = ["<!-- files:start -->", "| File | What it holds | License |", "| --- | --- | --- |", ...rows, "<!-- files:end -->"].join("\n");
  return text.replace(/<!-- files:start -->[\s\S]*<!-- files:end -->/, table);
}
const manifestOf = bundle => JSON.stringify({
  source: SOURCE, version: bundle.version, license: bundle.license, redactedKeys: bundle.redactedKeys ?? {},
  files: bundle.files.map(({ path, description, license, sha256 }) => ({ path, description, license, sha256 })),
}, null, 2) + "\n";

export async function sync(source = SOURCE) {
  const bundle = validate(await load(source));
  const old = JSON.parse(await read(path.join(DATA, "manifest.json")) ?? '{"files":[]}');
  const next = new Set(bundle.files.map(f => f.path)), changes = [];
  for (const f of bundle.files) {
    const file = path.join(root, f.path), before = await read(file);
    if (before === f.content) continue;
    await mkdir(path.dirname(file), { recursive: true });
    await writeFile(file, f.content);
    changes.push({ path: f.path, what: describe(f.path, before, f.content) });
  }
  for (const f of old.files) if (!next.has(f.path)) {
    await rm(path.join(root, f.path), { force: true });
    changes.push({ path: f.path, what: "removed" });
  }
  // A release that changed no data file changes nothing here: no version-only pull requests.
  if (!changes.length) return { version: old.version, previous: old.version, changes };
  await writeFile(path.join(DATA, "manifest.json"), manifestOf(bundle));
  await writeFile(path.join(DATA, "README.md"), readme(await readFile(path.join(DATA, "README.md"), "utf8"), bundle));
  return { version: bundle.version, previous: old.version ?? null, changes };
}

export function summary({ version, previous, changes }) {
  return [
    `Open data from Model Plan ${version}${previous ? ` (was ${previous})` : ""}, mirrored from [modelplan.ai/open-data.json](${SOURCE}).`,
    "",
    "| File | Change |",
    "| --- | --- |",
    ...changes.map(c => `| \`${c.path}\` | ${c.what} |`),
    "",
    "This directory is a one-way mirror: the data is edited upstream and reviewed against official sources. To correct something, [report a data problem](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml).",
  ].join("\n") + "\n";
}

// data/ holds exactly the files the manifest lists, with matching hashes, plus this repo's own files.
// Before the first sync there is no manifest and data/ holds only this repo's own files.
export async function check() {
  const manifest = JSON.parse(await read(path.join(DATA, "manifest.json")) ?? '{"version":null,"files":[]}');
  const listed = new Set(manifest.files.map(f => f.path));
  for (const f of manifest.files) {
    const text = await read(path.join(root, f.path));
    if (text === null || sha256(text) !== f.sha256) throw Error(`${f.path} differs from the mirror; data is edited upstream, report it with the data-problem form instead`);
  }
  for (const p of await walk(DATA)) if (!listed.has(p) && !OWN.has(p)) throw Error(`${p} is not part of the open data mirror`);
  return manifest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  if (args[0] === "--check") {
    const m = await check();
    console.log(m.version ? `data/ matches the mirror of Model Plan ${m.version} (${m.files.length} files)` : "data/ has not been synced yet");
  } else {
    const at = args.indexOf("--summary"), out = at >= 0 ? args.splice(at, 2)[1] : null;
    const result = await sync(args[0] ?? SOURCE);
    if (out) await writeFile(out, summary(result));
    console.log(`${result.changes.length} file${result.changes.length === 1 ? "" : "s"} changed (Model Plan ${result.version})`);
  }
}
