# R7: macOS distribution scaffold

This is release plumbing, not a distribution candidate or a B26 pass. It changes no CLI interface, schema, contract fixture, app appearance, permission, login item or updater runtime. Do not install credentials merely to exercise this scaffold.

## Automatic build

`.github/workflows/macos-distribution.yml` builds the public neutral Swift app for arm64 and x86_64 with a macOS 14 floor. It downloads only the two public CLI archives selected by `desktop/native/consent-cli-pin.json`, checks their pinned SHA256 values, and uses the existing community packager. The app/helper are ad-hoc signed with Hardened Runtime and no App Sandbox entitlement. The uploaded ZIP is labelled **unsigned** in the distribution sense: it is neither Developer ID signed nor notarized, and is never an update candidate. Intel is compiled, untested, and may stutter in 3D. This scaffold does not claim native UI acceptance.

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

## Ad-hoc beta channel

Before an Apple Developer account is available, dispatch this workflow on canonical `main` with `prepare_adhoc_beta=true` and a trusted `candidate_run_id`. The **macos-release** environment must require owner review for every run and restrict branches to main. The beta job verifies the same successful, exact-main official assembly run and validates the same official edition, source provenance, bundle ID, universal executables, helper hash and notices as the Developer ID path. No Apple certificate, team ID or notarization key is required; the existing signed/notarized stages retain their requirements.

