// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import WebKit
import XCTest
@testable import ModelPlanCockpitWeb

/// CKP-SHELL-33 normal entry (owner D157-D160, D172, D175, D178, D181, D186-D188; G3-83): the real controller and panels on
/// the real screen, entered the way the app does (the console sets the icon entrance and opens; the strip key sends the
/// detach / put-back intents; the strip drag). The page is a synthetic document, so the amber glow itself is the page's
/// (bridge.test.mjs); here the controller's ignition calls are observed. Window server: GUI leg.
@MainActor final class CockpitLaunchRackEntryTests: XCTestCase {
  private struct Fixture {
    let page: CockpitWindowController, session: CockpitShellSession, icon: CGRect, usable: CGRect, screenWidth: CGFloat
    var home: CGRect? { CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: false, screenWidth: screenWidth)?.frame }
  }
  private var failures: [CockpitWindowFailure] = []
  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-rack-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  /// `notch`: nil keeps the visible status item; `.some(edge)` hides it (the app's anchor is nil) on a display whose notch
  /// ends at `edge` (nil edge: no notch), D378.
  private func make(reduceMotion: Bool = false, hiddenItemNotch notch: CGFloat?? = nil) throws -> Fixture {
    _ = NSApplication.shared
    guard let screen = NSScreen.main else { throw XCTSkip("needs a display") }
    let usable = screen.visibleFrame
    // A status item's frame in the menu bar, left of centre so the cockpit has room on both sides.
    var icon = CGRect(x: (usable.minX + usable.width * 0.4).rounded(), y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let session = CockpitShellSession()
    let visible = notch == nil, shown = icon
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: reduceMotion), shellSession: session,
      anchor: { visible ? shown : nil })
    if let notch {
      let display = CockpitScreen(frame: screen.frame, visibleFrame: usable, notchRightEdge: notch)
      page.screens = { [display] }
      icon = CockpitShellLayout.menuBarEdgeAnchor(screen: display)
    }
    page.onFailure = { [weak self] in self?.failures.append($0) }
    return Fixture(page: page, session: session, icon: icon, usable: usable, screenWidth: screen.frame.width)
  }
  private func open(_ fixture: Fixture) throws -> NSWindow {
    fixture.session.nextEntrance = .fromIcon
    fixture.page.open()
    let window = try XCTUnwrap(fixture.page.window)
    (window.contentView?.subviews.first as? WKWebView)?.navigationDelegate = nil
    return window
  }
  private func wait(_ ms: Int) async throws { try await Task.sleep(for: .milliseconds(ms)) }
  /// Polls every 10 ms for up to 2 s; the failure names what never happened.
  private func until(_ what: String, file: StaticString = #filePath, line: UInt = #line, _ condition: @MainActor () -> Bool) async throws {
    for _ in 0..<200 {
      if condition() { return }
      try await wait(10)
    }
    XCTFail("never happened: \(what)", file: file, line: line)
  }

  func testIdleAttachedSizeChangeRefreshesRackMask() throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    // Keep the icon at the usable frame's top while giving both sizes room to fit.
    let usable = CGRect(x: fixture.usable.minX, y: fixture.usable.maxY - 1440, width: 2560, height: 1440)
    fixture.page.verificationPlacement = (usable: usable, anchor: fixture.icon)
    fixture.page.updateAppearance(.init(theme: .night, locale: .en, profile: .full, reduceMotion: true, size: .percent80))
    let window = try open(fixture)
    XCTAssertTrue(fixture.page.isAttached)
    XCTAssertFalse(fixture.page.verificationRack.moving)
    let before = try XCTUnwrap(fixture.page.verificationRackMask)
    let originalFrame = window.frame

    fixture.page.updateAppearance(.init(theme: .night, locale: .en, profile: .full, reduceMotion: true, size: .percent100))

    XCTAssertNotEqual(window.frame.size, originalFrame.size, "the Settings change must resize the cockpit")
    let layout = try XCTUnwrap(fixture.page.verificationLayout)
    let panel = try XCTUnwrap(fixture.page.verificationRack.panel)
    let actual = try XCTUnwrap(fixture.page.verificationRackMask)
    let drop = layout.rackMaskDrop
    let hidden = CGRect(x: window.frame.minX, y: window.frame.minY, width: window.frame.width,
                        height: max(0, window.frame.height - drop))
    let expected = CGRect(x: hidden.minX - panel.minX, y: panel.maxY - hidden.maxY,
                          width: hidden.width, height: hidden.height)
    XCTAssertNotEqual(actual, before, "the old mask must not survive a size change")
    XCTAssertEqual(actual, expected, "the rack clips against the resized cockpit")
    XCTAssertEqual(failures, [])
  }

  /// D430/D439/D446/D447 normal entry: the icon open slides the one-piece boom down with its clamp open; once the cockpit
  /// is home the clamp closes on the lug (drawn only while attached), then nothing redraws at rest. The strip key's
  /// detach opens the clamp and the lug goes with the cockpit.
  func testIconOpenClosesTheClampOnTheLugAndDetachOpensIt() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    var sawOpenWhileSliding = false
    fixture.page.verificationRackDrawn = {
      let boom = fixture.page.verificationBoom
      if fixture.page.verificationRack.ext < 1, let pose = boom.pose, pose.closure == 0 { sawOpenWhileSliding = true }
    }
    try await until("the attached entrance is settled with the clamp closed") {
      window.alphaValue == 1 && fixture.page.verificationRack.ext == 1 && fixture.page.verificationBoom.pose?.closure == 1
    }
    XCTAssertTrue(sawOpenWhileSliding, "the clamp is open while the boom slides")
    let pose = try XCTUnwrap(fixture.page.verificationBoom.pose)
    XCTAssertNotNil(pose.lug, "the lug is on the canopy while attached")
    XCTAssertEqual(fixture.page.verificationBoom.clampTarget, 1)
    let panel = try XCTUnwrap(fixture.page.verificationRack.panel)
    XCTAssertEqual(panel.width, CockpitLaunchRack.statusWidths.width, "the boom is the widest status width seen")
    XCTAssertGreaterThanOrEqual(CockpitLaunchRack.statusWidths.widest, fixture.icon.width)
    var redraws = 0
    fixture.page.verificationRackDrawn = { redraws += 1 }
    try await wait(250)
    XCTAssertEqual(redraws, 0, "nothing animates at rest")
    // macrev2-1207-1: the key detach opens the clamp first; the cockpit and the boom stay home until it is fully open.
    let home = window.frame
    let ticks = record(fixture, window)
    fixture.page.setAttached(false)
    XCTAssertEqual(fixture.page.verificationBoom.clampTarget, 0, "detaching: the clamp opens")
    try await until("the cockpit has landed and the boom is in") {
      fixture.page.verificationRack.panel == nil && !fixture.page.verificationRack.moving
    }
    assertClampOpensBeforeDeparture(ticks.samples, home: home, label: "key detach")
    fixture.page.verificationRackDrawn = nil
    XCTAssertEqual(failures, [])
  }

  /// macrev2-1207-1: the close of an icon-opened cockpit (the reverse) also opens the clamp before the cockpit rises.
  func testIconCloseOpensTheClampBeforeTheCockpitRises() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await until("the clamp is closed on the lug") {
      window.alphaValue == 1 && fixture.page.verificationBoom.pose?.closure == 1 && !fixture.page.verificationRack.moving
    }
    let home = window.frame
    let ticks = record(fixture, window)
    fixture.page.requestClose()
    try await wait(900)
    XCTAssertNil(fixture.page.window, "closed")
    assertClampOpensBeforeDeparture(ticks.samples, home: home, label: "icon close")
    fixture.page.verificationRackDrawn = nil
    XCTAssertEqual(failures, [])
  }

  /// macrev2-1207-1 round 3: a title-strip drag begun during a key detach's release hold ends the hold with the clamp
  /// open in that same step: on every observed tick, including the interruption frame and the drag's first moved frame,
  /// the boom never retracts and the cockpit never moves while the clamp is not fully open.
  func testADragDuringTheReleaseHoldOpensTheClampBeforeAnythingMoves() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await until("the clamp is closed on the lug") {
      window.alphaValue == 1 && fixture.page.verificationBoom.pose?.closure == 1 && !fixture.page.verificationRack.moving
    }
    let home = window.frame
    let ticks = record(fixture, window)
    // Coordinator ruling @ e11e00f3: no wall clock. The driver runs on the manual clock, one 60 Hz tick at a time.
    fixture.page.verificationManualRackClock = 1_000
    defer { fixture.page.verificationManualRackClock = nil }
    fixture.page.setAttached(false)
    XCTAssertEqual(window.frame, home, "the press: still home"); XCTAssertEqual(fixture.page.verificationRack.ext, 1)
    var partial: CGFloat?
    for _ in 0..<30 {
      fixture.page.verificationAdvanceRack(by: 1.0 / 60)
      let closure = fixture.page.verificationBoom.pose?.closure ?? 0
      if closure > 0, closure < 1 { partial = closure; break }
      XCTAssertEqual(window.frame, home, "held at home while the clamp is closed")
    }
    let closure = try XCTUnwrap(partial, "a tick inside the release hold has the clamp part open")
    XCTAssertEqual(window.frame, home, "at the partial tick (closure \(closure)) the cockpit is home")
    XCTAssertEqual(fixture.page.verificationRack.ext, 1, "at the partial tick the boom is down")
    XCTAssertTrue(fixture.page.verificationRack.moving, "the hold is still running")
    // From that tick: the drag begins and makes its first move.
    let grab = CGPoint(x: home.minX + 120, y: home.maxY - 16)
    // As the put-back test (f92449b6): down AND sideways toward the roomier side, so the drop is outside the catch zone
    // on a short display too (D444 fills its height).
    let side: CGFloat = fixture.usable.maxX - home.maxX >= home.minX - fixture.usable.minX ? 200 : -200
    fixture.page.titleDrag(.began, point: grab)
    XCTAssertEqual(fixture.page.verificationBoom.pose?.closure ?? 0, 0, "the interruption frame: the clamp is open")
    XCTAssertEqual(fixture.page.verificationBoom.clampTarget, 0)
    fixture.page.titleDrag(.moved, point: CGPoint(x: grab.x + side / 2, y: grab.y - 100))
    XCTAssertNotEqual(window.frame.origin, home.origin, "the drag moves the cockpit")
    XCTAssertEqual(fixture.page.verificationBoom.pose?.closure ?? 0, 0, "the first moved frame: the clamp is open")
    let drop = CGPoint(x: grab.x + side, y: grab.y - 200)
    fixture.page.titleDrag(.moved, point: drop)
    XCTAssertFalse(fixture.page.inCatchZone(window.frame), "the drop is outside the catch zone (\(window.frame) from \(home))")
    fixture.page.titleDrag(.ended, point: drop)
    for _ in 0..<120 where fixture.page.verificationRack.panel != nil || fixture.page.verificationRack.moving {
      fixture.page.verificationAdvanceRack(by: 1.0 / 60)
    }
    XCTAssertNil(fixture.page.verificationRack.panel, "the boom is in"); XCTAssertFalse(fixture.page.verificationRack.moving)
    // Every recorded frame, the interruption frame included: closure is 0 on or before the first one that moves.
    assertClampOpensBeforeDeparture(ticks.samples, home: home, label: "drag during the release hold")
    XCTAssertFalse(fixture.page.isAttached)
    fixture.page.verificationRackDrawn = nil
    XCTAssertEqual(failures, [])
  }

  /// macrev2-1207-1 round 3: an open during the icon close's release hold keeps the cockpit home; the interrupted hold
  /// leaves no release pending, so the clamp closes on the lug again.
  func testAnOpenDuringTheCloseReleaseClosesTheClampAgain() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await until("the clamp is closed on the lug") {
      window.alphaValue == 1 && fixture.page.verificationBoom.pose?.closure == 1 && !fixture.page.verificationRack.moving
    }
    let home = window.frame
    let ticks = record(fixture, window)
    fixture.page.requestClose()
    try await until("the close's release hold is running") {
      let closure = fixture.page.verificationBoom.pose?.closure ?? 0
      return closure > 0 && closure < 1
    }
    fixture.page.open()
    try await until("the clamp is closed on the lug again") {
      fixture.page.verificationBoom.pose?.closure == 1 && !fixture.page.verificationRack.moving
    }
    XCTAssertEqual(fixture.page.window?.frame.origin, home.origin, "still home")
    for (index, sample) in ticks.samples.enumerated() where sample.slide < 1 || sample.frame.origin != home.origin {
      XCTAssertEqual(sample.closure, 0, "tick \(index) moved with the clamp \(sample.closure) not open")
    }
    fixture.page.verificationRackDrawn = nil
    XCTAssertEqual(failures, [])
  }

  /// Reduce Motion: the detach releases the clamp and lands at once.
  func testReduceMotionDetachReleasesTheClampAtOnce() throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    let window = try open(fixture)
    var landing: CockpitDetachLanding.Plan?
    fixture.page.verificationLanding = { landing = $0 }
    fixture.page.setAttached(false)
    XCTAssertEqual(window.frame, try XCTUnwrap(landing).frame, "landed at once")
    XCTAssertNil(fixture.page.verificationBoom.pose, "the boom is gone at once")
    XCTAssertFalse(fixture.page.verificationRack.moving)
    XCTAssertEqual(failures, [])
  }

  private final class Ticks { var samples: [(closure: CGFloat, slide: CGFloat, frame: CGRect)] = [] }
  /// Every rack redraw (each 60 Hz tick of a motion) with the clamp, the slide and the cockpit's frame at that moment.
  private func record(_ fixture: Fixture, _ window: NSWindow) -> Ticks {
    let ticks = Ticks()
    fixture.page.verificationRackDrawn = {
      ticks.samples.append((fixture.page.verificationBoom.pose?.closure ?? 0, fixture.page.verificationRack.ext, window.frame))
    }
    return ticks
  }
  /// While the clamp is not fully open the cockpit's top-left and the boom stay home; the first tick that moves either
  /// one has the clamp fully open.
  private func assertClampOpensBeforeDeparture(_ samples: [(closure: CGFloat, slide: CGFloat, frame: CGRect)], home: CGRect,
                                               label: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThan(samples.count, 4, "\(label): ticks were observed", file: file, line: line)
    XCTAssertEqual(samples.first?.closure ?? 0, 1, accuracy: 0.2, "\(label): starts closed", file: file, line: line)
    var sawPartlyOpen = false
    for (index, sample) in samples.enumerated() {
      let moved = abs(sample.frame.minX - home.minX) > 0.01 || abs(sample.frame.maxY - home.maxY) > 0.01 || sample.slide < 1
      if sample.closure > 0, sample.closure < 1 { sawPartlyOpen = true }
      if moved {
        XCTAssertEqual(sample.closure, 0, "\(label): tick \(index) moved with the clamp \(sample.closure) not open", file: file, line: line)
      }
    }
    XCTAssertTrue(sawPartlyOpen, "\(label): the clamp visibly opened in place", file: file, line: line)
    XCTAssertTrue(samples.contains { $0.slide < 1 }, "\(label): then the boom left", file: file, line: line)
  }

  /// Owner 11-18: with the shutter closed, the rack must not show below the closed cockpit's top edge at any frame of the
  /// open (it used to hang 27-32 pt into empty space from ~83 ms until the cockpit covered it at ~364 ms).
  func testClosedShutterIconOpenNeverShowsRackBelowTheClosedTopEdge() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    fixture.session.shutterClosed = true
    let window = try open(fixture)
    let home = try XCTUnwrap(CockpitShellLayout.fit(usable: fixture.usable, anchor: fixture.icon, shutterClosed: true, screenWidth: fixture.screenWidth)?.frame)
    var sampled = 0
    for _ in 0..<30 {
      if let mask = fixture.page.verificationRackMask, let panel = fixture.page.verificationRack.panel {
        let maskTop = panel.maxY - mask.minY
        XCTAssertEqual(maskTop, home.maxY, accuracy: 0.5, "rack mask line is the closed slab's top edge")
        sampled += 1
      }
      try await wait(20)
    }
    XCTAssertGreaterThan(sampled, 5, "the rack was on screen while sampled")
    try await wait(300)
    XCTAssertEqual(window.frame, home)
    let layout = try XCTUnwrap(fixture.page.verificationLayout)
    XCTAssertEqual(layout.rackMaskDrop, 0)
    XCTAssertEqual(failures, [])
  }

  /// Owner 11-18: a shutter toggle while attached moves the rack's mask line with the slab, not in one step. Observed
  /// after each rack redraw driven by the shutter's frame animation, with monotonic times, the actual window
  /// height and the actual mask position at each one; no assumption about how often the main queue gets to run (CI
  /// coalesced 4 ms sleeps into steps of several points). The line must be the function of the window height at every
  /// observation (so it never moves independently of the slab), the height must pass through in-between values, and
  /// the line must end at the closed top edge.
  func testShutterToggleWhileAttachedMovesTheRackMaskLineSmoothly() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    // A 720 pt room: the open cockpit, scaled down (D444: no short version), even on a short CI desktop.
    let usable = CGRect(x: fixture.usable.minX, y: fixture.usable.maxY - 720, width: fixture.usable.width, height: 720)
    fixture.page.verificationPlacement = (usable: usable, anchor: fixture.icon)
    fixture.page.updateAppearance(.init(theme: .night, locale: .en, profile: .full, size: .percent80))
    let window = try open(fixture)
    try await until("the attached entrance is settled") {
      window.alphaValue == 1 && fixture.page.verificationRack.ext == 1 && !fixture.page.verificationRack.moving
    }
    let openLayout = try XCTUnwrap(fixture.page.verificationLayout)
    let total = openLayout.rackMaskDrop
    XCTAssertFalse(openLayout.forcedClosed)
    XCTAssertGreaterThan(total, 0)
    func line() -> CGFloat? {
      guard let mask = fixture.page.verificationRackMask, let panel = fixture.page.verificationRack.panel else { return nil }
      return window.frame.maxY - (panel.maxY - mask.minY)
    }
    struct Observation { let time: TimeInterval, height: CGFloat, line: CGFloat }
    var seen: [Observation] = []
    fixture.page.verificationRackDrawn = {
      if let value = line() { seen.append(.init(time: ProcessInfo.processInfo.systemUptime, height: window.frame.height, line: value)) }
    }
    defer { fixture.page.verificationRackDrawn = nil }
    let openHeight = window.frame.height
    fixture.page.toggleShutter()
    let closedLayout = try XCTUnwrap(fixture.page.verificationLayout)
    try await until("the shutter is settled at its closed height") {
      !fixture.page.shutterMoving && window.frame.height == closedLayout.frame.height
    }
    XCTAssertGreaterThanOrEqual(seen.count, 2, "the shutter's frame animation reported its progress")
    for (previous, next) in zip(seen, seen.dropFirst()) {
      XCTAssertGreaterThanOrEqual(next.time, previous.time, "monotonic observation times")
      XCTAssertLessThanOrEqual(next.height, previous.height + 0.001, "the slab only moves one way")
    }
    for item in seen {
      XCTAssertEqual(item.line, openLayout.rackMaskDrop(windowHeight: item.height), accuracy: 0.5,
                     "the mask line is the slab's own position at every observation, never an independent step")
    }
    XCTAssertTrue(seen.contains { $0.height < openHeight - 0.5 && $0.height > closedLayout.frame.height + 0.5 },
                  "the window passes through in-between heights")
    XCTAssertTrue(seen.contains { $0.line > 0.1 && $0.line < total - 0.1 }, "and so does the line")
    XCTAssertEqual(try XCTUnwrap(line()), 0, accuracy: 0.5, "closed: the line ends at the slab's top edge")
    XCTAssertEqual(failures, [])
  }

  /// D186/D188 as amended by D299: from the icon, the page is ordered in at the click (alpha 0, so it prepares) while the
  /// rack's visible part extends; the cockpit comes out from under the bar before the rack is out, and the whole open
  /// takes about 0.37 s. Attached: 10 pt under the bar, the rack hanging from the icon over the left shoulder. The close
  /// reverses it.
  func testIconOpenExtendsTheRackFirstThenTheCockpitAndTheCloseReverses() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    var entrances: [String] = []
    fixture.page.verificationEntrance = { entrances.append($0) }
    let window = try open(fixture)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertEqual(entrances, ["rack"])
    XCTAssertTrue(window.isVisible, "the page is prepared from the click")
    XCTAssertEqual(window.alphaValue, 0, "but not shown at the click: the rack leads")
    XCTAssertNil(fixture.page.attachmentHintAnchor)
    // D299's order at every sample (rack first, cockpit from 0.12 s, both end together) is pinned deterministically by
    // CockpitLaunchRackTests on `openProgress`. Here the live window is polled until each effect shows, never sampled at
    // a fixed wall-clock instant: a busy runner's main thread can delay the first 60 Hz tick past 50 ms (run 44887387735).
    try await until("the rack's visible part is extending") { fixture.page.verificationRack.ext > 0 }
    try await until("the cockpit comes out (D299)") { window.alphaValue > 0 }
    try await wait(400)
    XCTAssertEqual(window.alphaValue, 1)
    XCTAssertEqual(window.frame, home, "settled at its attached place")
    XCTAssertEqual(window.frame.maxY, fixture.usable.maxY - 10, "10 pt below the menu bar")
    let rack = fixture.page.verificationRack
    XCTAssertEqual(rack.ext, 1)
    let panel = try XCTUnwrap(rack.panel, "the rack hangs from the icon")
    XCTAssertEqual(panel.midX, fixture.icon.midX, accuracy: 1)
    XCTAssertEqual(panel.maxY, fixture.icon.minY, accuracy: 0.5, "from the menu bar's edge")
    if let layout = fixture.page.verificationLayout, home.minX > fixture.usable.minX, home.maxX < fixture.usable.maxX {
      XCTAssertEqual(layout.shoulder.x, fixture.icon.midX, accuracy: 0.5, "over the LEFT canopy shoulder")
    }
    XCTAssertNotNil(fixture.page.attachmentHintAnchor)

    try await until("the clamp is closed on the lug") { fixture.page.verificationBoom.pose?.closure == 1 }
    var closes: [TimeInterval] = []
    fixture.page.verificationCloseStarted = { closes.append($0) }
    fixture.page.requestClose()
    XCTAssertEqual(closes.count, 1)
    XCTAssertEqual(closes.first ?? 0, CockpitDockingBoom.clampTravel + 0.5, accuracy: 1e-9,
                   "the clamp opens (0.14 s, D439), the cockpit goes up (0.25 s), then the boom retracts (0.25 s)")
    try await wait(300)
    XCTAssertNotNil(fixture.page.window)
    XCTAssertGreaterThan(fixture.page.window?.frame.minY ?? 0, home.minY, "the cockpit goes back up under the bar")
    try await wait(700)
    XCTAssertNil(fixture.page.window)
    XCTAssertEqual(failures, [])
  }

  /// D181/D187: the key detach burns the nozzles about 0.6 s, the cockpit lands at the first spot fully on screen out of
  /// the catch zone, the rack retracts into the icon. The put-back key lights the nozzles at the press; the cockpit flies
  /// home, the rack extends and catches it, and the nozzles go out once it is latched.
  func testKeyDetachLandsOnScreenAndKeyPutBackIsCaughtByTheRack() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await wait(800)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertEqual(window.frame, home)
    var ignition: [Bool] = [], landing: CockpitDetachLanding.Plan?
    fixture.page.verificationIgnition = { ignition.append($0) }
    fixture.page.verificationLanding = { landing = $0 }

    fixture.page.setAttached(false) // the strip key while attached (icon: the arm swung down)
    XCTAssertFalse(fixture.page.isAttached)
    XCTAssertEqual(ignition, [true], "the nozzles light at the press")
    let plan = try XCTUnwrap(landing)
    XCTAssertTrue(fixture.usable.contains(plan.frame), "the landing is fully on screen")
    XCTAssertGreaterThanOrEqual(hypot(plan.frame.minX - home.minX, plan.frame.maxY - home.maxY), 56 - 0.01)
    XCTAssertNotEqual(plan.rule, .minimum, "a normal screen has room for a regular landing")
    XCTAssertEqual(plan.frame.size, home.size, "D444: a detach keeps the attached size")
    let detachedLayout = try XCTUnwrap(fixture.page.verificationLayout)
    XCTAssertEqual(detachedLayout.profile, .full, "D444: a detached cockpit never switches layout")
    XCTAssertEqual(fixture.page.verificationShellState?.tier, .tall)
    try await wait(300)
    XCTAssertEqual(ignition, [true], "still burning mid-move")
    XCTAssertNotEqual(window.frame, home); XCTAssertNotEqual(window.frame, plan.frame)
    try await wait(600)
    XCTAssertEqual(window.frame, plan.frame, "landed")
    XCTAssertEqual(ignition, [true, false], "a short burn, out when the move ends")
    XCTAssertEqual(fixture.page.verificationRack.ext, 0, "the rack retracted into the icon")
    XCTAssertNil(fixture.page.verificationRack.panel)
    XCTAssertFalse(fixture.page.inCatchZone(window.frame), "never ambiguous: out of the catch zone")

    fixture.page.setAttached(true) // the strip key while detached (icon: the arm holding the rocket)
    XCTAssertEqual(ignition, [true, false, true], "lit at the press")
    XCTAssertFalse(fixture.page.isAttached, "flying home")
    try await wait(2_600)
    XCTAssertTrue(fixture.page.isAttached, "caught and latched")
    XCTAssertEqual(window.frame, home)
    XCTAssertEqual(fixture.page.verificationRack.ext, 1)
    XCTAssertEqual(ignition, [true, false, true, false], "burning until latched, then out")
    XCTAssertEqual(failures, [])
  }

  /// D178/D181/D187: a drag tears off and the rack retracts; dragged back near home the rack extends and the nozzles
  /// light (no snap guide); the zone acts only on the release, and the cockpit snaps straight up and latches.
  /// Found-by post-merge sampling 2026-11-19 S12: a drag during the rack-first entrance ends it at once; the open's
  /// animation-complete receipt is still given (once), not lost with the cancelled motion.
  func testDragDuringTheEntranceStillGivesTheAnimationCompleteReceipt() async throws {
    let fixture = try make()
    defer { fixture.page.discard(); CockpitTimingLog.verificationLine = nil }
    var lines: [String] = []
    CockpitTimingLog.verificationLine = { lines.append($0) }
    _ = try open(fixture)
    try await wait(100)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertFalse(lines.contains { $0.hasPrefix("open stage=animation-complete") })
    fixture.page.titleDrag(.began, point: CGPoint(x: home.minX + 120, y: home.maxY - 16))
    XCTAssertEqual(lines.filter { $0.hasPrefix("open stage=animation-complete") }.count, 1)
    try await wait(900)
    XCTAssertEqual(lines.filter { $0.hasPrefix("open stage=animation-complete") }.count, 1)
  }

  func testDragPutBackExtendsTheRackInTheZoneAndLatchesOnRelease() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await wait(800)
    let home = try XCTUnwrap(fixture.home)
    var ignition: [Bool] = []
    fixture.page.verificationIgnition = { ignition.append($0) }
    let grab = CGPoint(x: home.minX + 120, y: home.maxY - 16)
    // Fix main (0b82b5e6): D444 scales the one full layout to fill a short display's height (the hosted runner's), so a
    // straight-down drag is clamped inside the 40 pt catch zone and never arms the put back. Tear off down AND sideways
    // toward the roomier side, so the drag leaves the zone on any display.
    let side: CGFloat = fixture.usable.maxX - home.maxX >= home.minX - fixture.usable.minX ? 200 : -200
    let away = CGPoint(x: grab.x + side, y: grab.y - 200)
    fixture.page.titleDrag(.began, point: grab)
    fixture.page.titleDrag(.moved, point: away)
    XCTAssertFalse(fixture.page.isAttached)
    XCTAssertFalse(fixture.page.inCatchZone(window.frame), "the tear-off leaves the catch zone (\(window.frame) from \(home))")
    XCTAssertEqual(fixture.page.verificationRack.target, 0, "tear-off: the rack retracts into the icon")
    XCTAssertEqual(ignition, [])
    let near = CGPoint(x: grab.x + 10, y: grab.y - 20)
    fixture.page.titleDrag(.moved, point: near)
    XCTAssertTrue(fixture.page.inCatchZone(window.frame))
    XCTAssertEqual(fixture.page.verificationRack.target, 1, "inside the zone the rack reaches down")
    XCTAssertEqual(ignition, [true], "and the nozzles light as it starts to extend")
    XCTAssertFalse(fixture.page.isAttached, "no snap by proximity: only the release")
    fixture.page.titleDrag(.moved, point: away)
    XCTAssertEqual(fixture.page.verificationRack.target, 0, "out of the zone it retracts")
    XCTAssertEqual(ignition, [true, false])
    fixture.page.titleDrag(.moved, point: near)
    fixture.page.titleDrag(.ended, point: near)
    try await wait(1_200)
    XCTAssertTrue(fixture.page.isAttached, "released in the zone: straight up and latched")
    XCTAssertEqual(window.frame, home)
    XCTAssertEqual(ignition.last, false, "out once latched")
    XCTAssertEqual(failures, [])
  }

  /// G3-130 (owner, 11-18): the put back starts the rack and the flight together, both at their normal speeds; the
  /// cockpit never waits. Before, the rack started only once the cockpit was in the catch zone. Sampled on the real
  /// window and rack: the cockpit lands at its motion time; after a long key flight the rack is fully out at the
  /// landing, after a ride home released at once it is partly out and carries on smoothly to fully out; it never jumps.
  func testThePutBackStartsTheRackWithTheFlightAndNeverWaits() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await wait(800)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertEqual(window.frame, home)

    // Long: the strip key's put back after a key detach (a flight of 0.82 s or more).
    fixture.page.setAttached(false)
    try await wait(1_000)
    XCTAssertEqual(fixture.page.verificationRack.ext, 0, "retracted after the detach")
    let long = try await samplePutBack(fixture, window, home, "key put back") {
      fixture.page.setAttached(true)
      XCTAssertEqual(fixture.page.verificationRack.target, 1, "the rack starts unfolding at the press, not when the cockpit nears")
    }
    XCTAssertEqual(long.extAtLanding, 1, "long flight: the rack is fully out at the moment the cockpit lands")
    XCTAssertTrue(long.sawPartial, "long flight: the rack unfolded through partial extensions, it did not jump")

    // Short: a drag torn off, brought back into the catch zone and released at once (a 0.3 s ride home).
    let grab = CGPoint(x: home.minX + 120, y: home.maxY - 16)
    fixture.page.titleDrag(.began, point: grab)
    fixture.page.titleDrag(.moved, point: CGPoint(x: grab.x, y: grab.y - 200))
    XCTAssertFalse(fixture.page.isAttached)
    try await wait(700)
    XCTAssertEqual(fixture.page.verificationRack.ext, 0, "retracted after the tear-off")
    let near = CGPoint(x: grab.x + 10, y: grab.y - 20)
    let short = try await samplePutBack(fixture, window, home, "drag released in the zone") {
      fixture.page.titleDrag(.moved, point: near)
      fixture.page.titleDrag(.ended, point: near)
    }
    XCTAssertGreaterThan(short.extAtLanding, 0, "short ride: the rack started with the ride, not after it")
    XCTAssertLessThan(short.extAtLanding, 1, "short ride: the cockpit lands while the rack is still extending, never waiting for it")
    XCTAssertTrue(short.sawPartial, "short ride: the rack unfolded through partial extensions, it did not jump")
    XCTAssertEqual(failures, [])
  }
  /// G3-156 (owner, build 2): the rack is ALWAYS behind the cockpit: the icon open, the key detach, the key put back,
  /// the drag tear-off and drag put back, and the close. Observed on every rack placement (each 60 Hz frame of every
  /// motion, `verificationRackDrawn`) on the real window server order, not at wall-clock instants; each phase waits
  /// for its end state by polling. Before the fix a detaching or flying cockpit (`.normal`, G3-102) sat under a rack
  /// left at the attached level, which drew over its canopy.
  func testTheRackStaysBehindTheCockpitInEveryPhaseAndBothDirections() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    var phase = "icon open", behind: [String: [Bool]] = [:]
    fixture.page.verificationRackDrawn = {
      if let value = fixture.page.verificationRackBehindCockpit { behind[phase, default: []].append(value) }
    }
    defer { fixture.page.verificationRackDrawn = nil }
    func settle(_ what: String, seconds: Int = 4, _ condition: @MainActor () -> Bool) async throws {
      let deadline = ContinuousClock.now + .seconds(seconds)
      while ContinuousClock.now < deadline, !condition() { try await Task.sleep(for: .milliseconds(4)) }
      XCTAssertTrue(condition(), "never happened: \(what)")
    }
    let window = try open(fixture)
    let home = try XCTUnwrap(fixture.home)
    try await settle("open settled") { window.alphaValue == 1 && window.frame == home && fixture.page.verificationRack.ext == 1 && !fixture.page.verificationRack.moving }

    phase = "key detach"
    fixture.page.setAttached(false)
    XCTAssertEqual(fixture.page.verificationRackBehindCockpit, true, "behind at the press, the frame the level drops")
    try await settle("detached, rack in") { fixture.page.verificationRack.panel == nil && !fixture.page.verificationRack.moving }

    phase = "key put back"
    fixture.page.setAttached(true)
    try await settle("latched, rack out") { fixture.page.isAttached && fixture.page.verificationRack.ext == 1 && !fixture.page.verificationRack.moving }

    phase = "drag tear-off"
    let grab = CGPoint(x: home.minX + 120, y: home.maxY - 16)
    fixture.page.titleDrag(.began, point: grab)
    fixture.page.titleDrag(.moved, point: CGPoint(x: grab.x, y: grab.y - 200))
    try await settle("torn off, rack in") { fixture.page.verificationRack.panel == nil }

    phase = "drag put back"
    let near = CGPoint(x: grab.x + 10, y: grab.y - 20)
    fixture.page.titleDrag(.moved, point: near)
    fixture.page.titleDrag(.ended, point: near)
    try await settle("latched again") { fixture.page.isAttached && fixture.page.verificationRack.ext == 1 && !fixture.page.verificationRack.moving }

    phase = "close"
    fixture.page.requestClose()
    try await settle("closed") { fixture.page.window == nil }

    for name in ["icon open", "key detach", "key put back", "drag tear-off", "drag put back", "close"] {
      let samples = behind[name] ?? []
      XCTAssertGreaterThan(samples.count, 1, "\(name): the rack was on screen and sampled")
      XCTAssertEqual(samples.filter { !$0 }.count, 0, "\(name): the rack was in front of the cockpit on \(samples.filter { !$0 }.count) of \(samples.count) frames")
    }
    XCTAssertEqual(failures, [])
  }

  /// D378 (owner, 11-21): with the status item not visible the attached cockpit still has its rack: it hangs from the
  /// menu bar's edge just right of the notch (or where a notch edge would be), over the left shoulder, behind the cockpit.
  func testAHiddenStatusItemOpensUnderTheNotchsRightEdgeWithTheRackBehind() async throws {
    guard let main = NSScreen.main else { throw XCTSkip("needs a display") }
    try await assertHiddenItemOpen(notch: (main.frame.midX + 92).rounded(), label: "notch")
  }
  func testAHiddenStatusItemOnADisplayWithoutANotchOpensRightOfTheMenuBarCentre() async throws {
    try await assertHiddenItemOpen(notch: nil, label: "no notch")
  }
  private func assertHiddenItemOpen(notch: CGFloat?, label: String, file: StaticString = #filePath, line: UInt = #line) async throws {
    let fixture = try make(hiddenItemNotch: .some(notch))
    defer { fixture.page.discard() }
    let main = try XCTUnwrap(NSScreen.main)
    let edge = notch ?? (main.frame.midX + CockpitShellLayout.nominalNotchHalfWidth).rounded()
    XCTAssertEqual(fixture.icon.minX, edge, "\(label): anchored at the edge", file: file, line: line)
    XCTAssertEqual(fixture.page.rackIcon(), fixture.icon, "\(label): the rack hangs there although the item is hidden", file: file, line: line)
    var behind: [Bool] = []
    fixture.page.verificationRackDrawn = { if let value = fixture.page.verificationRackBehindCockpit { behind.append(value) } }
    defer { fixture.page.verificationRackDrawn = nil }
    let window = try open(fixture)
    let home = try XCTUnwrap(fixture.home)
    try await until("\(label): open settled", file: file, line: line) {
      window.alphaValue == 1 && window.frame == home && fixture.page.verificationRack.ext == 1 && !fixture.page.verificationRack.moving
    }
    let panel = try XCTUnwrap(fixture.page.verificationRack.panel, "\(label): the rack is out", file: file, line: line)
    XCTAssertEqual(panel.minX, edge, accuracy: 0.5, "\(label): its left side on the notch's right edge", file: file, line: line)
    XCTAssertEqual(panel.width, CockpitDockingBoom.edgeAnchorWidth, "\(label): the edge anchor's own width, not the widest status width", file: file, line: line)
    XCTAssertEqual(panel.maxY, fixture.usable.maxY, accuracy: 0.5, "\(label): from the menu bar's edge", file: file, line: line)
    if let layout = fixture.page.verificationLayout, home.minX > fixture.usable.minX, home.maxX < fixture.usable.maxX {
      XCTAssertEqual(layout.shoulder.x, panel.midX, accuracy: 0.5, "\(label): over the left shoulder", file: file, line: line)
    }
    XCTAssertGreaterThan(behind.count, 1, "\(label): sampled while the rack was out", file: file, line: line)
    XCTAssertFalse(behind.contains(false), "\(label): the rack stays behind the cockpit", file: file, line: line)
    XCTAssertEqual(fixture.page.verificationRackBehindCockpit, true, file: file, line: line)
    XCTAssertEqual(failures, [], file: file, line: line)
  }

  /// Runs `press` (the put back) and samples the window and rack until the cockpit is latched. The proof is the order of
  /// the observed states, never elapsed time (a slow hosted runner stretches every gap, and the old wall-clock bounds on
  /// landing, pace and jump flaked there). Returns the
  /// rack's extension at the exact moment the cockpit landed (read in the motion's completion, `verificationLanded`, not
  /// sampled) and whether any partial extension (0 < ext < 1) was observed; an instant jump or a rack the flight waits
  /// for fails these. The rack never moves back and never exceeds 1; the 6 s deadline only
  /// guards against a hang.
  private func samplePutBack(_ fixture: Fixture, _ window: NSWindow, _ home: CGRect, _ label: String,
                             file: StaticString = #filePath, line: UInt = #line,
                             press: () -> Void) async throws -> (extAtLanding: CGFloat, sawPartial: Bool) {
    let deadline = ContinuousClock.now + .seconds(6)
    var extAtLanding: CGFloat?
    fixture.page.verificationLanded = { extAtLanding = $0 }
    defer { fixture.page.verificationLanded = nil }
    press()
    XCTAssertLessThan(fixture.page.verificationRack.ext, 1, "\(label): the rack does not jump out at the press", file: file, line: line)
    var sawPartial = false, last = fixture.page.verificationRack.ext
    while ContinuousClock.now < deadline {
      let ext = fixture.page.verificationRack.ext
      XCTAssertGreaterThanOrEqual(ext, last, "\(label): the rack never moves back", file: file, line: line)
      XCTAssertLessThanOrEqual(ext, 1, "\(label): the rack never overshoots", file: file, line: line)
      XCTAssertEqual(fixture.page.verificationRack.target, 1, "\(label): the rack's target stays out", file: file, line: line)
      last = ext
      if ext > 0, ext < 1 { sawPartial = true }
      if fixture.page.isAttached { break }
      try await Task.sleep(for: .milliseconds(4))
    }
    XCTAssertTrue(fixture.page.isAttached, "\(label): caught and latched", file: file, line: line)
    XCTAssertEqual(window.frame, home, file: file, line: line)
    XCTAssertEqual(fixture.page.verificationRack.ext, 1, "\(label): the rack ends fully out", file: file, line: line)
    return (try XCTUnwrap(extAtLanding, "\(label): landed", file: file, line: line), sawPartial || (extAtLanding ?? 0) < 1)
  }

  /// D454 (owner, 2026-11-26): the reserve under the hull holds the whole flame and never takes a click. Over the
  /// flame-only strip the real window ignores the mouse (the click reaches what is beneath) and a press there counts as
  /// outside; over the bell row and the hull it takes the mouse as before. Attached and detached alike.
  func testD454TheFlameStripPassesClicksThrough() async throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await wait(400)
    let layout = try XCTUnwrap(fixture.page.verificationLayout)
    XCTAssertEqual(window.frame, try XCTUnwrap(fixture.home), "attached at home, the whole window (hull and flame) on screen")
    XCTAssertTrue(fixture.usable.contains(window.frame), "attached, the whole flame is inside the visible frame")
    let strip = layout.passThroughHeight
    XCTAssertGreaterThanOrEqual(strip, ((CockpitShellLayout.baseReserve - CockpitShellLayout.bellRow) * layout.scale).rounded(.down) - 1)
    func check(_ label: String) {
      let f = window.frame
      fixture.page.syncPassThrough(at: CGPoint(x: f.midX, y: f.minY + 1))
      XCTAssertTrue(window.ignoresMouseEvents, "\(label): the bottom of the flame strip passes clicks through")
      fixture.page.syncPassThrough(at: CGPoint(x: f.minX + 2, y: f.minY + strip - 1))
      XCTAssertTrue(window.ignoresMouseEvents, "\(label): the top of the flame strip, at the window's edge, too")
      fixture.page.syncPassThrough(at: CGPoint(x: f.midX, y: f.minY + strip + 1))
      XCTAssertFalse(window.ignoresMouseEvents, "\(label): the bell row takes the mouse (hover names)")
      fixture.page.syncPassThrough(at: CGPoint(x: f.midX, y: f.minY + layout.hullBottomInset + 40))
      XCTAssertFalse(window.ignoresMouseEvents, "\(label): the hull takes the mouse")
      fixture.page.syncPassThrough(at: CGPoint(x: f.midX, y: f.minY - 5))
      XCTAssertFalse(window.ignoresMouseEvents, "\(label): outside the window nothing is ignored")
    }
    check("attached")
    fixture.page.setAttached(false)
    XCTAssertFalse(fixture.page.isAttached)
    XCTAssertEqual(fixture.page.verificationLayout?.passThroughHeight, strip, "a detach keeps the layout")
    check("detached")
    fixture.page.setAttached(true)
    XCTAssertTrue(fixture.page.isAttached, "Reduce Motion: latched at once")
    XCTAssertEqual(window.frame, try XCTUnwrap(fixture.home), "put back: the hull is home, nothing moved")
    check("put back")
    // Last, as it may close the cockpit: a press on the flame strip is a press on what is beneath, so attached it counts
    // as an outside press; a press on the hull does not.
    var outside = 0
    fixture.page.verificationOutsidePress = { _, _ in outside += 1 }
    let home = window.frame
    fixture.page.localPress(in: window, at: CGPoint(x: home.midX, y: home.minY + layout.hullBottomInset + 40), eventType: .rightMouseDown)
    XCTAssertEqual(outside, 0, "a press on the hull is the cockpit's own")
    fixture.page.localPress(in: nil, at: CGPoint(x: home.midX, y: home.minY + 1), eventType: .rightMouseDown)
    XCTAssertEqual(outside, 1, "a press on the flame strip is outside the cockpit")
    XCTAssertEqual(failures, [])
  }
}
#endif
