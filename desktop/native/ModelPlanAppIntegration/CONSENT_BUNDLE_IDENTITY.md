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

## Typed retained inspection for RELPIPE

The root delegate exposes read-only `settingsIntegration` and `companionSurface` references to its actual retained objects. Its public, idempotent `configureSettings(gate)` is the same function used at normal launch. Inspection must call that boundary and read the retained integration, rather than calling a parallel factory or force-casting it to the unwrapped `CommunitySettingsSession`:

```swift
_ = delegate.configureSettings(gate)
guard let actual = delegate.settingsIntegration as? CommunityConnectionIntegration else { throw CommunityConnectionWiringError.entryMissing }
let application = actual.flow.application
try CommunityConnectionWiring.requireInstalled(actual, application: application, backend: backend)
await actual.restorePreferences() // coalesced with the existing scheduled restore
let connections = application.editor.connections
let sameBackend = connections.isBound(to: backend)
let installed = connections.hasAllowanceBackend && sameBackend
let capability = backend.settingsConnectionAvailability // reads the retained command port's capability
// Require equality with connections.availability; derive API readiness from the actual flags/reason.
```

`CommunityConnectionBackend` requires a nonoptional command port at construction; no reflection of guessed field names or second presence flag is needed. A present service with `.unverified` capability remains unverified. For the actual retained Dock, cast `delegate.companionSurface` to `StaticDockPreviewHost` and inspect its `purpose == .production`; its historical type name does not establish purpose. Keep the missing-companion, actual `.selfTest`, missing-service and unverified-API negative controls.

A newly created `LifecycleCoordinator` starts with `canPresent == false`; inspection must not start OS events/runtime or manufacture a permissive presentation flag. Restoring the real integration can inspect canonical consent, so the smoke owner must retain its isolated input/network policy. M4 has only run in-memory construction checks with an unavailable fake transport, and has not executed an App, helper or smoke run locally. RELPIPE owns its hook/checker, and M0 integrates shared entry conflicts.
