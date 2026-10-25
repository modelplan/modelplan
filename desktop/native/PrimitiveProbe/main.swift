// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import ModelPlanCore
import ModelPlanPrimitives

@MainActor final class ProbeDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!, row: CalibrationRow!, resolver: AppearanceResolver?
    private let time = SystemRefreshTime()
    private var endTimer: Timer?, fixtureTimer: Timer?
    private var mode = "base", output: URL?, seconds = 92.0
    private var fixtureEpisode = 0
    private var originalFrontmost: pid_t?
    private var lostVisibility = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let args = CommandLine.arguments
        func value(_ key: String) -> String? { args.firstIndex(of: key).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        mode = value("--mode") ?? "base"; seconds = min(180, max(1, Double(value("--seconds") ?? "92") ?? 92))
        output = value("--receipt").map { URL(fileURLWithPath: $0) }
        originalFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        row = CalibrationRow(elapsed: { [weak self] in self?.time.elapsed ?? 0 })
        window = NSWindow(contentRect: row.bounds, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Model Plan — synthetic B05 calibration"; window.contentView = row; window.delegate = self
        window.isReleasedWhenClosed = false; window.level = .floating; window.center(); window.orderFront(nil)
        let count = mode.hasPrefix("jets") ? Int(mode.dropFirst(4)) ?? 0 : 0
        row.configure(profile: RenderProfile(), workingIDs: Set((0..<min(6, max(0, count))).map { "synthetic-sub-\($0)" }))
        if mode == "lamp" || mode == "steady" {
            row.caution.update([CautionCondition(id: "fixture-0", severity: .amber)], profile: row.profile)
            if mode == "steady" { row.caution.acknowledge() }
            else {
                let timer = Timer(timeInterval: 10.2, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }; self.fixtureEpisode += 1
                        self.row.caution.update([CautionCondition(id: "fixture-\(self.fixtureEpisode)", severity: .amber)], profile: self.row.profile)
                    }
                }
                RunLoop.main.add(timer, forMode: .common); fixtureTimer = timer
            }
        }
        if mode == "cursor" { row.startTyping(seconds: seconds) }
        if let directory = value("--captures") {
            Task { await captures(URL(fileURLWithPath: directory)); finish() }; return
        }
        if value("--follow-system") == "yes" {
            row.followSystemAppearance = true; row.appearance = nil
            let resolver = AppearanceResolver(view: row); self.resolver = resolver
            row.onAppearanceChange = { [weak resolver] in resolver?.invalidate() }
            resolver.onChange = { [weak self] profile in guard let self else { return }; self.row.configure(profile: profile, workingIDs: self.row.workingIDs); self.row.caution.validate() }
            resolver.start()
        }
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.finish() } }
        RunLoop.main.add(timer, forMode: .common); endTimer = timer
    }
    func windowWillClose(_ notification: Notification) { finish(interrupted: true) }
    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let row else { return }
        let visible = window.occlusionState.contains(.visible)
        if !visible && time.elapsed > 2 { lostVisibility = true }
        row.setVisible(visible)
    }
    private func captures(_ directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for dark in [false, true] { for scale in [1, 2] { for locale in ["en", "zh-Hans"] {
            let profile = RenderProfile(dark: dark, scale: scale, locale: locale)
            row.configure(profile: profile, workingIDs: ["synthetic-sub-0", "synthetic-sub-1"])
            row.caution.update([CautionCondition(id: "capture", severity: .amber)], profile: profile)
            try? await Task.sleep(nanoseconds: 150_000_000)
            row.freezeForCapture(); row.layoutSubtreeIfNeeded(); row.display(); CATransaction.flush()
            guard let context = CGContext(data: nil, width: 800 * scale, height: 330 * scale, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            context.setFillColor((dark ? NSColor.black : NSColor.white).cgColor); context.fill(CGRect(x: 0, y: 0, width: 800 * scale, height: 330 * scale))
            context.scaleBy(x: CGFloat(scale), y: CGFloat(scale)); row.layer?.render(in: context)
            if let image = context.makeImage(), let jpeg = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                try? jpeg.write(to: directory.appendingPathComponent("\(dark ? "night" : "day")-\(locale)-\(scale)x.jpg"))
            }
        } } }
    }
    private func finish(interrupted: Bool = false) {
        guard row != nil else { return }
        endTimer?.invalidate(); fixtureTimer?.invalidate(); resolver?.stop()
        var receipt: [String: Any] = ["schemaVersion": 1, "mode": mode, "elapsed": time.elapsed,
            "workingIDs": row.workingIDs.sorted(), "workingCount": row.workingIDs.count,
            "animatingCount": row.animatingCount, "poseCount": row.minimumPoseCount,
            "cacheBytes": row.pool.decodedBytes, "cachePeakBytes": row.pool.peakDecodedBytes,
            "cacheRefusals": row.pool.refusals, "frontmostUnchanged": NSWorkspace.shared.frontmostApplication?.processIdentifier == originalFrontmost,
            "becameKey": window.isKeyWindow, "interrupted": interrupted || lostVisibility,
            "scope": "neutral synthetic primitive, no appearance acceptance or physical input claim"]
        row.dispose(); receipt["cacheAfterDispose"] = row.pool.decodedBytes
        window.orderOut(nil); window.delegate = nil; row = nil
        if let output, let data = try? JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: output, options: .atomic) }
        NSApp.terminate(nil)
    }
}
@main struct PrimitiveProbe {
    @MainActor static func main() {
        let delegate = ProbeDelegate(); NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
