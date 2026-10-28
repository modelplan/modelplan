# Production Settings and Dock composition

The consent component and bundle-consistency contract are on main; see [the consent core](CONSENT_CORE.md). `CommunityApp` retains that port/backend, first-run flow and verified About context while adding the production Dock companion.

`CommunityApplicationFactory.connectSettings` binds one canonical backend into the existing Settings editor, then installs `CommunityPlacementBinding` on the same Dock. The `CommunityPlacementProducing` port supplies current placement; the optional `CommunityDockSettingsRouting` port supplies the existing drag-commit, display and subscription callbacks. Every explicit drag receipt saves through that same editor. Topology recovery updates context only and never overwrites durable placement preferences. The native Settings row labels the saved value as preferred and shows the actual placement first in its subtitle.

The factory regression constructs the actual production-purpose host with native panels disabled, verifies startup/recovery observations, then delivers a synthetic drag receipt through its installed commit port. It verifies persisted left-edge intent and the native catalogue's actual-left subtitle. This is in-memory wiring proof, not a native gesture, screen or owner journey.

## Typed retained inspection

The delegate exposes read-only `settingsIntegration` and `companionSurface` references to its actual retained objects. Its idempotent `configureSettings(gate)` is also used at normal launch:

```swift
_ = delegate.configureSettings(gate)
guard let actual = delegate.settingsIntegration as? CommunityConnectionIntegration else { throw CommunityConnectionWiringError.entryMissing }
let application = actual.flow.application
try CommunityConnectionWiring.requireInstalled(actual, application: application, backend: backend)
await actual.restorePreferences()
let connections = application.editor.connections
let installed = connections.hasAllowanceBackend && connections.isBound(to: backend)
let capability = backend.settingsConnectionAvailability
```

Require equality between the retained backend's capability and `connections.availability`; an installed but unverified service remains unverified. For the Dock, inspect the retained host's `purpose == .production`; the historical class name does not determine its purpose. Preserve missing-companion, self-test, missing-service and unverified-API negative controls.

A new lifecycle coordinator starts with presentation disabled. Inspection must not start OS events/runtime or manufacture a presentation grant. Canonical restoration may invoke the bundled component, so packaged smoke retains its isolated input/network policy. Local construction checks use only synthetic transports and fixtures. Actual packaged smoke, native consent and the owner journey remain separate acceptance gates.
