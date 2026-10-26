// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanShell
import ModelPlanCommunityHost

/// Legacy/probe-compatible entry; packaged apps use the upper ModelPlanCommunityApp composition.
@main struct CommunityMain {
    @MainActor static func main() {
        let delegate = CommunityDelegate(surfaces: NeutralSurfaceProvider())
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
