# ModelPlan for Codex

The Codex plugin provides automatic in-agent help and bundles the Skill and a pinned, checksum-checked CLI. **Automatic hints default to ON.** Ask Codex's ModelPlan setup to turn automatic hints off/on; setup runs `sh "<plugin root>/hooks/automatic-hints.sh" off` or `on` and verifies with `status`. The choice persists in `~/.config/modelplan/codex/automatic-hints`. Off silences the whole prompt hook, including notices and task briefs; explicit commands, tools and the panel keep working.

The existing panel is **feature-frozen**. Its current features remain available; new visuals belong in the Mac App and the website.

A compact, read-only GPT effort dashboard for Codex desktop, with a text fallback for Codex CLI. [中文](README.zh-CN.md)

## Install

You need a Codex version with `codex plugin` commands. Runtime dependencies and fonts are bundled: no npm install, API key or ModelPlan account.

```sh
codex plugin marketplace add modelplan/modelplan --sparse .agents --sparse codex
codex plugin add modelplan-codex@modelplan
```

1. **Add the source.** Codex clones this repository. The two `--sparse` paths check out only the marketplace file and this plugin, about 2 MB instead of the whole repository with its docs and media. The download, its progress output and retries are Codex's own; on a slow connection it can be quiet for a while. If it fails, run the same command again. Running it again after success only reports that the marketplace is already added. If an interrupted attempt left a broken source, run `codex plugin marketplace remove modelplan` and add it again.
2. **Install the plugin.** Codex copies it into its plugin cache. Running it again reinstalls the same version.
3. **Check the setup** (optional): ask Codex *"Check the ModelPlan plugin setup"*, or run the check yourself. `codex plugin list` shows the installed version:

   ```sh
   node ~/.codex/plugins/cache/modelplan/modelplan-codex/<version>/doctor.cjs
   ```

Then ask **"Open the ModelPlan dashboard"**. A new task is the reliable place to start; a task that was already open may pick the plugin up as well. You can also invoke the `model-dashboard` skill. Asked in the chat, the dashboard appears as a compact card in the conversation. To keep it beside the chat, open **Effort & quota** from the conversation's side panel: that thread entry is opened by you, not by a tool call, and each conversation gets its own copy. **ModelPlan** in the sidebar opens the board on its own. Codex CLI shows the same published comparison as text.

### Setup check

`doctor.cjs` asks Codex's own app-server to start the installed plugin the way a task does, opens a temporary thread without sending a message (no inference, nothing billed, no session log) and calls the read-only data tool once. It reports:

- whether Codex has the plugin commands, and whether the plugin is installed and enabled;
- the Node.js that Codex actually runs the plugin with, and how it was found;
- whether the MCP server started with both tools, and whether the dashboard resource is readable;
- whether the public data is current or a last-good snapshot;
- whether your quota is readable and by which reader, and whether proactive hints are on, with the missing piece if not.

It ends with three separate verdicts: **installed**, **tools callable**, and **panel shown**. The last one stays *unverified*: only opening the dashboard in Codex desktop proves the panel renders. Add `--json` for machine-readable output and `--lang zh` for Chinese.

### Node.js

The plugin's server needs Node.js 22 or newer. Codex starts `launch.cjs` with the `node` on its PATH; that Node only has to run the launcher (14+). The launcher uses the first runtime in this order that passes a version and feature check:

1. a pin in `~/.config/modelplan/runtime.json`: `{"node": "/path/to/node"}`. Codex does not pass your shell variables to plugin servers, so this file, not an environment variable, is how to choose a runtime. A pin that no longer works is reported and skipped;
2. the `node` Codex started the launcher with;
3. Codex desktop's own runtime under `~/.cache/codex-runtimes/`, when this Codex installed one. It is optional and its layout is Codex's; the plugin does not assume it exists;
4. other `node` entries on PATH;
5. standard locations: Homebrew and `/usr/local/bin` on macOS, `/usr/local/bin` and `/usr/bin` on Linux;
6. nvm, fnm, mise, asdf and Volta installs.

The choice is made again at every start and never cached, so an upgraded or removed runtime is picked up by the next task. The launcher never changes PATH or your global Node. When nothing fits, both tools still register and answer with the list of runtimes checked and how to fix it.

Limits: if Codex finds no `node` at all on its PATH, it cannot start the launcher and shows its own MCP startup error; install Node.js 22+ or make `node` visible to Codex.

### What is required

| Component | Needed for | Without it |
| --- | --- | --- |
| Codex with `codex plugin` commands | everything | the plugin cannot be installed |
| Node.js 22+ (found automatically, see above) | dashboard and both tools | the tools return a setup diagnosis |
| Python 3 | reading your quota until the plugin's CLI is there | quota shows as unavailable, with the reason |
| The plugin's `modelplan` CLI (**fetched automatically**) | proactive hints (`modelplan advise`), the prompt hook, the Codex account reading; also the preferred quota reader | until it lands: no hints; the dashboard says why |

