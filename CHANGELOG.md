# Changelog

Releases of the `modelplan` CLI and the plugins in this repository. Binaries are on [Releases](https://github.com/modelplan/modelplan/releases). The website and data change continuously; see [modelplan.ai/updates](https://modelplan.ai/updates).

## Unreleased

These ship with the next CLI release; its pin PR gives them a version heading.

- The menu-bar item now has an automatic display, the new default: just the icon normally; a compact number (about 42 pt wide, no pill) only while the tracked quota is below your alert line; the icon with a red dot when it is used up; and the icon alone again if macOS squeezes the item out of view. The accessibility label always carries the full reading, for example "ModelPlan · Codex 0%". "Icon only", "Tightest percentage" and "Two windows" stay in Settings.

- The cockpit's launch rack now always stays behind the cockpit, also while it detaches, flies back or opens and closes; before, a detaching or returning cockpit had the rack drawn over its canopy. With the menu bar icon hidden or squeezed off, the attached cockpit now hangs from the menu bar just right of the notch (or the same place on a display without one), with its rack, instead of opening at the top-right corner without one.

- The nozzle flame is now a bold, full-width exhaust (owner pick D381 v4-1): the base reserve under the hull grows from 34 to 46 px so the whole plume shows.

## CLI v0.5.70 (2026-11-22)

- The cockpit now hangs the same rocket nozzle under every plugin column (Calendar, Resources) as under a subscription column. A plugin nozzle stays dark at rest and lights with the whole row on landing.

- Quota widget and Settings fixes from the owner's 11-21 report: the Resources ring now sits after the subscription rings, as in the cockpit; its label under the ring is the percentage alone (VoiceOver still reads "Memory 77%"); the subscription rings no longer vanish for a moment when a Resources update lands while the widget content is being refreshed; its hover card stays open while the pointer rests on the ring or the card; opening the attached cockpit no longer leaves a stale Dock icon; Settings no longer lists the framework placeholder plugin and explains that unpinned plugins fill free columns after the subscriptions.

- The effort panel title no longer shows a doubled approximation sign ("≈≈$7.3"), a small cost on a model card uses a short form that fits ("<$0.01", "≈$0.42"), and an unreported current effort now reads "Effort not reported" (Chinese UI: effort not reported) instead of "Current not reported".

- The cockpit porthole HUD no longer has a background panel: one scrim that fades out at every edge, a 1 px dark outline on its text, the ★ effort column aligned across rows, and fewer whole rows when six do not fit the safe area. The Resources column bars and numbers use the normal, amber (from 80 %) and red (from 90 %) status colours with a 3 % hysteresis, and the Resources tab icon loses its small square frame. The porthole HUD scrim is now the half-opacity variant B (reaching 48 pt to the sides, 16 pt above and below) with the rank numbers in #aab6bf, and the Resources column cell is two fixed layers (number line with the tag inline, 6 pt bar with a 1 px trend inside the track), its side value going full, short, then hidden.

- The Resources ring, hover card bars and numbers now use the quota rings' status colours (normal, amber from 80 %, red from 90 %, 3-point hysteresis) instead of one orchid. The plugin logo loses its small square frame on the ring and the card header. Every Dock card (subscription and Resources) ends in one full-width "View in cockpit" row under a hairline: the menu-bar glyph, and a chevron (compact: 6 pt gap, hairline, 22 pt row); a subscription card opens the cockpit on that subscription, a plugin card opens that plugin's big screen, and an already open cockpit only switches. The sampling cadence moves to the card header.

- Internal: the D41 Keychain journey test clicks the live first-run Allow button only once the consent controller can mutate, so a redraw on a busy GUI runner can no longer retire the button between finding and clicking it.

- Codex: when Codex's own account reading could not be refreshed (a failed read, or none for an hour), the Codex row fell back to the session logs however old they were, so it could show a percentage read days earlier (34% left for a week that was used up) and lose the plan name. Logs now replace the account reading only when they are at least as new as it; otherwise the account reading stays, marked as a retained reading with the failure named. Codex: when Codex itself fails the usage read because it cannot decode the server's answer (a plan or field newer than the installed Codex) but quotes that answer in its error, ModelPlan now takes the windows, plan and credits from it instead of reporting a failed read. GLM (ZCode QR-code sign-in): an old ZCode provider file that names no key no longer hides the QR-code sign-in route; the row now asks for that sign-in's consent and reads it once allowed. A ZCode 3.19+ sign-in whose store is locked to the macOS Keychain is reported as not supported, without asking for consent that could not produce a reading.

- The landing burn under the cockpit's nozzles now looks like a rocket exhaust: a bright white-yellow core, an orange plume fading to nothing, three shock diamonds, and a slight width flicker. It is longer, up to the whole space under the hull, and stays one element with no extra cost; with Reduce Motion it is a still plume.

- Cockpit: closing or opening the porthole no longer shows the canopy half retracted outside the hull; the glass is clipped to the hull silhouette for the whole motion (the hull's top edge comes down over it, and rises off it on open), both ends unchanged, Reduce Motion unchanged.

- The cockpit Models chart now names every model on the chart without hover; crowded names move beside or to the right edge on a thin leader line.

- Opening the cockpit while the app is still starting (the menu bar icon, the Open Cockpit menu item, the open-cockpit shortcut, the widget's ignition or opening the app again) is no longer ignored: the icon shows pressed at once and the cockpit opens as soon as the engine is ready. The quota widget draws only the face of the edge it rests on (the other edges are drawn when a drag starts), and the app no longer asks the engine twice for the rows and the consent facts at launch, so the first readings arrive sooner.

## CLI v0.5.69 (2026-11-21)

- The cockpit calendar now writes subscription names with their colour mark instead of two-letter codes, shows the next reset as a large time, lists two different moments (or one when they are the same), and says "no time-slot rules" when you have none.

- Gemini CLI quota keeps reading after its one-hour access token lapses, if you allow it (D232). A new opt-in permission, `gemini.account_usage.token_refresh` (off by default, effective only together with the Gemini saved-login permission), lets the reader exchange the saved refresh token at Google's token endpoint using the Gemini CLI's published installed-app client. The new token stays in memory only: nothing is written to `~/.gemini` or to ModelPlan's cache, no client secret is read from the installed Gemini CLI, and revoking the permission drops the token.

- The merge gate now requires a mac-compile success status at the head of a pull request that changes desktop/native, the PR reviewer no longer waits for the Mac compile, a dropped review answer is retried once and then reported, and a scheduled sweep dispatches missing Mac compiles (also run when a PR is retargeted to main).

- The app's engine no longer burns CPU while nothing changes. Reading an existing account reference took a lock file in the folder the engine watches, so every snapshot started the next one; native readers were listed in a random order, so every snapshot was sent to the app as a change; and a session log with no recent responses was read in full and the usage ledger rewritten every 30 seconds. An idle engine now reads nothing again and sends nothing until a file it watches really changes or a scheduled read is due.

- Internal: the icon-open rack test no longer depends on a 50 ms wall-clock sample.

- Cockpit: a clicked date key, fader or scale key no longer shows the gold keyboard ring after the next key press; the overview keeps the last usage history while one reply could not read it, instead of flashing "No usage record yet"; the Resources column's CPU, Memory and Disk labels are no longer squeezed out of their rows; the porthole list lines up every ★ effort and names GPT-6 Astra and GPT-6 Luna with their version; the placeholder plugin is no longer offered in the "+" menu.

- The task-start brief keeps the best-value model as the default when it scores exactly three ties below the strongest on the 0.4 display scale (a gap of 2.445), instead of recommending the strongest model because of floating-point rounding. In the cockpit, a window's run-out line now shows that window's own forecast, so a five-hour forecast no longer hides the weekly one, and a reset announcement for one plan selects that plan's subscription when you click its alert.

- Privacy and usage-history fixes. Turning Gemini on (first-run Done, the Settings switch or Select all) no longer also allows Gemini sign-in renewal: renewal, which sends the saved refresh token to Google's token endpoint, is now only its own labelled choice, and turning it off keeps the Gemini quota already read. Forgetting Codex local history now stops a Codex read that was admitted before the Forget from opening the session logs again. A Codex five-hour forecast without a reset time no longer spans an unseen reset in some session-log orders. After an upgrade, a GLM reading of another account that an older build saved while your pasted key was selected is no longer shown. "Remove imported history" now also removes an imported response that a later scan had counted as live, and a normal transcript append no longer drops usage kept across a time-zone change. Clearing the cockpit (consent cleared) removes an open quota tooltip at once.

- Three quota fixes. Forgetting Codex local history now also discards what a Codex read that was already running had decoded, so nothing from the session logs stays in memory after Forget. A Codex five-hour forecast without a reset time no longer disappears when session logs are read in a different order: every order gives the same run-out time and headroom. After you paste a GLM key for another account, a refresh before the next reading is due shows "not read yet" instead of the previous account's quota from ZCode or Claude Code.

- A free Grok Build account whose $0 reading has expired stays out of the Dock and cockpit, the first scan after an upgrade no longer drops usage recorded under a different time zone, the Kiro cause says when a configured `MODELPLAN_KIRO` cannot start, and the CLI rejects a lineup step that starts or ends at a pending model.

- The public reader now rejects a publication whose lineup step starts or ends at a model that is still pending evaluation, and one whose usage-trend ranks carry an unpublished `__proto__` key, instead of showing them as measured data.

- A free Grok Build balance ($0) shows its line in Settings again, with the balance. Control-clicking the widget no longer leaves the attached cockpit stuck open, and dropping the widget back where it was saved no longer makes it jump.

- The app reaches its first readings and the cockpit's first data several seconds sooner after launch: an engine event that changes nothing the quota widget shows (a health, consent or cockpit reply) no longer clears and redraws the widget, and a delivery that does change it redraws the widget once instead of four times, so the engine's replies no longer queue behind widget redraws. Privacy clears still withdraw the widget at once.

- ZCode users who signed in by QR code can now see their GLM quota. The sign-in has its own consent, off by default: until it is allowed the ZCode / GLM row says the sign-in was found and offers the Settings action, instead of "unsupported login type". ModelPlan reads ZCode's sign-in read-only and in memory, sends it only to the official host of the account's region (z.ai or BigModel), never renews it, and asks you to sign in to ZCode again when it has ended. A GLM key in ZCode's provider file or the environment is still used first.

## CLI v0.5.68 (2026-11-21)

- The pull request review no longer sends the generated codex/server.bundle.mjs diff to the reviewer; it gets a one-line note, so Codex reader PRs are no longer skipped for exceeding the request size. The ci.yml codex job still verifies the committed bundle against its sources.

- Accept client-v1.7 publications: ability compares models on the ability index, and effort steps read the published within-model chain.

- Keep the selected cockpit page, overlays and comparison when a display update cannot be drawn.

- A window with no known reset time no longer forecasts a false early run-out when another Codex thread still holds readings from before an unseen reset, and its "runs out soon" warning now expires with its recent burn rate instead of staying on in cached views.

- Dragging the widget while the attached cockpit is open no longer closes the cockpit; a plain click on the widget still closes it, when you let go. A cockpit prepared at launch, before the app finished starting, now also follows wake, unlock, clock and display changes from the app's single source, so it is laid out again once the displays settle and is refreshed once per wake instead of twice.

- Resource plugin: a Resources column in the cockpit engine table shows this Mac's CPU, memory and disk (CPU · Memory · Disk), with a continuous bar and a thin trend line in orchid; only the numbers turn amber or red (CPU from 70 % and 90 %, memory by macOS memory pressure, disk from 90 %). Its key opens a screen with the last ten minutes. The app samples with system calls only, never a helper process: every 2, 5 or 10 s (Settings › Subscriptions › Plugins, default 5 s) while the column is shown, every 10 s while the widget is shown, every 60 s otherwise, and not at all when the plugin is off. The ten-minute history stays in memory and is never written to disk.

- A pull request that carries the label `review:gpt` is now always reviewed by GPT first, whatever the review provider mode says, and adding the label starts a review of the current head even if GLM already answered it. If GPT is out of quota the GLM fallback still answers and the review's provider line says "review:gpt requested; GPT quota out".

- Cockpit calendar plugin (v1.1): a calendar column shows the next 12 hours with the published peak hours of your plans in their colours, your own 5-hour and weekly resets and one all-day line, all in your local time; with no peak rules (for example only Codex) it shows the next-reset cells instead. Its key opens a 7-day week view on the MFD screen that you can zoom to about 8 hours; clicking a day there shows that day's events in the column's bottom line.

- The cockpit header has a new layout: ALERT sits left of a centred porthole switch (a click toggles; the slider drag is gone), three Today / 7d / 30d date keys with live labels (each key's click area covers its label, its cap and the halves of the gaps beside it), and the settings, detach and close buttons sit 6 pt apart. The close button, the settings and detach art, the logo and the ALERT lamp are unchanged. The date keys now follow the app's one time range (they show it and ask for it, like the T key), and they dim and ask for nothing while there is no usage source. The date keys now ask the app even with no usage source (they only look dim), and the header's tab order is ALERT, switch, date keys, buttons; the porthole switch toggles on a click only. The porthole switch no longer toggles when a press travels away and comes back, and the date labels sit 3 pt higher, as in the approved mock.

- The cockpit overview now follows the v1 design: up to four alert lines with "+N ▸", one totals row (the range's estimated cost, its tokens and the cost per day, or "since MM-DD" when the record is shorter than the range), and one stacked bar per day sized by estimated cost. Without public price data it draws no bars, and the heatmap key stays unlit.

- The cockpit's page keys now read Overview, Plans, Models and Breakdown; the Subscription page opens the first subscription expanded when there are fewer than 3; the Models page lists models by usage (with a List | Chart key for the ability-cost frontier); and the Breakdown page shows projects or sessions with each row's share as a bar.

- The Quota Widget keeps a subscription's last reading when a refresh does not land: it looks normal for the first hour, then dims, and shows "--" only once that window has reset; an unreadable subscription keeps its ring with a dim "--". The widget card is rebuilt to the v1 final layout: the header says only how long ago the reading was taken ("Updated 3 min ago"), each quota row ends with its reset time or "out ~40m" when a forecast runs out first, the today row reads "33.9M" on the left and "● 1 running · 66 t/s" on the right (each half only when known), the card ends with the same alert sentence as the cockpit and the menu, and the reserve line brightens when a reset is there to use. A loading card shows only the row names and empty bars; an unreadable card shows the cause, the one step to fix it and a Read again button.

- The app starts and opens faster without showing anything different: the engine no longer re-reads unchanged Codex session logs or re-verifies the unchanged public data on every look, the requests right after start answer from the snapshot the start already built while nothing has changed, and a cockpit query builds one snapshot instead of four. The engine starts alongside the app's permission checks, the hidden cockpit page is prepared at once (and 0.1 s after a close instead of 0.5 s) without hashing the cockpit files on the main thread, the first session-log scan waits 2.5 s so it does not compete with the first readings, and the open from the menu bar overlaps the launch rack and the cockpit (about 0.37 s instead of 0.5 s).

- A new manual job (desktop.yml with perf=true) for the cockpit perf measurement measures the cockpit's cold start, attached and detached open and close, and idle CPU on synthetic data and reports median, p90 and sample count against the 200 ms, 400 ms and 10% budgets, so the WP-17 numbers no longer depend on hand-run measurements; it changes nothing in the product.

## CLI v0.5.67 (2026-11-20)

- The CLI comparison tolerance and the task-start default floor now use the published display scale (tie 0.815, floor 2.445), so verdicts match the website after the 0.4 index scale change.

- The cockpit's engine table no longer repeats "reset ?" in every cell when a reset time is unknown (hovering the cell still says so). The cell that is forecast to run out says so itself ("out ~40m"), in red at or below the red line and amber above it. Each subscription key shows its plan when the reader knows it ("Codex Pro 200", shortened to the name when it does not fit). One quiet line under the table, right-aligned beside the page control, says when the readings on the shown page were taken ("Updated 3 min ago") with a Refresh; after reads keep failing it says "no new data" and offers Retry. Quota cells now show their state plainly: a dark placeholder while loading, a dim "--" with "no reading" when a subscription cannot be read, a red 0% with "used up", stale readings drawn like current ones, and "Quota only" when there is no usage record. The Other row tags read "MCP · mo" with "+N", the reserve row says what it holds ("2 resets · expires in 30h", "Credits 2,368") and leaves out zeros, the range row puts an estimated cost first when one is known and drops speed, then tokens, when narrow, and with fewer than three subscriptions the first empty bay offers a quiet "Add a subscription".

- The cockpit's model cards above the faders now show how much each model was used rather than its effort ladder: under the subscription-colour edge and the model name comes the estimated cost in large type (the token count until a cost can be estimated, and for models with no public price), a share bar in the subscription colour, the tokens with the model's share of the range ("212M 17%"), and a small effort line ("High ★Med"; just a dim "★Med" when the current effort is the recommended one). The five small ability bars are gone. A model with no use in the range is dimmed and reads "Unused", with its lever dimmed; a model in use without a usage record reads "No record"; an unreported effort reads "Effort ?". Every card line fits in nine characters in English and Chinese. While an effort is being tried the card reads "Try XHigh / Now High" in blue. The current effort is the one with the most activity in the last 15 minutes, held until another clearly leads, and another effort with a notable share gets a small white dot beside the slot. Each card has one session lamp under the row label "Sessions": lit in the subscription colour while a session runs, dim when the model was used in the range. Clicking a card frames it and brings in the effort page over 150 ms; Esc first cancels a trial, whose ghost lever glides back in 280 ms, and a second Esc returns to the previous page; clicking the card again or empty fader space deselects it. Motion follows Reduce Motion. Hovering a fader shows a blue dashed what-if box at the effort under the pointer, without trying it. A model the verified list does not carry but whose name could be read gets a card by that name, reading "Unlisted", with no lever; clicking it opens nothing.

- A free Grok Build subscription ($0 balance) no longer gets a widget ring or a cockpit column; it shows as one line in Settings. A tool whose reader fails before any account exists now shows the reason and one next step in its row under Settings, instead of "Reading...".

- The Mac app is now one app named ModelPlan (`ModelPlan.app`, bundle identifier `ai.modelplan.app`) instead of "ModelPlan Community". The official download carries the official visuals, and About lists their reserved licence first; a Mac app built from source is neutral by default, with a plain Dock and no official artwork. If the older app is still running, ModelPlan asks you to quit and delete it; settings and history are kept, and macOS asks again for notification permission and Open at Login.

- CI-only: native-headless builds both native packages once into one scratch path, publishes its build seed before the tests run, reads its test share from the sources instead of `swift test list`, and has a temporary 90-minute limit.

- Cockpit plugins can draw their own column and big screen when cells are not enough (a day strip, a week grid). The key, its underline, pinning, the + menu, the bottom line and the screen's title bar stay the cockpit's; a plugin paints only inside the area it is given, and falls back to plain cells if its drawing fails. The plugin screen's Close button now answers a mouse click.

- The cockpit data now carries ≈cost: the tokens counted on this device × each model's public API list price from the ModelPlan publication (client-v1.6), per day, hour and model for today, 7 and 30 days. Long-context prices apply per request, fast mode only with a published API price multiplier, and usage without a public price is counted in tokens and as an unpriced share, never guessed. It is an estimate at API list prices, not what a subscription charges.

- The app now owns one time range (Today / 7d / 30d, 7d on a fresh profile) and keeps it, with the cockpit's subscription scope, across restarts and days. The status menu starts with a range selector and a grey line with that range's output-token total across all subscriptions, then one problem line when there is one, then Open Cockpit, Show and Find Quota Widget, Reset Position, Settings…, Help… and Quit. The cockpit receives the range with its first shell, its big-screen time keys read Today / 7d / 30d, and T cycles the range; every surface shows the same state.

- The official app's enlarged launch field is now the website's launch field in a cockpit window: it opens at 88% of the cockpit's display over a plain dim, with the in-field menu, the full fleet and effort links to modelplan.ai, and a 2D view when 3D is unavailable. Esc, the close key or a click outside closes it; Increase Contrast and Reduce Motion apply while it is open.

## CLI v0.5.66 (2026-11-20)

- Clients accept client-v1.6 publications: public API list prices per model (USD per 1M tokens, with optional long-context rates), a daily usage-rank trend, small and pending-evaluation models, and a fast-tier API price multiplier. These fields are validated strictly and rejected in older projection versions; a pending model has no efforts or ★ recommendation and is never part of a lineup.

- The cockpit's effort page on the big screen ("Effort · <model>") is redrawn as the v1 bar version: two stereo-lane bars, ability (white) and cost (mid-grey), whose full length is the model's own top effort (100 %), over a line chart of ability, cost and time for every published effort. The whole 0-100 % track is always drawn with a 100 % end stop and notches every 10 % (a full-height one at 50 %); the recommended effort is a thin gold line with a small ★ above the bar. With no trial each bar is one solid fill with its percentage below; a trial splits it into two lanes from 0, the real configuration on top and the trial in blue underneath, and its chart column turns light blue with a blue border. Every effort key now carries two numbers under it, ability and cost with a $ ("84%", "$23%"), white for the current effort and blue for the one being tried. Ability is ModelPlan's own published score as a share of the model's best-scoring effort (named on the bar when it is not the top one; "no ability scores" when none is published), while cost and time are shares of the top effort; where the publication carries the Artificial Analysis Intelligence Index score, it appears only as an "AA official" reference in the key's tooltip. The title shows the model's 7-day use and its share of all recorded use, and a quiet line at the bottom right says how to try an effort (or that a trial changes no tool setting), with the website link to its left; on the short cockpit the line becomes an ⓘ and the link a ↗ beside the keys, and the chart gets shorter. A model with a single effort says so instead of drawing a chart. Trying is local only: nothing applies an effort. On the small fader screen, fast mode is a symbol-only bolt beside the lamp (white real, blue trial).

- The first cockpit open after launch shows the last result at once again. The fresh query used to start at the same moment and compete with the page's first render, so that first open waited for the query (up to about 1.5 s); now the query starts once the last result is drawn (G3-42).

- Codex session totals no longer count cache writes twice: uncached input now excludes both cache reads and cache writes, whichever usage report carries the writes.

- Kiro's missing command now reads "kiro-cli was not found" on the Settings card instead of "Node.js is required", and a drag during the cockpit's opening still logs the open's animation-complete stage.

- Clear a previous Settings search when opening a specific pane so a widget card's subscription row stays visible.

- Cockpit plugin columns: plugins sit after your subscriptions in the engine table (at least three columns, at most six a page, up to two pinned to page 1). A plugin key looks like a subscription key, with a white line icon and a dashed underline; its column reads like a subscription column (small label, large number, side value, a continuous bar with a thin trend line). Click a plugin key to open its screen in the big-screen area; right-click it to remove it. Empty columns show a + menu to connect a detected subscription or add a plugin, and Settings › Subscriptions has a Plugins section to turn each plugin on or off, set its options and pin it. Plugins only run while the cockpit is open and their column is shown. Only a placeholder plugin (off by default) ships with the framework.

- Cockpit alerts now use one sentence everywhere ("Claude Weekly 42% · out ~1d20h · resets in 2d10h"), shared by the page and the native app. The ALERT lamp always opens the alert list, which has a count title, two lines per alert, red, amber, blue then grey order, and rows that select their subscription; an unreadable subscription is a grey list-only row that opens Settings › Subscriptions. A forecast with no known reset now counts as amber. System notifications are limited to a quota reset and an official extra reset.

- The porthole HUD lists only models your subscriptions carry (a session on another vendor's model no longer adds it), sits on a solid dark backing with white names, marks each model a session is running with a small green dot, and the rocket flames now step through five levels instead of animating every frame.

## CLI v0.5.65 (2026-11-19)

- The cockpit session strip now reads tool, project, model and effort, elapsed time and the session's total tokens for each session, and ends in the live speed ("● 58 t/s") while it runs or how long ago it was seen ("6m ago") when it is idle. A time, token total or speed that is not known is left out instead of written as "--". A model that is not in the published list but has a readable name shows that name with a dim "Not listed" badge, and a name that cannot be read reads "Unknown model". When more sessions are running than fit, the last line reads "3 more sessions" and opens the Breakdown page; with no session the strip says so in one grey line. Clicking a line again, or the empty strip, clears the model it lit. The cockpit data now carries each session's start time, total tokens and, for an unlisted model, its display name.

- CI-only: the Mac compile check clears read-only scratch and seed clones before wiping them, and builds cold instead of failing when a temp directory cannot be deleted.

- Forgetting a tool while a refresh is reading now waits up to two seconds for the refresh to finish instead of reporting that the reader is busy.

- ZCode / GLM keeps reading after the first-run Done: allowing it no longer switches the read from ZCode's own key file to an environment variable the app does not have, so its widget ring and cockpit column appear.

- With two displays, the attached cockpit and its launch rack always open under the menu bar icon's display, even when the widget's ignition is on the other display, and Put back returns a cockpit dragged to another display home under the icon. On a put back the rack starts unfolding together with the cockpit's flight. A cockpit you just detached comes to the front and takes the keyboard, and stays an ordinary window afterwards. The cockpit now has one size on every display: Auto picks 85 % when any connected display is laptop-width and 100 % only when all are wider, and every size is capped so the cockpit fits the smallest connected display, so dragging it between displays never resizes it.

- Order the cockpit faders by what the history shows was used in the last 7 and 30 days, after sessions seen in the last 7 days and before unused recommendations.

- Clients accept a lineup tie of 0.815 as well as 1: the index display scale moves to version 0.4, where the same one-point tie reads 0.815. Verdicts are unchanged.

- The Codex Ultrafast speed line now labels the Pro $200 plan instead of dropping it.

- The cockpit's launch rack no longer hangs into empty space under the menu bar when the cockpit opens or closes with the shutter closed: its mask line now follows the shutter state.

- Keep the launch rack clipped to the attached cockpit when its size changes in Settings.

- While you have an enabled subscription, the app now re-checks the publication for announced reset notices every 15-30 minutes (a conditional request, spread per client) instead of every six hours. Reset notices travel in the same publication, so when the pointer changes the whole publication switches with them; an unchanged cache is still force-refreshed only on the six-hour rule (DOCK-3.8-30).

- Codex and Claude Code usage now counts responses independently of speed samples, including unfinished turns. The today number includes input, cached input and output tokens; generation speed remains output tokens per second. The CLI exposes local-day today/7-day/30-day accounting with separate cache and reasoning buckets, without counting reasoning twice.

- OpenCode, Gemini CLI and Qwen Code now use local-day token accounting based on ccusage: OpenCode counts completed compactions and a reported total the other buckets leave out, and no longer counts the parent history a forked session copies; Gemini and Qwen local usage reports add input without cache, cache read, output and reasoning for today, the last 7 days and the last 30 days, with the total as the sum of those buckets. Qwen counts cached prompt tokens once: input excludes cache, intentionally correcting ccusage's overlap. OpenCode keeps running compactions pending so a status-only completion counts once after the cursor advances.

## CLI v0.5.64 (2026-11-17)

- The cockpit's effort faders are now the top-down throttle the owner chose: each model's real lever sits in a chamfered slot plate, day and night, and dragging it moves a translucent blue ghost grip with a thin blue line along the slot that snaps to the nearest effort the model has when released, while the real lever stays on the current effort. The recommended effort is a small gold ★ tick on the slot scale, and every lever is drawn exactly on its column's centre (it looked off-centre on the GLM column before). The community edition keeps the flat fader.

- Clear stale GLM quota readings when a saved key is replaced or removed, while retaining the detected-key indication.

- Quota Widget: a ring's card now opens the moment the pointer reaches the ring and closes promptly once the pointer leaves the ring and its card, a click outside closes it at once, and a plain click on the widget body no longer makes the widget redraw under the pointer.

## CLI v0.5.63, Codex plugin 0.15.50 and Claude Code plugin 0.7.49 (2026-11-17)

- The cockpit "All" scope, the porthole HUD ranking and the Models page now list only models your own subscriptions can use, not the whole published field, and the page key formerly called Effort is now Models. When the publication lists which models each plan can use (planModels), the cockpit uses that list for a subscription whose plan it can match, and falls back to the developer match otherwise.

- While the cockpit is busy, it no longer queues every reading that arrives: one update is drawn at a time, with only the newest one waiting behind it, so a burst of readings or a slow page cannot fill the queue, hold back a settings change or cause a rebuild.

- When the cockpit page cannot draw one update, the app now keeps the page and its last readings instead of closing and rebuilding it; a page that has not finished loading is no longer timed out while it is hidden, and is checked again after the Mac wakes.

- The cockpit no longer closes and rebuilds itself when its page is only slow or refuses one update: it keeps the last readings on screen, marks the reading as delayed after two seconds and checks whether the page still answers. Only a page whose process ended, or that stays silent for 30 seconds through two checks, is rebuilt, at most twice in ten minutes (after one and then four seconds), and only then does the "Cockpit unavailable" notice appear; a damaged install asks for a reinstall at once.

- When the cockpit is already showing readings and one read fails or returns bad data, it now keeps showing them and asks again a moment later instead of reporting the cockpit unavailable.

- When Codex can list the models the signed-in account may use (its own model list), the cockpit now uses that list first for that subscription's model filter, then the published plan list, then the developer match. Only model ids are read, with the same refresh as the quota reading.

- The cockpit's per-subscription model filter now also uses the models the tool itself reports for Gemini CLI, Antigravity, Grok Build, GitHub Copilot, Kimi and Claude Code, read with the existing quota read (no higher frequency, 3 second cap, failures never affect the quota). Only model slugs are read, and they map to published models only once harness aliases for that tool are published.

- A subscription row model merges the engine's consent facts, row state, cause code and visibility, and the first-run list shows one prerequisite line per tool from the same next-step table (kiro-cli install and sign-in, manual key entry).

- Settings > Subscriptions now lists one row per subscription with its status, one fix action, a display-only visibility switch and up/down; detected tools that are not added get an Add button, and tools this Mac does not have are listed under a collapsed section. A widget card's reason opens its Subscriptions row.

- Saving a manual GLM key no longer switches off ZCode's own detected key (removing the manual key reads it again), and replacing or removing an OpenCode Go key drops its previously cached reading.

- GLM (z.ai) and OpenCode Go can now be read with a key you enter in Settings (kept only on this Mac, sent only to the provider's official host), used instead of a detected key (Settings says when another key was also found; OpenCode's own saved login is never read, D230), and a GLM key that belongs to a relay is refused with a plain reason instead of being sent anywhere.

- The macOS app now keeps its own diagnostics: a rotating `~/Library/Logs/ModelPlan/ModelPlan.log` (cockpit, lifecycle, Quota Widget drag and edge, reader state and consent events, with timestamps) and `engine.log`, which keeps the engine helper's stderr, start and exit status or signal, so a crash of the reader leaves a trace. Settings → Diagnostics → Export diagnostics… first lists what is included, then saves a zip you choose the place for: both logs, ModelPlan's crash reports from the last 14 days, `modelplan doctor readers --json` and the app, engine and macOS versions. Logs hold event names, scope ids, cause codes, counts and durations only; every line and every bundled file passes a redaction step for keys, tokens, cookies, emails and the user folder name, and nothing is uploaded.

- When the reading service crashes repeatedly, the app now waits two minutes and starts it again by itself instead of staying stopped until Refresh; a lost consent check, a busy start-up and a stuck screen update also recover on their own.

- The cockpit page now reads all of its remaining labels, accessibility names, help captions, alert lines and relative times from its string tables in both languages instead of choosing between English and Chinese inline, so a screen in one language never shows text from the other. A test-only pseudo-long English locale (every string about 40 percent longer) now checks that key labels stay inside their boxes; it found three labels that are sized only for today's two languages and are listed for the v1.1 layout work.

- When the reading service comes back by itself after a crash, the menu bar and widget now show its fresh readings again without a Refresh, and a wake or unlock during its cool-down restarts it at once.

- The attached cockpit now hangs 10 pt below the menu bar with the menu bar icon above its left canopy shoulder, joined to it by a slim launch rack that shows only in the gap. Opening from the icon extends the rack first and then brings the cockpit out from under the menu bar; closing reverses it. The title-strip key shows what it will do (a launch tower with the arm swung down to detach, or holding the rocket to put back). Detaching with the key fires a short amber nozzle burn and moves the cockpit just out of the catch zone to a spot fully on screen while the rack retracts into the icon; putting it back lights the nozzles until the rack has caught it. Dragging the cockpit back near its place makes the rack reach for it, and releasing there snaps it straight up; the grey dashed snap outline is gone. The cockpit also asks for fresh data at the click, while the rack extends.

- The attached cockpit now opens over another app's full-screen window and on the current Space, and it no longer shows up in Cmd-` or Mission Control. It closes once when you click elsewhere or switch apps, and stays open while you drag its title strip, while one of our menus is open (including the status menu from the icon) and while an alert is showing. A detached cockpit gets a Dock icon and a Cmd-Tab entry, as Settings already does, so it is easy to find behind other windows. Closing Settings no longer removes that icon while the cockpit is still detached. The Help map no longer closes on the click that opened it. After waking, unlocking, a clock change or a display change, the cockpit is refreshed and laid out once, from a single source.

- A reader that fails before any account or reading exists (not signed in, waiting for permission, app server closed or errored) now shows its cause and a fix on that tool's own row in Settings > Tools, instead of the row disappearing.

## CLI v0.5.62, Codex plugin 0.15.49 and Claude Code plugin 0.7.48 (2026-11-14)

- Upgrading now revokes the runtime and account scopes that the earlier automatic local-history grant opened for tools installed after the first run: they stay off until you allow them in Settings › Subscriptions, and unrepaired grants are kept out of refresh until the repair commits (#971).

- Clearing a tool's history now also removes that tool's speed and performance ledger entries, keeps other tools' data and erased request ids, and later reads move past rows written before the clear, also when the history database file is replaced (#941).

- The cockpit fader row now shows only models from your own plans: models used in the last 7 days first (even when no plan of yours offers them), then the recommended ones, then the rest by ability, at most 12. A new Settings switch, "Show all models", lifts the plan filter and the limit. Favourite models you pin with a long press are now kept across app restarts.

- Readers now say why more tools cannot be read, and name the command that fixes it (D232, parity with CodexBar). Codex set to Amazon Bedrock or another custom model provider reports `codex_custom_provider` ("Codex uses another model provider, so there are no ChatGPT plan limits to read") instead of a generic service error; the check reads Codex's `config.toml` read-only and keeps none of its values. A Grok team login whose usage the billing endpoint does not report shows `team_unsupported`. For a signed-out or missing Codex, Claude Code, Gemini CLI, Grok Build or Kiro, each desktop row's `nextStep.hint` now carries that tool's own sign-in command (`codex login`, `claude`, `gemini`, `grok login`, `kiro-cli login`) or install command/URL, so the app can offer a Copy control. ModelPlan never runs these commands.

- Closing a detached cockpit right after closing its porthole no longer reopens it lower than where it was left.

- Choosing a subscription tab in the cockpit now shows only that subscription's models on the fader banks (starting at bank 1, the faders glide to the new models); the All tab keeps the full fader set.

- The past-usage import now also reads Codex's archived threads (`archived_sessions`), so archiving a thread no longer hides its usage; Codex history imported by an earlier version is read again once from both folders. After the first-run import was requested, a Claude Code or Codex history that is still not imported (the run failed, was interrupted or its permission was withdrawn, or its history was cleared and then allowed again) is imported in the background a few seconds after the engine starts or after the next permission change: quietly (a failure is never shown), pausing between logs, and at most five times per permission with growing waits between attempts (1, 2, 4 and 8 hours apart while the app runs). Cancelling an import (or a waiting retry) stops every automatic retry until that permission is granted again. Automatic imports read only tools whose history you allowed explicitly, history you removed with "Remove imported history" stays removed until that permission is revoked and granted again, and a fresh profile still waits for the first-run consent (G3-112). `modelplan doctor readers` lists `codex:history` and `claude:history` with the import's coverage, reports a GLM key-file reader that has never read as `unavailable:not_read` instead of `stale`, and a signed-in Cursor account on the free or hobby plan as `no_plan` instead of `schema_changed` (G3-117). ZCode installed only as the CLI community package (`~/.local/share/zcode-community`, `~/.local/share/zcode-cli`) or the macOS support folder without a provider file now shows "This saved sign-in is not supported" instead of waiting for a first reading forever, also under a bare legacy GLM permission. The public `readerErrorCode` schema now lists `codex_custom_provider`, `team_unsupported` and `policy_pending`, which the CLI already emits.

- A cockpit left open for a while no longer flickers closed and open and then reports "Cockpit unavailable" when a settings or layout change arrives while it is busy rendering new readings. After the reading service stops on its own, Refresh and the next wake or unlock start it again instead of leaving the widget at "?" until the app is quit.

- The menu-bar percentage no longer blinks on and off: while new readings come in, the icon keeps showing the last number until the next one is ready. The status menu no longer changes under the pointer while it is open; it updates once it closes. After a display change the icon is checked again once the displays have settled, and a menu-bar position saved for a display that no longer exists is reset at launch (a position you dragged is kept).

- Mac app: the Help map now always closes with Esc or a click outside it, even when macOS does not bring ModelPlan to the front after Help is chosen from the menu bar.

- The app now follows your Mac's language list: the first Chinese or English entry wins (Traditional Chinese opens the Chinese interface) and English is the single fallback. Settings, General, Language gains Follow System beside Chinese and English; Follow System re-reads the macOS list at every launch. Menu items, the status window, the field view buttons, the model picker label, Dock guidance text and the empty menu-bar reading now appear in the chosen language only instead of both languages at once, and the app bundle declares English and Simplified Chinese localizations.

- The cockpit's small porthole now shows the website's fleet round-four rockets in their maker liveries at night (official edition), rendered from the same 3D models with the porthole's own camera; the approved background and glow are unchanged.

- Readers match five recent CodexBar fixes. A Claude plan that reports no measured five-hour window (weekly-only) no longer fails or shows a session window; its weekly and per-model windows stay, and a model entry without a percentage no longer hides the others. Grok local history counts each turn once from its own `totalTokens`, including turns without a per-model breakdown, and history recorded by earlier versions is re-read once so unchanged session files are corrected too. Kiro plans keep their plus: `KIRO PRO+` shows as Kiro Pro+ and is no longer an unknown plan. Local day boundaries hold across daylight saving, so on a day whose midnight is skipped the day no longer starts an hour early inside the previous day and the midnight refresh is not missed.

- Settings: upgrading from a build before Follow System no longer switches a Chinese interface to English; a saved file without a language now reads as the Chinese it meant, and every save writes the language. A tool switch now shows On whenever any of that tool's paths is read, so after the OpenCode Go key comes back still refused, the switch no longer shows Off while the history is read, and the next click stops reading instead of allowing the key.

- Settings: switching a tool off now refuses every saved or default-on reading path of that tool, including paths not detected at that moment, so an OpenCode Go key that comes back later is not read against your Off. When an OpenCode Go sign-in is found but no key is set in OPENCODE_API_KEY, the OpenCode Go row now says why no quota is shown.

- Quota Widget: while you drag the widget, its quota rings stay on it even when new readings arrive mid-drag, and an open ring card now moves with its ring instead of staying behind where the widget was.

- Quota Widget: dragging the widget onto another screen edge now always saves the new position, so it is still there after the app restarts.

- A ZCode install whose data folder keeps no `provider_config.json` (the ZCode Desktop layout, or a sign-in that stores no plaintext Coding Plan key) now shows "This saved sign-in is not supported" instead of waiting for a first reading that can never come, and `modelplan doctor readers` reports it as `unavailable:no_provider_file` (G3-21). Nothing inside the folder is opened.

## CLI v0.5.61, Codex plugin 0.15.48 and Claude Code plugin 0.7.47 (2026-11-14)

- A supported tool installed after the first run no longer gets runtime or account reads from the automatic local-history grant: the grant enables local session or history log reading only. Anything that needs the tool's saved sign-in, its runtime or a network call stays off until you allow it in Settings › Subscriptions (G3, #924).

- Cockpit help now starts inside the visible window when the Window shutter is closed on the tall cockpit, and a shell refresh during the opening motion no longer snaps the glass open.

## CLI v0.5.60, Codex plugin 0.15.47 and Claude Code plugin 0.7.46 (2026-11-13)

- Codex's Pro tiers now show by name, as Codex itself shows them: Pro 100, Pro 200 and Pro 500 instead of the raw plan ids `prolite`, `pro` and `promax`, in the quota text, the effort and reset-card lines and the desktop app; history and advice still key on the id. A z.ai/GLM key without a Coding Plan, which the quota service answers with a body code 500, is now reported as `no_plan` ("This key has no GLM Coding Plan") instead of a provider server error. Codex speed no longer drops every response after a tool call in a tool-heavy turn: the token_count notice Codex writes after the tools finish is matched to its own response instead of being counted as a new one.

- The cockpit's engine screen no longer says only "No subscriptions" when nothing has been read yet: it shows one line ("No quota read yet. Sign in to a coding tool and it shows up here.") and one button that opens Settings › Subscriptions.

- The Claude Code session reading (current model, effort and Fast mode) now works on large local histories. It reads the newest transcripts first, starts a huge transcript from its tail, skips single records over 1 MiB instead of stopping there, and keeps its progress across refreshes, so the most recent session is known after the first refresh instead of staying "partial" forever. When it really cannot tell yet whether a newer session exists, only that part is reported as partial; the calling session's own reading is still used. No prompt or reply text is read into ModelPlan's cache.

- The cockpit no longer disappears and reopens by itself after a display change such as a screen-size change. A settings update that had to wait for the page could time out even though the page was ready again, which rebuilt the cockpit mid-use and could leave it on screen after close (G3-97).

- Closing the cockpit from the menu bar icon keeps shrinking back into the icon when the display arrangement changes or the cockpit size is changed during the close, instead of jumping back to full size before it disappears.

- Cockpit maker colours go back to the old pastel palette, completed (owner decision D250, 2026-11-13, replacing "Set 1" for accents): engine tabs, fader strips, record-strip chips and chart series use Codex #6aa8ff, Claude #ff9a6a, GLM #8f7dff, Copilot #c08cff, Kimi #ff8fcf, OpenCode #b5d65a, Cursor #eef2f6, xAI #8594a4, Google #4eccd3, MiniMax #f16f7e, Meta #a6dcff, Alibaba #4ab89a, DeepSeek #00aad6 and Xiaomi #e89700. Each maker has a darker same-hue alternate shade for when two makers share a screen. Rockets keep the website colours.

- The cockpit takes every maker colour (engine tabs, fader vendor strip, session list, subscription header, launch-field cards) from one shared maker colour table instead of three disagreeing per-file sets: GLM is no longer purple. Owner decision "Set 1" (2026-11-12): Codex ChatGPT green #10a37f, GLM Zhipu blue #3859ff, xAI yellow #f5e642 and Cursor rose #f79dcb (the last two assigned, unofficial), Claude orange #d97757. When two makers shown together are too close in colour (computed distance), the later one uses its alternate shade, and on the day theme the marks are drawn darker so they stay readable. Logos and names stay beside every colour.

- The cockpit opens again while a reset announcement or reset credit is published. Since CLI v0.5.59 every reset event carries its kind, and the page refused those events, so the cockpit showed "Cockpit unavailable" on every open (G3-96).

- Opening or closing the cockpit porthole no longer makes the whole cockpit jump. The porthole glass slides down into the hull top on close and rises out of it on open; attached under the menu bar icon the cockpit's body slides up or down with it in one motion, and a detached cockpit's body stays where it is while only the porthole changes (it comes down only as far as needed when there is no room above). The thin see-through line under the closed slab is gone. Reduce Motion switches at once.

- While a trial detent is shown, the effort comparison now carries one quiet line: "Trial only — your tool settings stay unchanged". In the compact shell, where the chart leaves no height for the line, it collapses to an info mark in the effort row that shows the same text on hover or focus.

- When the cockpit cannot open for a reason that can pass (engine or page not ready, a closed page process), the open is retried once quietly, and the notice no longer asks you to reinstall; that wording stays only for a damaged or missing bundled cockpit. The notice's third button is now called "Readings" (it opens the readings list). The app log names the cause of every notice.

- Cockpit fixes from a page-logic audit: an open fader trial and the comparison stay on their own model when a session starts or ends and the faders reorder; the comparison measures against the session's current effort as reported now instead of the one seen when it opened; its "Compare on the website" link opens the right model; the Models chart marks the current effort again for sessions that report it in lower case, and of two equally priced points only the more capable one is drawn as leading; daily bars and heatmap cells keep their dates across a daylight-saving change; and an empty fader slot no longer keeps a blue trial cap after paging banks.

- A money balance now shows the currency its reader reports (Grok Build: US dollars) instead of "Currency not reported". When a tool reports a balance but no usage percentage, such as Grok Build on the X Subscription, its card is a normal successful reading with a small grey note at the bottom saying so, instead of a failed card or an empty "Other --" row, and Grok no longer adds an "Additional usage" row when no additional-usage cap is set.

- A supported tool installed after the first run is now noticed without restarting ModelPlan: the engine re-checks which tools are present (presence only) when it starts, after wake and every 30 seconds. If the new tool can be read from its local session or history logs alone (no sign-in read, no network call), ModelPlan starts reading those logs right away, with no prompt; you can turn this off in Settings › Subscriptions. Anything that needs the tool's saved sign-in, its runtime or a network call stays off until you allow it: such a tool shows in the status menu as "Detected · Enable…", which opens Settings › Subscriptions, and the line goes away when you decide or uninstall the tool. Tools that were already installed at first run are not changed. ModelPlan remembers only which tool ids were present at first run (`detected-tools.json` in its data folder).

- The enlarged launch field now flies the website's fleet round-four rockets (Falcon 9, Falcon Heavy, New Glenn, Vulcan, Long March 2F/5/3B and the Starship) in the shared maker colours, the same vehicles the website shows. Official edition only.

- First run now opens at once, before the reader has started: each tool found on this Mac is listed from a quick local check and shows its own step (looking, reading, read, signed out, or "couldn't read" after 15 seconds without holding the others), the header shows the real count, Done waits for the reader with the reason shown, and closing the window mid-scan saves nothing and brings the guide back from the menu bar icon or the next launch. The Quota Widget and the cockpit prewarm wait until setup is done, the menu bar icon shows a dimmed "setting up" state meanwhile.

- Revoking or forgetting a local-history scope now waits up to two seconds for a background reader to release its lock, instead of failing the cleanup at once with a consent error when the two overlap.

- The first-run page is reorganised: a dark window with the privacy promise in large type, the existing recommendation line and a "Learn more ›" link that opens Settings › Data & Privacy, then the tools ModelPlan reads as cards with their current 5h and weekly values and, for Claude Code, the Keychain line with Allow and Later. The three small-print paragraphs are now one, and the window height fits its content.

- The CLI and desktop app honour `MODELPLAN_PROFILE_ROOT=<absolute folder>`: every ModelPlan config and cache file (consent, connections, declared quota, local-usage and project-label choices, the publication cache and history) and the app's settings, notification ledgers and caches move under that folder, so a test build can run a true first run without touching the real profile. The app refuses to start rather than fall back to the real profile when the folder is unusable or the bundled engine does not support it.

- Codex's output speed (t/s) shows again on the widget card and in the cockpit. Codex writes each reply's usage twice, and when a tool call ran in between, the reader took the second copy for a new reply with no timing, so most replies had no speed and today's rate stayed hidden.

- A tool that failed to read (for example Grok Build before you signed in) is read again within five minutes after you sign in to it again or turn its reading back on in Settings, instead of waiting out a back-off of up to an hour. A provider's own rate limit is still respected.

- Tool detection now uses only signals that belong to each tool. Settings no longer says Gemini CLI is installed on a Mac that only has Google Antigravity: Gemini CLI is detected from its command, its sign-in file or its chat history, not from the `~/.gemini` folder Antigravity also uses, and Antigravity is now detected as its own tool. Kiro is detected from the Kiro CLI it is read through, not from the Kiro IDE's folder. Finding OpenCode no longer counts as an OpenCode Go subscription: the subscription is detected only when OpenCode's own key store has an OpenCode Go entry (only its existence is checked; the key is never read) or OPENCODE_API_KEY is set, and otherwise Settings says "OpenCode installed · no OpenCode Go subscription found".

- A pressed amber quota caution ("won't last until the reset") now stays acknowledged for the rest of that window's cycle. Before, the forecast pausing during an idle spell counted as a clear, so the caution blinked again on the next cockpit entry once usage resumed. It blinks again only in the window's next cycle or when it turns red.

- In the cockpit, an extra limit without a known period (such as Grok Build's "Other limit") no longer shows an internal text key, a cell line that is too long for its column switches to its shorter form and otherwise ends in an ellipsis, a money balance (Grok Build) shows in the engine column's reserve row in its reported currency, and the Overview for a subscription that reports only a balance shows that balance and says no usage percentage is reported, instead of an empty page.

- Dragging a ring on the quota widget now moves the whole widget, like dragging its body, instead of trying to reorder subscriptions (the reordered ring used to snap back). A click on a ring still refreshes it, and Option-arrow keys still move a ring one place. The cockpit's subscription tabs and columns now follow the same saved order as the widget.

- Settings now save only the values you changed, so an untouched setting follows a later default change; settings files written by older builds had every key stored at once, so a stored menu-bar display of "icon" from before the default became the tightest percentage is dropped once and the percentage shows beside the menu-bar icon again (a choice made after this change stays).

- The hidden-icon notice appears on the General pane only, can be dismissed, mentions the camera notch and lists what still works (Quota Widget, ignition key, shortcut), with a Set Shortcut button.

- A history log that cannot be read during an import is no longer marked as covered: that one file is retried on the next import, and the logs already read are not counted again. A log whose folder cannot be listed stays owed until it is read or confirmed deleted.

- The widget's red ignition key now closes the cockpit when it is open under the menu bar icon, instead of opening it again. A detached cockpit is brought to the front by the key (from behind other windows, another Space or the Dock) and closes only from its own close key. With several displays, an attached cockpit opens under the menu bar icon of the display where the key was pressed.

- The cockpit always shows its night look, whatever the macOS appearance: light mode no longer shows a half-finished day cockpit. The day look stays in the code behind one switch for a later release.

- Revoking or re-granting a history source while another one is still importing no longer restores the revoked source's rows or aborts the other import, and first-run Done can no longer finish without saving the reading choices after a privacy reset.

- A bundled cockpit file that goes missing after the app started now gets the reinstall notice, a quiet open retry also follows a pending open, and a retry no longer carries over into the next open.

- A session's project now follows each tool's own definition of a project instead of ModelPlan's git-root grouping: Codex uses the project folders Codex lists, Claude Code the session's folder, OpenCode and ZCode their stored project; a session with no project in its tool shows "No project" in the record strip instead of a guessed folder name, while a project whose name `project-labels off` hides shows "--". Needs a CLI release.

- The publication reader now accepts optional harness model ID keys for Gemini, Antigravity, Grok, GitHub Copilot and Kimi, so a digest that maps those tools' model slugs is no longer rejected.

- Reader fixes: a Cursor reading is no longer discarded when Cursor writes unrelated app state during a refresh; a Claude Code reading is discarded when the saved login is replaced or removed mid-refresh, so another account's quota is never shown; OpenCode Go `usage`/`limit` counters are read as counters (120 of 1000 is 12%, not 100%); a MiniMax key rejection reports "The provider rejected the saved sign-in" instead of a format change; a signed-out Kiro shows "Not signed in"; a resumed Claude Code session no longer counts its copied requests twice in live speed and performance totals; and Codex requests reported only as cumulative totals are no longer dropped between reads.

- After a ring click, the new number now fades in when the refreshed reading arrives, instead of appearing at once.

- The widget's working ring now turns smoothly at one steady turn every 2 seconds, and no longer jumps back when the widget refreshes. With Reduce Motion on, the ring stays still.

## CLI v0.5.59, Codex plugin 0.15.46 and Claude Code plugin 0.7.45 (2026-11-12)

- The cockpit shows exactly the subscriptions the quota widget shows: tools the widget hides (signed out or without a reading) no longer get a tab or an empty quota column. The porthole's enlarge key no longer lights up after a click and a key press; it shows its focus ring only when reached with Tab. A fader trial on a model with no running session now draws the comparison chart relative to the recommended effort, while the table keeps its dashes for the unknown current setting.

- The widget and cockpit today row now shows today's tokens and output speed: the app declares the accountTodayV1 capability when it starts the CLI, so the CLI sends the today figures (build 14c always showed "-- · -- t/s").

- A Fast session now compares as Fast in the cockpit (the engine sends the recorded speed mode with each live session), a forecast notification is no longer sent for a reading that has expired, finishing or removing an imported history refreshes an open cockpit, and Settings › Data & Privacy no longer keeps a previous engine's import counts or loses its first status request when it is opened before the engine is ready.

- Background reads recover on their own in more cases: a stalled Codex runtime that leaves a child process holding its output no longer blocks every other refresh, a corrected GLM key in Claude Code's settings clears a rejected sign-in, a resumed older Codex session is found again, a recreated ZCode or OpenCode database is read from its first row, `modelplan sync` repairs a missing or damaged cached publication, and a missing Codex executable is retried on the first-read schedule.

- The porthole glass is filled right up to the canopy's top and sides again: the desktop no longer shows through as a light raised band on the top of the porthole and a bright line down its sides.

- The cockpit hull is narrow under the porthole and steps out above the instruments, as in the design; the porthole frame keeps its rounded sides, the closed cockpit sits right under the menu bar with its lid aligned to the walls, and the title strip shows the rocket mark with the ModelPlan wordmark.

- Pressing a fader's display in the cockpit now only opens the effort comparison for that model; it no longer starts a trial ("Try = ★"). A trial exists only while the fader sits on another effort than the real one (the current effort, or ★ when the current effort is not reported), and moving it back ends the trial.

- Cockpit window fixes: clicking inside the enlarged launch field no longer closes the cockpit and the field; reopening the cockpit while it fades out loads fresh data instead of failing; Put back from another display lays the cockpit out for the menu bar icon's display; after dragging the cockpit by its title strip the page gets the keyboard back (Esc works again); a query failure that recovers, or that the user closes the cockpit over, no longer shows "Cockpit unavailable" a few seconds later; and turning on Reduce Motion no longer flashes the hidden, preloaded cockpit onto the screen.

- The cockpit no longer closes as unavailable about a minute after opening when several updates arrive at once: a burst of settings or appearance updates now replaces the queued older ones instead of filling the delivery queue, one update that cannot be queued is skipped and resent, and a reading that is not a finite number is shown as unavailable instead of ending the cockpit.

- With more than one display, the widget's ignition now opens the cockpit on the display you clicked, and the cockpit can be dragged to any display. The enlarged launch field opens on the cockpit's display, moves by the strip above its card, and resizes to fit the display it is on.

- The porthole no longer shows a blue focus ring round its frame after it has been clicked; keyboard focus shows on its enlarge key instead.

- Opening the cockpit while the engine is still starting no longer flashes the "Cockpit unavailable" notice: the open completes as soon as the engine is ready, and the notice appears only if the failure lasts a few seconds.

- At a scaled size, such as the 85 percent Auto default on a MacBook Air, the cockpit no longer cuts off the outer edges of the hull's side walls: its window is now sized in whole points, so the page always has room for the whole hull at every size.

- Cockpit tab marks have one visible size again: the Codex tab shows the OpenAI mark instead of a dot.

- The cockpit no longer shows "unavailable" when a prewarmed page is opened before its own visibility event has fired: the page now treats a window the app reports as visible as visible, and a refused freshness tick is retried briefly instead of discarding the page. A refused host message now logs the page code path that refused it (a fixed code, never data).

- Public Codex reset news now reaches the Mac widget for extra resets issued as well as direct limit resets: a forecast shows a hollow dot on the Codex row with its expected window, and a confirmation a solid dot for three hours with its time and one notification (none for forecasts). The CLI admits both kinds in both states, emits the kind and confirmation time on reset events, and never treats extra resets as a quota window restart; your own balance is still the local reading.

- Revoking a tool's local history now stops a running history import before it opens another of that tool's logs and removes that tool's imported coverage dates along with its rows; Settings can remove imported history that has coverage but no rows; first-run Done stays open when the engine rejects the reading choices; changing an unrelated permission no longer restarts a cancelled first-run import; and choosing Open at Login in Settings acts on the login item's current state rather than the one seen at launch.

- A failed reading now says why. The engine carries a fixed cause code per row and account (command not found, Node.js missing, timeout, background service error or closed, no key, relay address refused), `doctor readers` prints it with Codex's last ten failures, and the widget card and Settings show one plain reason and next step per cause instead of "Reading unavailable".

- The first-run tool list shows ZCode's Zhipu mark instead of the letters ZC, and draws Kiro's mark in its own colours instead of a white block.

- The app-server now reads the local Codex and Claude Code session logs every 30 seconds on its own schedule, so the cockpit overview, record strip and fader session lights fill in even while a quota refresh is waiting or stuck (build 14c showed only "quota only" with Codex in heavy use). Each pass records what it did (ran, or skipped for consent, no logs, a busy lock, or an error) in `observed/observe-decisions.json` in the cache.

- The quota ring's time marks are easier to see: the dots are brighter (white 80 %, the same as the cockpit's time dots), and on standard-resolution (1x) displays each dot sits on a whole screen pixel instead of being blurred across several.

- Added a read-only check accessor on the Dock instrument view so tests can inspect the open-card ring glow; no behaviour change.

- When Open at login is unavailable because ModelPlan is not in the Applications folder (for example opened from Downloads), Settings now says so and offers a Show how button with the steps.

- With two displays the "menu bar is full" warning no longer shows while the icon is visible on one of them, and it now appears in Settings only, no longer in the widget's right-click menu; the menu-bar percentage is written again when a display change or a returning menu-bar window could have left it stale; and the ignition key's help tip is sized to its text on the study's dark tooltip panel and goes when the cockpit opens or the pointer leaves the key.

- The subscription order control moved from the Quota Widget pane to Settings > Subscriptions; the order is the same one the widget and cockpit use.

- A Codex account reading that fails before it ever succeeds (or after the last good reading has expired) now names its cause, and a kept Codex reading shows why its refresh failed. After a cockpit is dropped on another display, the snap guide now shows where Put back really goes. With no widget subscription yet, the cockpit keeps showing running sessions, and a saved tab for a tool the widget hides falls back to All.

- The Quota Widget is shared with screen capture by default (owner decision C19) and v1 ships no switch for hiding it; tests now pin the shared dock window and the Settings row's not-supported reason so the default cannot drift (SET-9-12).

- Settings > About "Copy diagnostics" now describes the running engine: the CLI version comes from the engine the app accepted, readers lists the tools whose reading is allowed, and errors lists the coarse classes of the current row reasons (fixed names only, never paths, accounts or text). An owner test build shows its own CLI version instead of "unknown". Settings > Subscriptions no longer ticks a tool the engine is not reading: a path that is only on by the built-in default is shown ticked only when the engine reports it as read (or allowed); otherwise it shows unticked, and ticking it sends the grant and waits for the engine to confirm.

- Settings now lists each tool once, like the first-run list (mark, what is read, why a tool is not read), with the reading paths and saved-permission buttons behind a disclosure, and the "Request sent to the app" line clears itself.

- Settings now lists every tool first run would list (detected ones with a switch that adds or removes the subscription right away) and, below them, each supported tool this Mac does not have, with the reason.

- In Settings > Subscriptions the order list now uses the same wide column as the visibility and name rows, so the controls line up.

## CLI v0.5.58, Codex plugin 0.15.45 and Claude Code plugin 0.7.44 (2026-11-10)

- The quota widget card's vendor mark now sits on the name's line instead of below it, and the reserve line (extra resets and credits) always reads as labelled text such as "Resets 1 · Credits 19,614", with no hover swap.

- The cockpit engine table now follows the Settings remaining or used choice: in used mode the percentages and the segmented bars both show what is used, while the colours stay tied to what is remaining.

- The Quota Widget's dotted clock now follows the remaining/used choice: remaining lights the time left, used lights the time elapsed. The Quota Widget rings now follow the remaining/used choice too: in used mode the arcs fill with usage while colours stay keyed to what is left. The Quota Widget card bars follow the remaining/used choice too.

- The cockpit porthole canopy keeps the shipped lower body and adds the missing top: completed shoulders and arc with a rounded outer wall edge (D74 and D100, art pending owner acceptance); the tall window grows by 28 points and the compact window by 8 (root 635), and the compact strip moves into the glass.

- The cockpit 7-day and 30-day charts now draw imported-history days exactly like live days: no lighter bars or cells and no data-start marker. A day with imported output only says so in its hover note.

- Right-clicking the cockpit now shows ModelPlan's own menu (Settings, Reset Position, Quota Widget Size, Help). The widget and the menu bar icon menus gain Reset Position. While Settings is open the app has a standard menu, so Command-comma, Command-W and Command-Q work, and it goes back to a menu-bar-only app when Settings closes. The cockpit's drag area shows an open hand and a faint grip when you hover it.

- The cockpit has its detach and put-back key again, in the strip between Settings and Close. Attached, it opens centred under the menu bar icon, grows out of the icon and shrinks back into it (instantly with Reduce Motion), keeps the icon pressed while open and closes when you click elsewhere. Detach it with the key, the right-click menu or by dragging the title strip; a detached cockpit stays open when you click elsewhere and goes back with the put-back key or by dropping it near the icon. A one-time hint explains each.

- The cockpit now fits its size to your screen. A new "Cockpit size" setting offers Auto (the default), 80, 85, 90 and 100 percent; Auto draws the cockpit at 85 percent on laptop screens up to 1512 points wide, such as a MacBook Air, and at 100 percent on larger displays, and switches when the cockpit opens on another screen. On a screen too short for the chosen size, such as a MacBook Air with the Dock at the bottom, the whole cockpit, flames included, shrinks evenly to fit below the menu bar instead of switching to the short version; text stays sharp and controls respond where they are drawn. The short version only appears where the full cockpit would drop below 75 percent. Choosing Detach or Put back from the cockpit's right-click menu no longer crashes the app.

- Right-clicking the cockpit no longer shows a browser menu, and reloading the page can no longer take the cockpit down.

- The cockpit's alert list now notes when a declared plan's published peak-rate hours start, and how long they last.

- The cockpit's Breakdown page now lists the past week's sessions in its 7-day time view, each with when it was last seen.

- When this Mac has recorded less than the period a cockpit total covers, the total now says when the record starts instead of claiming 30 or 7 days.

- Added normal-entry tests for the cockpit: placement under the menu-bar icon, the Reduce transparency setting, the porthole's expand gestures and the fader bars and star; no user-visible change.

- Find Quota Widget no longer draws a bright ring around the widget. The clearing now has a soft, feathered edge that fades smoothly into the dim, with a gentle glow in your accent colour just outside it so the widget still stands out on a dark desktop; the glow fades in once (not with Reduce Motion) and is a little stronger with Increase Contrast.

- Find Quota Widget now clears the dimmed screen around the widget's real drawn outline, rounded ends and ring bumps included, instead of a rounded rectangle; the dim still fades in smoothly over about 24 points from the widget's edge, with no border or shadow.

- The first-run page now lists every coding tool found on this Mac with a checkbox, says in one line what ModelPlan reads for it and whether macOS may ask for Keychain access, and explains when a tool cannot be read (for example Claude Code not signed in, or ZCode signed in with an account). Readable tools start checked; pressing Done saves the choices as the one first-run consent, and an unchecked tool is not read. Claude Code that is installed but signed out is now reported as "Not signed in" instead of a generic reader error, and it no longer gets an empty ring on the Quota Widget.

- The first-run page now shows the approved recommendation line, "Recommendations use ModelPlan's published model data; your usage never leaves this Mac." (and its Chinese counterpart), instead of the shorter placeholder, so it says plainly that recommendations come from published data and that usage stays on the Mac.

- A cockpit total that names where a short record starts now also accounts for imported history, and its spec fixtures carry the daily bucket origin.

- A subscription with no reading gets no Dock ring from the first frame, whatever the reason (not signed in, waiting for permission or consent, an unsupported sign-in, a reader error, or still waiting on its first read); it gets its ring when a reading arrives. The Settings subscription list and the menu still list it with the reason.

- `modelplan history --import [--days N]` reads older Claude Code and Codex logs on this machine (timestamps, model, effort, speed mode and token counts only) into `observed/imported.json` (a separate ledger; the cockpit charts and the effort suggestion do not read it yet, that is the next slice). Rows are marked `origin: "import"`, a re-import or an overlap with the live observers never counts a turn twice, each tool needs its own history consent, and `modelplan history --remove-imported` deletes exactly the imported rows. The app gets an "Import usage history" row in Settings › Data & Privacy (day count 7 / 30 / 90, progress, Cancel, Remove imported history) and one plain line under the first-run consent; after consent the import runs once in the background with no extra dialog. The engine serves it through the new `history/import_start`, `history/import_status`, `history/import_cancel` and `history/import_remove` methods.

- The quota widget keeps a ring magnified while the pointer moves across the whole unit (ring, percentage and the gap between them), magnifies the ring alone about its own centre instead of moving it, and shows the percentage under each ring about 2 pt larger.

- The enlarged launch field is now a feathered porthole silhouette floating on a transparent panel, with the model picker as a frosted card beside it.

- The cockpit's porthole now has a ⤢ key, and a double-click or a click on a rocket opens the enlarged 3D launch field (focused on that rocket).

- Menu bar: the status icon keeps its accessible help while the cockpit is open and the tooltip is withdrawn.

- The Quota Widget now starts expanded: Auto-Collapse is off by default, so a fresh install shows the widget after first run and a saved choice (on or off) is kept. The first time the widget collapses to its edge strip, a one-time hint says where it went and that hovering it or Find Quota Widget in the menu bar brings it back.

## CLI v0.5.57, Codex plugin 0.15.44 and Claude Code plugin 0.7.43 (2026-11-09)

- The cockpit base now shows a bell under each subscription column, and a subscription with a session running right now lights the inside of its bell mouth in the colour of its quota state, as on the prototype. The official appearance uses the released base-bell art; the community appearance draws a flat light in the same place.

- The cockpit comparison view now reads the published fast tiers, matching a model by its published or vendor model id, so the fast key can show off and on. It stays dark for a model with no tier.

- The cockpit publication now carries the published fast tiers (speedTiers, unchanged from the client data), so the comparison fast key has data to read.

- The cockpit's porthole HUD now fits all six model rows on the tall screen with whole names, and its small chart carries the Ability and Cost captions and rank numbers, as in the design.

- The cockpit's ALERT lamp no longer blinks again for a caution you already pressed: a refresh, a reopen or a pending read keeps it steady, and pressing the lamp flashes the row of the newest caution once in the list.

- At night the cockpit now draws its hull as in the design: the r3 hull walls and aft plate around the canopy, with nothing drawn around the hull, so the desktop shows through beside and below it.

- The cockpit's Subscription page now switches its usage block between 7 and 30 days and its history between the 5-hour and weekly windows, draws the cycle bars in the subscription's colour, and shows the 30-day credits total as unknown instead of leaving it out.

- The cockpit now lines up with its design at both heights: the canopy joins the title strip, every record line fits, and the full height is used whenever it actually fits the screen. Dragging the left of the title strip now detaches and moves the cockpit.

- A failed Codex refresh (Codex not found, a timeout, a transient error) no longer throws away the last good reading: for up to six hours the account keeps its windows as a stale reading that names the failure, so its ring stays, and the retry still follows the usual back-off. Doctor now reports Codex failures as runtime_missing or reader_error with the specific reason, like the other readers.

- After consent is reset and granted again, Codex is read at once even when the cache folder still holds an older snapshot and next-attempt time from before the grant, so the Codex ring no longer waits for the old half-hour schedule.

- The Help map places its captions beside the Quota Widget instead of over its rings, and its leader lines now show on dark desktops.

- Help map captions on the Quota Widget no longer lose their last words; a caption that just fit its measured width wrapped onto a line its box could not show.

- Esc and a click outside now close the Help map: opening it brings the app forward so the keys and clicks reach it.

- The menu-bar percentage no longer jumps while the pointer is on the item: a refresh that changes nothing writes nothing, and the reset dot is placed from the icon's own width instead of the button's stale bounds.

- The widget card now draws every vendor mark at the same size as its title, measured by the mark itself rather than its file's clear space, and keeps the prototype's gap from a ring that hover has magnified, so the card no longer crowds the ring and its arrow tip is no longer hidden under it.

- The cockpit's alert list now also notes extra resets that expire within 48 hours.

- The cockpit now shows one fader for each model you can use, three per bank, paged with the arrow keys or with [ and ], instead of stopping at three.

- Model names in the cockpit's short porthole readout no longer run into each other.

- Clicking the menu bar icon while the cockpit is open now closes it. It keeps its state and any detached position for the next open.

- The menu bar icon's tooltip no longer covers the top of the cockpit when it opens.

- The cockpit now opens with its left edge under the menu bar icon, like other menu bar tools, and moves left only as far as needed to stay on the screen.

- The cockpit now opens the "Compare · <model>" page when you try an effort on a fader, colours each fader and record line by its subscription, uses short model names, names subscriptions with their mark, plan and whole-minute reading age, explains the Reserve row, and records live Codex sessions when only Codex is allowed.

- The cockpit Overview now lists a blue lower-effort suggestion for a session running on a red quota and shows when an announced official extra reset is expected. Its Grid heatmap is drawn at the size of its area, takes the subscription's colour in a subscription scope, and shows the date and tokens when you hover a day.

- The cockpit opens at once: the app loads an empty cockpit page in the background after launch and after each close, and a click shows it with the last readings, which the fresh ones then replace. Readings past their freshness time are still not shown as current. Under memory pressure the background page is released until memory is normal again. The app logs each prewarm and open stage (names and milliseconds only, no data), and a hidden page whose WebKit process answers late at launch is no longer thrown away and rebuilt.

- The cockpit remembers the subscription you picked for the rest of the day, even if you quit and reopen the app, and starts at All again the next day.

- The Quota Widget now starts collapsed to its edge strip on a fresh install; an existing saved Auto-Collapse choice is kept. A new Find Quota Widget command in the menu bar icon's menu, the Quota Widget shortcut in Settings and the end of first run slide the widget out and briefly dim the rest of its display around it; any click or key ends it at once, and Reduce Motion skips the slide and fades.

- The first-run page now comes to the front on first launch instead of possibly opening behind the window you were in. A later restore after a wake still leaves focus alone.

- First-use hints and the Help map from the status menu now appear. Both waited for a state macOS only reports after they have been shown, so they were withdrawn every time.

- Quota rings now sit centred across the widget face by default, the position the owner chose after comparing it with the prototype. The owner test menu option for this is gone.

- An alarming quota (warning or empty) now shows on the collapsed widget strip as the prototype's glow: a red or amber gradient centred on that ring's place, at the prototype's strength, instead of a faint flat tint.

- Spawning subagents while quota is low now gets one line before the spend: the Claude Code plugin hooks the Agent and Workflow tools, the Codex plugin hooks spawn_agent (Codex asks you to review the new hook). It shares the 20/10/5% record with the prompt notices, at most three times per session, says nothing inside a subagent or on an old reading, and never blocks the spawn. Low-quota lines also name another connected plan that clearly has room, such as "Codex still has 60% of its weekly quota left". The Skill now answers which of your plans still has quota. Needs CLI 0.5.56.

- The quota widget now stays visible while the cockpit is open. The cockpit opens above it and may cover it; closing the cockpit leaves the widget exactly where it was.

- A quota window that is used up now shows on the widget the way the prototype's empty nozzle does: the ring's track turns dark red, the nozzle face takes a light red tint and the vendor mark dims. Its card adds one plain line such as "5-hour quota used up · resets in 3h 18m".

## CLI v0.5.55, Codex plugin 0.15.41 and Claude Code plugin 0.7.40 (2026-11-07)

- The app now fetches the public publication by itself soon after it starts, so a Mac with only the app installed gets its faders without running `modelplan sync`. The cockpit fills in when the data arrives; while it cannot be fetched the app keeps working, retries, and the faders say the data is unavailable.

- A quota card now closes when the pointer leaves it after a ring was clicked. The click used to count as keyboard focus on the first ring, which held that ring's card open whichever ring was clicked.

- The cockpit gains the enlarged launch field with vendor marks, the frontier page and the porthole HUD, which follows the selected subscription.

- The cockpit opens faster: the app checks its cockpit files once at launch instead of on every click.

- The app now logs which path raised "Cockpit unavailable", so a report can name the failure. The log holds code paths and counters only, never account data.

- A failed first Codex read no longer leaves the widget without a Codex reading for half an hour. Until Codex has answered once, a failed read retries after 20 seconds, 1 minute and 5 minutes, then falls back to the half-hour wait, and the first read gets more time for a cold start.

- `modelplan quota` now says why it read nothing. With reading off it names the cause in text as well as `--json`, and a consent record written by a newer ModelPlan has its own reason, `consent-newer`, with the fix: update the plugin or the CLI.

- Pressing Allow for Keychain access now always brings up the Keychain prompt. A background refresh starting at the same moment could take its place and the prompt never appeared.

- Allowing Keychain access now makes one credential read. An automatic refresh could slip in beside the read you just approved, read the credential a second time, and if it was slow make your approved read fail.

- The cockpit now returns to All on the first open of a new day; within a day it keeps the subscription you chose.

- Website links in the cockpit's main screen now open the matching page in your browser. The plan details link also follows the app language and is left out when the maker is unknown.

- Links opened from the menu bar menu and Settings now share one path.

- The two-window menu bar title now uses the same admission rule as the Quota Widget.

- Chinese status lines now say the usage was read, instead of using an internal word.

- `modelplan quota` no longer lets an old reading pass for a current one. Each window now says `stale` when its own reading is over an hour old, and the text output marks it, with the refresh command for Codex. `--refresh-account` reports what happened in `refresh` (refreshed, too soon with the next time, failed with the reason, or not allowed) instead of silently showing the old figures, and it no longer skips the other readers' background refresh. The Skill now answers quota questions from a fresh reading and is triggered by them in English and Chinese. The wording for reset cards becomes "extra resets".

- Settings wording now follows the label rules in both languages, and CI checks the native app and cockpit strings against them.

- VoiceOver and other accessibility tools now find each quota ring where it is painted; the widget reported every ring reflected top to bottom.

## CLI v0.5.54, Codex plugin 0.15.40 and Claude Code plugin 0.7.39 (2026-11-07)

This heading also covers v0.5.47 to v0.5.53, which were released without their own heading.

- Standard readers are on by default. The app reads Codex's runtime, and its session logs as the fallback, on a profile with no recorded choices, without a consent click. A recorded refusal, a tool-level denial, a reset consent store and `MODELPLAN_READERS=off` still win.

- One Codex account per ChatGPT login. While Codex's own live account reading is available, it is the only Codex account: session logs are no longer shown as a second account beside it, also after a plan upgrade. Only the current session's model, effort and allowance pool come from the logs. Without a live reading the session logs remain the Codex reading, and an older runtime plan never replaces a newer one.

- A read that loses a lock to another ModelPlan process, such as a plugin hook, now retries after 15 seconds. Before, nothing had been read but the app waited 10 minutes, or 30 for Codex's runtime.

- An older tool-level allow no longer switches off default-on reads added after it: for example Codex's runtime is read on such profiles, while a refusal, a denied source or a chosen non-native backend still wins. `doctor readers` now lists Codex.

- Verification only: `MODELPLAN_VERIFY_READERS=<tool,...>` narrows every consent read (saved grants and default-on local/runtime scopes) to the listed tool IDs for device test runs. It never grants anything, an invalid entry denies every tool, and it is never written to the consent file. Unset, nothing changes.

- A finished Codex reading is no longer lost when the consent lock is briefly held. Before, the reading was dropped and the next attempt waited 5 to 30 minutes.

- Withdraw today statistics from subscribed account rows when their session evidence, day, or current source binding expires, even when no cache file changes.

- Do not run this CLI concurrently with an older CLI against the same cache: the ledger lock protocols differ and do not mutually exclude one another. Stop older processes before starting this version.

- Keep C14 local default-effort suggestions off by default until the owner's go-live (earliest 2026-11-07; no automatic activation). Explicit local opt-in limits delivery to text history and the status line within 24 hours of a weekly reset, sharing one notice per rolling week. Hooks and desktop JSON no longer expose suggestions; the three-week minimum, local-only calculation and history opt-out remain.

- Accept the optional published `provisional: true` on a model's effort in the CLI, the public reader and the Codex plugin. `modelplan effort` marks that ability as provisional (`暂定`), `--json` carries the flag only when set, and quota hints never offer a provisional configuration as another model's alternative, nor compare a provisional current configuration across models. Other unknown effort fields are still rejected.

- Add the pure CLI rows projection core: stable tool membership, contextual reason mapping, per-profile value states, conservative clocks, and field-specific privacy checks. Missing or retired allowed tools take priority over no-reader guidance. Production desktop integration follows the reader/consent adapters; quota output is unchanged.

- Granting Claude Keychain access in Settings now runs one foreground read right away, so the macOS prompt appears while you are there. Before, only two-second background reads ran, an unanswered prompt timed out, and the Keychain state stayed stuck so Claude never got a reading. Replays, grants without Keychain, and Keychain denials read nothing.

- Extend the app–CLI contract to plugin installation: schemas cover every existing status, and real-binary synthetic captures verify both host tools, offline planning and partial failures. Schema/type/status drift is checked against the production Go model; install behavior is unchanged.

- The Mac app now ships the owner-accepted app icon, so Finder, Launchpad and Spotlight no longer show a blank app.

- Claude Code's saved login is read by default. A login kept only in the macOS Keychain is never read before you allow it: the Claude Code row asks for Keychain permission instead, and the read right after Allow no longer waits for a back-off left by failures that never reached Anthropic.

- The cockpit's faders now show the published models for your subscriptions, models in use first, with pinning by a long press. They were empty before. The cockpit entry stays off in packaged builds until the v1 cockpit is enabled.

- Cockpit record lines now link: hovering one lights its engine column, and clicking selects its subscription and opens the session list.

- The cockpit's sessions now name their account, so a record line links to its column, and the app keeps quota history without a plugin.

- Allow explicitly granted local Codex history to refresh when the retained runtime reading is too old to be usable.

- The cockpit and Quota Widget now have automated checks for the status colours, the brand red rule and steady layout during state changes.

- The red threshold choices are now 40, 30, 25, 20, 15 and 10 percent remaining, in Settings, the Quota Widget, the cockpit and the engine. An older saved 16 stays on disk and acts as 25.

- Added checks for the Quota Widget's face gradient and grip position; nothing changes for users.

- The Quota Widget's percentage switch in Settings now has its agreed name, and the app logs when a stale lock forces the widget to hide.

- Added checks for more Quota Widget rules; nothing changes for users.

- The Quota Widget's grip now lights with the prototype's warm ring and glow on hover and focus, with a gold outline for keyboard focus.

- Flames now light on the Quota Widget while a Claude Code, Codex or ZCode turn is running, for the account that runs it, without any plugin; they go out when the turn ends or its evidence expires.

- The Quota Widget's flames step at half rate on battery, and return to normal on AC at the next data change.

- Once the cockpit entry is on, left-clicking the menu bar icon opens the cockpit and reopening the app from Spotlight or Launchpad does too. While it is off, as in current release packages, left-click shows the menu. Right-click or control-click always shows the menu.

- Plugin updates now deliver a new CLI pin. Moving the pin left the plugin versions unchanged, so `claude plugin update` and Codex's marketplace upgrade reported nothing to do and users stayed on an old CLI; on a machine whose consent file a newer CLI had upgraded, that old CLI read no quota at all. `scripts/pin-cli.mjs` now moves the plugin versions with the pin, and CI fails a pin change without them. Codex asks you to allow the plugin's hooks again after this update.

## CLI v0.5.46, Codex plugin 0.15.38 and Claude Code plugin 0.7.37 (2026-10-29)

- Desktop connections now reflect native Claude consent, Keychain choice, production admission and read status, with an actionable Settings next step. Tool CLI discovery includes npm-global, Volta and Bun; env-node scripts launch through a resolved Node/Bun runtime under a minimal GUI PATH, with a distinct missing-runtime reason.
  桌面连接状态现反映 Claude 原生授权、钥匙串选择、生产读取准入及读数状态，并提供可操作的设置入口。工具发现支持 npm-global、Volta 和 Bun；GUI 最小 PATH 下的 env-node 脚本通过已定位的 Node/Bun 运行，缺少运行时单独说明。

- Add machine-checkable app–CLI command schemas and synthetic fixtures generated from the current CLI binary. CI rejects fixture drift, and native app decoders and Settings consent adapters consume the same captures.
  新增可机器校验的 App–CLI 命令契约与当前 CLI 实际生成的合成样例；CI 检查样例漂移，原生 App 解码器及设置授权适配器共同读取同一组样例。

- Native reader failures now retain bounded error codes for file access, JSON/schema changes, HTTP/auth responses, transport failures and runtime discovery. `doctor readers` text/JSON and desktop connection reasons expose codes only. Cursor's explicit consent now admits a missing standard profile so it reports `file_missing` rather than silently remaining unadmitted, while privacy, catalogue and unsafe-profile vetoes remain enforced.
  原生读取器失败现保留文件访问、JSON/格式变化、HTTP/认证响应、网络和运行时发现等固定错误码；`doctor readers` 文本/JSON 与桌面连接原因仅输出代码。Cursor 显式授权后，缺失的标准资料目录可进入只读诊断并报告 `file_missing`，不再无声地拒绝准入；保留隐私、目录路由与不安全路径限制。

- Both plugins and their bundled Skill pin CLI v0.5.46 and its published archive checksums.

## CLI v0.5.45, Codex plugin 0.15.37 and Claude Code plugin 0.7.36 (2026-10-28)

- Desktop, quota, advice and online hooks explicitly schedule due native readers in one locked detached worker. The first read after a JSON consent grant is immediately due; quiet scheduled refreshes preserve provider budgets, background Keychain policy and generation fences. Offline/read-only paths start nothing.
  桌面、额度、建议及在线钩子显式调度到期的原生读取器，跨进程锁保证仅有一个后台任务。JSON 授权后首次读取立即到期；静默后台刷新保留提供方间隔、后台钥匙串策略与授权代次保护，离线及只读模式不启动任务。

- CLI consent read/grant responses add `hostDetails` with bare DNS hostnames and separate notes, while preserving existing `hosts` display labels.
  CLI 授权读取和提交响应新增 `hostDetails`，分别返回裸 DNS 主机名与说明，保留现有 `hosts` 展示文本。

- Both plugins and their bundled Skill pin CLI v0.5.45 and its published archive checksums.

## CLI v0.5.44, Codex plugin 0.15.36 and Claude Code plugin 0.7.35 (2026-10-28)

- CLI adds cache-only `windows` for public time-of-day billing rates, local-time changes and unverified evidence labels; `lineup` / `plan` and task-start briefs include declared-plan rate context and optional cheaper-window hints. Expired horizons stay unknown, and `lineup <developer-id>` now selects that developer.
  CLI 新增只读缓存的 `windows`，显示公开分时计费倍率、本机时间和未核实标记；`lineup` / `plan` 与任务简报提供已声明套餐的倍率及可选低价时段。过期时域保持未知，`lineup <开发者 ID>` 现正确筛选开发者。

- CLI consent commands explain the required `--json` flag on stderr. On macOS, when unset Claude Keychain permission blocks a saved-login read, the reader notice and consent readback name the missing choice and direct users to allow Keychain for Claude Code in Settings. Linux keeps the saved-login notice without a Keychain remedy.
  CLI 授权命令在缺少 `--json` 时输出用法；macOS 上 Claude 钥匙串选择未设置而无法读取时，读取器提示及授权回读说明原因，并引导用户在设置中允许 Claude Code 访问钥匙串。Linux 保留已有登录不可读的提示，不显示钥匙串操作。

- Both plugins and their bundled Skill pin CLI v0.5.44 and its published archive checksums.

## CLI v0.5.43, Codex plugin 0.15.35 and Claude Code plugin 0.7.34 (2026-10-28)

- CLI adds `consent --json` and `consent grant --json` for the App: bilingual consent text, atomic generation/text-version checks, durable request replay, standard-route gating, recorded Keychain choices and revoke-first Forget cleanup. Replay receipts, cleanup obligations and Keychain restrictions survive pre-API shared-store readers/writers. Existing production readers pick up the new generation and invalidate in-flight older grants.
  CLI 新增 App 授权 JSON 读取和提交接口，返回中英文原文，原子校验授权代次与文本版本，支持持久化幂等请求；仅授权标准读取、记录钥匙串选择，拒绝先撤销再清理，并使旧代次的进行中读取失效。旧版 CLI 读写共享授权文件后，幂等回执、清理义务及钥匙串限制仍有效。

- Add `modelplan doctor readers [--json]` for sanitised owner verification of native quota readers, local-history adapters and Claude session state. The default reads only cache/presence metadata; explicit `--refresh` uses production consent and interactive Keychain policy while sharing per-provider request floors, intervals and backoff with ordinary refreshes. Output contains only compiled provider IDs, status codes, window counts, UTC ages and beta flags.
  新增 `modelplan doctor readers [--json]`，用于所有者核验原生额度读取器、本机历史适配器与 Claude 会话状态。默认仅读取缓存与存在性元数据；显式 `--refresh` 遵循生产授权和交互式钥匙串策略，与普通刷新共享各提供方的请求下限、间隔与退避。输出仅含固定提供方标识、状态码、窗口数量、UTC 年龄及 beta 标记。

- CLI weekly effort suggestions now share one notice across text history, the Claude Code status-line hint and user-only hooks. The status line steps from the explicit current effort using published reference costs; previews, record-only mode and urgent quota advice do not consume the notice.
  每周档位建议在历史文本、Claude Code 状态栏和钩子的用户提示间共享一次提示；状态栏从明确的当前档位按公开参考成本建议一步，预览、仅记录和紧急额度提示不消耗次数。

- Add the beta passive Claude session-state reader for owner-confirmed model/effort/Fast fields, using the shared local-history projection engine for bounded incremental reads and atomic sanitized snapshots. Production admission supports Automatic/Passive consent and cache-only caller selection without a plugin or status line. Background progress and excluded worker metadata cannot change the selected main branch or its classification; no independent cursor or quota-network schedule.

- Both plugins and their bundled Skill pin CLI v0.5.43 and its published archive checksums.

## CLI v0.5.42, Codex plugin 0.15.34 and Claude Code plugin 0.7.33 (2026-10-28)

- CLI production paths now admit consented native saved-login readers, carrying local profiles, selected region, bounded Keychain policy and revocation-fenced publication into quota, hooks and desktop feeds. Explicit `MODELPLAN_READERS=automatic` preserves saved privacy; runtime imports stay blocked in Passive. Wire incremental local-history refresh and the optional desktop `localHistory` feed, add an explicit GLM configuration source, and include the newer captures in Forget while preserving request gates and Keychain Deny.
  CLI 生产路径现将共享授权接入原生登录读取器、钩子与桌面，保留本机来源、地区、钥匙串期限及撤销写入保护；显式 automatic 保留已保存的隐私设置。接入增量本机历史与桌面可选字段，GLM 配置来源需显式选择；忘记读数保留请求间隔和钥匙串拒绝状态。

- Both plugins and their bundled Skill pin CLI v0.5.42 and its published archive checksums.

## CLI v0.5.41, Codex plugin 0.15.33 and Claude Code plugin 0.7.32 (2026-10-27)

- Catalogue helper routes now distinguish audited standard, separate advanced browser-session and not-read access. Standard consent excludes browser sessions and forces both the Keychain gate and `cookieSource: off` across the complete effective helper registry, verified after normalization, including for Firefox/Safari cookies. Only the explicitly granted browser-session target gets `cookieSource: auto`; user-set Keychain disables remain in force. `connect <tool> --browser-session` explains Safe Storage/cookie caching and grants one provider explicitly. Forget atomically captures current cookie-cleanup obligations during revocation and keeps blocked cleanup pending. All connect JSON paths are previews; confirmations name destination hosts. Privacy/revocation gates now also protect Qwen status exports and generation-fenced refresh/snapshot/history writes.

- CLI `connect --detected` adds a pre-checked, single-confirmation consent chooser and read-only JSON preview, shared versioned per-tool grants, automatic/passive privacy (`MODELPLAN_READERS=passive|off`), persistent source denials, and one-time new-tool hints. `disconnect <tool|--all>` revokes first and deletes ModelPlan-owned readings while retaining other tools and request gates. Unreviewed helper routes and incompatible catalogue entries cannot admit readers.

- Add the beta China-only Kimi Code saved-login reader with the existing device identity, one usage request and no credential refresh or device creation. Login and explicit-key routes share a persisted attempt floor/backoff; other quota durations retain labels and reset-past windows leave current projections.
- Add the beta native Grok Build saved-session reader: one read-only billing request for included periods and separate prepaid USD balance, with shared-consent admission, backoff and conservative Cursor/Grok spacing. Shared-pool links remain unverified; no refresh, login launch, inference or automatic account merging.
- Add the beta native Gemini CLI OAuth-file quota reader, with explicit shared consent, at most Code Assist metadata + quota per read, separately aged Google One AI credits and model/request counters. No OAuth refresh, project enumeration, inference or CodexBar fallback; unsupported login modes make no request.
- Add the beta native Claude Code account quota reader, admitted through the shared consent interface: OAuth usage/profile and a bounded `/usr/bin/security` adapter that persists Deny and confirmation-needed states. Prepaid credits are omitted from v1; only evidenced usage windows and extra-usage spend/limit are read. No credential refresh or inference calls; command/consent wiring belongs to the CLI framework.
- Cursor's beta saved-login reader uses at most plan-info + period-usage per read, with explicit shared-consent admission, a five-minute floor, cached metadata and last-good capture retention. Eligible X Subscription pools stay labelled link-unverified and non-additive until a verified common ID exists.
- CLI `modelplan detect [--json]` checks tool presence from a verified cached catalogue or a built-in bootstrap, without credential contents, network calls, tool launches or cache writes. Unknown signals/rules are inert; incompatible `minCli` entries request an update.

- CLI publication refreshes spread load with independent uniform 0–60 second jitter before interval-triggered online checks and on the 10-minute check interval. Caller deadlines are preserved; first checks, explicit syncs and offline/cache reads have no added pre-check delay.

- Both plugins and their bundled Skill pin CLI v0.5.41 and its published archive checksums.

## CLI v0.5.40, Codex plugin 0.15.32 and Claude Code plugin 0.7.31 (2026-10-26)

- `modelplan advise`: **no spending ahead of a reset that already came.** A Codex reset can land
  before its stated time, before the announcement is seen, or minutes before the post itself,
  while the public record still says "announced". `announced_reset_with_surplus` now needs a
  reading taken after the post, and is not given when that reading shows the reset reached the
  account: the longer window began after the post (or within six hours before it), or, after the
  hint, restarted or has 10 points more left. The "Codex announced a usage reset" news is dropped
  for the same reason, and the switch-back comes as soon as an early landing shows instead of
  waiting for the stated time.
- Both plugins pin CLI v0.5.40 and its published archive checksums.

## CLI v0.5.39, Codex plugin 0.15.31 and Claude Code plugin 0.7.30 (2026-10-25)

- A weekly default-effort suggestion from the user's own local quota history. After three
  comparable finished weekly cycles, `modelplan history` and the hooks' user-facing message may
  suggest one published effort step up (often well under the limit) or down (often at the
  limit), with the published reference-cost ratio. Nothing leaves the machine; the agent never
  sees it.
- `modelplan history --effort-suggestion dismiss|off|on`, and `MODELPLAN_EFFORT_SUGGESTION=off`.
- `desktop --json` adds an optional `effortSuggestion` (contract version stays 1).
- Both plugins pin CLI v0.5.39 and its published archive checksums.

## CLI v0.5.38, Codex plugin 0.15.30 and Claude Code plugin 0.7.29 (2026-10-25)

- `modelplan publication --json` passes through the published lineage selection results:
  per-model `lineageId`, `lineageStatus` (`current`, `older`, `preview`, `retired`) and
  `defaultSelected`, plus the publication's `selectionRevision`. Missing or null values mean
  unknown. The `lineageSelection` capability is now `publication-dependent`; contract version stays 1.
- The public reader accepts these optional fields.
- Both plugins pin CLI v0.5.38 and its published archive checksums.

## CLI v0.5.37, Codex plugin 0.15.29 and Claude Code plugin 0.7.28 (2026-10-25)

- Public display names now read "ModelPlan" in the CLI output, the plugins and the Skill.
  Command, package and repository identifiers stay lowercase.
- `modelplan desktop --json --read-only` and `modelplan publication --json` add
  `contractVersion: 1` and a `capabilities` map (frozen desktop contract v1). Existing
  fields and `schemaVersion` are unchanged. Schemas are in `schema/`, synthetic goldens in
  `testdata/contract-v1/`.
- `publication --json` also carries the verified public reset announcements and
  confirmations, scoped windows, quota multipliers with their horizon, and plan metering.
- Capabilities mark credit history, reset-drop provenance and model-lineage selection as
  unavailable instead of inventing values.
- Both plugins pin CLI v0.5.37 and its published archive checksums.

## CLI v0.5.36, Codex plugin 0.15.28 and Claude Code plugin 0.7.27 (2026-10-24)

- Claude Code and Codex prompt hooks give the model one factual line when the harness's
  5-hour or weekly quota falls below 15% remaining, and one after that window resets
  with more than 50% remaining. Each low/reset line fires at most once per window per thread.
- These lines use the hook's English/Chinese setting and show only the window, remaining
  percentage and time to reset. Unknown or stale readings never trigger them; quota is read
  from the local cache without waiting on the network. Existing advice stays in the user's
  `systemMessage`, separate from the model's `additionalContext`.
- `MODELPLAN_TASK_BRIEF=off` disables the quota lines along with the task-start brief.
  Session state is stored beside the brief state with the same eight-day expiry and cleanup.
- Both plugins pin CLI v0.5.36 and its published archive checksums.

## CLI v0.5.35, Codex plugin 0.15.27 and Claude Code plugin 0.7.26 (2026-10-24)

- Cursor personal-plan quota is opt-in with `modelplan connect cursor`. It reads only
  `cursorAuth/accessToken` from the editor's `User/globalStorage/state.vscdb`, read-only,
  including existing WAL state: `~/Library/Application Support/Cursor/` on macOS,
  absolute `$XDG_CONFIG_HOME/Cursor/` or `~/.config/Cursor/` on Linux, `%APPDATA%/Cursor/` on Windows.
  It calls private dashboard JSON on `cursor.com` (`/api/usage-summary`,
  `/api/dashboard/get-plan-info`, legacy `/api/usage?user=...`) and, for unified plans,
  `api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`. Included requests,
  monthly/weekly pools, usage-based spend and reset dates stay distinct. Tokens are never
  refreshed, rewritten, copied or stored; expired, sealed or opaque sign-ins remain unknown.
  `modelplan connect cursor --backend codexbar` explicitly selects the existing fallback.
- MiniMax plan quota is opt-in with `modelplan connect minimax --region international|china`.
  It reads only `MINIMAX_CODING_API_KEY` (or `--key-env NAME`) and calls
  `GET /v1/token_plan/remains` on `api.minimax.io` (default) or `api.minimaxi.com`.
  The same-host legacy `/v1/api/openplatform/coding_plan/remains` is tried only after
  endpoint/auth rejection; no cross-region retry occurs. The current route is documented on
  `www.minimax.io`; API subdomains, response schema and the legacy route are compatibility
  interfaces. Remaining percentages take precedence over legacy remaining counters; missing,
  inactive, unfamiliar or expired values stay unknown. No credential files, browser sessions,
  refresh, inference or API cash balance are used, and keys are never printed or stored.
- Both quota readers remain off until connected. `modelplan disconnect <provider>` or
  `MODELPLAN_NATIVE=off` stops reads. Connections and desktop diagnostics disclose the source
  path or environment variable, called hosts and endpoint documentation status; snapshot v1
  adds diagnostics without changing existing quota meanings. Identity references use local keyed hashes.
- `modelplan publication --json [--offline]` returns one public-only object with
  `schemaVersion: 1`, `publicationId`, nullable `publishedAt`, `units`, `models[]`, `lineups[]`
  and `speedTiers[]`. `lineups` is an array, unlike `lineup --json`'s developer-keyed object.
  Published order, unknown `null` values and speed qualifiers are preserved; no ranking is inferred.
  Online it anonymously refreshes verified public data; `--offline` re-verifies the cache without
  network requests or writes. It reads no account data, credentials, quotas or personal history.
- Validation uses handwritten synthetic fixtures and local test servers. Live accounts,
  endpoint acceptance and all platform/region/plan combinations were not verified; no real
  vendor credentials or quota endpoints were used during testing.
- Both plugins pin CLI v0.5.35 and its published archive checksums.

## CLI v0.5.34, Codex plugin 0.15.26 and Claude Code plugin 0.7.25 (2026-10-23)

- Quota windows become unknown (`--`) once their reset passes without a fresh reading.
  CLI readers, the Python Skill and desktop snapshots withhold the old percentage and explain why.
- Copilot premium-request quota is opt-in with `modelplan connect copilot`: the signed-in
  runtime's `account.getQuota` returns monthly used/limit/reset without a session or inference.
  Copilot owns GitHub access (normally `api.github.com`); modelplan imports no token and makes no
  direct vendor HTTP call. `MODELPLAN_COPILOT` can select the executable; the explicit
  `--backend codexbar` option keeps the existing bridge available as a fallback.
- Gemini local tokens/model/day/session history is opt-in with `modelplan usage gemini enable`.
  It reads `~/.gemini/tmp/*/chats/session-*.{json,jsonl}` and the legacy root layout; an absolute
  `MODELPLAN_GEMINI_HOME` overrides the root. `disable`, `MODELPLAN_GEMINI=off` or
  `MODELPLAN_HISTORY=off` stops it. No executable, credential file, host or remote quota is read/called.
- Kimi Code plan quota is opt-in with `modelplan connect kimi --region china|international`.
  It reads only `KIMI_CODE_API_KEY` (or `--key-env NAME`) and calls the undocumented compatibility
  `GET /coding/v1/usages` on `api.kimi.com` or `api.kimi.ai`. The key is never printed/stored;
  no OAuth, cookies, credential files, inference or Moonshot balance is used.
- Qwen local tokens/model/day/session history is opt-in with `modelplan usage qwen enable`.
  It reads `~/.qwen/projects/*/chats/*.jsonl` and legacy tmp/root chat layouts;
  `MODELPLAN_QWEN_HOME` overrides the root. `disable`, `MODELPLAN_QWEN=off` or
  `MODELPLAN_HISTORY=off` stops it. No executable, credential file or host is accessed.
  Optional `qwen-usage --export PATH` / `MODELPLAN_QWEN_USAGE_EXPORT` reads local aggregate JSON
  exports separately, without enabling or double-counting session history.
- `modelplan connections` discloses each source and host boundary. New sources are off by default;
  `modelplan disconnect <provider>` or `MODELPLAN_NATIVE=off` stops native quota reads.
  Local Gemini/Qwen history preserves unknown counters, deduplicates records and reports bounded
  coverage; desktop schema v1 adds fields without changing existing quota/speed meanings.
- Validation uses synthetic fixtures. Live accounts, endpoint acceptance and future tool schemas
  were not verified; no real account data or vendor quota endpoints were accessed during testing.
- Both plugins pin CLI v0.5.34 and its published archive checksums.

## CLI v0.5.33, Codex plugin 0.15.25 and Claude Code plugin 0.7.24 (2026-10-23)

- Personal snapshot v1 adds local-day `perfStats[].windows.today`, per-source `todayTotals[]`,
  recent `liveSessions[]` with a 60-second generation rate, and two-day `hourly[]` buckets.
- Input, cache-read and cache-write tokens are nullable in performance/daily/hourly sums. Codex
  inclusive input is normalized without double-counting its usage notice; old unknown data stays null.
- Separate local subagent logs can appear as independent live sessions. SQLite agents keep their
  no-first-token limitation; no new account call, upload or content collection is added.
- History-off stops new recording; read-only projection preserves it. The snapshot docs describe
  timing boundaries, DST, sample gates and bounded retention. Desktop parser types accept the additions.
- Complete the existing macOS CLI dependency notices for go-isatty and go-strftime (no dependency change).

- Both plugins pin CLI v0.5.33.

## CLI v0.5.32, Codex plugin 0.15.24 and Claude Code plugin 0.7.23 (2026-10-22)

- The CLI, the publication reader and the Codex plugin now skip manifest component kinds they do not know, instead of rejecting the whole publication. This lets the producer add page-sized slices (modelplans.ai #544) without breaking installed clients.
  - Unknown kinds still need a well-formed name and reference (hash, size, schema version), and are never downloaded.
  - The seven base kinds and `client` remain required. A manifest may list at most 32 kinds.
- The desktop snapshot (schema v1, additive) gains `dailyLong[]` and `dailyLongCoverage`: observed output tokens and requests per local day, source and model over the last 371 days (53 weeks), for a year-long heatmap.
  - They come from a new local ledger, `observed/daily-long.json`. It keeps the days `perf.json` lets go after 35 days, counts nothing `perf.json` did not, from the same `since`, and stays below 1 MiB.
  - It holds only days, model names and the two sums: no prompts, paths, projects, sessions or ids. `MODELPLAN_HISTORY=off` stops it.
  - `docs/personal-snapshot.md` describes both fields.
- Project labels are on by default: the desktop snapshot's project ranking names projects by their folder.
  - A stored choice is kept, so a user who turned labels off stays off.
  - `modelplan project-labels off` still deletes the stored names.
  - The names stay on this machine and are never synced or uploaded.
- Both plugins pin CLI v0.5.32.

## CLI v0.5.31, Codex plugin 0.15.23 and Claude Code plugin 0.7.22 (2026-10-22)

- ZCode and OpenCode (V2) sessions are read from their own local databases (`~/.zcode/cli/db/db.sqlite`, `opencode.db`). They are opened read-only and never changed.
  - Tokens per day, sessions, projects and both rankings in the desktop snapshot include them.
  - Their request times include the wait for the first token, so they give no generation rate.
  - Their efforts stay unreported.
  - The formats follow tokei and Tokscale.
- `modelplan connect kiro` reads Kiro credits natively through `kiro-cli`'s own ACP usage call. No prompt or session is sent, and Kiro keeps its sign-in. The route follows Pulse.
- The CLI now includes a pure-Go SQLite library, about 4 MB larger. Release archives ship `THIRD-PARTY-NOTICES.md`.
- Both plugins pin CLI v0.5.31.

## CLI v0.5.30, Codex plugin 0.15.22 and Claude Code plugin 0.7.21 (2026-10-22)

- Other plans can be read natively, without CodexBar.
  - `modelplan connect zai` reads Z.ai / GLM Coding Plan with the API key in `Z_AI_API_KEY`. Add `--region bigmodel-cn` for open.bigmodel.cn.
  - `modelplan connect opencodego` reads OpenCode Go with `OPENCODE_API_KEY`.
  - Each key is sent only to its vendor's usage endpoint and never stored.
  - The readers are ported from CodexBar (MIT).
  - Copilot, Cursor and Kiro stay on CodexBar.
- `~/.config/modelplan/connections.json` (optional) chooses `native`, `codexbar-compat` or off per provider.
  - Existing `codexbar.json` settings keep working.
  - Nothing falls back silently from one backend to the other.
  - `modelplan connections` shows the effective choice. `MODELPLAN_NATIVE=off` stops native readers.
- Subscriptions are told apart automatically, as random local references. Sources:
  - Codex's own `account/read`;
  - the account and organization ids in Claude Code's `.claude.json` (no e-mail, names or tokens);
  - CodexBar's account id;
  - a native reader's key.
  - Accounts, sessions and both rankings in the desktop snapshot carry the reference. `subscriptions[]` lists them for a scope selector.
  - The identity itself is never stored. `MODELPLAN_IDENTITY=off` turns this off.
- Both plugins pin CLI v0.5.30.

## CLI v0.5.29, Codex plugin 0.15.21 and Claude Code plugin 0.7.20 (2026-10-22)

- When a Codex plan window is used up and the account has usage credits, the hint says further use draws on them and gives the balance, for example `Codex 每周额度已用完，5天5时后重置：继续用会扣点数，剩 73,172`. A reading older than 15 minutes shows its age. Reset cards are still named.
  - `modelplan quota`, the Codex dashboard and the desktop snapshot show the balance (`accounts[].credits`).
  - It is read from the same Codex logs and account reading as the windows. The task-start brief still gives the agent no quota or credit figures.
- The desktop snapshot ranks projects (`projectRanking`) by observed output tokens over 7 and 30 days.
  - Projects are opaque references: a keyed hash of the repository, so worktrees of one repository are one project.
  - Folder names are stored only after `modelplan project-labels on`. Turning them off deletes them.
  - Ranked configurations now carry their share and the published ★ effort.
- CodexBar CLI v0.77.0 is pinned.
- Both plugins pin CLI v0.5.29.

## CLI v0.5.28, Codex plugin 0.15.20 and Claude Code plugin 0.7.19 (2026-10-21)

- The task-start brief no longer gives the agent quota figures: no remaining share, reset time or headroom verdict. You see those in the quota hints. Figures given once per thread went stale and the agent repeated them.
- While quota is tight or used up, the brief offers no step up, so the agent cannot contradict a "step down" hint.
- When you ask about quota or a hint, the agent is told to run `modelplan quota` or `modelplan advise` for current figures.
- Both plugins pin CLI v0.5.28.

## CLI v0.5.27, Codex plugin 0.15.19 and Claude Code plugin 0.7.18 (2026-10-21)

- `modelplan desktop --json --read-only` builds the personal snapshot without writing a file, starting a background process, asking Codex for an account reading or using the network. The default form and `--offline` are unchanged.
- The snapshot (schema v1, additive) gains these fields. `docs/personal-snapshot.md` describes all of them.
  - `dataRevision`: a hash of the observed inputs only.
  - `validUntil`: the next instant at which the clock alone changes a verdict.
  - `sessions[].effortStatus`: `reported` or `unreported`. The `effort` fallback to ★ stays for older clients.
  - `sessions[].workloadRate` and `tokenRate`: the recent 7-day generation rate per engine and per configuration, as ratios of sums.
  - `sessions[].activity`: `recent`, `quiet` or `unknown`, from the harness's own timestamps.
  - `perfStats[]`, `daily[]` and `dailyCoverage`: per-configuration figures and observed tokens per day over the recent 7 and 30 days.
  - `sessionRanking`: the top five sessions by observed output tokens.
  - `paceHistory`: quota percentage pace per window cycle, with gaps and drops.
  - `connections[]`: whether each agent and quota source is installed, has readable history, is authorized and has quota read. Only paths are checked; nothing is run and no credential is read.
- Two new local ledgers sit beside the existing ones. Neither changes `speed.json`, `cycles.json`, `measured[]` or `modelplan history`.
  - `observed/perf.json`: 35 days, counted from when it is created. It holds per-configuration sums and histograms, plus sessions under random references.
  - `observed/pace.json`: every counted quota reading with its gaps and drops.
  - Neither stores prompts, replies, titles, paths or ids. `MODELPLAN_HISTORY=off` stops both.
- Both plugins pin CLI v0.5.27.

## CLI v0.5.26, Codex plugin 0.15.18 and Claude Code plugin 0.7.17 (2026-10-20)

- The client digest size limit rises from 150 kB to 250 kB in the CLI (`maxObjectBytes`) and the publication reader (`CLIENT_RAW_LIMIT`), and the Codex plugin bundle is rebuilt with it. The digest reached 86% of the old limit as the multiplier packs and per-effort data grew. Integrity checks (exact byte length and SHA-256 against the manifest) are unchanged. The producer only raises its own budget after clients that accept the larger digest are released.
- Both plugins pin CLI v0.5.26.

## Public core / Codex 0.15.17 / Desktop community 0.1.1

- The already-public publication verifier has a canonical `reader/` module with hash metadata; clients display published recommendations. Scoring/recommendation source and full calibration remain private; method explanations stay public.
- The desktop builds independently with a neutral community appearance. A private official package is an explicit optional build input; historical MIT grants remain documented.
- Source/agent/CI policies separate public software, per-file data licenses, official visuals and brand identity. New original-data publications use CC BY-SA 4.0; historical and third-party exceptions remain separate.

## Desktop app preview (unreleased)

- **`desktop/`: a Tauri menu bar app**, macOS first. The menu bar shows what is left in the windows of the harness you used last and the current hint (`12% · wk70% ↓★Med ×0.73`). A popover has Now (sessions against ★, Fast, advice), Quota (windows, resets, run-out, Reserve, CodexBar) and Effort (the open curves and ladder, with your measured speed). Notifications are sent once per advice: tight or exhausted, switch back, a better model on by default; surplus before a reset off. Personal data comes from the bundled CLI (`modelplan desktop --json`), public data from the hash-checked publication; nothing personal leaves the machine. CI builds an ad-hoc signed Apple Silicon `.dmg` to try; not notarized yet. See `desktop/README.md`.
- The CLI's golden snapshot (`cli/internal/snapshot/testdata/snapshot.json`) is the contract the app is tested against.

## Codex plugin 0.15.16 and Claude Code plugin 0.7.16 (2026-10-18)

- The Skill explains the ★ effort as the best value among a model's own efforts (ability, cost and task time), not the top effort or the vendor's default: agents no longer call it an error, and point to the top effort of the same ladder when the user wants maximum quality regardless of cost.
- The Skill says ability is a frozen scale (50 = the September 2026 frontier average), so negative or above-100 values are valid data, not a bug.
- Still pinned to CLI v0.5.25.

## Codex plugin 0.15.15 and Claude Code plugin 0.7.15 (2026-10-18)

- Pinned CLI v0.5.25: a tight hint that already offers a model switch is not repeated as a separate better-model hint.

## v0.5.25 (2026-10-18)

- **`modelplan desktop`** prints the personal snapshot for the coming desktop app: sessions against ★, quota accounts, advice events with their text and a short menu-bar form, measured speed. One call; the format is in `docs/personal-snapshot.md` and is the one a mobile client will later receive through end-to-end encrypted sync.
- A tight window that already offers switching to a model is not followed by a separate better-model hint for the same switch.

## Codex plugin 0.15.14 and Claude Code plugin 0.7.14 (2026-10-18)

- Pinned CLI v0.5.24: a better model is named once when the one in use is beaten (Fable 5.1 → Opus 5.5, GPT-6 Astra → GPT-6.1 Sol), and tight hints offer it before stepping down. Claude Code's status line shows it for a week.

## v0.5.24 (2026-10-18)

- **Switch models, not just efforts.** When the publication marks the model in use as beaten (`dominatedBy`) and the model that beats it runs in the same harness, the CLI names it: its cheapest effort within the lineup's tie (1 point) of the current configuration at no more than 0.7× its cost. Today that is Fable 5.1 → Opus 5.5 (★Med: +2.5 points, ×0.52) and GPT-6 Astra → GPT-6.1 Sol (★Med: about the same, ×0.18). New event `better_model_available`, with `suggest.kind` (`stronger` | `equivalent`) and `current`. The prompt hook tells you once per model and effort and not again for 90 days (if you stay on it, you chose it); the Claude Code status line shows `→Opus 5.5 ★Med ×0.52` for a week.
- **Tight windows name the model first.** A tight window's alternative (`cheaper_model`) now uses the same tie, so Astra Med finds Sol Med (−0.2 points, ×0.18) rather than Sol High, and the hint puts it before stepping down, since it keeps the ability; the status line shows `→Sol …` instead of `↓Low`.

## Codex plugin 0.15.13 and Claude Code plugin 0.7.13 (2026-10-18)

- Pinned CLI v0.5.23: your measured speed per model, effort and Fast, on this machine only.
- Codex: the effort text lists the model's measured configurations, and the dashboard shows the chosen effort's measured turn time, tokens and tok/s against ★ (a Fast row's rate against Standard).
- Claude Code: `/modelplan:effort` explains the measured section under the ladder.

## v0.5.23 (2026-10-18)

- **Your measured speed.** Per model, effort and speed mode, over the last 28 days on this machine: output tokens per second of generation, the median time to the first token, and the median turn time and output tokens per turn. `modelplan effort <model>` shows the model's rows under its ladder, each effort against ★ in standard mode beside the published time multiple, and Fast against the same effort in Standard beside the published speed-up; `modelplan history` shows every model. `--json` adds `measured[]`.
- Read from the current Claude Code session's transcript (the status line and hooks name it) and the recent Codex rollouts: timestamps, output token counts, model, effort and speed mode only; never prompts, replies or tool output, and no paths or ids are stored (`observed/speed.json`, per day). A figure needs 5 samples. `MODELPLAN_HISTORY=off` stops it with the quota history.

## Codex plugin 0.15.12 and Claude Code plugin 0.7.12 (2026-10-17)

- Pinned CLI v0.5.22: GPT Reserve kept apart from the main Codex allowance; Codex Fast read as about ×1.5.
- Codex: the text summary and the dashboard show a `Reserve` row and name the allowance in the verdict; Fast reads "about ×1.5 faster", Ultrafast lists its plans, and the dashboard estimates task time from the speed-up, as the website does.

## v0.5.22 (2026-10-17)

- **GPT Reserve is its own allowance.** Codex meters GPT Reserve from a weekly allowance of its own (limit `base_model_inference`, `gpt-reserve`). It now shows as `weekly Reserve`, and the account's new `pool` says which allowance the latest thread drew from: headroom, hints and switch-back look only at that one, so a used-up Reserve no longer makes the main allowance tight (or the other way round). The Codex account reading keeps the two apart too; it used to fold windows of different limits into one.
- **Codex Fast about ×1.5.** The published speed-up now reads `about ×1.5 faster · generation time about ×0.67`; `up to` stays for ceilings such as Ultrafast's ×8.
- The Skill's Python reader does the same.

## Codex plugin 0.15.11 and Claude Code plugin 0.7.11 (2026-10-17)

- Pinned CLI v0.5.21: the new Claude Code status line.

## v0.5.21 (2026-10-17)

- **Status line bars.** Each window shows what is left as a bar: green from 30%, amber from 10% or when the pace is tight, red below 10%. The reset countdown, the run-out time and the hint follow.
- **Off ★ at a glance:** an effort above the recommendation is amber and one below it blue, with ★ in brackets. The cost and lineup tags show only when there is no quota to draw.
- **Narrow terminals** (`COLUMNS` under 100) get a short form: `▲ Opus 5.5 ★Med │ ▓▓▓▓░░ 65%↻40分 周70% ↑High ×1.37`.

## Codex plugin 0.15.10 and Claude Code plugin 0.7.10 (2026-10-17)

- Pinned CLI v0.5.20: the plugins' status line and hooks start the local quota history.

## v0.5.20 (2026-10-17)

- **Local quota history.** For each Claude Code and Codex window cycle, the CLI records on this machine how much was used and how many points each model, effort and Fast setting spent (`observed/cycles.json`, never uploaded). It records when the status line, a plugin hook or `advise` runs, and keeps five-hour cycles for 28 days and weekly ones for 12 weeks. `MODELPLAN_HISTORY=off` stops recording; deleting the file clears it.
- **`modelplan history`** (`--json`) shows it: weekly cycles one per line with where their points went, five-hour cycles as a summary. A later release will use it to suggest a default effort from your own finished weeks.

## Codex plugin 0.15.9 and Claude Code plugin 0.7.9 (2026-10-17)

- Pinned CLI v0.5.19: tight hints say when the window runs out at the recent rate.
- Codex: the text summary and the dashboard's quota rows show the run-out time.

## v0.5.19 (2026-10-17)

- **Recent rate of use.** Windows carry `recentPercentPerHour` and `runsOutInMinutes`, measured over the last 10–45 minutes of readings (Claude Code: the status-line snapshot now keeps the last hour of readings; Codex: every turn in its logs). The Skill's Python reader follows the same rules, tested against the same cases.
- **A burst counts as tight.** A window that runs out within three hours at the recent rate, before its reset, is tight whatever the average pace says. The hint names the time ("runs out in 2h20m, before the reset in 3h20m"), and a run-out within half an hour gets the hint shown once more.
- **Status line:** `≈2时20分用完` / `out ~2h20m` next to the window. `modelplan quota` adds it to the window line.

## Codex plugin 0.15.8 and Claude Code plugin 0.7.8 (2026-10-17)

- Pinned CLI v0.5.18: after a reset, the hint points back to the model and effort you used before it (and Codex Fast off).

## v0.5.18 (2026-10-17)

- **Switch back to what you used before.** When it first advises on a window, the CLI records the model, effort and Codex Fast in use. After that window resets it suggests going back to that configuration rather than always to ★, and says nothing if you never changed it. A used-up window still says the allowance is back.
- **The reset hint waits for your next prompt,** up to 24 hours (was 90 minutes), so coming back after a break or the next morning still gets it once. The status line shows `↺…` for 90 minutes from when it first appears.
- **Codex Fast:** after the reset, a Fast you turned on since the hint gets "turn Fast off". A tight window with Fast on says to turn it off before stepping down. A surplus no longer offers Fast when it is already on.

## Codex plugin 0.15.7 and Claude Code plugin 0.7.7 (2026-10-17)

- Pinned CLI v0.5.17: quota hints are shown to you, not the agent, and the task-start brief comes once per session.
- Claude Code: the status-line reminder shows twice at most, a week apart, and is never relayed by Claude; the reply-parsing "not now" is gone (`/modelplan:setup` still records it).
- Codex: the fetch-failure notice no longer goes to the model.

## v0.5.17 (2026-10-17)

- **Hints are for you, not the agent.** `advise --hook` shows quota hints, the plugins' setup notices and the "which plan pays for GLM" question as the hook's `systemMessage`; none of them enters the model's context, so replies no longer open or end with quota or setup talk.
- **The task-start brief comes once per thread,** about 1.2k characters (from 1.6-1.8k): options a better one beats are left out unless the thread is on one, the disclaimer is one clause, and the model is told not to bring up quota. A model the thread was not briefed on adds one line with its ladder; quota and effort changes no longer resend the brief.

## Codex plugin 0.15.6 and Claude Code plugin 0.7.6 (2026-10-16)

- Pinned CLI v0.5.16: the status line follows the declared plan for GLM through Z.ai.

## v0.5.16 (2026-10-16)

- **The status line follows the declared plan for GLM through Z.ai.** It shows that plan's windows (CodexBar's Z.ai reading) and its hint: `◷45m` when off-peak starts before the reset, `!` when tight on a per-request plan (never `↓`, which saves nothing there).
- README: other plans through CodexBar (macOS and Linux) and `modelplan declare`.

## Codex plugin 0.15.5 and Claude Code plugin 0.7.5 (2026-10-16)

- Pinned CLI v0.5.15: advice follows the plan that pays for GLM through Z.ai in Claude Code, and the hook asks once which plan that is.

## v0.5.15 (2026-10-16)

- **Advice follows the plan that pays (client-v1.3 `planMetering`, #37).** Claude Code on GLM through Z.ai runs on the user's Zhipu plan, not on Claude's. With the plan declared in `local.json` (`planId`, and `generation` where the plan meters more than one way), the session is advised by that plan's rules and its windows (the plan's own, or CodexBar's Z.ai reading):
  - per-request plans (Zhipu legacy V2) never get "step down", since every effort costs one request; a tight window says when off-peak starts instead, and a surplus says a higher effort costs no extra quota;
  - credit plans compare models by credits per API dollar at the current time-of-day rate; plans with a pool per model or unpublished rates get no cross-model cost;
  - the task-start brief lists GLM's lineup instead of Claude's and names the plan and how it counts.
  Nothing is guessed: without a declared plan, with two plans that meter the model, or with a generation missing where it matters, advice stays as before. Time rules are matched by the plan's `timeRules`, so a declared plan's peak and off-peak hints now also work for Zhipu Pro/Lite/Max on legacy V2.
- **`modelplan declare <planId> [generation]`** records the plan in `local.json` (keeping the rest of the file), checked against the publication: a plan metered two ways needs the generation. When a Claude Code session runs GLM through Z.ai with no declared plan, the hook asks the model once per model to ask the user which plan they have (only Z.ai's global plans for `api.z.ai`) and to run `declare` with the answer.
- The status line records Claude Code's `ANTHROPIC_BASE_URL` (scheme, host and path only), so GLM through Z.ai is recognised; it also shows GLM instead of an unknown model.
- Model ids with Claude Code's 1M-context suffix (`glm-5.3[1m]`, `claude-opus-4-6[1m]`) were dropped from the status-line snapshot; they are kept now.

## Codex plugin 0.15.4 and Claude Code plugin 0.7.4 (2026-10-16)

- Pinned CLI v0.5.14 and the plugin changes listed under it: setup offers CodexBar, the Codex dashboard shows those plans.

## v0.5.14 (2026-10-16)

- **The pinned CodexBar release is fetched even when one is already installed.** 0.5.13 used any `codexbar` it found and fetched only when there was none. On the owner's Mac that meant CodexBar 0.60.3, 16 releases older than the pin, whose provider code (Cursor's changes almost daily) and output were never tested. A copy the user installed is now used only until the pinned one is in place; a failed fetch is retried after 30 minutes. `MODELPLAN_CODEXBAR=<path>` still chooses a copy explicitly. `modelplan codexbar` says which copy runs.
- **Window titles that only restate the window are dropped.** CodexBar calls Z.ai's windows "5 hours" and "Weekly", which printed as "5h 5 hours". Titles that name something else ("Third Party", "MCP") stay.
- **Plugins: setup offers CodexBar, and the Codex dashboard shows those plans.** `/modelplan:setup` (Claude Code) and the Codex setup skill now list the enabled providers with what each still needs, and, when none is enabled, ask once which of these plans the user has; enabling runs only after the user agrees, with what CodexBar reads said first. The Codex dashboard and its text summary list the plans read through CodexBar under Codex's own quota (v0.5.13 said they did, but the plugin kept only the Codex account), and a provider that was not read appears as a setup line with its next step.
- **Claude Code prompts refresh CodexBar too.** In 0.5.13 only `quota`, `advise` and Codex prompts started the background CodexBar refresh, so a Claude Code user's reading went stale. Found by testing the plugin in Claude Code.

## Codex plugin 0.15.3 and Claude Code plugin 0.7.3 (2026-10-16)

- Pinned CLI v0.5.13: `~/.cache/modelplan-cli/modelplan codexbar enable cursor zai` reads other plans through CodexBar (opt-in). The setup command and the dashboard do not offer it yet.

## v0.5.13 (2026-10-16)

- **Other plans through CodexBar (opt-in): `modelplan codexbar enable cursor zai`.** Copilot, Cursor, Kiro, OpenCode Go and Z.ai / GLM keep their meters behind the vendor's own sign-in, so this client reads them through the CLI of [CodexBar](https://github.com/steipete/CodexBar) (MIT). Credentials stay with CodexBar: its config, another CLI's login, the Cursor app or browser cookies, and never a Keychain prompt in the background. This client handles none of them.
  - The first run fetches CodexBar's pinned release (`internal/quota/codexbar-pin.json`, about 14 MB on macOS and 53 MB on Linux), checked against the pinned SHA-256.
  - It runs in the background at most every 10 minutes, one provider per call, and caches only windows, reset times and the plan name.
  - `modelplan codexbar` shows what each provider returned and, when nothing was read, what CodexBar needs.
  - `quota` and the dashboards show these plans; they give no hints inside Claude Code or Codex.
  - OpenCode Go's local estimate uses fixed denominators and is not shown as quota.
  - A weekly workflow proposes newer CodexBar releases after a live check that their JSON still parses.

## Open data (2026-10-16)

- **`data/` mirrors Model Plan's reviewed data.** Plan tiers, prices, quota metering, plan model access, calendars, model identities and lineages, speed claims and effort policies, copied exactly from [modelplan.ai/open-data.json](https://modelplan.ai/open-data.json) with SHA-256 checks. The hourly `data-sync` workflow turns each change into a pull request that lists the records added, removed and changed. Data is [CC BY 4.0](data/LICENSE); `real-api-pricing/` keeps its MIT license.

## Codex plugin 0.15.2 and Claude Code plugin 0.7.2 (2026-10-16)

- Pinned CLI v0.5.12; the Codex panel changes listed under v0.5.12.

## v0.5.12 (2026-10-16)

- **Switching back to a model no longer resends the brief.** 0.5.11 compared against the last brief only, so Sol → Astra → Sol sent the Sol brief again, contrary to its own changelog (found by a Codex review). A thread now remembers every model it was briefed on, with the last effort known for each: a model it was briefed on is no reason by itself, a new effort on it still is.
- Codex plugin (next pin): in a narrow right-hand panel the curve and lineup folds stay closed (they opened in any "fullscreen" view, and the sidebar board opens fullscreen in the right panel); thread and sidebar panels ask the host for 460 px where it leaves the width to the app; the comparison says whether it shows the current (or latest local) session's model, and that model's chip is marked; the footer names the plugin version and when the panel read its data; a panel still served by an older plugin version than the one installed says so (restart Codex or open a new task).

## Codex plugin 0.15.1 and Claude Code plugin 0.7.1 (2026-10-16)

- Pinned CLI v0.5.11 (advice per model and effort, brief on substantial changes). Updating the plugin brings it; the previous copy is used while it downloads.

## v0.5.11 (2026-10-16)

- **Configuration advice per model and effort.** A tight window, a surplus before a reset or an announced reset is about the configuration in use, so the hook now remembers it per model and effort instead of per account window: a thread on another model (Astra after Sol) hears its own advice, while threads on the same configuration do not repeat it; a tight window that gets critical (10% or less left) is said once more. Account news (used up, switch back, peak hours, cards, public resets) is still said once. Only threads you send a message in hear anything. From a Codex review.
- **The task-start brief follows substantial changes:** besides a thread's first prompt and another model, another known effort (an effort first read on a later prompt does not count) and quota turning tight, used up or into a surplus. A thread switching back to a model it was briefed on keeps that brief.
- Plugins (next pin): the previous fetched CLI bridges a plugin update while the new one downloads; the Codex dashboard and text output explain every way hints can fail (unreadable hints, a CLI without `advise`, a failing run) instead of only the last.

## Codex plugin 0.15.0 and Claude Code plugin 0.7.0 (2026-10-16)

- **The plugins bring their own CLI.** Each plugin pins one `modelplan` release in `cli-pin.json` (version, release URL and the SHA-256 of each macOS and Linux archive) and fetches it with `hooks/fetch-cli.sh` (shared, identical) into `~/.cache/modelplan-cli/<version>`, using it only if the archive's checksum equals the pinned one; `~/.cache/modelplan-cli/modelplan` links the newest, a stable path for the status line. Installing or updating a plugin is all there is to do: the separate "install the CLI / upgrade the CLI / not now" flow is gone. Nothing else changes (no PATH, profile or sudo); a CLI the user installed is left alone and used only while the plugin's copy is missing. `MODELPLAN_PLUGIN_CLI=off` turns fetching off; Windows has no automatic fetch. Pinned now: v0.5.10.
- **Who fetches.** Codex: the plugin's MCP server, in the background when it starts; its hook still downloads nothing. Claude Code (no separate hook review): the hook, in the background. A failed fetch is retried after 10 minutes; Codex's dashboard has **Retry**, Claude Code's `/modelplan:setup` gives the command. Commands (`/modelplan:plan` and others) fetch on demand.
- **What you see.** The CLI's first arrival is announced once; a failed fetch says why (download, checksum mismatch, unsupported system), at most weekly; nothing is asked. The dashboard, text output, doctor and `/modelplan:setup` show the plugin's copy, a user's copy, "downloading", "failed (why)" or "off". Claude Code keeps one question, the status line, with a short "no" recorded by the hook.
- Release flow: tag the CLI, then `node scripts/pin-cli.mjs vX.Y.Z`; CI checks the pins against the published release (`--check`).

## Codex plugin 0.14.2 and Claude Code plugin 0.6.2 (2026-10-16)

- The Skill stays usable without the CLI and now says what only the CLI adds (`advise` hints with memory and the cheaper-model option, Codex's account reading, Claude Code's quota, a verified local publication), so those stay "unknown" instead of improvised. When the user asks about their own quota or resets without the CLI, it mentions the install command once; never for model or effort questions, and it never installs anything itself.

## v0.5.10 (2026-10-16)

- Plugins: Codex 0.14.1, Claude Code 0.6.1 (the Skill copies below; CLI 0.5.9 is still enough).
- **Skill's Python reader matches the CLI again.** `scripts/quota.py` (used when the CLI is not installed, also by the Codex dashboard) still had the old pace rule, so 72% of a week used with six days left was `on_track` there and `tight` in the CLI. It now applies the same early-tight rule and reads Claude Code's `sessionKey` against `CLAUDE_CODE_SESSION_ID` (`current-thread` / `recent-thread`). Both readers now run one shared table, `cli/internal/quota/testdata/pace-cases.json`, so the rules cannot drift apart unnoticed.
- Skill docs: `alternative` (`cheaper_model`) in `advise`, Claude Code attribution, the early-tight rule, the CLI found in `~/.local/bin`, a status line configured with the CLI's full path and `statusline --preview`, and that a cheaper cross-model reference cost is never a promised quota saving.
- CLI help and README: the hook's task-start brief, `quota`, `advise`, `statusline --preview`, `MODELPLAN_TASK_BRIEF`, `MODELPLAN_CODEX_ACCOUNT`, and the install command.

## v0.5.9 (2026-10-16)

- Plugins: Codex 0.14.0, Claude Code 0.6.0 (both need CLI 0.5.9).
- **Earlier warning.** A window already half used and on pace to run out is `tight` however early it is; before, the projection counted only after a fifth of the window, so 72% of a week used with six days to go showed as on track (from a Codex review). Lighter early use still waits for the fifth.
- **A cheaper model, not only a lower effort.** When a window is tight, the hint also names the cheapest configuration of another published model, usable in this harness, that scores at least as high as the current one (`alternative`, action `cheaper_model`), with its multipliers, and leaves the choice to the user ("unless this task needs the current model"). Today: GPT-6 Astra Med → GPT-6.1 Sol High, +2.4 pts at ×0.25 the reference cost.
- **The brief follows the model.** A thread that moves to another model (or whose model becomes known) gets the brief again for it; otherwise still once per thread. Without a readable model the brief tells the model to go by the model its own instructions name.
- **Cost wording.** Hints and the brief say that × is the published API cost of a reference task: within one model it roughly tracks plan usage, across models it is only a guide, never a promised quota saving. The brief names the publication date.

## Codex plugin 0.14.0 and Claude Code plugin 0.6.0 (2026-10-16)

- **The hook's outcome, not just its start.** The hook still never blocks a prompt, but it now records how each run ended: `ok`, `failed: exit N: <first error line>`, or why the CLI was not asked; and the last success. The dashboard, text output, doctor and `/modelplan:setup` show "hints computed (nothing to flag)", "hints failed (why, last success)" and "not verified yet" apart. These records are labelled as this machine's, from any chat.
- **Codex: hook definition, not plugin version.** The heartbeat records a checksum of `hooks.json`; "review due" shows only when the definition changed, not on every plugin update. Trust is reported as unknown (plugins cannot see it; `doctor.cjs` reads it from Codex in a project). Setup text names the desktop entry: the hook icon with a yellow dot next to the input, source `modelplan-codex`; `/hooks` in the CLI.
- **One CLI finder.** `hooks/find-cli.sh` (shared by both plugins) and the dashboard's `findCli` use the same order and rules: executable files only, and the first copy at least the required version wins over an older one earlier on PATH (a non-executable `modelplan` on PATH made the dashboard and the hook disagree).
- **One minimum version**, in each plugin's `cli-min.txt`, read by the hook, the dashboard and checked against the docs by a test; no more "0.4+" next to "0.5.5".
- **Install failures by kind.** `install.sh` names download, checksum and permission failures; the dashboard says what to do for each, and for an older copy found first or an unsupported system. After a successful install it says the next step (send a message to verify the hook; allow it if Codex asks).
- Hints arrive with a prompt only; the docs say so instead of implying continuous monitoring.

## v0.5.8 (2026-10-16)

- Plugins: Claude Code 0.5.1, Codex 0.13.1.
- `advise --hook`: a first sync that does not finish within 3.5 seconds goes on in the background, so the next prompt has the data. Before, a slow first download failed and was not retried for 10 minutes (seen in a logged-in Claude Code run).

## Claude Code plugin 0.5.1 and Codex plugin 0.13.1 (2026-10-16)

- **"Not now" without a command.** After the one-time setup question, the hook reads the user's next message itself: a short "no" (不用, 暂不, 算了, no, not now, skip, …) is recorded and Claude or Codex is told to acknowledge it and run nothing. Before, the model had to run `touch` in `~/.cache`, which needs approval outside the project (Claude Code blocked it even with an allow rule), so a "no" came with a permission prompt or was not recorded. Any other message consumes the question without recording anything. Claude Code's `/modelplan:setup` records "not now" with `hooks/decline.sh`.

## v0.5.7 (2026-10-16)

- `advise --hook`: with no publication on the machine yet (the CLI was just installed), the hook waits up to 3 seconds for a first sync, so the first prompt already gets the task-start brief; before, it only started a background sync and the brief came with the next prompt. A failed attempt is not retried for 10 minutes, so an offline machine is not slowed down. A stale publication is still refreshed in the background.

## v0.5.6 (2026-10-16)

- Plugins: Claude Code 0.5.0.
- **Task-start brief for Claude Code.** `advise --hook claude-code` now also hands the model the brief on the first prompt of each session (Anthropic models at ★, the default configuration, the current model's ladder, the quota headroom), as for Codex. The current model and effort come from the status line's reading only when it was this session's: the snapshot keeps a one-way `sessionKey` (a hash, never the id), and `quota` marks the Claude Code harness `current-thread` or `recent-thread` from the hook's `session_id` or `CLAUDE_CODE_SESSION_ID`. Without it the brief says "model unknown".
- The hook refreshes the published data in the background when it is older than 6 hours (before, only the status line did), and takes a plugin's setup notice (`--add-system`, `--add-context`) so one JSON object comes out.
- `statusline --preview` renders a sample without recording it; the plugin's preview used to write its sample windows into the real snapshot.

## Claude Code plugin 0.5.0 (2026-10-16)

- **One hook,** `UserPromptSubmit` → `hooks/modelplan-quota-hints.sh`; `SessionStart` is gone (the CLI refreshes data itself). It finds the CLI off PATH (`~/.local/bin`, Homebrew), records a heartbeat with the plugin version, and shows a setup notice when the CLI is missing or older than 0.5.6, or the status line has never recorded: the first notice asks Claude to offer the fix once (a "no" is recorded), later ones at most weekly without asking, none for 90 days after "not now". A current CLI with a recording status line gets hints and the brief only. Verified in Claude Code 2.1.301 (plugin hooks run without a separate review there).
- **`/modelplan:setup`** reports plugin, CLI (missing, outdated, failed, ok, and whether it is on PATH), status line (recording, set but no reading, not set), hook (last run, plugin version) and hints, each on its own line, then installs the CLI with consent, syncs and re-checks.
- `/modelplan:plan`, `/modelplan:effort`, `/modelplan:lineup` and `/modelplan:statusline` reach the CLI through the plugin, so they work when it is not on PATH; the status line is configured with the CLI's full path.
- Tests for the hooks and commands run in CI on Ubuntu and macOS.

## v0.5.5 (2026-10-16)

- Plugins: Codex 0.13.0.
- The task-start brief no longer needs a quota reading: without one (a first thread, an API-key login) it still lists the options and the default, with quota "unknown". It takes the thread's model from the hook input; when the thread's effort is not in its log, it says so and shows the ladder against ★ instead of assuming ★.

## Codex plugin 0.13.0 (2026-10-16)

- **One hook, named by its command.** `SessionStart` is gone; `UserPromptSubmit` runs `hooks/modelplan-quota-hints.sh` (status message "ModelPlan: quota hints and task-start brief"). Codex 0.157's review shows plugin hooks as "Hook 1"; `statusMessage` does not change that, so the script name, the README and the `setup` skill explain it.
- **Setup notice on the prompt, not the session start,** so it also works after an upgrade inside an open chat and after the hook is trusted mid-session (both verified in the Codex TUI). Missing or outdated CLI: the first notice asks the model to offer it once (on a no it records `cli-declined`); later notices at most weekly, without asking; none for 90 days after "not now". Asking about setup is never limited. With a current CLI only hints and the brief.
- **Setup on the dashboard, part by part:** CLI missing (Install / Not now), outdated (Upgrade), failing (with the error); hook never ran, or an update's hook has not run (Codex skips a changed hook until trusted again; the hook records its plugin version); one "setup complete" line otherwise. The text output says the same. Install and upgrade succeed only when the CLI the plugin will use reports at least 0.5.5; an older copy found first is named.
- `setup` skill rewritten: report each part from the check, never from a command having run; offer, install, re-check; record "not now"; explain hook trust and re-trust after updates. `doctor.cjs` shows when the hook last ran. App-only tool `dismiss_cli_setup` for "not now".

## v0.5.4 (2026-10-16)

- Task-start brief names a **default for ordinary tasks**: the published best value at ★, unless it scores more than 3 points below the strongest, then the strongest at ★ (today GPT-6.1 Sol ★Med, both). It lists the default model's ladder when the thread is on another model, and tells the model to suggest a step down for small tasks, High/XHigh of the default for complex ones and the default again afterwards.

## v0.5.3 (2026-10-16)

- Plugins: Codex 0.12.0.
- **Task-start brief for Codex.** On the first prompt of a Codex thread, `advise --hook codex` also hands the model a short brief: the Codex models at ★ with ability, cost relative to the cheapest and lineup verdicts (dominated ones marked skip), the current model's effort ladder against the current effort, the quota headroom and, with a surplus, Fast when it draws plan quota. The model judges the task and suggests one configuration only when the current one clearly does not fit; the brief says it never changes settings. Once per thread (by the hook's `session_id`); `MODELPLAN_TASK_BRIEF=off` disables it.

## v0.5.2 (2026-10-16)

- Plugins: Codex 0.12.0.
- **Codex account reading.** `modelplan quota`, `advise` and the Codex hook ask Codex itself for the account's windows and reset credits: `codex app-server` → `account/rateLimits/read`, in the background at most every 5 minutes (30 after a failure such as no login), with Codex's own login; `quota --refresh-account` asks now. The answer is cached in `observed/codex-account.json` without account or credit ids and merged with the session-log windows, newest observation per window, so a 5-hour window missing from recent logs is filled in. Available credits become `cards` of kind `full` with their expiry, which feed `cards_expiring` and `use_card`. The reading is marked `via: "codex-account"`. Nothing is redeemed. `MODELPLAN_CODEX_ACCOUNT=off` disables it.

## Codex plugin 0.12.0 (2026-10-16)

- The dashboard and the text output show full-reset credits (count, first expiry, redeem in Codex yourself) and name a Codex account reading as the source.

## v0.5.1 (2026-10-16)

- Plugins: Codex 0.11.0.
- `modelplan advise`: **spend ahead of an announced Codex reset.** When OpenAI has announced a reset with a time in the next 24 hours and the longer Codex window still has 20% or more that would otherwise last past it, `announced_reset_with_surplus` suggests the next effort, a stronger model or Fast, worded as applying only if the reset covers the account. The switch-back hint after it waits for a reading taken after the announced time that shows the window restarted, and is kept for up to six hours for that proof. An announcement whose time has passed is no longer shown as news.

## Codex plugin 0.11.0 (2026-10-16)

- **The hooks now load.** The manifest moved to Codex's native `.codex-plugin/plugin.json`. The old root `plugin.json` carried the Agent Plugins `$schema`, and Codex then skipped the plugin's hooks, so the `UserPromptSubmit` hint hook never ran. `codex app-server` `hooks/list` now shows both hooks; `doctor.cjs` reports whether they are loaded and trusted.
- **Getting the CLI:** an **Install CLI** button on the dashboard (macOS, Linux; app-only tool `install_modelplan_cli`, the click is the consent) runs the bundled copy of `install.sh`: latest release, checksum-checked, into `~/.local/bin`, nothing else changed. A `setup` onboarding skill checks for the CLI after install and offers it. A `SessionStart` hook shows a short notice with the install command when the CLI is missing, at most once a week.
- The server, hooks and doctor find the CLI in `~/.local/bin`, `$MODELPLAN_BIN` and Homebrew's directories as well as PATH, since Codex starts them with a short PATH.

## Codex plugin 0.10.0 (2026-10-16)

- **Panel beside the chat:** a separate `Effort & quota` thread entry (tool `open_model_panel`) opens the dashboard in the conversation's side panel; the sidebar board is its own `Model Plan` global entry. OpenAI's extension spec allows one entrypoint per tool; 0.9 declared both on `open_model_dashboard`. Each surface has its own UI resource, so the model's call still shows the inline card and a tool call never claims to open the side panel. The inline card says how to open the panel instead.
- **Width no longer follows the display mode:** hosts show every entrypoint `fullscreen`, which widened 0.9 to 640 px inside the side panel. The content is at most 420 px everywhere (borders and padding included). The inline card reports its own width to the host (`ui/notifications/size-changed`, within `containerDimensions.maxWidth`) and leaves the chat column around it unpainted. Expand appears only on the inline card.
- **Diagnosable size:** *Data & basis* shows what the host reported (surface, display mode, container dimensions) and the laid-out viewport and panel widths. `doctor.cjs` reports whether the side panel entry is registered.

## Codex plugin 0.9.0 (2026-10-16)

- **Compact inline dashboard:** opens inline (was fullscreen) at a 360–420 px target with content height and no inner scroll areas. The first screen shows the thread's model, effort and speed tier, its step against ★ and the quota. Model chips select the comparison. Curves, the full lineup and reset notices are folded; Expand opens them.
- **Speed tiers are consistent and honest:** the readout, mini curve and detail curve share one comparison state. Under Fast or Ultrafast, cost becomes an estimated plan-quota multiple vs ★ standard and task time is unknown, never shown as ×1.00 or divided by the generation speed-up. Generation speed is shown as an "up to" ceiling or as not stated, with credit multiples, eligibility, the official source and its review date.

## v0.5.0 (2026-10-16)

- Plugins: Codex 0.8.1.
- **Codex quota and the current thread are separate.** Account windows are merged across recent Codex threads, newest reading per limit id and window, each with its own `observedAt` and age; a window absent from the newest log is no longer dropped. Model and effort come from one thread: the calling one when `CODEX_THREAD_ID` (or a hook's `session_id`) names it, marked `attribution: "current-thread"`, else the newest interactive thread, marked `recent-thread`. Background threads (`subagent:*`, `internal:*`, `codex-auto-review`) never supply them. The harness also reports `observedAt`, `origin`, `serviceTier`, and the effort from `collaboration_mode` when the turn context has no top-level one. Go and Python read one shared multi-thread fixture.
- Codex plugin: the MCP server is never told which thread called it, so its reading is labelled "latest local thread, may not be this conversation" with its age; readings from older CLIs that carry `codex-auto-review` are dropped. Windows older than an hour show their age; five-hour or weekly windows not seen are listed as such.

## Codex plugin 0.8.0 (2026-10-16)

- **Runtime discovery:** Codex now starts `launch.cjs`, which runs the server on the first Node.js 22+ that passes a feature check: a pin in `~/.config/modelplan/runtime.json`, the Node Codex used, Codex desktop's own runtime when present, other PATH entries, standard locations and version managers. Re-checked at every start; PATH and global Node are never changed. With no usable runtime both tools still register and return the diagnosis. The minimum is Node.js 22 (was 24); CI runs 22 and 24.
- **Setup check:** `node doctor.cjs` starts the installed plugin through Codex's app-server without a turn and reports Codex support, install state, the runtime Codex actually used, MCP tools, the dashboard resource, public data, quota reader and hints, ending with separate *installed* / *tools callable* / *panel shown (unverified)* verdicts.
- **Install:** `--sparse .agents --sparse codex` checks out about 2 MB instead of the whole repository; README covers each step, retries, update and uninstall, and required versus optional components.
- Quota and hint results name their reader and why hints are off (`cli_missing`, `cli_without_advise`); the text output and dashboard show it.
- Fixed `tests/mcp-smoke.mjs`, which compared the effort text without the speed-tier lines.

## v0.4.1 (2026-10-15)

- `modelplan advise`: one switch-back hint per window, even when it was advised more than once (#10).

## v0.4.0 (2026-10-15)

- **Proactive advisor:** `modelplan advise [--json] [--source] [--hook claude-code|codex]` with events for a window about to reset with allowance left, tight or used-up windows, switching back to ★ after a reset, peak and off-peak starting soon, reset cards expiring and public Codex resets. Each hint is given once (#9).
- **Hooks:** UserPromptSubmit hooks for Claude Code and Codex pass new hints to the agent once.
- **Status line hints:** `↑High ×1.37`, `↓★Med ×0.73`, `↺★Med`.
- **Speed tiers:** ⚡ Fast and ⚡⚡ Ultrafast lines in `modelplan effort`; the Codex dashboard gets a Standard / Fast / Ultrafast switch; the Skill reads them. The CLI accepts any `client-v1.x` projection.
- Skill: Claude Code fast mode bills usage credits, not plan quota (#8).
- Plugins: Claude Code 0.4.0, Codex 0.7.0.

## v0.3.0 (2026-10-15)

- Quota-aware Skill, status line and Codex dashboard: Claude Code and Codex 5-hour and weekly windows read locally (#7).
- Codex effort dashboard and install instructions (#1); clients point at modelplan.ai (#2); methodology and sources published (#3); data-problem issue form (#4).
- CLI accepts the ten-component compact publication (#6).

## v0.2.1 and v0.2.0 (2026-10-12)

- First releases of the `modelplan` CLI: `lineup`, `effort`, `models`, `statusline`, `sync`, `doctor`.
