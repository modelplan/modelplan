// SPDX-License-Identifier: MIT
// D481 (owner 2026-11-27): the committed map from source paths to the native GUI test classes that exercise them
// (desktop/native/tools/ci/gui-test-map.json). A ready PR whose changed paths match an area of the map needs a
// successful exact-head PR GUI run of that area's classes before modelplan-gates passes (rules.mjs prGuiState), and
// desktop.yml's PR GUI leg runs exactly those classes through the pinned trusted-mac.yml (`gui_classes`).
//
// Pure functions plus a small CLI. The merge gate runs main's copy with main's map (and the head's map when the PR
// changes it); the PR GUI leg runs the head's copy with the head's map plus main's, so the leg never runs less than
// the gate asks for unless the PR itself changes this selector.
//
//   node scripts/merge-gates/gui-map.mjs select --files <jsonl> --map <map.json> [--map <other map.json>]
// --files: one JSON object per line with `filename` and optional `previous_filename` (the PR files API, as
// `gh api --paginate .../pulls/<n>/files --jq '.[] | {filename, previous_filename}'` prints it). Prints one JSON
// object: {"gui": "<the app-integration classes, comma-separated, or none>", "all": ["<package>:<Class>", ...],
// "truncated": bool}. A list of FILE_LIST_LIMIT or more files may be cut off by the API: every mapped class is selected.
// An invalid map exits 1 (the leg fails; the gate's evaluation fails and posts nothing, so it never passes).
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

export const MAP_PATH = "desktop/native/tools/ci/gui-test-map.json";
// The only package whose classes trusted-mac.yml's `gui_classes` narrows (native_test_partition.py --only). Classes of
// the other packages (ModelPlanSettings) run whole in every GUI leg that runs at all.
export const NARROWED_PACKAGE = "app-integration";
export const PACKAGES = Object.freeze(["app-integration", "settings"]);
export const FILE_LIST_LIMIT = 3000;
const CLASS = /^[A-Za-z_][A-Za-z0-9_]*$/;
const AREA = /^[a-z0-9]+(-[a-z0-9]+)*$/;

// Glob to an anchored RegExp: `**` any number of whole segments (also none), `*` and `?` within one segment,
// `{a,b}` alternatives (not nested). Everything else is literal.
export function globRegExp(glob) {
  let re = "", i = 0, brace = false;
  while (i < glob.length) {
    const c = glob[i];
    if (c === "*" && glob[i + 1] === "*") {
      const slash = glob[i + 2] === "/";
      if ((i > 0 && glob[i - 1] !== "/") || (!slash && i + 2 !== glob.length)) throw new Error(`${glob}: ** must be a whole path segment`);
      re += slash ? "(?:[^/]+/)*" : ".*";
      i += slash ? 3 : 2;
      continue;
    }
    if (c === "*") re += "[^/]*";
    else if (c === "?") re += "[^/]";
    else if (c === "{") { if (brace) throw new Error(`${glob}: nested braces`); brace = true; re += "(?:"; }
    else if (c === "}") { if (!brace) throw new Error(`${glob}: unbalanced brace`); brace = false; re += ")"; }
    else if (c === "," && brace) re += "|";
    else re += c.replace(/[.+^$()|[\]\\]/g, "\\$&");
    i++;
  }
  if (brace) throw new Error(`${glob}: unbalanced brace`);
  return new RegExp(`^${re}$`);
}

// Shape problems of one parsed map (an empty list = valid). Whether the classes exist and every glob matches a file
// is checked against the tree by scripts/tests/gui-test-map.test.mjs.
export function mapProblems(map) {
  const p = [];
  if (!map || typeof map !== "object") return ["map is not an object"];
  if (map.schemaVersion !== 1) p.push("schemaVersion must be 1");
  const pkgs = map.packages ?? {};
  for (const k of PACKAGES) if (typeof pkgs[k] !== "string" || !pkgs[k]) p.push(`packages.${k} must name its test sources directory`);
  for (const k of Object.keys(pkgs)) if (!PACKAGES.includes(k)) p.push(`unknown package ${k}`);
  if (!Array.isArray(map.areas) || !map.areas.length) return [...p, "areas must be a non-empty list"];
  const names = new Set();
  for (const [i, a] of map.areas.entries()) {
    const at = `areas[${i}]${a?.area ? ` (${a.area})` : ""}`;
    if (!AREA.test(a?.area ?? "")) p.push(`${at}: area must be a kebab-case name`);
    else if (names.has(a.area)) p.push(`${at}: duplicate area`);
    names.add(a?.area);
    if (!Array.isArray(a?.paths) || !a.paths.length) p.push(`${at}: paths must be a non-empty list`);
    for (const g of a?.paths ?? []) {
      if (typeof g !== "string" || !g || g.startsWith("/") || g.split("/").includes("..")) { p.push(`${at}: bad path glob ${JSON.stringify(g)}`); continue; }
      try { globRegExp(g); } catch (e) { p.push(`${at}: ${e.message}`); }
    }
    if (a?.curated !== undefined && a.curated !== true) p.push(`${at}: curated is true or absent`);
    const cls = a?.classes ?? {};
    if (!Object.keys(cls).length) p.push(`${at}: classes must name at least one package`);
    for (const [k, list] of Object.entries(cls)) {
      if (!PACKAGES.includes(k)) { p.push(`${at}: unknown package ${k}`); continue; }
      if (!Array.isArray(list) || !list.length || list.some((c) => !CLASS.test(c))) { p.push(`${at}: classes.${k} must be a non-empty list of class names`); continue; }
      if (list.join("\n") !== [...new Set(list)].sort().join("\n")) p.push(`${at}: keep classes.${k} sorted and unique`);
    }
  }
  return p;
}

