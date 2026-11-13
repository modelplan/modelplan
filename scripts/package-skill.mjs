// Copies the canonical Skill (skills/model-plan) into each plugin that ships it.
// `--check` fails when a copy drifted; CI runs it.
import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = fileURLToPath(new URL("..", import.meta.url));
const files = ["SKILL.md", "reference.md", "scripts/quota.py", "cli-pin.json", "scripts/fetch-cli.sh", "scripts/install-cli.sh"];
const removed = ["scripts/read-local.py"];
const targets = ["claude-code/skills/model-plan", "codex/skills/model-plan"];
const check = process.argv.includes("--check");

const drift = [];
for (const target of targets) {
  for (const f of files) {
    const want = await readFile(path.join(root, "skills/model-plan", f));
    const dest = path.join(root, target, f);
    const have = await readFile(dest).catch(() => null);
    if (have?.equals(want)) continue;
    if (check) drift.push(`${target}/${f}`);
    else {
      await mkdir(path.dirname(dest), { recursive: true });
      await writeFile(dest, want);
    }
  }
  for (const f of removed) {
    const dest = path.join(root, target, f);
    const have = await readFile(dest).catch(() => null);
    if (!have) continue;
    if (check) drift.push(`${target}/${f} (remove)`);
    else await rm(dest);
  }
}
if (drift.length) {
  console.error("Skill copies out of date; run node scripts/package-skill.mjs:\n" + drift.join("\n"));
  process.exit(1);
}
console.log(check ? "skill copies match" : `packaged into ${targets.join(", ")}`);
