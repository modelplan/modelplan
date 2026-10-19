// Community build by default. A private official visual package is an explicit, isolated input.
import { build } from "esbuild";
import {
  copyFile,
  mkdir,
  readFile,
  readdir,
  rm,
  writeFile,
  lstat,
  realpath,
} from "node:fs/promises";
import { resolve, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
const here = (p) => fileURLToPath(new URL(p, import.meta.url));
const dist = here("app/dist/");
const args = process.argv.slice(2);
if (args.length && (args.length !== 2 || args[0] !== "--visual-package"))
  throw Error("usage: node build.mjs [--visual-package /private/package]");
const visual = args.length ? await realpath(resolve(args[1])) : null;
if (
  visual &&
  process.env.GITHUB_ACTIONS === "true" &&
  process.env.GITHUB_REPOSITORY === "modelplan/modelplan"
)
  throw Error("private_visuals_forbidden_in_public_ci");
const publicRoot = await realpath(here("../"));
if (visual && !relative(publicRoot, visual).startsWith(".." + sep))
  throw Error("official_visuals_must_be_outside_public_checkout");
const branding = visual
  ? JSON.parse(await readFile(resolve(visual, "branding.json"), "utf8"))
  : {
      name: "Model Plan Community",
      edition: "community",
      licenseNotice:
        "MIT community code. Branding is not an endorsement grant.",
    };
if (
  !["official", "community"].includes(branding.edition) ||
  typeof branding.name !== "string" ||
  branding.name.length > 80 ||
  typeof branding.licenseNotice !== "string"
)
  throw Error("invalid_visual_branding");
for (const f of visual ? ["theme.css", "logo.svg", "LICENSE.md"] : []) {
  const s = await lstat(resolve(visual, f));
  if (!s.isFile() || s.isSymbolicLink() || s.size > 1024 * 1024)
    throw Error("invalid_visual_package");
}
await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
const logo = visual
  ? await readFile(resolve(visual, "logo.svg"), "utf8")
  : '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="3" width="18" height="18" rx="4" fill="none" stroke="currentColor"/><path d="M7 16V8l5 5 5-5v8" stroke="currentColor" fill="none"/></svg>';
await build({
  entryPoints: [here("app/src/main.ts")],
  outfile: dist + "main.js",
  bundle: true,
  format: "esm",
  target: ["safari16"],
  minify: true,
  nodePaths: [here("node_modules")],
  loader: { ".svg": "text" },
  define: { __MP_BRANDING__: JSON.stringify({ ...branding, logo }) },
  legalComments: "eof",
  logLevel: "warning",
});
let css = await readFile(here("app/style.css"), "utf8");
if (visual) {
  css += "\n" + (await readFile(resolve(visual, "theme.css"), "utf8"));
  await copyFile(resolve(visual, "LICENSE.md"), dist + "VISUAL-LICENSE.md");
}
await writeFile(dist + "app.css", css);
await copyFile(here("app/index.html"), dist + "index.html");
await writeFile(
  dist + "build-edition.json",
  JSON.stringify(
    {
      edition: branding.edition,
      name: branding.name,
      licenseNotice: branding.licenseNotice,
    },
    null,
    2,
  ) + "\n",
);
console.log("Built desktop " + branding.edition + " edition.");
