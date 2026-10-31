<!-- SPDX-License-Identifier: MIT -->
# Install the unnotarized Mac beta

The beta requires macOS 14 or later. macOS 14 is not tested in CI and not guaranteed (2026-11-02). The first-launch steps below cover macOS 14 Sonoma and macOS 15 Sequoia. The app archive is universal; Apple silicon is tested, while Intel remains untested and 3D may stutter.

## Download

Download the Mac app ZIP and its matching `SHA256SUMS` from the beta announcement or [ModelPlan's releases](https://github.com/modelplan/modelplan/releases). A CLI archive or GitHub's source-code ZIP is not the Mac app. Check the downloaded ZIP's SHA-256 against the published value before extracting it. You can calculate it in Terminal with `shasum -a 256`, followed by a space and the ZIP dragged from Finder.

Extract the ZIP and drag the app into **Applications**. The community build is named **ModelPlan Community.app**; a beta release may use **ModelPlan.app**. Use the name of the app you downloaded in the steps below.

## What ad-hoc signing means

The beta has a code signature that seals its files, but it has no Apple-issued Developer ID certificate and has not been notarized by Apple. The signature does not establish a developer identity trusted by Gatekeeper. macOS may block the downloaded app until you approve that app's first launch.

This approval applies to the app, rather than turning off Gatekeeper. A later ad-hoc build may need approval again, including permissions you previously granted. See [Apple's explanation of opening downloaded apps](https://support.apple.com/en-us/102445).

## Allow the first launch

Use **System Settings > Privacy & Security** on both macOS 14 and 15:

1. In Finder, open **Applications** and double-click the ModelPlan app once. This creates the blocked-app entry in System Settings.
2. Dismiss the warning with **Cancel** or **Done**, according to the dialog shown. Keep the app in Applications.
3. Choose **Apple menu > System Settings**. Select **Privacy & Security** in the sidebar.
4. Scroll down to **Security**. Find the message naming the ModelPlan app, then click **Open Anyway** for that app.
5. Approve opening the app in the confirmation dialog: click **Open** or **Open Anyway**, as shown. If macOS asks you to authenticate, use Touch ID or your login password and confirm with **OK**.
6. If the app does not open immediately, double-click it again in Applications. Subsequent launches of the approved build can use the usual app icon.

The blocked-app button is available for about an hour after the attempted launch. If it is missing, try opening the app again, then return to Privacy & Security. A managed Mac may require help from its administrator.

Apple documents the exception in the [macOS 14 guide](https://support.apple.com/guide/mac-help/mh40616/14.0/mac/14.0) and the [macOS 15 guide](https://support.apple.com/guide/mac-help/mh40616/15.0/mac/15.0). On macOS 15, Control-clicking **Open** no longer overrides Gatekeeper; use the System Settings route above. [Apple's Sequoia change notice](https://developer.apple.com/news/?id=saqachfa) explains this change.

## Updates

For the current scaffold builds, update manually: quit the app, download and check the next beta ZIP, then replace the app in Applications. Keep the data folders below to retain your settings. The bundled CLI is replaced with the app.

The release scaffold introduced in [#142](https://github.com/modelplan/modelplan/pull/142) prepares updates for **Sparkle**. The scaffold produces the beta appcast file `appcast-beta.xml`. It lists the version, release notes and download, with an **EdDSA (Ed25519) signature on the update archive**. A Sparkle-enabled app will check that signature against the public key embedded in the app before accepting an update. This signature is separate from Apple's code signing and notarization. See [Sparkle's update-signing documentation](https://sparkle-project.org/documentation/publishing/).

The current source prepares these release files for review; it does not publish them or wire a Sparkle updater into the running app. Do not rely on automatic updates for these builds. Follow the beta announcement for the available download and whether a later build has enabled the update service.

## Where data lives

These are the current default paths on macOS. `~` means your home folder. In Finder, choose **Go > Go to Folder** (Shift-Command-G) and paste a path to open it. Files are created as their features are used, so some may be absent.

| Path | Contents |
| --- | --- |
| `~/Library/Application Support/ModelPlan/Native/settings-v1.json` | App settings, including appearance, window behavior and first-run choices. |
| `~/Library/Application Support/ModelPlan/Native/community-v1.json` | App preferences for language, favorite models and the model picker. |
| `~/Library/Caches/modelplan/` | Shared CLI publication cache, observed readings, local history and reader state. `observed/effort-suggestion.json` also holds the CLI's weekly suggestion preferences. If you configured `MODELPLAN_CACHE`, that directory replaces this cache path. |
| `~/.config/modelplan/consent.json` | Shared reader permissions and consent receipts. |
| `~/.config/modelplan/` | Other ModelPlan configuration, including `local.json` for declared plans, `connections.json` for reader selections and `codexbar.json` for bridge configuration, when present. |

The cache and configuration are shared with standalone CLI and plugin copies. Removing them resets those clients too. The app preference files are separate from the shared consent file.

## Uninstall completely

1. If you enabled opening at login, turn it off in the app first. Remove any remaining ModelPlan entry under **System Settings > General > Login Items** on macOS 14, or **Login Items & Extensions** on macOS 15.
2. Choose **Quit** from the ModelPlan menu bar menu. Stop other ModelPlan CLI/plugin sessions before removing shared data, so they cannot recreate it while you clean up.
3. Move the ModelPlan app from Applications to the Trash. Delete the downloaded ZIP and any extra extracted copies you kept.
4. For a complete data reset, use Finder's **Go to Folder** to move these ModelPlan folders to the Trash, if present: `~/Library/Application Support/ModelPlan/`, `~/Library/Caches/modelplan/` (or your configured `MODELPLAN_CACHE` directory), and `~/.config/modelplan/`. This removes both app preference files, consent, configuration and the cached data listed above.
5. If you granted ModelPlan Accessibility permission, remove its entry under **System Settings > Privacy & Security > Accessibility**. Remove any other ModelPlan-specific permission entry you granted.
6. Empty the Trash when you no longer need the deleted files.

Removing the app also removes its bundled CLI. Separately installed ModelPlan plugins or standalone CLI copies remain installed and can recreate shared data if run again; uninstall those through the tool or package manager you used if you are removing all ModelPlan clients. After uninstalling all ModelPlan plugins, you can also remove their downloaded CLI cache at `~/.cache/modelplan-cli/`; it is separate from the app's bundled CLI and the shared data cache. Keep other tools' folders and Keychain sign-in items, such as Claude Code's or Codex's: they belong to those tools, not to ModelPlan.

## Send beta feedback

Open the [Mac beta feedback form](https://github.com/modelplan/modelplan/issues/new?template=beta-feedback.yml) to report what happened and what you expected. In the app, choose **Settings > About > Copy diagnostics**, review the output, and paste it into the form. Some fields may be empty or `unknown`; you can still send feedback if diagnostics are unavailable.

Issues are public. Never paste tokens, account emails or raw provider responses, including in reproduction steps or diagnostics.
