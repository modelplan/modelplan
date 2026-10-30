# U10 candidate packaging — interface only

Tier 2: signing and consent identity. This pipeline extends the macOS release
scaffold with a run-only candidate artifact. It does not register a new native
runtime, prove U6/U8/U11 wiring, or earn L2/L3 acceptance.

The `U10 candidate interface` workflow runs portable contracts on draft PRs and
builds on standard hosted macOS when ready, on relevant main pushes, or on manual
dispatch. It checks out the PR head itself, so the manifest identifies the reviewed
source rather than an unreviewed merge build. Its only token permission is
`contents: read`. It uploads no artifact after a failed assembly or signature check.
No Developer ID, certificate, protected environment, notarisation, Sparkle,
release publication or secrets are part of this workflow.

## Product and resources

- `ModelPlan.app`; display name `ModelPlan Candidate`; fixed candidate bundle ID
  `ai.modelplan.candidate`. This is an interface-stage identity, not a commitment
  to the shipping identifier or a stable Keychain designated requirement.
- Version comes from `desktop/package.json`; build number is the workflow run
  number. Both app and bundled CLI contain arm64 and x86_64 slices. Intel execution
  remains `not-run`.
- The existing `package-neutral.sh` compiles the production native executable and
  fetches no replacement engine. Its reviewed native CLI archive input comes from
  `desktop/native/consent-cli-pin.json` (v0.5.48), independently of plugin pins.
- `Contents/Resources/OfficialVisuals` contains only the public official assets,
  including their runtime manifest and reserved visual licence. The public icon
  is also installed as the app icon. OFL fonts, each family licence, font manifest
  and notices remain separately under `ThirdParty/fonts`; other public desktop
  third-party notices and licences are included too.
- The future public `desktop/cockpit/dist` interface expects an `index.html` and
  locally built resources, with no symlinks. U11 owns its build and runtime bridge.
  Until U11 lands, `Resources/Cockpit/index.html` is a labelled placeholder and the
  receipt says `placeholder`. Private porthole art is absent/unsupported. Packaging
  these resources does not claim that the current native host loads them.

## Helper sealing contract

1. The existing fetcher verifies both pinned Darwin **archive** hashes.
2. The canonical consent identity producer verifies the two extracted, unmodified
   Darwin **inner-binary** hashes (arm64 and x86_64). Neither an archive hash nor a
   signed universal hash can stand in for these source hashes.
3. After assembling the universal helper, sign it ad hoc with Hardened Runtime.
4. Invoke `write-consent-bundle-identity.py --mode release` **after** that signature.
   It binds the reviewed source hashes/version, the exact public source commit,
   and the post-sign universal helper SHA-256 into Info.plist; the same post-sign
   hash is written to `Resources/modelplan.sha256`. No unverified/debug mode.
5. Sign the outer app without `--deep`, then verify helper and outer signatures
   strictly (deep verification only). Recheck every identity field and actual
   helper digest after the outer seal. No helper execution is needed for sealing.

Ad-hoc signing does not prove Always Allow survives the next build. U7/A14's
real two-build Keychain check remains `not-run`.

## Artifact and evidence

The artifact contains the exact `ModelPlan-candidate-adhoc.zip`, `SHA256SUMS`,
`packaging-receipt.json`, and an `evidence/` bundle produced by the existing U14
candidate generator/schemas. Archive round-trip verification compares the
unpacked sealed app to its tree digest before the manifest is generated.

The manifest hashes the final sealed app tree, bundled helper, official runtime
manifest and public source SHA. A content-addressed receipt records the archive
hash, resource tree hashes, identity fields, product version, and stage/gaps.
No publication was read, so publication revision is `unsupported`. No HOME was
exercised: the hand-built packaging baseline covers no owner structures. Product
scenarios remain `unsupported` or `not-run`; only the packaging identity check is
recorded as passed. This artifact must not be described as an accepted release.

On macOS, from a clean public checkout (Node 24, Go per cli/go.mod, Swift 6 Xcode):

```sh
node scripts/check-source-policy.mjs
node scripts/check-visual-pack.mjs
node scripts/check-font-pack.mjs
python3 -m unittest discover -s tools/u10/tests -v
python3 tools/u10/package_candidate.py --output "$PWD/.tmp/u10-candidate" \
  --candidate-id local-candidate-1 --build-number 1
```

Use a new output directory; never rebuild a package while retaining evidence
that identifies its earlier bytes. The workflow uploads the zip with its modes
and signature resources preserved, then removes its own scratch. Existing
release-scaffold consumers remain unchanged.
