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
    // Look through wrappers, but don't mistake a member label alongside its
    // control, or a standalone empty-state readout, for a note below a control.
    private func nestedNotesBelowControls(_ root: NSView) -> [NSTextField] {
        func containsControl(_ view: NSView) -> Bool {
            descendants(view).contains { !$0.isHiddenOrHasHiddenAncestor &&
                ($0 is SettingsOwnedControl || ($0 is NSControl && !($0 is NSTextField))) }
        }
        var found: [NSTextField] = []
        for stack in descendants(root).compactMap({ $0 as? NSStackView })
        where stack.orientation == .vertical && !stack.isHiddenOrHasHiddenAncestor {
            var earlierControl = false
            for child in stack.arrangedSubviews where !child.isHiddenOrHasHiddenAncestor {
                if containsControl(child) { earlierControl = true; continue }
                guard earlierControl else { continue }
                found += descendants(child).compactMap { $0 as? NSTextField }.filter {
                    !$0.isHiddenOrHasHiddenAncestor && !$0.stringValue.isEmpty
                }
            }
        }
        return found
    }
    private func centreOffset(label: NSView, control: NSView, in parent: NSView) -> CGFloat {
        control.convert(control.bounds, to: parent).midY - label.convert(label.bounds, to: parent).midY
    }

    func testFrameOracleDetectsAChildMovedInsideAnUnchangedContainer() {
        let line = NSView(frame: .init(x: 0, y: 0, width: 200, height: 40))
        let label = NSView(frame: .init(x: 0, y: 10, width: 80, height: 20))
        let control = NSView(frame: .init(x: 100, y: 10, width: 80, height: 20))
        line.addSubview(label); line.addSubview(control)
        XCTAssertEqual(centreOffset(label: label, control: control, in: line), 0, accuracy: 0.01)
        let original = line.frame
        control.setFrameOrigin(.init(x: 100, y: 13))
        XCTAssertEqual(line.frame, original, "Moving a child must not require moving its parent")
        XCTAssertGreaterThan(abs(centreOffset(label: label, control: control, in: line)), 1)
    }

    func testNestedNoteOracleDistinguishesMemberLabelsAndEmptyReadouts() {
        let member = NSStackView(views: [NSTextField(labelWithString: "Member"), NSButton(title: "Choice", target: nil, action: nil)])
        member.orientation = .horizontal
        let wrapper = NSStackView(views: [NSTextField(labelWithString: "Unavailable")])
        let controls = NSStackView(views: [member, wrapper])
        controls.orientation = .vertical
        XCTAssertEqual(nestedNotesBelowControls(controls).map(\.stringValue), ["Unavailable"])
        wrapper.isHidden = true
        XCTAssertTrue(nestedNotesBelowControls(controls).isEmpty)
        let readout = NSStackView(views: [NSTextField(labelWithString: "No subscriptions")])
        readout.orientation = .vertical
        XCTAssertTrue(nestedNotesBelowControls(readout).isEmpty)
    }

    func testG3_16_SettingsRowsMeasureActualBands() async throws {
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        let output = root.appendingPathComponent("dock-instrument-checks/dock-visual/g3-16", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var allOffenders = [String]()
        var totalRows = 0
        var nestedControls = 0
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g316-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: profile) }
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), makeClient: { _, _ in G316Engine() }, activateSettings: {})
            await app.prepare()
            var context = app.settingsHost.application.editor.context
            context.subscriptions = [
                .init(id: "g316-first", name: .init("First sample", "示例一")),
                .init(id: "g316-second", name: .init("Second sample", "示例二"))
            ]
            app.settingsHost.application.update(context: context)
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
                    for note in nestedNotesBelowControls(row.controls) {
                        offenders.append((note.convert(note.bounds, to: canvas), "\(pane.id).\(row.key.rawValue): text beneath control"))
                    }
                    for line in descendants(row.controls).compactMap({ $0 as? NSStackView }) where line.orientation == .horizontal && !line.isHiddenOrHasHiddenAncestor {
                        let children = line.arrangedSubviews.filter { !$0.isHiddenOrHasHiddenAncestor }
                        guard let label = children.first(where: { $0 is NSTextField && !($0 is SettingsOwnedControl) }) else { continue }
                        for control in children where control is SettingsOwnedControl {
                            nestedControls += 1
                            let childOffset = centreOffset(label: label, control: control, in: line)
                            let detail = "G3-16 locale=\(locale) pane=\(pane.id) row=\(row.key.rawValue) nested-control-offset=\(String(format: "%.2f", childOffset))"
                            print(detail); measurements.append(detail)
                            if abs(childOffset) > 1 { offenders.append((control.convert(control.bounds, to: canvas), detail)) }
                        }
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
                $0.accessibilityIdentifier().hasPrefix("settings.section.")
            }
            XCTAssertEqual(sectionLabels.count, 1, "Search must remove headings without matching rows")
            XCTAssertEqual(sectionLabels.first?.accessibilityIdentifier(), "settings.section.dock.numbers")
            controller.searchField.stringValue = ""
            controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.searchField))
            XCTAssertGreaterThan(stack.arrangedSubviews.compactMap { $0 as? NSTextField }.filter {
                $0.accessibilityIdentifier().hasPrefix("settings.section.dock.")
            }.count, 1, "Clearing search must restore all visible Dock sections")
            await app.composition.stop()
        }
        XCTAssertGreaterThan(totalRows, 0, "The measurement must inspect real Settings rows")
        XCTAssertGreaterThanOrEqual(nestedControls, 2, "The synthetic subscriptions must populate nested controls")
        XCTAssertTrue(allOffenders.isEmpty, allOffenders.joined(separator: "; "))
    }
}