export function parseMap(text, where = MAP_PATH) {
  const map = JSON.parse(text);
  const p = mapProblems(map);
  if (p.length) throw new Error(`${where}: ${p.join("; ")}`);
  return map;
}

// The classes the changed paths map to, over every map given (union), as sorted "<package>:<Class>" strings. With
// truncated = true (the file list may be cut off) every class of every map is selected.
export function mappedClasses(paths, maps, { truncated = false } = {}) {
  const out = new Set();
  for (const map of maps) {
    for (const a of map.areas) {
      const res = a.paths.map(globRegExp);
      if (!truncated && !paths.some((p) => res.some((re) => re.test(p)))) continue;
      for (const [k, list] of Object.entries(a.classes)) for (const c of list) out.add(`${k}:${c}`);
    }
  }
  return [...out].sort();
}

// The `gui_classes` value for trusted-mac.yml: the narrowed package's classes, or "none" when only other packages'
// classes are mapped (those run whole whenever the leg runs).
export function guiClassesInput(qualified) {
  const names = qualified.filter((q) => q.startsWith(`${NARROWED_PACKAGE}:`)).map((q) => q.slice(NARROWED_PACKAGE.length + 1));
  return names.length ? names.join(",") : "none";
}

// D481 (macrev2-1310-1): the PR GUI leg records the class set it selected as a notice annotation on its gui-scope job
// (`::notice title=<RECORD_TITLE>::<classes or none>`); the gate reads it back and requires it to cover the classes
// required now, so a map that grew after the run does not count an older, smaller run.
export const RECORD_TITLE = "D481 PR GUI classes";
const QUALIFIED = /^[a-z-]+:[A-Za-z_][A-Za-z0-9_]*$/;
export function parseRecord(message) {
  const text = String(message ?? "").trim();
  if (text === "none") return [];
  const list = text.split(",");
  return list.length && list.every((q) => QUALIFIED.test(q)) ? list : null;
}

export const bareNames = (qualified) => [...new Set(qualified.map((q) => q.slice(q.indexOf(":") + 1)))].sort();

function cli(argv) {
  const [cmd, ...rest] = argv;
  if (cmd !== "select") throw new Error("usage: gui-map.mjs select --files <jsonl> --map <map.json> [--map <map.json>]");
  let files = null;
  const maps = [];
  for (let i = 0; i < rest.length; i += 2) {
    const [flag, value] = [rest[i], rest[i + 1]];
    if (value === undefined) throw new Error(`${flag} needs a value`);
    if (flag === "--files") files = value;
    else if (flag === "--map") maps.push(parseMap(readFileSync(value, "utf8"), value));
    else throw new Error(`unknown flag ${flag}`);
  }
  if (files === null || !maps.length) throw new Error("--files and at least one --map are required");
  const rows = readFileSync(files, "utf8").split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l));
  const paths = [];
  for (const r of rows) {
    if (typeof r?.filename !== "string") throw new Error("a file row has no filename");
    paths.push(r.filename);
    if (typeof r.previous_filename === "string" && r.previous_filename) paths.push(r.previous_filename);
  }
  const truncated = rows.length >= FILE_LIST_LIMIT;
  const all = mappedClasses(paths, maps, { truncated });
  return { gui: guiClassesInput(all), all, truncated };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    console.log(JSON.stringify(cli(process.argv.slice(2))));
  } catch (e) {
    console.error(`gui-map: ${e.message}`);
    process.exitCode = 1;
  }
}
