# Consent API bundle consistency

`CommunityApp` calls `CommunityApplicationFactory.makeConsentPort(bundle:transport:)` over its own containing bundle and the same bundle's pinned `BundledCLI`. The factory enables the v0.5.43 consent API only when `CommunityConsentBundleIdentity.matches(bundle:)` accepts all fixed, bounded inputs. Old, absent, malformed or inconsistent metadata leaves the port unverified, with no helper invocation during construction.

The packager supplies these `Contents/Info.plist` keys:

| Key | Required value |
| --- | --- |
| `ModelPlanPublicSource` | The app's public source revision, 40 lowercase hex characters |
| `ModelPlanHelperVersion` | `0.5.43` |
| `ModelPlanSourceHelperSHA256` | One reviewed raw upstream helper SHA-256 for a thin package |
| `ModelPlanSourceHelperSHA256ByArchitecture` | For a universal helper, both `arm64` and `x86_64` raw upstream hashes instead of the single-source key |
| `ModelPlanBundledHelperSHA256` | Actual helper SHA-256 after the packager's final helper signing step |

The reviewed raw hashes are published in `CommunityConsentBundleIdentity.sourceSHA256ByArchitecture`. The actual bytes of `Contents/Helpers/modelplan`, the bundled hash in Info and `Contents/Resources/modelplan.sha256` must agree. The signature-covered resource pin must be refreshed if signing changes the helper. Symlinked, missing or oversized fixed inputs are rejected. `BundledCLI` still performs its independent hash check before a requested command.

This gate checks consistency, **not standalone source provenance, signature authenticity, reader consent, account availability or working quota data**. M0 owns verified upstream acquisition and assembly/signing provenance. Synthetic fixtures deliberately use inert helper bytes and test only this consistency contract. No credential or owner profile is read by the factory.

The private Beta07 bootstrap retains its additional private-source/review identity checks and uses the same reviewed arm64 release tuple. Its new identity gate may enable its port; old Beta06 stays unchanged. M0 owns writing the above metadata in the actual public/community packaging producer (`tools/package-neutral.sh`) and checking the resulting package; that script is not changed or executed by this Settings slice. Missing producer metadata remains an explicit integration gap, rather than a default-on API flag.
