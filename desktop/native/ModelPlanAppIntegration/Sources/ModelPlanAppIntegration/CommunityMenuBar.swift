// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanDock
import ModelPlanCommunityHost

struct CommunityMenuBarProjector: CommunityMenuBarProviding {
    func make(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics, now: Date) -> CommunityMenuBarPresentation {
        let inputs = CommunityDockSnapshot(snapshot: snapshot, diagnostics: diagnostics, now: now).inputs
        var lowest: (reading: DockInstrumentReading, remaining: Double)?
        for input in inputs {
            // The same adapter and evaluator used by the Dock own all freshness/reset/unknown rules.
            guard let reading = try? DockInstrumentProjection.evaluate(input, now: now),
                  let remaining = reading.remainingPercent else { continue }
            if lowest.map({ remaining < $0.remaining }) ?? true { lowest = (reading, remaining) }
        }
        guard let lowest else { return .empty }
        return .init(title: "\(Int(lowest.remaining.rounded()))%", detail: (lowest.reading.alias ?? lowest.reading.name) + " · " + lowest.reading.readout)
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