**The plugin's CLI.** The plugin pins one `modelplan` CLI release in `cli-pin.json`: its version and the SHA-256 of each macOS and Linux archive. When Codex starts the plugin, its server fetches that release from GitHub in the background into `~/.cache/modelplan-cli/<version>` and uses it only if the archive's checksum equals the pinned one, so installing or updating the plugin is all there is to do; there is no separate CLI install or upgrade. Nothing else changes: no PATH, profile or sudo, and a `modelplan` you installed yourself (for the terminal) is left alone and used only while the plugin's copy is not there. `MODELPLAN_PLUGIN_CLI=off` turns fetching off.

**Turning on hints.** Hints need the plugin's CLI and the plugin's prompt hook, which Codex runs only after you allow it. The dashboard's NOW panel lists only what is not ready, each part on its own line: the CLI is still downloading, its download failed (why, with **Retry**), or you run an older one of your own meanwhile; the hook has not run on this machine yet, its definition changed and the new one has not run (Codex skips a changed hook until you review it again; in an open chat nothing says so), or its last run failed to compute hints (with the exit code, the error and the last success). Plugins cannot see whether a hook is trusted, so the panel reports when the hook last ran on this machine, from any chat, and how that run ended, never "trusted". When everything works it shows one line: setup complete, hints computed, and whether there is anything to flag. You can also ask Codex to "check ModelPlan setup" (the `setup` skill).

**The hook.** Codex's hook review lists it as `UserPromptSubmit · Hook 1`, source `Plugin - modelplan-codex@modelplan`, command `sh "$PLUGIN_ROOT/hooks/modelplan-quota-hints.sh"`, timeout 5 s; Codex 0.157 shows no other name (`statusMessage` is only shown while it runs). On each prompt it shows you new quota hints (as the hook's message; they never reach Codex's context) and, on a thread's first prompt, gives Codex the task-start brief (`modelplan advise --hook codex`). Until the plugin's CLI is there it says nothing; if fetching it failed, it says why, at most once a week. When the CLI first lands it says so once. The hook itself downloads nothing (the server does), writes only `~/.cache/modelplan-codex` and changes no setting. To allow it: in the desktop app click the hook icon with a yellow dot next to the input, check that the source is `modelplan-codex` and allow it; in the CLI use `/hooks`. It takes effect from the next prompt, also in an open chat. Hints arrive only with a prompt: during one long turn nothing new is said until your next message, and the plugin does not claim to monitor continuously. On low quota Codex also gets one factual line per window cycle: at 20, 10 and 5% left, and when the recent rate (the last day for the weekly window, the last few dozen minutes for the 5-hour one) runs it out before its reset; with a step to ★ only when the effort is above ★, otherwise only a cheaper model that scores as well, if there is one. A window resetting soon with a lot left gets one line too.

**The second hook (optional).** `SessionStart · Hook 2`, matcher `compact|resume`, command `sh "$PLUGIN_ROOT/hooks/session-start.sh"`: after Codex compacts or resumes a thread, it hands Codex back the low-quota line that thread was sent, with current figures, while it still holds. It never fetches, records nothing and changes no setting. Without it everything else works; a compacted thread just loses that line.

The plugin already contains three Skills, `model-dashboard` (dashboard, model and effort comparison), `model-plan` (advice that combines your task, the public data and your quota) and `setup` (first-run check). Do not install the same Skill separately. For the terminal you can still install the CLI yourself with `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh`; the plugin does not need it.

### Update and uninstall

```sh
codex plugin marketplace upgrade modelplan
codex plugin add modelplan-codex@modelplan
```

```sh
codex plugin remove modelplan-codex@modelplan
codex plugin marketplace remove modelplan
```

`plugin remove` deletes the plugin's cache. The public-data cache (`~/Library/Caches/modelplan` or `~/.cache/modelplan`) is shared with the CLI; delete it if you use neither.

## What you see

The content is at most 420 px wide wherever it appears, including borders and padding, and grows in height with its content. In the chat, the card asks the host for its own width rather than the chat column's; beside the chat it fills a narrow panel up to that width. Hosts show every entry "fullscreen", which in the side panel means filling the panel, so the width never follows the display mode. On the in-chat card, **Expand** asks the host for its larger view and opens the curve and lineup sections. *Data & basis* ends with a **Display** line: the surface, the display mode and container size the host reported, and the measured widths. Include it when reporting a layout problem. The first screen shows the Codex model, effort and speed tier from your latest local thread, how that step compares with ★, and your quota. The comparison console comes next. The effort curves, the full model lineup and public reset notices are folded until you open them.


