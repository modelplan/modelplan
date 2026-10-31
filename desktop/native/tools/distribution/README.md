# macOS beta distribution

The public `.github/workflows/macos-distribution.yml` prepares Sparkle updates without an Apple Developer account. It validates an approved official assembly, ad-hoc signs the app, signs its update ZIP with the owner's EdDSA key, generates a separate beta appcast and release notes, and creates a **draft prerelease**. PR builds use standard hosted runners without secrets. Developer ID and notarization remain disabled placeholders.

## Owner setup, once

Configure the protected **macos-release** GitHub environment with required reviewers and main-only deployment branches. The owner creates the Sparkle key pair later, outside CI, with the reviewed Sparkle distribution's `generate_keys`. Store the exported private key only as the encrypted environment secret **`SPARKLE_ED25519_PRIVATE_KEY`** (the existing repository name). Give the app packager the matching public key for `SUPublicEDKey`. Never put a private key in the checkout, an Actions variable, a command argument, an artifact, or a release. The workflow never creates keys or searches a local Keychain; it passes the secret to `sign_update` through stdin. [Sparkle key setup](https://sparkle-project.org/documentation/#eddsa-ed25519-signatures), [stdin signing](https://sparkle-project.org/documentation/security-and-reliability/).

Set these nonsecret environment variables:

| Variable | Purpose |
| --- | --- |
| `MACOS_BUNDLE_ID` | Approved stable official bundle identity; no Apple account is required |
| `MACOS_OFFICIAL_WORKFLOW_ID` | Numeric ID of the trusted official assembly workflow |
| `SPARKLE_TOOLS_URL`, `SPARKLE_TOOLS_SHA256` | Reviewed immutable Sparkle release tar.xz and checksum; no latest download |
| `MACOS_BETA_FEED_URL` | Dedicated credential-free HTTPS beta appcast file, matching the app's `SUFeedURL` |
| `MACOS_FEED_URL` | Future stable feed, when known; must be a separate file |
| `MACOS_UPDATE_URL` | `https://github.com/modelplan/modelplan/releases/download/macos-beta-BUILD/ModelPlan-beta-universal.zip` |
| `MACOS_RELEASE_NOTES_URL` | `https://github.com/modelplan/modelplan/releases/download/macos-beta-BUILD/release-notes.html` |

Replace `BUILD` with the candidate's numeric `CFBundleVersion` before dispatch. Publication checks that both URLs match the resulting release assets. Feed separation rejects same-host/port/path aliases, including query-only differences, escaped paths and dot segments. Hosting redirects and aliases must also keep beta and stable files separate.

Missing or whitespace-only signing secrets or settings **fail the explicitly requested beta job**, with a diagnostic listing setting names only. There is no unsigned fallback. The automatic neutral build still needs no secrets or private checkout.

## Assembly handoff

Dispatch on canonical `main` with `prepare_adhoc_beta=true` and `candidate_run_id` identifying a successful push/manual official assembly on the **exact current main SHA**, in this repository, from `MACOS_OFFICIAL_WORKFLOW_ID`. PR, fork, tag, other-branch and other-commit inputs are rejected. The assembly must upload `modelplan-macos-official-candidate` containing `ModelPlan.app.zip`. The automatic community build cannot supply the official handoff.

The candidate must have the approved bundle ID, numeric build version, macOS 14 minimum, universal app/helper executables, exact source provenance, official edition marker, helper integrity record, and MIT/CLI third-party/official visual notices. ZIP traversal and escaping symlinks are rejected. `SUFeedURL` must match the beta feed and `SUPublicEDKey` must contain the owner's public key.

