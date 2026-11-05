// SPDX-License-Identifier: MIT
import AppKit
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

    func testG3_16_SettingsRowsMeasureActualBands() async throws {
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        let output = root.appendingPathComponent("dock-instrument-checks/dock-visual/g3-16", isDirectory: true)
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
                let language: SettingsLanguage = locale == "en" ? .english : .chinese
                for group in pane.groups {
                    guard let title = group.title,
                          let first = rows.first(where: { group.keys.contains($0.key) }),
                          let stack = first.superview as? NSStackView,
                          let rowIndex = stack.arrangedSubviews.firstIndex(of: first) else { continue }
                    let identifier = "settings.section.\(pane.id).\(group.id)"
                    let headings = stack.arrangedSubviews.compactMap { $0 as? NSTextField }.filter {
                        $0.accessibilityIdentifier() == identifier && !$0.isHiddenOrHasHiddenAncestor
                    }
                    XCTAssertEqual(headings.count, 1, "One section heading must precede its first visible row")
                    if let heading = headings.first, let headingIndex = stack.arrangedSubviews.firstIndex(of: heading) {
                        XCTAssertEqual(heading.stringValue, title.value(language))
                        XCTAssertEqual(headingIndex + 1, rowIndex)
                    }
                }
                var canvas = content
                if var ancestor = rows.first as NSView? {
                    while let parent = ancestor.superview {
                        if parent is NSClipView { canvas = ancestor; break }
                        ancestor = parent
                    }
                }
                var offenders = [(NSRect, String)]()
                var measurements = [String]()
                for row in rows {
                    let title = row.titleLabel.convert(row.titleLabel.bounds, to: row)
                    let subtitle = row.subtitle.convert(row.subtitle.bounds, to: row)
                    let text = title.union(subtitle)
                    let control = row.controls.convert(row.controls.bounds, to: row)
                    let offset = control.midY - text.midY
                    let measurement = "G3-16 locale=\(locale) pane=\(pane.id) row=\(row.key.rawValue) frame-offset=\(String(format: "%.2f", offset))"
                    print(measurement); measurements.append(measurement)
                    if abs(offset) > 1 { offenders.append((row.convert(control, to: canvas), "\(pane.id).\(row.key.rawValue): \(offset)")) }
                    if let copy = row.titleLabel.superview as? NSStackView {
                        if copy.arrangedSubviews.count != 2 || copy.arrangedSubviews[0] !== row.titleLabel || copy.arrangedSubviews[1] !== row.subtitle {
                            offenders.append((.zero, "\(pane.id).\(row.key.rawValue): unexpected content in title stack"))
                        }
                    } else { offenders.append((.zero, "\(pane.id).\(row.key.rawValue): missing title stack")) }
                    let visible = row.controls.arrangedSubviews.filter { !$0.isHiddenOrHasHiddenAncestor }
                    if visible.count > 1 && visible.contains(where: { $0 is NSTextField }) {
                        offenders.append((.zero, "\(pane.id).\(row.key.rawValue): text beneath control"))
                    }
                }
                let attachment = XCTAttachment(string: measurements.joined(separator: "\n"))
                attachment.name = "G3-16 \(locale) \(pane.id) frame offsets"
                attachment.lifetime = .keepAlways
                add(attachment)
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
            controller.selectPane("dock")
            controller.searchField.stringValue = locale == "en" ? "critical threshold" : "变红阈值"
            controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.searchField))
            let content = try XCTUnwrap(window.contentView)
            let filtered = descendants(content).compactMap { $0 as? SettingsNativeRow }.filter { !$0.isHiddenOrHasHiddenAncestor }
            let threshold = try XCTUnwrap(filtered.first { $0.key == .redBelow })
            let stack = try XCTUnwrap(threshold.superview as? NSStackView)
            let sectionLabels = stack.arrangedSubviews.compactMap { $0 as? NSTextField }.filter {
                $0.accessibilityIdentifier()?.hasPrefix("settings.section.") == true
            }
            XCTAssertEqual(sectionLabels.count, 1, "Search must remove headings without matching rows")
            XCTAssertEqual(sectionLabels.first?.accessibilityIdentifier(), "settings.section.dock.numbers")
            controller.searchField.stringValue = ""
            controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.searchField))
            XCTAssertGreaterThan(stack.arrangedSubviews.compactMap { $0 as? NSTextField }.filter {
                $0.accessibilityIdentifier()?.hasPrefix("settings.section.dock.") == true
            }.count, 1, "Clearing search must restore all visible Dock sections")
            await app.composition.stop()
        }
        XCTAssertGreaterThan(totalRows, 0, "The measurement must inspect real Settings rows")
        XCTAssertTrue(allOffenders.isEmpty, allOffenders.joined(separator: "; "))
    }
}
