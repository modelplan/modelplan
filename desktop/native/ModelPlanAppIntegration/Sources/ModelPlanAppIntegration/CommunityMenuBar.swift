// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
import ModelPlanCommunityHost

@MainActor public protocol CommunityMenuBarPreferencesProviding: AnyObject {
    var currentMenuBarPreferences: SettingsPreferences? { get }
    var menuBarPreferencesChanged: (() -> Void)? { get set }
}
extension StaticDockPreviewHost: CommunityMenuBarPreferencesProviding {}

struct CommunityMenuBarProjector: CommunityMenuBarProviding {
    let preferences: @MainActor () -> SettingsPreferences?
    func make(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics, now: Date) -> CommunityMenuBarPresentation {
        guard let preferences = preferences() else { return .empty }
        let inputs = CommunityDockSnapshot(snapshot: snapshot, diagnostics: diagnostics, now: now).inputs
        let ids = inputs.map(\.id)
        guard Set(ids).count == ids.count, let order = try? preferences.presentedSubscriptionIDs(ids) else { return .empty }
        let byID = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, $0) })
        var lowest: (reading: DockInstrumentReading, remaining: Double, used: Bool)?
        for id in order {
            guard let raw = byID[id] else { continue }
            let input = preferences.applying(to: raw)
            // The same adapter and evaluator used by the Dock own all freshness/reset/unknown rules.
            guard let reading = try? DockInstrumentProjection.evaluate(input, now: now),
                  let remaining = reading.remainingPercent else { continue }
            if lowest.map({ remaining < $0.remaining }) ?? true { lowest = (reading, remaining, input.showUsedPercent) }
        }
        guard let lowest else { return .empty }
        let shown = lowest.used ? 100 - lowest.remaining : lowest.remaining
        let basis = lowest.used ? "Used / 已用" : "Remaining / 剩余"
        return .init(title: "\(Int(shown.rounded()))%", detail: (lowest.reading.alias ?? lowest.reading.name) + " · " + basis + " " + lowest.reading.readout)
    }
}
@MainActor enum CommunityMenuBarResources {
    static let bundleName = "ModelPlanAppIntegration_ModelPlanAppIntegration.bundle"
    static var buildBundleURL: URL { Bundle.module.bundleURL }
    static func templateImage(appURL: URL? = nil) -> NSImage? {
        let app = appURL ?? (Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil)
        let bundle: Bundle?
        if let app { bundle = Bundle(url: app.appendingPathComponent("Contents/Resources/" + bundleName)) }
        else { bundle = .module }
        guard let url = bundle?.url(forResource: "tray", withExtension: "png", subdirectory: "Resources"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true; return image
    }
}
