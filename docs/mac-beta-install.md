# Install the ModelPlan Mac beta

[简体中文](mac-beta-install.zh-CN.md)

Requires **macOS 14 or later**. Apple silicon is tested; Intel is untested and 3D may stutter.

## Download and install

Download the Mac app ZIP and its published SHA-256 checksum from [GitHub Releases](https://github.com/modelplan/modelplan/releases). In Terminal, check the ZIP before opening it (replace the example filename):

```sh
shasum -a 256 "$HOME/Downloads/ModelPlan.app.zip"
```

Compare the full hash with the checksum for that exact asset. If they differ, download again. Unzip the archive and drag the app to **Applications**.

**TODO(M4):** Public beta ZIP/checksum publication and the final app name are pending. The current source packager produces `ModelPlan Community.app`; `ModelPlan.app` below is the planned beta name.

## First open

These builds are **ad-hoc signed and not notarized**: we do not have an Apple Developer account or Apple notarization yet. Gatekeeper blocks the first launch. The build and its checksum are published together so you can check the download.

- **macOS 14:** in Applications, right-click the app → **Open** → **Open**.
- **macOS 15 or later**, or if that fails: try opening once, then go to **System Settings → Privacy & Security → Open Anyway** and confirm **Open**. See [Apple's instructions](https://support.apple.com/en-us/102445).

After checking the download, the Terminal alternative removes quarantine from this app:

```sh
xattr -dr com.apple.quarantine "/Applications/ModelPlan.app"
```

Use the installed app's actual name if it differs, then open it again.

## First run

**TODO(M4):** The beta's detected-tool consent integration is pending. The planned single consent screen lists detected tools, with only **standard** readers pre-checked. **Browser-session readers (advanced)** stay off until you explicitly enable each one. Review the list before confirming. Nothing is uploaded to ModelPlan; enabled quota readers authenticate only to their own providers. See [what each reader reads](clients-and-readers.md).

## Updates

**TODO(M4):** Automatic Sparkle updates are pending app integration. Beta updates will be signed with ModelPlan's own EdDSA key. Each ad-hoc build has a new signature, so macOS may ask again for permissions you granted earlier. Notarized builds will arrive later as a normal update.

## Quit and uninstall

Choose **Quit** from the menu bar menu. If enabled, remove the app's login item in **System Settings → General → Login Items** before deleting the app. **TODO(M4):** App login-item registration is pending.

To remove local data, use Finder's **Go → Go to Folder** to delete these folders if present (`~` means your home folder):

- `~/Library/Caches/modelplan/` — shared CLI store; if you set `MODELPLAN_CACHE`, use that directory instead.
- `~/.config/modelplan/` — shared consent and configuration.
- `~/Library/Application Support/ModelPlan/Native/` — current app settings, including `settings-v1.json`.

The first two are shared with CLI/plugin copies: deleting them resets those clients too. **TODO(M4):** Confirm the shipping bundle ID and any bundle-specific Application Support/preferences cleanup. The current packager uses `org.modelplan.community.swift.scaffold`; the app stores settings in the folder above and has no bundle-ID preferences store yet.

## Report a problem

Open **Settings… → About → Copy diagnostics**, then paste it with reproduction steps into a [GitHub issue](https://github.com/modelplan/modelplan/issues/new/choose). Diagnostics contain only app/CLI versions, macOS version, enabled reader IDs and recent error codes, with no personal data. **TODO(M4):** The copy control exists; live version/reader/error data still need app wiring, so some fields may be empty or `unknown`.
