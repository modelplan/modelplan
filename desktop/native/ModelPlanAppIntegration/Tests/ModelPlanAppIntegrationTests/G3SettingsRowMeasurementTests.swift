// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
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
                let rows = descendants(content).filter { String(describing: type(of: $0)).contains("SettingsNativeRow") && !$0.isHiddenOrHasHiddenAncestor }
                totalRows += rows.count
                var canvas = content
                if var ancestor = rows.first {
                    while let parent = ancestor.superview {
                        if parent is NSClipView { canvas = ancestor; break }
                        ancestor = parent
                    }
                }
                var offenders = [(NSRect, String)]()
                for (index, row) in rows.enumerated() {
                    let band = row.bounds.midY
                    for item in descendants(row).filter({ !$0.isHiddenOrHasHiddenAncestor }) {
                        var target: NSRect?
                        var kind = ""
                        if let text = item as? NSTextField, !text.stringValue.isEmpty {
                            let draw = text.cell?.drawingRect(forBounds: text.bounds) ?? text.bounds
                            let storage = NSTextStorage(attributedString: text.attributedStringValue)
                            let layout = NSLayoutManager(); let container = NSTextContainer(size: draw.size)
                            container.lineFragmentPadding = 0; container.lineBreakMode = text.lineBreakMode
                            container.maximumNumberOfLines = text.maximumNumberOfLines
                            layout.addTextContainer(container); storage.addLayoutManager(layout)
                            let range = layout.glyphRange(for: container)
                            let glyph = layout.boundingRect(forGlyphRange: range, in: container)
                            let originY = text.isFlipped ? draw.minY + glyph.minY : draw.maxY - glyph.maxY
                            target = text.convert(NSRect(x: draw.minX + glyph.minX, y: originY, width: glyph.width, height: glyph.height), to: row)
                            kind = "text"
                        } else if item is NSPopUpButton || item is NSButton || item is NSImageView {
                            target = item.convert(item.bounds, to: row); kind = "control"
                        }
                        guard let target, !target.isEmpty else { continue }
                        let offset = target.midY - band
                        print("G3-16 locale=\(locale) pane=\(pane.id) row=\(index) element=\(kind) offset=\(String(format: "%.2f", offset))")
                        if abs(offset) > 1 { offenders.append((row.convert(target, to: canvas), "\(pane.id).\(index).\(kind): \(offset)")) }
                    }
                }
                let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
                canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
                let image = NSImage(size: canvas.bounds.size); image.addRepresentation(bitmap)
                image.lockFocus()
                NSColor.systemRed.setStroke()
                for (rect, _) in offenders { let path = NSBezierPath(rect: rect); path.lineWidth = 2; path.stroke() }
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
