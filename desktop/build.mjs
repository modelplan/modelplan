// Community build by default. The official edition is an explicit choice: --official assembles the
// reserved visuals in desktop/official-visuals/ (LicenseRef-ModelPlan-Visuals-1.0), and
// --visual-package <dir> assembles an external package that lies outside this checkout.
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
const usage =
  "usage: node build.mjs [--official | --visual-package /path/to/package]";
const official = args.length === 1 && args[0] === "--official";
const external = args.length === 2 && args[0] === "--visual-package";
if (args.length && !official && !external) throw Error(usage);
const publicRoot = await realpath(here("../"));
let visual = null;
if (official) {
  // Only this branch reads the reserved folder; the community build never does.
  const reserved = here("official-visuals");
  const s = await lstat(reserved);
  visual = await realpath(reserved);
  if (
    !s.isDirectory() ||
    s.isSymbolicLink() ||
    relative(publicRoot, visual) !== "desktop" + sep + "official-visuals"
  )
    throw Error("official_visuals_must_be_desktop_official_visuals");
} else if (external) {
  visual = await realpath(resolve(args[1]));
  if (
    process.env.GITHUB_ACTIONS === "true" &&
    process.env.GITHUB_REPOSITORY === "modelplan/modelplan"
  )
    throw Error("external_visual_package_forbidden_in_public_ci");
  if (!relative(publicRoot, visual).startsWith(".." + sep))
    throw Error("external_visual_package_must_be_outside_public_checkout");
}
for (const f of visual
  ? ["theme.css", "logo.svg", "LICENSE.md", "branding.json"]
  : []) {
  const s = await lstat(resolve(visual, f));
  if (!s.isFile() || s.isSymbolicLink() || s.size > 1024 * 1024)
    throw Error("invalid_visual_package");
}
const branding = visual
  ? JSON.parse(await readFile(resolve(visual, "branding.json"), "utf8"))
  : {
      name: "ModelPlan Community",
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
if (official && branding.edition !== "official")
  throw Error("official_visuals_must_declare_official_edition");
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
  define: {
    __MP_BRANDING__: JSON.stringify({
      name: branding.name,
      edition: branding.edition,
      licenseNotice: branding.licenseNotice,
      logo,
    }),
  },
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
