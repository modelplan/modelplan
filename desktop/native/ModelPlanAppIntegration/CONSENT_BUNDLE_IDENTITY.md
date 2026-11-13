# Production Settings and Dock composition

The consent component and bundle-consistency contract are on main; see [the consent core](CONSENT_CORE.md). `CommunityApp` retains that port/backend, first-run flow and verified About context while adding the production Dock companion.

`CommunityApplicationFactory.connectSettings` binds one canonical backend into the existing Settings editor, then installs `CommunityPlacementBinding` on the same Dock. The `CommunityPlacementProducing` port supplies current placement; the optional `CommunityDockSettingsRouting` port supplies the existing drag-commit, display and subscription callbacks. Every explicit drag receipt saves through that same editor. Topology recovery updates context only and never overwrites durable placement preferences. The native Settings row labels the saved value as preferred and shows the actual placement first in its subtitle.

The default Community factory registers its own painted rectangular body and move outline without an official skin. `registeredMoveOutlinePath` is separate from the supplier hull contract: a neutral preview must never replace an appearance’s registered sliver span/anchor with the full view rectangle. Its row control rectangles exclude an 8-point scaled grab margin; drawing, pointer actions and accessibility share those control rectangles. The empty-status label is hit-through. Every allowed target edge is registered before tracking. The same expanded-state handler binding runs before the native-panel boundary, so no-window checks inspect the actual production input graph.

The factory regressions verify default neutral registration, row actions, hidden/disposed regions and the real registered handler. The latter starts on the right, begins/updates/ends a move through that controller, observes a left snap destination, and verifies persisted left-edge intent plus the native catalogue's actual-left subtitle. It injects only display/clock/scheduler and disables panels; no official skin, manual callback installation, native input event, screen or owner journey is substituted. Native vector/raster preview presentation and official assembly still require their own packaged/native acceptance.

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
