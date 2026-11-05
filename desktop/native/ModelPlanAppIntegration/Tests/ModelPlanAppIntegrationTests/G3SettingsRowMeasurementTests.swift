// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
@testable import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor G316Engine: EngineClient {
    let context = EngineDeliveryContext(sessionID: "g316", floor: .init(storeEpoch: "g316", generation: 1), revision: 1)
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext { context }
    func retry() async throws -> EngineDeliveryContext { context }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g316")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class G3SettingsRowMeasurementTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    // Text and control bounds are measured in the row's own point coordinates.
    private func glyphBounds(_ field: NSTextField, in row: NSView) -> NSRect? {
        guard !field.isHiddenOrHasHiddenAncestor, !field.stringValue.isEmpty else { return nil }
        let draw = field.cell?.drawingRect(forBounds: field.bounds) ?? field.bounds
        let storage = NSTextStorage(attributedString: field.attributedStringValue)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: draw.size)
        container.lineFragmentPadding = 0
        container.lineBreakMode = field.lineBreakMode
        container.maximumNumberOfLines = field.maximumNumberOfLines
        layout.addTextContainer(container); storage.addLayoutManager(layout)
        let glyphs = layout.boundingRect(forGlyphRange: layout.glyphRange(for: container), in: container)
        guard !glyphs.isEmpty else { return nil }
        let y = field.isFlipped ? draw.minY + glyphs.minY : draw.maxY - glyphs.maxY
        return field.convert(NSRect(x: draw.minX + glyphs.minX, y: y, width: glyphs.width, height: glyphs.height), to: row)
    }

    // Experimental: cell ink may omit the actual bezel; do not treat this as
    // a verified visible-control measurement until compared with the image.
    private func controlInkBounds(_ control: NSControl, in row: NSView) -> NSRect? {
        guard let cell = control.cell, control.bounds.width > 0, control.bounds.height > 0 else { return nil }
        let scale = control.window?.backingScaleFactor ?? 1
        let width = Int(ceil(control.bounds.width * scale)), height = Int(ceil(control.bounds.height * scale))
        guard width > 0, height > 0,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = control.bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        cell.draw(withFrame: NSRect(origin: .zero, size: control.bounds.size), in: control)
        NSGraphicsContext.restoreGraphicsState()
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let rect = NSRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
                          width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
        return control.convert(rect, to: row)
    }

    func testG3_16_SettingsRowsMeasureActualBands() async throws {
        let temp = try XCTUnwrap(ProcessInfo.processInfo.environment["RUNNER_TEMP"], "CI artifact root required")
        let output = URL(fileURLWithPath: temp).appendingPathComponent("dock-instrument-checks/dock-visual/g3-16", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var allOffenders = [String]()
        var totalRows = 0
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g316-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: profile) }
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), makeClient: { _, _ in G316Engine() }, activateSettings: {})
            await app.prepare()
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.settingsHost.present(paneID: "general", origin: .userInitiated)
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
            for pane in SettingsStructure.task65.panes {
                controller.selectPane(pane.id)
                let content = try XCTUnwrap(window.contentView)
                content.layoutSubtreeIfNeeded(); window.displayIfNeeded()
                let rows = descendants(content).compactMap { $0 as? SettingsNativeRow }.filter { !$0.isHiddenOrHasHiddenAncestor }
                totalRows += rows.count
                var canvas = content
                if var ancestor = rows.first as NSView? {
                    while let parent = ancestor.superview {
                        if parent is NSClipView { canvas = ancestor; break }
                        ancestor = parent
                    }
                }
                var offenders = [(NSRect, String)]()
                for row in rows {
                    // A visible section heading is outside the row's content band.
                    var band = row.bounds
                    if !row.group.isHiddenOrHasHiddenAncestor {
                        let heading = row.group.convert(row.group.bounds, to: row)
                        if heading.midY > band.midY {
                            band.size.height = max(0, heading.minY - band.minY - 5)
                        } else {
                            let edge = heading.maxY + 5
                            band.size.height = max(0, band.maxY - edge); band.origin.y = edge
                        }
                    }
                    let blocks = [row.titleLabel, row.subtitle].compactMap { glyphBounds($0, in: row) }
                    guard let first = blocks.first, band.height > 0 else { continue }
                    let text = blocks.dropFirst().reduce(first) { $0.union($1) }
                    let textOffset = text.midY - band.midY
                    print("G3-16 locale=\(locale) pane=\(pane.id) row=\(row.key.rawValue) element=text-block offset=\(String(format: "%.2f", textOffset))")
                    if abs(textOffset) > 1 { offenders.append((row.convert(text, to: canvas), "\(pane.id).\(row.key.rawValue).text: \(textOffset)")) }
                    let controls = descendants(row.controls).compactMap { $0 as? NSControl }.filter { !$0.isHiddenOrHasHiddenAncestor }
                    for (index, control) in controls.enumerated() {
                        guard let ink = controlInkBounds(control, in: row) else {
                            print("G3-16 locale=\(locale) pane=\(pane.id) row=\(row.key.rawValue) element=control-\(index) UNMEASURABLE")
                            offenders.append((.zero, "\(pane.id).\(row.key.rawValue).control-\(index): unmeasurable"))
                            continue
                        }
                        let offset = ink.midY - band.midY
                        print("G3-16 locale=\(locale) pane=\(pane.id) row=\(row.key.rawValue) element=control-\(index) offset=\(String(format: "%.2f", offset))")
                        if abs(offset) > 1 { offenders.append((row.convert(ink, to: canvas), "\(pane.id).\(row.key.rawValue).control-\(index): \(offset)")) }
                    }
                }
                let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
                canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
                let image = NSImage(size: canvas.bounds.size); image.addRepresentation(bitmap)
                image.lockFocus()
                NSColor.systemRed.setStroke()
                for (rect, _) in offenders {
                    // NSImage's drawing coordinates are unflipped even when the
                    // document view is flipped. Both rectangles are in points;
                    // the bitmap representation supplies its backing scale.
                    let y = canvas.isFlipped ? canvas.bounds.maxY - rect.maxY : rect.minY - canvas.bounds.minY
                    let imageRect = NSRect(x: rect.minX - canvas.bounds.minX, y: y, width: rect.width, height: rect.height)
                    let path = NSBezierPath(rect: imageRect); path.lineWidth = 2; path.stroke()
                }
                image.unlockFocus()
                let tiff = try XCTUnwrap(image.tiffRepresentation)
                let png = try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
                try png.write(to: output.appendingPathComponent("\(locale)-\(pane.id).png"), options: .atomic)
                allOffenders.append(contentsOf: offenders.map { locale + "." + $0.1 })
            }
            await app.composition.stop()
        }
        XCTAssertGreaterThan(totalRows, 0, "The measurement must inspect real Settings rows")
        XCTExpectFailure("G3-16 product-missing: visible row elements are not centred") {
            XCTAssertTrue(allOffenders.isEmpty, allOffenders.joined(separator: "; "))
        }
    }
}
