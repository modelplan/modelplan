Owner-approved B5 (D371, 2026-11-21): the Settings Subscriptions page (including its plugin section) and the Quota Widget page, rebuilt to the complete target in one pass from the owner's design page (12-point difference list; approved 11-13 "subscription order, second version" and opus-r7 "rings and numbers").

Stacked on #1134 (head `claude/badcase-1121-native`): that PR already removes the placeholder plugin from release Settings and starts every plugin unpinned, so this PR reuses both and adds no second copy. Until #1134 lands this diff shows only the B5 files (the base is #1134's head, not main). Not touched: the cockpit page and the Dock cards (B2 / B4c / B4e lane).

Requirements: D371 (B5), SET-9-13 (order: buttons, grip, keyboard), SET-9-16 (display switch), SET-9-29 (an unavailable setting is not listed), SET-9-51 (three subscription sections), CKP-PLG-54 (Settings > Plugins), D202 (fix is a status-line link), D87 / D89 (rows, drag), D124 (plugin columns), SET-9-41 (key entry stays on its row)
Journeys: Settings > Subscriptions with Codex, an unverified ZCode and Kiro (switch off a row, move with the arrows, the grip and Option-Up/Down, type an alias, fix link, Add a detected tool, open "Supported, not installed"); Settings > Subscriptions > Plugins (switch, sampling interval, Pin to cockpit page 1, move); Read access rows (Check permissions, diagnostics, Install a plugin, expand read paths); Settings > Quota Widget (dropdowns, percentage window per subscription, no "Hide from capture")
Invariant: every row of "My subscriptions" and of "Plugins" has the same cells on the same x lines (alias 132 | switch 40 | grip 22 | up 26 | down 26), so no fix button, alias or plugin option moves a control; an alias field is owned by the Settings window, never by a row, so a draft survives every redraw; a fix is only ever drawn when the app can perform it (no dead word); no unavailable setting is drawn; pinning is off until the user turns it on.
Scenarios: none (no spec scenario IDs; cases: verified, unverified and pending (Cursor / Grok Build) rows; hidden row keeps its switch and grip; Option-Up/Down at the first and last verified row; a plugin with no options (Calendar) and with a segmented interval (Resources); two plugins already pinned; 0 and 3 subscriptions on the page layout oracle)
Reference: none (Settings layout follows the owner-approved 11-13 subscription-order design and the opus-r7 settings study, not a reference app)
Ledger: D371 (B5) in handoffs/shared/g3-owner-ledger.md

## The 12 differences (subscription page) and the Quota Widget page

| # | Before | Now |
|---|---|---|
| 1 | checkbox | painted switch (`ConnectionSwitchButton` / `PlainSwitchButton`, still `NSButton`, role checkbox with subrole switch) |
| 2 | controls follow the name, x differs per row | one grid: mark 30, name flexible, alias 132, switch 40, grip 22, up 26, down 26 (`SettingsGrid`) |
| 3 | Cursor, Grok Build have no controls | pending rows get the same cells, disabled (there is no subscription to hide or order yet) |
| 4 | fix button between name and controls | blue word in the status line (D202); no fix when the app cannot perform it |
| 5 | no keyboard hint | hint under the list; Option-Up/Down on a selected row moves it (focus returns to the row after the redraw) |
| 6 | separate alias block | alias field in each row; unverified account: disabled field, placeholder "验证后可改", tooltip "验证账号后才能保存" |
| 7 | Add follows the text | Add on the right edge |
| 8 | no "Supported, not installed (N)" | disclosure kept under "Detected" (it shows when the engine reports absent tools) |
| 9 | plugin row: placeholder, checkboxes, stepper vs segmented | placeholder not listed (#1134); plugin row on the same grid; indented line: sampling interval (segmented) and "Pin to cockpit page 1" switch, default off; the grip reorders plugins |
| 10 | plugins under read paths | plugins directly after "My subscriptions" |
| 11 | read permission, tool plugins, read paths: buttons under the title | rows: name and note left, button right |
| 12 | no dividers | thin lines between rows and blocks |
| Widget 1 | popups 132 / 180 | 150 pt dropdowns in the 230 pt control column |
| Widget 2 | percentage window: lines in the control column | indented per-subscription lines under the title, dropdown on the control column's right edge |
| Widget 3 | "Hide from capture" shown as unavailable | not drawn (catalogue row kept for the SET-9-12 catalogue tests) |
| Widget 4 | picture in its own 96 pt column | under the text, left aligned, outside the control column |

## Tests (Swift: no toolchain on the Linux box; mac-compile and the macOS legs are the proof)
- New `SettingsB5GridTests` (through `SettingsScopeConsentView`, `SubscriptionRowsView`, `SettingsNativeRow`): same x lines for visible / grip / up / down in every row, switch type and width; pending row has the same controls disabled; alias field in the row and the unverified placeholder; fix link in the status line and the controls not moved; keyboard hint and Option-Down moves, not on the last or unverified row; plugins between the rows and the read access rows, on the same x lines, pin off by default; read access rows with the button on the right; "Supported, not installed (2)" and Add on the right edge; 150 pt dropdowns and indented lines on the Quota Widget page. All fail on the old layout.
- Adjusted (the old assertion described the layout D371 removes): `CockpitPluginPreferencesTests` (pin copy "固定到驾驶舱第 1 页", off by default); `G3FirstRunSubscriptionsLayoutTests.testG3_26` (the alias catalogue row is gone, the subscription rows must be shown); `G3SettingsRowMeasurementTests` (nested dropdown lines are measured in the row's indented list, not only in `controls`); `G1SettingsJourneys` SET-9-11 / SET-9-12 (the capture-hiding label is no longer listed, SET-9-29; the catalogue `SET912CaptureHidingDefaultTests` stay unchanged and green).
- `node scripts/changelog.mjs --check`: valid.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
