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
        let basis = lowest.used
            ? (preferences.language == .english ? "Used" : "已用")
            : (preferences.language == .english ? "Remaining" : "剩余")
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
              let retinaURL = bundle?.url(forResource: "tray@2x", withExtension: "png", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url), let retinaData = try? Data(contentsOf: retinaURL),
              let one = NSBitmapImageRep(data: data), let two = NSBitmapImageRep(data: retinaData),
              one.pixelsWide == 16, one.pixelsHigh == 16, two.pixelsWide == 32, two.pixelsHigh == 32 else { return nil }
        let logicalSize = NSSize(width: 16, height: 16)
        one.size = logicalSize; two.size = logicalSize
        let image = NSImage(size: logicalSize)
        image.addRepresentation(one); image.addRepresentation(two)
        image.isTemplate = true; return image
    }
}