- Published OpenAI recommendations, high-capability pick, best value and cheapest.
- One model's native effort lever and a compact capability/cost/time curve. Click a metric to isolate it; click again to restore all. Use arrow keys or Home/End on the lever.
- Gold ★ means recommended effort only. Capability changes are additive points; cost/time are multiples of that model's recommendation. Estimates are marked ≈; missing or incompatible time evidence leaves gaps.
- **Your quota**: 5-hour and weekly usage, time to reset and a headroom hint (surplus before a reset → stepping up is cheap; tight → stay at ★). GPT Reserve has a weekly allowance of its own: it shows as its own row, and the hint is about the allowance the latest thread drew from, so a used-up Reserve does not make the main allowance look tight. Read on this machine from the rate-limit snapshot Codex writes to its session logs, via `modelplan quota` or the bundled Skill reader (Python 3). With the CLI (0.5.2+) it also asks Codex itself (`codex app-server`, `account/rateLimits/read`, at most every 5 minutes in the background) for the account's current windows and its full-reset credits with their expiry; Codex makes that request with its own login, and the cache keeps no account or credit ids. Redeeming a credit stays yours, in Codex. `MODELPLAN_CODEX_ACCOUNT=off` keeps it to the logs. Nothing is uploaded; credentials are never read. The CLI also keeps a local history of each window's use and which model, effort and Fast spent it (`modelplan history`; `MODELPLAN_HISTORY=off` stops it), the basis for suggesting a default effort from your own weeks later. It also measures your own speed per model, effort and Fast from the same logs (timestamps and token counts only): the dashboard shows the chosen effort's measured turn time, tokens and tok/s against ★, and the effort text lists every measured configuration.
- **Hints** (need the plugin's CLI, fetched automatically, and the allowed hook; until then the dashboard says why): the window resets soon with allowance left → which effort to step up to and its cost multiplier; tight, including a recent burst that would use the window up within three hours (shown with the time) → back to ★ or one step down (Fast off first when it is on); after an advised reset → back to the model and effort used before the hint, and Fast off if it was turned on since; a public Codex reset in the last day. The plugin's `UserPromptSubmit` hook (`hooks/hooks.json`, enabled once you trust it in Codex) shows you each new hint once, without putting it in Codex's context; on the first prompt of each thread it hands Codex a short **task-start brief**: the Codex models at ★ with ability and cost multipliers (options a better one beats are left out), and the current model's effort ladder. It carries no quota figures: those are in the hints you see, and when you ask about quota or a hint Codex runs `modelplan quota` or `modelplan advise` for current figures. While quota is tight it offers no step up. Only a model the thread was not briefed on adds one line later; quota and effort changes do not resend it. It names a **default for ordinary tasks**: the published best value at ★, or the strongest at ★ when the best value scores more than 3 points lower; it follows the publication (today GPT-6.1 Sol ★Med). Codex points back to it: a step down for small tasks, High or XHigh of the default model for complex ones (not while quota is tight) and back afterwards. Codex judges the task and suggests one configuration in one sentence only when the current one clearly does not fit; otherwise it says nothing. `MODELPLAN_TASK_BRIEF=off` turns the brief off. It reads local files only and never changes the model, effort or Fast.
- **Speed tiers** (⚡ Fast, ⚡⚡ Ultrafast): ability does not change. Cost becomes *Quota*, an estimate of plan-quota use: the reference-task cost multiple times the tier's published included-usage multiple, valid within one model and relative to its ★ effort in standard mode. Task time, as on the website, divides by the published generation speed-up and is marked as an estimate: only generation gets faster, not tools, network or tests, so the real saving is smaller. Without a stated speed-up it stays as in standard mode. Generation speed is listed separately: "about ×1.5" (Codex Fast), an "up to" ceiling (Ultrafast), or not stated. Credit multiples, plan eligibility and the official source link are shown with each tier. The readout and both curves always show the same mode.
- Public Codex reset notices with source, scope and stated time precision. They are not your own meter.

The dashboard reads the same verified client publication as [ModelPlan](https://modelplan.ai/effort). It does not rank locally, call model inference, buy a plan or change the active model. Cached, unavailable and last-good states stay explicit. The roster is the published evaluated GPT set, not the host's complete picker.

## Transport and development

`mcp.json` configures an internal stdio transport for `open_model_dashboard` (the in-chat card), `get_model_dashboard` (text and data), and the user-opened entries `open_model_panel` (thread side panel) and `open_model_board` (sidebar), one entrypoint per tool and one UI resource per surface. Codex runs `launch.cjs`, which starts `server.bundle.mjs` on a compatible Node (see above). The app resource includes its styles and fonts without third-party browser requests. Normal usage contacts ModelPlan's public publication endpoint; the local cache contains public data only. No telemetry or credentials are collected.

```sh
cd codex
npm ci --ignore-scripts
npm test
npm run build
node tests/mcp-smoke.mjs --fresh
node tests/codex-host-smoke.mjs
node doctor.cjs
```

The last command requires this version to be installed in Codex. It checks registration, tools and app-resource transport without creating a thread or running inference; it does not validate native panel placement. `npm start` provides an optional loopback preview for UI development. It is not a public server.

`lib/client-reader.mjs` vendors the canonical publication verifier. Both source and the bundled runtime are shipped. UI fonts retain their SIL OFL notices under `ui/fonts`; runtime dependency licenses are in `THIRD-PARTY-NOTICES.md`.

MIT. See [LICENSE](LICENSE).
