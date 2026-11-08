# macOS v1 distribution checks

The v1 neutral build is an ad-hoc-signed Apple silicon application for macOS
15 or later. It does not include Sparkle, a Sparkle feed URL or automatic
updates. The independently approved credential helper remains byte-for-byte
universal and is the only permitted non-arm64 bundle executable. The app and
bundled CLI are arm64-only. The architecture check rejects an unknown or
modified helper, any other non-arm64 Mach-O, `Sparkle.framework` anywhere in
the bundle, and an `SUFeedURL` in the app Info.plist.

`macos-distribution.yml` performs the neutral build and uploads a CI artifact;
it neither prepares Sparkle nor publishes a release. Its public PR jobs use no
release secrets. The app's reviewed CLI and helper artifacts must be available
and independently pinned. Build receipts and generated checksums describe only
the CI build; ad-hoc signing is not Developer ID signing or notarization.

`check_cli_pin_consistency.py` guards the App/CLI pair. With `--force` it
requires the native pin (`desktop/native/consent-cli-pin.json`, or `--pin`) to be
a valid release at least `EngineRowsEntry.minimumAppServerVersion`, its
`v<version>` tag to exist, and the commit's `cli/` tree to equal that tag. With
`--app` it inspects a packaged App: `Contents/Helpers/modelplan` must match its
recorded hash in `Contents/Resources/modelplan.sha256` and Info.plist, any
declared `ModelPlanHelperVersion`/source hashes must equal the pin, and the
helper itself must report exactly `modelplan <pin version>`.
`--require-release-identity` also requires those declarations. A candidate job
runs `--force --app <App>` after packaging, so a candidate is refused both when
its helper is not the pinned release and when the pinned release is older than
the candidate's own `cli/` (a stale engine). The neutral build and the packaged
smoke build run `--app` alone; they are not candidates and make no source-tree
claim. PRs labelled `release-candidate`, on a `candidate/` or
`release-candidate/` branch, titled `Release candidate:`, or changing the native
pin also run the tree check in `repo-checks.yml`. Missing tags, differing
trees and unreadable helpers fail closed; nothing is tagged or published.

`release.py` retains older signing, notarization and appcast helper routines for
historical compatibility. The v1 workflow does not call them. Their presence is
not an update service or authorization to sign, notarize or publish. Real
release decisions, trusted-candidate verification, user consent and owner
approval remain separate gates.

For local synthetic checks run:

```sh
python3 -m unittest discover -s desktop/native/tools/distribution -p 'test_*.py' -v
node scripts/check-source-policy.mjs
```

The tests exercise fail-closed metadata, architecture, pin and orchestration
boundaries using synthetic fixtures. They do not prove a physical Mac run,
release signing, notarization or a user installation.
