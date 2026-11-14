// SPDX-License-Identifier: MIT
// Which changed paths can affect the Mac jobs of desktop.yml (app-smoke, native-headless). desktop.yml's own
// trigger list is wider because its Linux jobs (the Tauri app and shell, the contract fixtures) read more:
// codex/ui, codex/lib, desktop/app, desktop/src-tauri, desktop/scripts, desktop/tests, cli/internal/{snapshot,digest,
// desktopcontract,contracttest}. None of those is read by the Swift packages, the cockpit bundle the app packages, or the
// packaging scripts. The CLI the app bundles is the released one named by codex/cli-pin.json, never built from cli/.
// CLI: `git diff --name-only -z A B | node scripts/desktop-mac-scope.mjs` exits 0 when a Mac job must run, 1 when not.
import { pathToFileURL } from "node:url";

export const DESKTOP_MAC_PATHS = new RegExp(
  "^(" + [
    "desktop/native/", // Swift packages, packaging, tools, verification, pins
    "desktop/cockpit/", // the cockpit bundle packaged into the app and its admission pins
    "desktop/official-visuals/", "desktop/third-party/", // packaged visuals, fonts, notices
    "clients/swift/", // Swift packages the app links
    "schema/app-cli/", "testdata/contract-v1/", // contracts the native checks read
    "tools/u10/", // referenced by the native verification tools
    "scripts/check-visual-pack\\.mjs$", // run by the cockpit build
    "codex/cli-pin\\.json$", // the CLI app-smoke bundles
    "\\.github/workflows/(desktop|trusted-mac)\\.yml$",
  ].join("|") + ")",
);

export function touchesDesktopMac(files) {
  return files.some((file) => DESKTOP_MAC_PATHS.test(file));
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  const files = Buffer.concat(chunks).toString("utf8").split("\0").filter(Boolean);
  process.exit(touchesDesktopMac(files) ? 0 : 1);
}