App integration remains the packager's responsibility: embed the reviewed Sparkle runtime and permit `beta` through `SPUUpdaterDelegate.allowedChannels(for:)`. Otherwise Sparkle ignores beta items even in a dedicated feed. This pipeline does not add runtime updater code. Verify the actual Sparkle assembly's component entitlements/runtime flags after signing and exercise a real update before releasing a candidate; synthetic tests cannot establish that packaging behavior. [Sparkle channels](https://sparkle-project.org/documentation/publishing/#channels), [component signing](https://sparkle-project.org/documentation/sandboxing/#code-signing).

## Feed generation and publication

The job downloads the **beta** feed history over HTTPS and retains its existing items and signatures. Malformed, unavailable, unsigned, duplicate-version or non-beta history fails closed. For the very first beta only, set `bootstrap_beta_feed=true`: this permits a confirmed HTTP 404 to initialize the feed. It does not permit authentication errors, timeouts or server errors to erase history. Subsequent releases must read the current hosted beta feed; retain the last published appcast there before the next dispatch.

New build numbers must exceed every retained version. One-, two- and three-component numeric versions compare numerically with zero padding (`10` = `10.0.0`, and `10` > `9`). The appcast lists items newest first and rejects stable items. The current archive signature is verified by Sparkle and independently with CryptoKit against the public key embedded in the candidate. [Sparkle publishing and version fields](https://sparkle-project.org/documentation/publishing/).

After ad-hoc signing, helper-hash refresh, app resealing and strict signature verification, the job creates a symlink-preserving ZIP with `ditto`. It uploads:

- `ModelPlan-beta-universal.zip` and `appcast-beta.xml` with beta channel, EdDSA signature, archive length, build/display versions and macOS 14.0.0 minimum.
- `RELEASE_NOTES.md` and escaped `release-notes.html`, identifying the build/source and explaining first-open and permission limits.
- `SHA256SUMS` covering those four files, plus `draft-release.json` with `draft: true` and `prerelease: true`.

A separate protected job with repository write permission, **without signing secrets**, checks the payload and creates `macos-beta-BUILD` using `gh release create --draft --prerelease --latest=false`. It first requires a confirmed HTTP 404 for that tag; an existing tag or inconclusive lookup fails before release creation. It never edits an existing release, changes the stable feed, or promotes anything to a normal/latest release. Reusing a tag fails rather than replacing previously reviewed assets. A failed publication can leave a partial draft; inspect/remove that draft explicitly before retrying.

Draft assets are not anonymously downloadable and do not activate auto-updates. After reviewing the exact bytes, the coordinator can publish the draft **as a prerelease only** and place its `appcast-beta.xml` at `MACOS_BETA_FEED_URL`, preserving the ZIP/notes URLs and bytes. This workflow prepares that reviewable release; it never replaces a live hosted feed. Test N→N+1, invalid-signature and interruption behavior on the actual app before beta rollout.

## Limits users see

This beta is ad-hoc signed and **not notarized**. Gatekeeper can block first open. After trying to open the app, a user who trusts the release may need System Settings → Privacy & Security → **Open Anyway**, then confirmation of the first-open prompt. [Apple's first-open guidance](https://support.apple.com/en-us/102445).

Accessibility and Screen Recording (TCC) grants may need re-granting after updates because the ad-hoc signature changes. Generated release notes repeat both limits. Intel is compiled but execution is untested; 3D may stutter. Local tests and CI do not establish clean-Mac Gatekeeper/TCC behavior, real updates, minimum-OS launch, or visual acceptance.

## Later: Developer ID and notarization

The existing `release-candidate` job requires both `prepare_signed_candidate=true` and the explicit repository variable **`MACOS_DEVELOPER_ID_ENABLED=true`**. With the variable unset it stays off, even if Apple credentials appear. It does not publish releases. Enable it only when the owner is ready to configure the Apple account and validate that path.

Its environment secrets remain `MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY_P8_BASE64`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`, and the Sparkle secret above. Additional variables are `MACOS_SIGNING_IDENTITY` (exact Developer ID Application identity) and `MACOS_TEAM_ID`, plus the existing bundle/feed/tool settings. Missing dependencies skip optional signed stages; malformed material, identity mismatch and notarization rejection fail. Temporary keychains/credential files are removed and raw credential-tool diagnostics are never uploaded.

The preserved path signs inside-out, refreshes helper identity, verifies team/bundle, waits for notarization acceptance, staples, assesses Gatekeeper, then archives/signs the update. Later migration needs the same bundle identity and Sparkle key with a higher build number: publish a notarized transition item to the existing beta feed, then point the notarized app at the separate stable feed. That transition requires real update validation.

## Local checks

```sh
python3 -m unittest discover -s desktop/native/tools/distribution -p 'test_*.py' -v
node scripts/check-source-policy.mjs
```

Tests generate and discard a throwaway Ed25519 key inside the test (CryptoKit on macOS; OpenSSL on Linux). They verify serialized enclosure signatures, numeric ordering, beta isolation, history bootstrap refusal, missing-key failure, draft-only publication guards, candidate validation and signing/hash order. No owner key, account, credential discovery or real release is used. The native consent pin remains independent of plugin pins; `test_consent_input.py` checks workflow/runtime/producer agreement without executing the helper.
