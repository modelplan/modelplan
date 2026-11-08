// SPDX-License-Identifier: MIT
// Exploration only (scratch branch, never merged): renders the production Dock at a 0% Codex 5-hour quota and three
// option overlays drawn with the real station geometry, then prints the PNGs as base64 for the evidence branch.
import AppKit
import CoreGraphics
import CoreText
import Foundation
import XCTest
import ModelPlanSettings
@testable import S1GalleryCore
@_spi(DockResourceChecks) import ModelPlanDock
@_spi(DockResourceChecks) import ModelPlanAppIntegration

@MainActor private final class ZeroProvider: DockContentProvider {
    let inputs: [DockInstrumentInput]
    init(now: Date) {
        typealias Window = (DockQuotaPeriod, Double, Double?, Double)
        let fixtures: [(String, String, String, [Window])] = [
            ("codex", "ChatGPT", "openai", [(.fiveHour, 0, 198, 300), (.week, 76, 7410, 10080)]),
            ("claude", "Claude", "claude", [(.fiveHour, 41, 120, 300), (.week, 62, 3490, 10080)]),
            ("zhipu", "GLM", "zhipu", [(.fiveHour, 72, 48, 300)]),
            ("cursor", "Cursor", "cursor", [(.month, 58, 19020, 43200)])
        ]
        inputs = fixtures.map { id, name, vendor, list in
            var input = DockInstrumentInput(id: id, name: name, windows: list.enumerated().map { i, w in
                DockQuotaWindowInput(id: "window-\(i)", period: w.0, label: w.0.rawValue, remainingPercent: w.1,
                                     resetsAt: w.2.map { now.addingTimeInterval($0 * 60) }, durationSeconds: w.3 * 60) })
            input.vendorResourceKey = vendor; input.dataState = .fresh
            return input
        }
    }
    func makeContent(_ context: DockContentContext) -> DockContent {
        .init(snapshot: .init(inputs: inputs), signals: inputs.map { var s = DockSubscriptionSignal(id: $0.id); s.dataState = .fresh; return s })
    }
}

@MainActor final class S1GalleryTestsZeroQuota: XCTestCase {
    private func emit(_ name: String, _ image: CGImage) throws {
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        let text = png.base64EncodedString()
        print("ZQ-BEGIN \(name)")
        var index = text.startIndex
        while index < text.endIndex { let end = text.index(index, offsetBy: 3000, limitedBy: text.endIndex) ?? text.endIndex; print("ZQ-DATA \(name) " + text[index..<end]); index = end }
        print("ZQ-END \(name)")
    }
    /// Draws on a copy of the production image in skin coordinates, with the renderer's own transform.
    private func overlay(_ base: CGImage, _ skin: DockInstrumentSkin, scale: CGFloat, _ draw: (CGContext) -> Void) throws -> CGImage {
        let w = base.width, h = base.height
        let c = try XCTUnwrap(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        c.draw(base, in: CGRect(x: 0, y: 0, width: w, height: h))
        c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: scale, y: -scale); c.translateBy(x: -skin.bounds.minX, y: -skin.bounds.minY)
        draw(c)
        return try XCTUnwrap(c.makeImage())
    }
    private func colour(_ hex: UInt32, _ alpha: CGFloat) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
    private func text(_ c: CGContext, _ value: String, centre: CGPoint, size: CGFloat, colour: CGColor) {
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour]))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        c.saveGState(); c.translateBy(x: centre.x - width / 2, y: centre.y + (ascent - descent) / 2); c.scaleBy(x: 1, y: -1)
        c.textMatrix = .identity; c.textPosition = .zero; CTLineDraw(line, c); c.restoreGState()
    }

    func testRenderZeroQuotaOptions() async throws {
        _ = NSApplication.shared
        let now = ISO8601DateFormatter().date(from: "2026-10-20T14:05:00Z")!
        let display = DockDisplayArea(id: "zq", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "zq")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zq-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, tag) in [(SettingsLanguage.english, "en"), (.chinese, "zh")] {
            let store = try SettingsStore(url: root.appendingPathComponent("\(tag).json"))
            try await store.update { $0.dockEdge = .right; $0.size = .medium; $0.dockDisplayID = "zq"; $0.dockAlongFraction = 0.5; $0.language = language; $0.autoHide = false }
            let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
            defer { host.close() }
            host.captureBackingScaleForChecks = 2; host.dockView.zaiMarkEnabled = true
            host.setDockContentProvider(ZeroProvider(now: now))
            let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }; await coordinator.reload(); host.setPresentationAllowed(true)
            let image = try XCTUnwrap(host.dockView.presentedImageForChecks), skin = try XCTUnwrap(host.dockView.presentedSkinForChecks)
            let s = try XCTUnwrap(skin.stations.first { $0.subscriptionID == "codex" })
            let scale = CGFloat(image.width) / skin.bounds.width
            print("ZQ-GEOMETRY \(tag) centre=\(s.centre) diameter=\(s.diameter) outer=\(s.outer.radius)/\(s.outer.width) inner=\(s.inner.radius)/\(s.inner.width) case=\(s.caseInnerRadius) glyph=\(s.glyphRect) readout=\(s.readout) scale=\(scale)")
            try emit("main-\(tag)", image)
            let ring = { (c: CGContext) in
                // A: the empty ring's whole track in deep red, where the arc would be.
                c.setLineWidth(s.outer.width); c.setStrokeColor(self.colour(0x9c3427, 0.95))
                c.strokeEllipse(in: CGRect(x: s.centre.x - s.outer.radius, y: s.centre.y - s.outer.radius, width: 2 * s.outer.radius, height: 2 * s.outer.radius))
            }
            try emit("optionA-\(tag)", try overlay(image, skin, scale: scale) { c in ring(c) })
            try emit("optionB-\(tag)", try overlay(image, skin, scale: scale) { c in
                ring(c)
                // B: a red-tinted face and a dimmed vendor mark (the prototype's used-up nozzle).
                let r = s.caseInnerRadius, face = CGRect(x: s.centre.x - r, y: s.centre.y - r, width: 2 * r, height: 2 * r)
                c.setFillColor(self.colour(0xdf604c, 0.20)); c.fillEllipse(in: face)
                c.setFillColor(self.colour(0x0b0f13, 0.45)); c.fillEllipse(in: s.glyphRect.insetBy(dx: -1, dy: -1))
            })
            try emit("optionC-\(tag)", try overlay(image, skin, scale: scale) { c in
                ring(c)
                // C: a small red badge on the ring's lower edge with the time until the quota returns.
                let label = tag == "en" ? "3h18" : "3时18", w: CGFloat = 26, h: CGFloat = 10
                let pill = CGRect(x: s.centre.x - w / 2, y: s.centre.y + s.outer.radius - h / 2, width: w, height: h)
                c.setFillColor(self.colour(0xb3392c, 1)); c.addPath(CGPath(roundedRect: pill, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)); c.fillPath()
                self.text(c, label, centre: CGPoint(x: pill.midX, y: pill.midY), size: 7, colour: self.colour(0xffffff, 1))
            })
        }
    }
}
