<!-- SPDX-License-Identifier: MIT -->
# ModelPlan for Mac, v1 release notes (draft)

Draft for the v1 candidate. Requires macOS 15 or later on Apple silicon. Not yet announced or published.

ModelPlan shows how much of your AI coding plans you have left, when each limit resets, and which model and effort fit what is left. It reads usage on your Mac and shows it in the menu bar, a small widget and a cockpit.

## Menu bar and widget

- The menu bar item keeps a stable place and a steady percentage. Open it to see a total for the time range you chose.
- The Quota Widget starts collapsed. Hover or click a ring to open its card.
- Rings close fully when a plan is nearly used up. Dragging the widget moves it and does not open or close anything by accident.
- Find Quota Widget in the menu and the shortcut now bring the widget back if you lose it. Hiding it with the keyboard is gone.
- The card says how long ago the reading was taken ("Updated 3 min ago"). Each quota row ends with its reset time, or "out ~40m" when your pace runs out first.
- If a refresh fails, the widget keeps the last reading. It looks normal for the first hour, then dims, and shows "--" only once that window has reset.
- A card that cannot read a plan shows why, the one step to fix it, and a Read again button.
- The card also shows today's tokens and how many sessions are running and how fast.
- A run-out warning appears even when a plan's reset time is unknown, based on how fast you are using it.
- The widget stays open and in place when the cockpit opens next to it.

## Cockpit pages

- Open the cockpit from the menu bar. It follows the screen your menu bar is on, opens on full-screen Spaces, and comes to the front when detached.
- The header has ALERT, a porthole switch, and Today / 7d / 30d keys. One time range applies across the cockpit, the menu and the widget.
- Overview: up to four alert lines, one totals row (estimated cost, tokens and cost per day), and one bar per day.
- Plans: your subscriptions with reset pace, the account line, forecasts and what-if sliders.
- Models: models by usage, with a List and Chart key for ability against cost.
- Breakdown: projects or sessions, each with its share as a bar.
- ALERT blinks once for each new or worse warning, then stays lit until you look.
- Session strip: elapsed time, tokens and speed.
- If the cockpit page fails to draw, it keeps what you were looking at and recovers by itself.

## Plugins

- Calendar: the next 12 hours with the published peak hours of your plans in their colours, your own 5-hour and weekly resets, and one all-day line, all in local time. With no peak rules it shows next-reset cells. Its key opens a 7-day week view you can zoom to about 8 hours.
- Resources: a column showing your Mac's CPU, memory and disk. Only the numbers turn amber or red. Its key opens the last ten minutes. It samples with system calls only, never a helper process, and the history stays in memory and is never written to disk. Turned off, it does nothing.
- Plugins are added and removed in Settings, Subscriptions, Plugins.

## Settings

- Subscriptions has three sections, and every tool row says in plain words why it is not showing data and what to do.
- Resource sampling can be set to every 2, 5 or 10 seconds.
- Search in Settings clears when you jump to a pane.

## Readers and the command line

- ModelPlan reads your tools' own usage: Claude Code, Codex, Grok, Kiro, GLM and more. Plans that cannot be read yet say so instead of showing stale numbers.
- The `modelplan` command line tool keeps pace with the app and now reads the newer public data format, including cost estimates and the 0.4 ability scale. Unreadable optional fields are skipped, not treated as a failed read.
- Starting up and opening are faster. Unchanged session logs are not read again.

## Privacy

- Your usage stays on your Mac. ModelPlan reads local files and each tool's own sign-in, and asks first.
- Nothing is turned on until you consent. Browser sign-ins are never read unless you add them yourself, one tool at a time.
- Keychain consent from earlier builds is kept, and first launch asks once.
- The Resources history is never saved to disk.

## Known issues

- Cold start can take several seconds before data appears. We are working on it.
- "Remove plugin" from the cockpit key is not yet verified on hardware.