On the owner's Mac, use the reviewed Sparkle distribution's `bin/generate_keys` to make a key pair. Export the private key with `bin/generate_keys -x <private-key-file>` and store its contents as the **macos-release** environment secret `SPARKLE_ED25519_PRIVATE_KEY`; keep the key safe on the owner's Mac. Give M0 the public key for the app's `SUPublicEDKey`. The workflow sends the private key to `sign_update` over stdin and verifies the result against that embedded public key. [Sparkle key setup](https://sparkle-project.org/documentation/#eddsa-ed25519-signatures).

Set these nonsecret environment variables:

- `MACOS_BUNDLE_ID` and `MACOS_OFFICIAL_WORKFLOW_ID`: the approved bundle identity and trusted assembly workflow, as above.
- `SPARKLE_TOOLS_URL` / `SPARKLE_TOOLS_SHA256`: the reviewed immutable tools archive and its checksum, as above.
- `MACOS_BETA_FEED_URL`: a dedicated credential-free HTTPS beta feed file; the candidate's `SUFeedURL` must match exactly.
- `MACOS_UPDATE_URL`: the final, versioned HTTPS download URL for `ModelPlan-beta-universal.zip`.
- `MACOS_RELEASE_NOTES_URL`: the HTTPS release notes URL included in the beta appcast.
- `MACOS_FEED_URL`: reserve the future notarized feed at a different file when known. It is optional for beta preparation; when both feeds are configured, preparation rejects the same host/port/path, including case/default-port, escaped-path, dot-segment and query-string aliases. Redirects and hosting aliases remain the owner's responsibility; never map the two feed URLs to one file.

The job deep ad-hoc signs the app, refreshes the helper integrity record, reseals it and runs `codesign --verify --deep --strict` before making a symlink-preserving `ditto` ZIP. Its artifact `modelplan-macos-adhoc-beta-DRAFT-NOT-PUBLISHED` contains `ModelPlan-beta-universal.zip`, `appcast-beta.xml`, `SHA256SUMS` (ZIP and appcast hashes), and `draft-release.json` (`draft: true`, `prerelease: true`). The beta XML includes `sparkle:channel` = `beta`, minimum macOS 14.0 (`14.0.0` in Sparkle's three-part XML format), release notes and the archive's EdDSA signature. No GitHub Release is created. The coordinator separately reviews and publishes the payload and beta feed only after explicit owner approval, keeping the final archive bytes and URL unchanged.

M0 owns the app integration: embed Sparkle, set `SUPublicEDKey` to the owner's base64 public key and beta `SUFeedURL` to `MACOS_BETA_FEED_URL`, and allow `beta` through `SPUUpdaterDelegate.allowedChannels(for:)`. Without that delegate setting Sparkle ignores beta items even in a dedicated feed. This PR edits no app sources. [Sparkle channels](https://sparkle-project.org/documentation/publishing/#channels).

Known limits: first open requires a Gatekeeper override for the non-notarized app; Accessibility and Screen Recording (TCC) grants may need re-granting after an update because the ad-hoc signature changes. Once the Apple account exists, enable the existing Developer ID/notarization configuration. With the same bundle identity and Sparkle key and a higher build number, the notarized build can arrive as a normal Sparkle update: the coordinator must publish a notarized transition item to the existing, separate beta feed, and M0's notarized app uses the official `SUFeedURL` afterward. This transition is not automatic feed publication or a claim of tested update behavior; the existing B26 live-update and clean-Mac checks still apply.

## Local checks

```
python3 -m unittest discover -s desktop/native/tools/distribution -p 'test_*.py' -v
node scripts/check-source-policy.mjs
```

These tests use synthetic strings and generated ZIPs, not credentials. They prove missing-secret ordering (including all beta-setting combinations), trusted-trigger denial, archive traversal/link rejection, community/official separation, distinct feed files, beta signing order/helper hash refresh and appcast XML bounds/escaping. They do not prove Developer ID, Apple notarization, a live Sparkle update, minimum-OS launch or visual acceptance. Do not run sign/notarize/appcast locally to seek credentials; these commands require an explicitly configured release context.

References: [Sparkle publishing](https://sparkle-project.org/documentation/publishing/) (archive preservation, signed enclosure and version fields), [Sparkle security](https://sparkle-project.org/documentation/security-and-reliability/) (stdin key handling), [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

The native consent archive pin is independent of plugin CLI pins. It must match both the runtime consent identity and its metadata producer; plugin updates do not implicitly upgrade the App helper. The focused `test_consent_input.py` follows the real workflow input and checks that three-part contract without executing a helper, package or signing command. Bumping the native pin requires a reviewed identity update in the same change.

## Prebuilt credential-helper input

`package-neutral.sh` requires `MODELPLAN_CREDENTIAL_AGENT_ARTIFACT` and
`MODELPLAN_CREDENTIAL_AGENT_SHA256` for every mode, including synthetic smoke.
The directory is the independently approved universal artifact from the U7
builder: `modelplan-credential-agent`, `credential-agent.json`, and `proof.json`.
The external SHA must be approved independently, not derived from an untrusted
artifact directory as an automatic approval. Different compiler/SDK inputs need
their own reviewed artifact; no cross-environment digest equivalence is assumed.

Missing/linked inputs or a binary digest mismatch fail before App compilation.
The canonical U7 embed tool then enforces its pin, universal architecture and
existing signature checks before the outer App seal; the canonical final checker
validates the embedded pin after sealing. Packaging never calls the credential
helper builder, executes the helper, or re-signs it. Existing CLI signing is
separate. `--single` proves one final App's pin, not two-App, Keychain or A14 proof.
The helper remains R2 default-deny.

The canonical U7 tools are supplied by prerequisite public #376; App wiring stays
in #369. Packaging callers must provide
their reviewed artifact inputs before enabling this hook; there is no silent
fallback. The shell fixture tests use inert build/signing/verifier boundaries and
prove orchestration and failure propagation only.

U10 modifies and re-seals its outer App after the neutral scaffold; it therefore
runs the same `--single` checker again after its final seal/archive identity
checks, before writing delivery checksums. It consumes the same approved inputs.

## Coordinator-approved producer-run binding

The reviewed triple lives at `desktop/native/credential-agent-artifact-pin.json`
with exactly three string fields: `runID`, `artifactName`, and `sha256`. The last
field is the credential-helper **binary** SHA-256, not GitHub's ZIP digest. This
file is added or updated only after the coordinator approves that exact triple;
no placeholder approval or build-derived automatic approval is supplied.

`fetch_credential_artifact.py` resolves only that run in `modelplan/modelplan`,
requires a successful completed main push/manual run from the same repository,
selects the unique unexpired named artifact in that run, safely reads its ZIP,
and checks the binary and descriptor against the independently approved digest.
It exports the artifact directory/digest only after verification. There is no
latest-run fallback or helper builder call. Missing approvals, wrong run/name,
expired or ambiguous artifacts, unsafe members and digest mismatches fail closed.
The canonical U7 embed/final tools still own universal/signature/full-pin checks.

macos-distribution and desktop app-smoke use the CLI's `--github-env` output.
U10 and the e2e builder call the same downloader before CLI/App compilation,
passing the verified binding explicitly to `package-neutral.sh`; e2e does not
create a second helper. Their artifact-consuming jobs add only `actions: read`
to `contents: read`. The ephemeral download token is not exported in the binding
or passed by the Python callers to packaging children. No signing secret or
release permission is added. The producer workflow remains M3-owned.

The producer artifact also carries `SHA256SUMS` and `LICENSE.txt`; the downloader
retains both alongside the binary, pin and proof. These audit checksums do not
replace the coordinator-approved independent binary digest.
