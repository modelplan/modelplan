// SPDX-License-Identifier: MIT
import Foundation

/// Production always uses the existing native interactive controller/panel path.
/// Official material stays external; missing official input never silently becomes community.
@MainActor public enum ProductionDockFactory {
    public enum WiringError: Error { case missingAppearance }
    public static func community() -> StaticDockPreviewHost {
        StaticDockPreviewHost(purpose: .production)
    }
    public static func official(appearance: StaticDockPreviewHost.Appearance?) throws -> StaticDockPreviewHost {
        guard let appearance else { throw WiringError.missingAppearance }
        return StaticDockPreviewHost(purpose: .production, appearance: appearance)
    }
}
