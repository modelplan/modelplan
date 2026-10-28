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

The private Beta07 bootstrap retains its additional private-source/review identity checks and uses the same reviewed arm64 release tuple. Its new identity gate may enable its port; old Beta06 stays unchanged. M0's actual public/community producer (`tools/package-neutral.sh`) now calls `tools/write-consent-bundle-identity.py` after sealing the helper and before sealing the App. The writer checks both raw helper bytes against the reviewed source hashes and writes Info plus the resource pin. This M0-owned producer is included in the Settings integration; the actual package script has not been executed by M4. M0 still owns checking the resulting package and every later reseal: whenever helper bytes change, both `ModelPlanBundledHelperSHA256` and the resource pin must be refreshed before sealing the App. Source integration and metadata checks do not prove an actual package or owner journey.
