// SPDX-License-Identifier: MIT
// Changelog fragments: one file per change in changelog.d, collated at release so parallel PRs
// do not conflict in CHANGELOG.md. The GitHub release body does not read any of this.
//   node scripts/changelog.mjs --check
//   node scripts/changelog.mjs --collate vX.Y.Z [--date YYYY-MM-DD]
import { readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const MAX_BYTES = 2048;
const NAME = /^[a-z0-9][a-z0-9._-]*\.md$/;
const HEADING = "## Unreleased";

export function fragmentProblem(name, text) {
  if (!NAME.test(name)) return `${name}: use a lower-case name ending in .md`;
  const body = text.trim();
  if (!body) return `${name}: empty fragment`;
  if (Buffer.byteLength(text) > MAX_BYTES) return `${name}: longer than ${MAX_BYTES} bytes`;
  if (/\n\s*\n/.test(body)) return `${name}: write one paragraph`;
  if (/^(#|- |\* )/.test(body)) return `${name}: no heading or leading list marker`;
  if (/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(body)) return `${name}: English only`;
  return null;
}

export function fragments(root) {
  const dir = path.join(root, "changelog.d");
  return readdirSync(dir).filter((name) => name !== "README.md").sort()
    .map((name) => ({ name, file: path.join(dir, name), text: readFileSync(path.join(dir, name), "utf8") }));
}

// Moves the Unreleased entries, then the fragments, under a new heading. The Unreleased
// heading and its intro stay, empty, for the next release.
export function collated(changelog, entries, version, date) {
  const start = changelog.indexOf(`${HEADING}\n`);
  if (start === -1) throw Error("CHANGELOG.md has no Unreleased section");
  const after = changelog.indexOf("\n## ", start + HEADING.length);
  const end = after === -1 ? changelog.length : after + 1;
  const section = changelog.slice(start, end);
  const blank = section.indexOf("\n\n", HEADING.length + 1);
  const intro = section.slice(0, blank === -1 ? section.length : blank).trimEnd();
  const existing = blank === -1 ? "" : section.slice(blank).trim();
  const items = [existing, ...entries.map((text) => `- ${text.trim().replace(/\s*\n\s*/g, " ")}`)].filter(Boolean);
  if (!items.length) throw Error("nothing to collate");
  return `${changelog.slice(0, start)}${intro}\n\n## CLI ${version} (${date})\n\n${items.join("\n\n")}\n\n${changelog.slice(end)}`;
}

function main(argv) {
  const root = fileURLToPath(new URL("..", import.meta.url));
  const found = fragments(root);
  const problems = found.map((f) => fragmentProblem(f.name, f.text)).filter(Boolean);
  if (problems.length) throw Error(problems.join("\n"));
  if (argv[0] === "--check") return console.log(`${found.length} changelog fragments valid`);
  const version = argv[1];
  if (argv[0] !== "--collate" || !/^v\d+\.\d+\.\d+$/.test(version ?? "")) {
    console.error("usage: node scripts/changelog.mjs --check | --collate vX.Y.Z [--date YYYY-MM-DD]");
    process.exit(2);
  }
  const date = argv[2] === "--date" ? argv[3] : new Date().toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? "")) throw Error("invalid date");
  const file = path.join(root, "CHANGELOG.md");
  writeFileSync(file, collated(readFileSync(file, "utf8"), found.map((f) => f.text), version, date));
  for (const f of found) rmSync(f.file);
  console.log(`collated ${found.length} fragments into ${version}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main(process.argv.slice(2));
