// SPDX-License-Identifier: MIT
import AppKit
import OSLog
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
    /// Outcome of the most recent lookup, repeated in the status-item diagnosis line.
    private(set) static var lastLookup = "not attempted"
    private static let logger = Logger(subsystem: "org.modelplan.community", category: "status-item")
    /// Inside an .app (any install path) the resource bundle is resolved from the app's own
    /// resource directory; `Bundle.module` is only used outside an app bundle (tests, swift run).
    static func packagedBundleURL(appURL: URL? = nil, main: Bundle = .main) -> URL? {
        if let appURL { return appURL.appendingPathComponent("Contents/Resources", isDirectory: true).appendingPathComponent(bundleName) }
        guard main.bundleURL.pathExtension == "app" else { return nil }
        let resources = main.resourceURL ?? main.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        return resources.appendingPathComponent(bundleName)
    }
    static func templateImage(appURL: URL? = nil) -> NSImage? {
        let root = packagedBundleURL(appURL: appURL) ?? Bundle.module.bundleURL
        // The packaged bundle is a flat SwiftPM directory with no Info.plist: read the files by path
        // instead of relying on NSBundle layout heuristics, and accept a nested Contents layout too.
        for folder in ["Resources", "Contents/Resources/Resources", "Contents/Resources", ""] {
            let base = folder.isEmpty ? root : root.appendingPathComponent(folder, isDirectory: true)
            guard let data = try? Data(contentsOf: base.appendingPathComponent("tray.png")),
                  let retinaData = try? Data(contentsOf: base.appendingPathComponent("tray@2x.png")) else { continue }
            guard let one = NSBitmapImageRep(data: data), let two = NSBitmapImageRep(data: retinaData),
                  one.pixelsWide == 16, one.pixelsHigh == 16, two.pixelsWide == 32, two.pixelsHigh == 32 else {
                lastLookup = "invalid tray images in \(base.path)"
                logger.error("Status item image invalid: \(base.path, privacy: .public)")
                return nil
            }
            let logicalSize = NSSize(width: 16, height: 16)
            one.size = logicalSize; two.size = logicalSize
            let image = NSImage(size: logicalSize)
            image.addRepresentation(one); image.addRepresentation(two)
            image.isTemplate = true
            lastLookup = "loaded from \(base.path)"
            return image
        }
        let exists = FileManager.default.fileExists(atPath: root.path)
        lastLookup = "missing tray images under \(root.path) (bundle exists: \(exists))"
        logger.error("Status item image NOT FOUND under \(root.path, privacy: .public) bundleExists=\(exists, privacy: .public) mainBundle=\(Bundle.main.bundleURL.path, privacy: .public)")
        return nil
    }
}
