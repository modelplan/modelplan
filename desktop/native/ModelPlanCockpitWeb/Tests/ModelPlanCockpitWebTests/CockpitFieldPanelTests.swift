// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest

@testable import ModelPlanCockpitWeb

/// The enlarged field's lifetime: nothing exists before open, and every close path destroys the page.
/// WP-22 (owner D298): the panel is one transparent rectangle, 88% of the cockpit display's visible frame within
/// 820×560–1600×1000 pt, over a plain full-display dim; the launch-field component draws everything inside it.
final class CockpitFieldPanelTests: XCTestCase {
  @MainActor private func bundle(_ root: URL) throws -> VerifiedCockpitBundle {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let html = Data("<!doctype html><title>synthetic field</title>".utf8)
    try html.write(to: root.appendingPathComponent("field.html"))
    try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["field.html": VerifiedCockpitBundle.digest(html), "index.html": VerifiedCockpitBundle.digest(html)],
    ])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  @MainActor private func makePanel(_ name: String, idleSeconds: TimeInterval = CockpitFieldPanel.defaultIdleSeconds,
                                lowPower: @escaping @MainActor () -> Bool = { false }, notifications: NotificationCenter = NotificationCenter(),
                                workspace: NotificationCenter = NotificationCenter()) throws -> CockpitFieldPanel {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(name + "-" + UUID().uuidString)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root), idleSeconds: idleSeconds, lowPower: lowPower,
                                  notifications: notifications, workspaceNotifications: workspace)
    panel.accessibility = { (false, false) }
    panel.openURL = { _ in XCTFail("no website opens unless a test asks") }
    return panel
  }
  // A: the built-in display with the menu bar icon; B: a larger display to its right.
  private let screenA = CockpitScreen(frame: NSRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 949))
  private let screenB = CockpitScreen(frame: NSRect(x: 1512, y: 0, width: 2560, height: 1440), visibleFrame: NSRect(x: 1512, y: 0, width: 2560, height: 1415))

  @MainActor func testIdleClosesThePanelOnceAndCloseIsIdempotent() async throws {
    let panel = try makePanel("field-panel", idleSeconds: 0.05)
    var closed = 0
    panel.onClosed = { closed += 1 }
    XCTAssertFalse(panel.isOpen)
    panel.close()
    XCTAssertEqual(closed, 0, "Closing an unopened panel does nothing")
    panel.open(payload: "{}", near: nil)
    XCTAssertTrue(panel.isOpen)
    for _ in 0..<100 where panel.isOpen { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertFalse(panel.isOpen, "The idle timer closes the panel")
    XCTAssertEqual(panel.lastCloseReason, .idle)
    XCTAssertEqual(closed, 1)
    panel.close()
    XCTAssertEqual(closed, 1)
    panel.open(payload: "{}", near: nil)
    XCTAssertTrue(panel.isOpen, "A closed panel can open again")
    panel.close()
    XCTAssertEqual(closed, 2)
  }

  // MARK: WP-22 (D298) container, dim and closing

  /// D298 size rule on common visible frames: 88% within 820×560–1600×1000, never larger than the visible frame, centred
  /// on whole points.
  func testTheContainerIs88PercentOfTheVisibleFrameClampedAndCentred() {
    let cases: [(NSRect, NSRect, String)] = [
      (NSRect(x: 0, y: 0, width: 1470, height: 919), NSRect(x: 88, y: 55, width: 1294, height: 809), "a 14-inch laptop: 88% each way"),
      (NSRect(x: 0, y: 25, width: 1920, height: 977), NSRect(x: 160, y: 83, width: 1600, height: 860), "1920×1080 with menu bar and Dock: the 1600 pt width cap"),
      (NSRect(x: 2000, y: 25, width: 2560, height: 1415), NSRect(x: 2480, y: 232, width: 1600, height: 1000), "a large display: the 1600×1000 cap"),
      (NSRect(x: 0, y: 0, width: 900, height: 600), NSRect(x: 40, y: 20, width: 820, height: 560), "the 820×560 floor"),
      (NSRect(x: -800, y: 0, width: 800, height: 500), NSRect(x: -800, y: 0, width: 800, height: 500), "a display smaller than the floor: the whole visible frame"),
    ]
    for (visible, expected, label) in cases {
      let frame = CockpitFieldPanel.frame(in: visible)
      XCTAssertEqual(frame, expected, label)
      XCTAssertTrue(visible.contains(frame), label)
      XCTAssertEqual(frame.minX, frame.minX.rounded(), label); XCTAssertEqual(frame.minY, frame.minY.rounded(), label)
    }
  }
  /// The normal entry opens the panel on the cockpit's display with the clamped size, over a plain dim (#0B0F1A at 0.52,
  /// no blur) that covers that whole display, menu bar and Dock included.
  @MainActor func testOpeningTheFieldCreatesTheClampedPanelOverAFullDisplayDim() throws {
    let panel = try makePanel("field-open")
    let displays = [screenA, screenB]
    panel.screens = { displays }
    let cockpit = NSRect(x: 3000, y: 400, width: 636, height: 900)
    panel.open(payload: "{}", cockpit: cockpit, pointer: CGPoint(x: 300, y: 300), fallback: NSRect(x: 1100, y: 949, width: 28, height: 24))
    defer { panel.close() }
    let window = try XCTUnwrap(panel.verificationWindow)
    XCTAssertEqual(window.frame, NSRect(x: 1992, y: 207, width: 1600, height: 1000), "on the cockpit's display B, 88% capped at 1600×1000, centred")
    XCTAssertEqual(panel.windowFrame, window.frame)
    XCTAssertFalse(window.isOpaque); XCTAssertEqual(window.backgroundColor.alphaComponent, 0); XCTAssertFalse(window.hasShadow)
    let web = try XCTUnwrap(panel.verificationWebView)
    XCTAssertTrue((window.firstResponder as? NSView)?.isDescendant(of: web) == true, "the page has the keys, so Esc reaches the component")
    let dim = try XCTUnwrap(panel.verificationDimWindow)
    XCTAssertEqual(dim.frame, screenB.frame, "the dim covers the whole display")
    XCTAssertEqual(dim.level, window.level, "directly under the panel, above the cockpit")
    XCTAssertGreaterThan(window.level.rawValue, CockpitWindowController.panelLevel.rawValue)
    XCTAssertFalse(dim.canBecomeKey, "the dim never takes key")
    XCTAssertFalse(dim.isOpaque); XCTAssertFalse(dim.hasShadow)
    let colour = try XCTUnwrap(dim.backgroundColor.usingColorSpace(.sRGB))
    XCTAssertEqual(colour.redComponent * 255, 11, accuracy: 0.01)
    XCTAssertEqual(colour.greenComponent * 255, 15, accuracy: 0.01)
    XCTAssertEqual(colour.blueComponent * 255, 26, accuracy: 0.01)
    XCTAssertEqual(colour.alphaComponent, 0.52, accuracy: 0.001)
    XCTAssertFalse(dim.contentView?.subviews.contains { $0 is NSVisualEffectView } ?? true, "plain dim, no blur")
    XCTAssertEqual(dim.identifier, CockpitWindowController.fieldWindowIdentifier, "a press on the dim closes the field, not the cockpit")
    panel.close()
    XCTAssertNil(panel.verificationDimWindow, "closing removes the dim")
    XCTAssertFalse(dim.isVisible)
  }
  /// D298: a press outside the rectangle (on the dim) closes the field once; the whole rectangle counts as inside.
  @MainActor func testAPressOutsideTheRectangleClosesTheFieldAndInsideDoesNot() throws {
    let panel = try makePanel("field-outside")
    let displays = [screenA]
    panel.screens = { displays }
    var closed = 0
    panel.onClosed = { closed += 1 }
    panel.open(payload: "{}", near: nil)
    let window = try XCTUnwrap(panel.verificationWindow), web = try XCTUnwrap(panel.verificationWebView)
    let dim = try XCTUnwrap(panel.verificationDimWindow), surface = try XCTUnwrap(dim.contentView)
    // Inside the rectangle, corners included, a press reaches the page (the component), never the dim.
    let content = try XCTUnwrap(window.contentView)
    for point in [CGPoint(x: 1, y: 1), CGPoint(x: content.bounds.maxX - 1, y: content.bounds.maxY - 1), CGPoint(x: content.bounds.midX, y: content.bounds.midY)] {
      XCTAssertTrue(content.hitTest(point)?.isDescendant(of: web) == true, "a press at \(point) is the page's")
    }
    XCTAssertTrue(panel.isOpen)
    // Outside: a press on the dim, through the window's normal event path.
    let outside = CGPoint(x: 10, y: 10)
    XCTAssertFalse(window.frame.contains(dim.convertPoint(toScreen: outside)))
    XCTAssertTrue(surface.hitTest(outside) is FieldDimView)
    let press = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: outside, modifierFlags: [], timestamp: 0,
                                                 windowNumber: dim.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    dim.sendEvent(press)
    XCTAssertFalse(panel.isOpen, "a press outside the rectangle closes the field")
    XCTAssertEqual(panel.lastCloseReason, .outside)
    XCTAssertEqual(closed, 1)
    dim.sendEvent(press)
    XCTAssertEqual(closed, 1, "a second press does nothing")
  }
  /// Esc and × come from the component (onClose); losing key still closes as before.
  @MainActor func testTheComponentsCloseAndLosingKeyCloseTheField() throws {
    let panel = try makePanel("field-key")
    var closed = 0
    panel.onClosed = { closed += 1 }
    for (message, reason) in [(#"{"type":"close","reason":"esc"}"#, CockpitFieldPanel.CloseReason.esc), (#"{"type":"close","reason":"key"}"#, .key)] {
      panel.open(payload: "{}", near: nil)
      panel.receive(message)
      XCTAssertFalse(panel.isOpen); XCTAssertEqual(panel.lastCloseReason, reason)
    }
    panel.open(payload: "{}", near: nil)
    panel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
    XCTAssertFalse(panel.isOpen, "losing key closes the field")
    XCTAssertEqual(panel.lastCloseReason, .resign)
    panel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
    XCTAssertEqual(closed, 3, "a second resign does nothing")
  }
  /// The component's onOpenSite: only the spec's four addresses open, in the default browser; a slug outside
  /// ^[a-z0-9.-]+$, extra parameters or another target are ignored.
  @MainActor func testTheSiteKeysOpenOnlyTheAllowlistedAddresses() throws {
    let panel = try makePanel("field-site")
    var opened: [String] = []
    panel.openURL = { opened.append($0.absoluteString) }
    panel.open(payload: "{}", near: nil)
    defer { panel.close() }
    for message in [
      #"{"type":"openSite","target":"fleet","params":{}}"#,
      #"{"type":"openSite","target":"effort","params":{}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":"claude-opus-5.5"}}"#,
      #"{"type":"openSite","target":"methodology","params":{}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":"Claude_Opus"}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":"../../admin"}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":"a/b"}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":"x?y=1"}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":""}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":7}}"#,
      #"{"type":"openSite","target":"effort","params":{"m":"opus","x":"1"}}"#,
      #"{"type":"openSite","target":"fleet","params":{"m":"opus"}}"#,
      #"{"type":"openSite","target":"compare","params":{"m":["a","b"]}}"#,
      #"{"type":"openSite","target":"https://example.invalid","params":{}}"#,
      #"{"type":"openSite","target":"fleet","params":[]}"#,
    ] { panel.receive(message) }
    XCTAssertEqual(opened, ["https://modelplan.ai/", "https://modelplan.ai/effort", "https://modelplan.ai/models/claude-opus-5.5",
                            "https://modelplan.ai/methodology"])
    XCTAssertTrue(panel.isOpen, "opening the website leaves the field open")
    XCTAssertNil(CockpitFieldPanel.siteURL(target: "effort", params: ["m": "é"]))
    XCTAssertEqual(CockpitFieldPanel.siteURL(target: "fleet", params: nil)?.absoluteString, "https://modelplan.ai/")
  }

  /// macrevb-1062-3: the field's selection reaches the host as a public model id, or nil for a clear. Anything else
  /// (a malformed id, an effort, another shape) is ignored, and a closed panel reports nothing.
  @MainActor func testTheFieldsSelectionAndClearReachTheHostByPublicModelID() throws {
    let panel = try makePanel("field-select")
    var selected: [String?] = []
    panel.onSelect = { selected.append($0) }
    panel.open(payload: "{}", near: nil)
    for message in [
      #"{"type":"select","model":"sonnet-5.5"}"#,
      #"{"type":"select","model":null}"#,
      #"{"type":"select","model":""}"#,
      #"{"type":"select","model":7}"#,
      #"{"type":"select"}"#,
      #"{"type":"select","model":"a\u0001b"}"#,
      "{\"type\":\"select\",\"model\":\"" + String(repeating: "x", count: 129) + "\"}",
    ] { panel.receive(message) }
    XCTAssertEqual(selected, ["sonnet-5.5", nil])
    XCTAssertTrue(panel.isOpen, "a selection leaves the field open")
    panel.close()
    panel.receive(#"{"type":"select","model":"opus"}"#)
    XCTAssertEqual(selected, ["sonnet-5.5", nil], "a closed field reports nothing")
  }

  // MARK: Live settings

  /// Spike 11-08 / D63: native tells the page about Low Power Mode, which the page cannot read. Changes while open go
  /// to `power` once the page has loaded and only when the state changes; a closed panel stops listening.
  @MainActor func testLowPowerChangesReachTheOpenPageOnce() throws {
    var low = false
    let center = NotificationCenter()
    let panel = try makePanel("field-power", lowPower: { low }, notifications: center)
    var scripts: [String] = []
    panel.scriptSink = { scripts.append($0) }
    let changed = {
      center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    XCTAssertFalse(panel.isLowPower)
    panel.open(payload: #"{"lowPower":false}"#, near: nil)
    low = true; changed()
    XCTAssertTrue(scripts.isEmpty, "Nothing reaches a page that has not loaded")
    panel.receive(#"{"type":"loaded"}"#)
    XCTAssertEqual(scripts.count, 3)
    XCTAssertTrue(scripts[0].hasPrefix("window.modelPlanField?.show("))
    XCTAssertEqual(scripts[1], "window.modelPlanField?.power(true)", "The change before load catches up after show")
    XCTAssertTrue(scripts[2].hasPrefix("window.modelPlanField?.options("))
    changed()
    XCTAssertEqual(scripts.count, 3, "No change, nothing sent")
    low = false; changed()
    XCTAssertEqual(scripts.last, "window.modelPlanField?.power(false)")
    panel.close()
    low = true; changed()
    XCTAssertEqual(scripts.count, 4, "A closed panel stops listening")
  }
  /// D63 (review of #734): a field opened while Low Power Mode is already on is quiet from the start, whatever the
  /// payload said: right after `show` the page gets `power(true)`.
  @MainActor func testAFieldOpenedInLowPowerModeIsQuietFromTheStart() throws {
    let center = NotificationCenter()
    let panel = try makePanel("field-power-open", lowPower: { true }, notifications: center)
    var scripts: [String] = []
    panel.scriptSink = { scripts.append($0) }
    XCTAssertTrue(panel.isLowPower)
    panel.open(payload: #"{"lowPower":false}"#, near: nil)
    defer { panel.close() }
    panel.receive(#"{"type":"loaded"}"#)
    XCTAssertEqual(scripts.count, 3)
    XCTAssertTrue(scripts[0].hasPrefix("window.modelPlanField?.show("))
    XCTAssertEqual(scripts[1], "window.modelPlanField?.power(true)")
    center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    XCTAssertEqual(scripts.count, 3, "still on, nothing more")
  }
  /// D298: macOS Increase Contrast and Reduce Motion reach the component live (setOptions), once per change.
  @MainActor func testIncreaseContrastAndReduceMotionReachThePageLive() throws {
    let workspace = NotificationCenter()
    let panel = try makePanel("field-a11y", workspace: workspace)
    var settings = (contrast: false, reduceMotion: true)
    panel.accessibility = { settings }
    var scripts: [String] = []
    panel.scriptSink = { scripts.append($0) }
    let changed = {
      workspace.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    panel.open(payload: "{}", near: nil)
    changed()
    XCTAssertTrue(scripts.isEmpty, "nothing before the page has loaded")
    panel.receive(#"{"type":"loaded"}"#)
    XCTAssertEqual(scripts.last, #"window.modelPlanField?.options("{\"contrast\":false,\"reduceMotion\":true}")"#)
    let sent = scripts.count
    changed()
    XCTAssertEqual(scripts.count, sent, "no change, nothing sent")
    settings = (true, true); changed()
    XCTAssertEqual(scripts.last, #"window.modelPlanField?.options("{\"contrast\":true,\"reduceMotion\":true}")"#)
    settings = (true, false); changed()
    XCTAssertEqual(scripts.last, #"window.modelPlanField?.options("{\"contrast\":true,\"reduceMotion\":false}")"#)
    panel.close()
    settings = (false, false); changed()
    XCTAssertEqual(scripts.count, sent + 2, "a closed panel stops listening")
  }

  // MARK: Build 14c, G3-80: placement and refitting across displays

  /// The owner's 14c report: the field opened on the menu bar icon's display. It opens where the user clicked.
  @MainActor func testTheFieldOpensOnTheClickDisplay() throws {
    let panel = try makePanel("field-click")
    let displays = [screenA, screenB]
    panel.screens = { displays }
    panel.open(payload: "{}", near: NSRect(x: 1100, y: 949, width: 28, height: 24), at: CGPoint(x: 2800, y: 700))
    defer { panel.close() }
    let window = try XCTUnwrap(panel.verificationWindow)
    XCTAssertEqual(window.frame, CockpitFieldPanel.frame(in: screenB.visibleFrame), "opens on the click's display B, not the icon's A")
    XCTAssertEqual(window.frame.size, NSSize(width: 1600, height: 1000), "whole points: the window server keeps the size exact")
    XCTAssertEqual(panel.verificationDimWindow?.frame, screenB.frame)
  }
  /// Unplugging the display the field is on, or the field landing on another display, refits it and its dim there.
  @MainActor func testADisplayChangeRefitsTheFieldOnTheDisplayItIsOn() async throws {
    let panel = try makePanel("field-refit")
    var displays = [screenA, screenB]
    panel.screens = { displays }
    panel.open(payload: "{}", near: nil, at: CGPoint(x: 2800, y: 700))
    defer { panel.close() }
    let window = try XCTUnwrap(panel.verificationWindow), dim = try XCTUnwrap(panel.verificationDimWindow)
    XCTAssertEqual(window.frame.size, NSSize(width: 1600, height: 1000), "B's size rule")
    displays = [screenA]
    NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    for _ in 0..<50 where window.frame != CockpitFieldPanel.frame(in: screenA.visibleFrame) {
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertEqual(window.frame, CockpitFieldPanel.frame(in: screenA.visibleFrame), "B unplugged: back on A, A's size rule")
    XCTAssertEqual(dim.frame, screenA.frame, "the dim follows")
    // Moved onto another display without a drag: the window's screen changes and the size rule follows.
    displays = [screenA, screenB]
    window.setFrame(NSRect(x: 2000, y: 300, width: window.frame.width, height: window.frame.height), display: false)
    panel.windowDidChangeScreen(Notification(name: NSWindow.didChangeScreenNotification))
    XCTAssertEqual(window.frame, CockpitFieldPanel.frame(in: screenB.visibleFrame), "now on B, centred")
    XCTAssertEqual(dim.frame, screenB.frame)
  }
}
