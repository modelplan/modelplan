# R7: macOS distribution scaffold

This is release plumbing, not a distribution candidate or a B26 pass. It changes no CLI interface, schema, contract fixture, app appearance, permission, login item or updater runtime. Do not install credentials merely to exercise this scaffold.

## Automatic build

`.github/workflows/macos-distribution.yml` builds the public neutral Swift app for arm64 and x86_64 with a macOS 14 floor. It downloads only the two public CLI archives selected by `codex/cli-pin.json`, checks their pinned SHA256 values, and uses the existing community packager. The app/helper are ad-hoc signed with Hardened Runtime and no App Sandbox entitlement. The uploaded ZIP is labelled **unsigned** in the distribution sense: it is neither Developer ID signed nor notarized, and is never an update candidate. Intel is compiled, untested, and may stutter in 3D. This scaffold does not claim native UI acceptance.

Public PR builds receive no secrets or protected environment. Outputs are short-lived Actions artifacts, not GitHub Releases. The existing CLI tag-release workflow is unchanged.

## Optional official candidate preparation

The second job runs only for a manual dispatch on `main` in the canonical repository, with `prepare_signed_candidate=true`. It references the **macos-release** protected GitHub environment. Before enabling this job for real credentials, the owner must configure required reviewers and restrict that environment to main. R7 does not create or modify that environment, any secret, an Apple account, team/bundle identity, or an update host.

The job first prints only stage decisions and missing **variable names**. Missing signing material skips signing and all dependent stages. Missing notarization material permits signing but skips notarization and appcast. Missing Sparkle material permits notarization but skips appcast. Malformed supplied material, a failed command, identity/hash mismatch or notarization rejection fails the job; it never becomes a successful unsigned update.

GitHub encrypted environment secret names (placeholders only; no values are stored here):

| Secret name | Purpose |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Developer ID Application certificate with private key, base64 P12 |
| `MACOS_CERTIFICATE_PASSWORD` | P12 import password |
| `APPLE_NOTARY_KEY_P8_BASE64` | App Store Connect notarization API key, base64 P8 |
| `APPLE_NOTARY_KEY_ID` | Notarization API key ID |
| `APPLE_NOTARY_ISSUER_ID` | Notarization API issuer ID |
| `SPARKLE_ED25519_PRIVATE_KEY` | Sparkle-exported base64 key, passed only through stdin |

Nonsecret, owner-reviewed environment variable names:

| Variable | Purpose |
| --- | --- |
| `MACOS_OFFICIAL_WORKFLOW_ID` | Numeric ID of the future trusted official assembly workflow |
| `MACOS_SIGNING_IDENTITY` | Exact Developer ID Application identity; no guessed identity |
| `MACOS_TEAM_ID`, `MACOS_BUNDLE_ID` | Owner's stable Apple team and official bundle ID |
| `MACOS_FEED_URL`, `MACOS_UPDATE_URL` | Credential-free HTTPS official-channel feed and versioned archive URL |
| `SPARKLE_TOOLS_URL`, `SPARKLE_TOOLS_SHA256` | Reviewed immutable Sparkle release tar.xz URL and SHA256 |

The CLI pin remains read-only. Sparkle version selection is deferred to B26; there is no `latest` download or automatically selected dependency here. A reviewed Sparkle tool must support `--ed-key-file -` and `-p`.

### Official assembly handoff (not implemented by R7)

`candidate_run_id` identifies a successful push/manual official assembly run on **the exact current main commit**, in this repository, from the approved workflow ID. PR/fork/tag runs and other commits are rejected. That workflow must upload an artifact named `modelplan-macos-official-candidate` containing `ModelPlan.app.zip`. The community build above deliberately does not supply it or masquerade as official.

The ZIP must contain `ModelPlan.app/` (internal framework symlinks allowed; no outside paths). The app must have:

- Approved bundle ID, numeric build version, macOS 14 minimum, universal app and CLI executable slices.
- `Contents/Resources/build-edition.json` with `edition: "official"` and `release-provenance.json` with `sourceCommit` matching the exact approved main SHA.
- The MIT, CLI third-party and official visual license notices. Official visual sources remain private; only an authorized assembled binary may enter this handoff.
- `Contents/Helpers/modelplan` and its current `Contents/Resources/modelplan.sha256` integrity record.
- The approved `SUFeedURL` and `SUPublicEDKey` in Info.plist. Actual Sparkle embedding, XPC entitlements, updater UI/preferences and channel/key-rotation behavior are B26 integration work; those are not supplied by this scaffold.

Signing imports the supplied certificate into a new temporary keychain without invoking default-keychain or replacing the keychain search list. It signs Mach-O leaves and nested containers inside-out with secure timestamps and Hardened Runtime, refreshes the bundled CLI hash **after helper signing**, signs the outer app, and verifies the team and bundle. This initial template has no sandbox/debug entitlement exceptions; any required per-component updater entitlements need explicit B26 review. Temporary credential files/keychain are removed in `finally`; GitHub also discards the hosted VM after termination. No key, keychain, raw credential-tool output or notarization diagnostic archive is uploaded.

Notarization uses `notarytool --wait`, requires Accepted, staples and validates the app ticket, assesses Gatekeeper, and only then creates a symlink-preserving update ZIP with `ditto`. Sparkle archive signing uses stdin; subprocess errors are withheld because upstream tools can echo malformed key input. The signature is verified both by Sparkle and independently with CryptoKit against the **public key embedded in that app** before creating `appcast.xml`.

The XML is a single-version **feed candidate**, includes build/display versions and minimum macOS, and requires a nonempty signed archive. It is not an in-place updater for an existing feed. R7 uploads only a candidate artifact and never pushes a feed, writes Pages, creates a release or deploys anything. Preserving old items, monotonically increasing versions, matching the final download URL/archive bytes, N→N+1/invalid-signature/interruption tests, clean-Mac offline Gatekeeper checks and owner release approval remain B26 gates.

## Local checks

```
python3 -m unittest discover -s desktop/native/tools/distribution -p 'test_*.py' -v
node scripts/check-source-policy.mjs
```

These tests use synthetic strings and generated ZIPs, not credentials. They prove missing-secret ordering, trusted-trigger denial, archive traversal/link rejection, community/official separation and appcast XML bounds/escaping. They do not prove Developer ID, Apple notarization, a live Sparkle update, minimum-OS launch or visual acceptance. Do not run sign/notarize/appcast locally to seek credentials; these commands require an explicitly configured release context.

References: [Sparkle publishing](https://sparkle-project.org/documentation/publishing/) (archive preservation, signed enclosure and version fields), [Sparkle security](https://sparkle-project.org/documentation/security-and-reliability/) (stdin key handling), [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
