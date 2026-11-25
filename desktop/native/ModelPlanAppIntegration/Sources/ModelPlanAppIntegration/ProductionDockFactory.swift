// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanPrimitives
import ModelPlanOfficialDock

/// D57/D321: which visuals a packaged app carries. `package-neutral.sh` writes `ModelPlanEdition`; a package
/// built from source is `neutral` and ships no reserved Dock artwork. Outside a package (tests, `swift run`)
/// there is no key and the official appearance stays the default, as before.
public enum ProductionEdition: String, Sendable {
    case official, neutral
    public static func from(info: [String: Any]?) -> ProductionEdition {
        (info?["ModelPlanEdition"] as? String) == ProductionEdition.neutral.rawValue ? .neutral : .official
    }
    public static var current: ProductionEdition { from(info: Bundle.main.infoDictionary) }
}

/// Production always uses the existing native interactive controller/panel path.
/// Official material stays external; missing official input never silently becomes community.
@MainActor public enum ProductionDockFactory {
    public enum WiringError: Error { case missingAppearance }
    /// The official edition draws the T2 skin; the neutral edition uses the plain community rendering
    /// (no reserved artwork, no flame frames).
    public static func appearance(for edition: ProductionEdition) -> StaticDockPreviewHost.Appearance? {
        edition == .official ? T2ProductionAppearance().apply : nil
    }
    public static func community(createsNativePanels: Bool = true,
                                 nativeEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
                                 elapsedClock: (() -> TimeInterval)? = nil,
                                 edgeScheduling: (any DockEdgeScheduling)? = nil,
                                 currentDate: @escaping @MainActor () -> Date = { Date() },
                                 edition: ProductionEdition = .current) -> StaticDockPreviewHost {
        let host = StaticDockPreviewHost(appearance: appearance(for: edition), currentDate: currentDate, createsNativePanels: createsNativePanels,
            prepareDetachedAlternateAppearances: true, nativeEnvironment: nativeEnvironment, elapsedClock: elapsedClock, edgeScheduling: edgeScheduling,
            purpose: .production)
        guard edition == .official else { return host }
        do { host.installWorkingEffects(pool: EffectResourcePool(), provider: try T2FlameFrameProvider.bundled()) }
        catch { host.recordWorkingEffectFailure(error) }
        return host
    }
    public static func official(appearance: StaticDockPreviewHost.Appearance?) throws -> StaticDockPreviewHost {
        guard let appearance else { throw WiringError.missingAppearance }
        return StaticDockPreviewHost(purpose: .production, appearance: appearance)
    }
}
