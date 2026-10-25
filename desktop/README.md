# ModelPlan desktop (preview)

A menu bar app for ModelPlan: which model and effort fit, your quota and resets, Codex Fast, switching back after a reset, and a better model when the one you use is beaten. Built with [Tauri](https://tauri.app). macOS first; the front end is written so iOS and Android can reuse it later.

**Status: early preview.** Builds are ad-hoc signed, not notarized. There is no auto-update yet.

## What it shows

- **Menu bar**: what is left in the five-hour and weekly windows of the harness you used last, and the current hint, like the narrow Claude Code status line: `12% · wk70% ↓★Med ×0.73` or `→GPT-6.1 Sol ★Med ×0.55`. The tooltip lists every session.
- **Now**: the Claude Code and Codex sessions (model and effort against ★, Fast, the quota verdict) and the advice, most urgent first.
- **Quota**: each window as a bar of what is left, the reset, and the run-out at the recent rate. Codex's Reserve and CodexBar accounts are included.
- **Effort**: the effort curves and ladder for the model a session uses (the Codex dashboard's open curves), with Fast and the speed you measured.
- **Notifications**, each sent once:
  - on by default: tight or exhausted quota, switch back after a reset, a better model;
  - off by default: unused quota before a reset; peak hours, reset cards and public resets.

## Data

- Personal data comes from the bundled `modelplan` CLI (`modelplan desktop --json`, [personal snapshot](../docs/personal-snapshot.md)). The CLI reads what Claude Code and Codex write locally, as it does for the plugins. The app reads no harness files and no credentials itself.
- Public data comes from `https://modelplan.ai/publications/` through the shared client reader. Every object is hash-checked, and the last good copy is kept for offline use. That host is the only one the app may fetch from.
- Nothing personal leaves the machine. Settings and notified keys stay in the app's own data folder.

The CLI is found in this order: `MODELPLAN_CLI`, the copy bundled in the app, the newest one the plugins installed (`~/.cache/modelplan-cli/<version>/`), `modelplan` on the login `PATH`.

## Try a build

The `desktop` workflow builds an Apple Silicon `.dmg` for each pull request and push to `main`; download it from the run's artifacts. The build is not notarized, so macOS blocks the first launch. Clear the quarantine flag once:

```sh
xattr -dr com.apple.quarantine "/Applications/ModelPlan Community.app"
```

## Develop

Node 24+. The UI runs in a browser against a dev server; no Rust needed for that.

```sh
cd desktop
npm ci
npm run dev          # http://127.0.0.1:5174/ ; ?fixture=1 uses the CLI's golden snapshot
npm test             # node --test, TypeScript run directly
npm run typecheck
```

The dev page shows above the UI what the menu bar and notifications would show.

The shell itself needs Rust 1.90+ and, on Linux, WebKitGTK (see the [Tauri prerequisites](https://tauri.app/start/prerequisites/)):

```sh
npm run tauri dev
# macOS bundle with the pinned CLI inside:
node scripts/fetch-cli.mjs aarch64-apple-darwin
npm run tauri build -- --bundles app,dmg --config src-tauri/tauri.sidecar.conf.json
```

## Layout

```
app/src/        TypeScript front end, shared with future mobile apps
  snapshot.ts   personal snapshot v1 types
  platform*.ts  the platform adapter (Tauri, browser dev server)
  menubar.ts    the menu bar line
  notify.ts     which advice to notify, once per key
  views/        Now, Quota, Effort, Settings (2D)
src-tauri/      Rust: tray item, popover, window, the CLI command
scripts/        fetch-cli.mjs: the pinned CLI as a sidecar
official-visuals/  the official appearance (reserved license, not MIT; --official only)
```

The figures come from the CLI and the publication. The UI only shapes them: it derives no advice of its own.

## Licence and trademarks

The code here is MIT, like the rest of this repository, except `official-visuals/`, which is under the [ModelPlan Official Visuals License 1.0](official-visuals/LICENSE.md). The fonts are under the SIL Open Font License (`codex/ui/fonts`). "ModelPlan", the ModelPlan logo and the app icon are trademarks of the ModelPlan project. Forks must use their own name and icon.

## Community and official appearance

The default build is the complete MIT community edition, with neutral styling and a generic mark; it never reads `official-visuals/`. The official edition is built from the same checkout:

```sh
npm run build:official   # node build.mjs --official: theme, logo and branding from official-visuals/, license as VISUAL-LICENSE.md
```

The official visuals in `official-visuals/` are not part of this repository's MIT grant: you may read them and build the official app for your own use, but forks and redistributed builds must ship the community edition. `node build.mjs --visual-package <dir>` still assembles an external package that lies outside this checkout. See [source policy](../docs/source-policy.md) and [licensing map](../LICENSING.md). Historical MIT visual portions retain their grants. Rebuild from a full checkout including `reader/`; a sparse plugin install runs its existing bundled runtime without rebuilding.
