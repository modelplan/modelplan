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
  private func make(reduceMotion: Bool = false) throws -> Fixture {
    _ = NSApplication.shared
    guard let screen = NSScreen.main else { throw XCTSkip("needs a display") }
    let usable = screen.visibleFrame
    // A status item's frame in the menu bar, left of centre so the cockpit has room on both sides.
    let icon = CGRect(x: (usable.minX + usable.width * 0.4).rounded(), y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let session = CockpitShellSession()
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: reduceMotion), shellSession: session, anchor: { icon })
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
    let drop = CockpitShellLayout.shoulderDrop(layout.profile) * layout.scale
    let hidden = CGRect(x: window.frame.minX, y: window.frame.minY, width: window.frame.width,
                        height: max(0, window.frame.height - drop))
    let expected = CGRect(x: hidden.minX - panel.minX, y: panel.maxY - hidden.maxY,
                          width: hidden.width, height: hidden.height)
    XCTAssertNotEqual(actual, before, "the old mask must not survive a size change")
    XCTAssertEqual(actual, expected, "the rack clips against the resized cockpit")
    XCTAssertEqual(failures, [])
  }

  /// D186/D188: from the icon, the page is ordered in at the click (alpha 0, so it prepares) while the rack's visible part
  /// extends for 0.25 s; then the cockpit comes out from under the bar for 0.25 s. Attached: 10 pt under the bar, the rack
  /// hanging from the icon over the left shoulder. The close reverses it.
  func testIconOpenExtendsTheRackFirstThenTheCockpitAndTheCloseReverses() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    var entrances: [String] = []
    fixture.page.verificationEntrance = { entrances.append($0) }
    let window = try open(fixture)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertEqual(entrances, ["rack"])
    XCTAssertTrue(window.isVisible, "the page is prepared from the click")
    XCTAssertEqual(window.alphaValue, 0, "but not shown while the rack extends")
    XCTAssertNil(fixture.page.attachmentHintAnchor)
    try await wait(150)
    XCTAssertEqual(window.alphaValue, 0, "still the rack's turn")
    XCTAssertGreaterThan(fixture.page.verificationRack.ext, 0, "the rack's visible part is extending")
    XCTAssertLessThanOrEqual(fixture.page.verificationRack.ext, 1.0 / 3 + 0.001, "only its visible part")
    try await wait(250)
    XCTAssertGreaterThan(window.alphaValue, 0, "then the cockpit comes out")
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

    var closes: [TimeInterval] = []
    fixture.page.verificationCloseStarted = { closes.append($0) }
    fixture.page.requestClose()
    XCTAssertEqual(closes, [0.5], "the cockpit goes up (0.25 s), then the rack retracts (0.25 s)")
    try await wait(150)
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
  func testDragPutBackExtendsTheRackInTheZoneAndLatchesOnRelease() async throws {
    let fixture = try make()
    defer { fixture.page.discard() }
    let window = try open(fixture)
    try await wait(800)
    let home = try XCTUnwrap(fixture.home)
    var ignition: [Bool] = []
    fixture.page.verificationIgnition = { ignition.append($0) }
    let grab = CGPoint(x: home.minX + 120, y: home.maxY - 16)
    let away = CGPoint(x: grab.x, y: grab.y - 200)
    fixture.page.titleDrag(.began, point: grab)
    fixture.page.titleDrag(.moved, point: away)
    XCTAssertFalse(fixture.page.isAttached)
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
    let long = try await samplePutBack(fixture, window, home, "key put back", within: 1.3) {
      fixture.page.setAttached(true)
      XCTAssertEqual(fixture.page.verificationRack.target, 1, "the rack starts unfolding at the press, not when the cockpit nears")
    }
    XCTAssertEqual(long.extAtLanding, 1, "long flight: the rack is fully out when the cockpit lands")

    // Short: a drag torn off, brought back into the catch zone and released at once (a 0.3 s ride home).
    let grab = CGPoint(x: home.minX + 120, y: home.maxY - 16)
    fixture.page.titleDrag(.began, point: grab)
    fixture.page.titleDrag(.moved, point: CGPoint(x: grab.x, y: grab.y - 200))
    XCTAssertFalse(fixture.page.isAttached)
    try await wait(700)
    XCTAssertEqual(fixture.page.verificationRack.ext, 0, "retracted after the tear-off")
    let near = CGPoint(x: grab.x + 10, y: grab.y - 20)
    let short = try await samplePutBack(fixture, window, home, "drag released in the zone", within: CockpitLaunchRackTiming.rideHome) {
      fixture.page.titleDrag(.moved, point: near)
      fixture.page.titleDrag(.ended, point: near)
    }
    XCTAssertLessThan(short.extAtLanding, 1, "short ride: the rack is still coming down when the cockpit lands")
    XCTAssertEqual(failures, [])
  }
  /// Runs `press` (the put back) and samples the window and rack every 4 ms until the cockpit is latched, all timed from
  /// just before the press, which is when the rack's own clock can start (macrevb-1038-4: timing from after the press
  /// left out the rack's first, slower frame and read its catch-up as a jump). `within`: the motion's own time; the
  /// landing (the window exactly at home) may be up to 150 ms of timer and sampling latency later. The rack never moves
  /// back, in total never runs ahead of its full-travel pace since the press, and never jumps between two samples (the
  /// 100 ms allowances cover a late tick catching up after a busy main thread).
  private func samplePutBack(_ fixture: Fixture, _ window: NSWindow, _ home: CGRect, _ label: String, within: TimeInterval,
                             file: StaticString = #filePath, line: UInt = #line,
                             press: () -> Void) async throws -> (landed: Duration, extAtLanding: CGFloat) {
    func seconds(_ value: Duration) -> Double { Double(value.components.seconds) + Double(value.components.attoseconds) / 1e18 }
    let full = CockpitLaunchRackTiming.fullTravel
    let started = ContinuousClock.now, deadline = started + .milliseconds(2_600), ext0 = fixture.page.verificationRack.ext
    press()
    var landed: Duration?, extAtLanding: CGFloat = -1
    var last = (time: started, ext: ext0)
    while ContinuousClock.now < deadline {
      let now = ContinuousClock.now, ext = fixture.page.verificationRack.ext
      XCTAssertGreaterThanOrEqual(ext, last.ext, "\(label): the rack never moves back", file: file, line: line)
      XCTAssertLessThanOrEqual(ext - ext0, CGFloat((seconds(now - started) + 0.1) / full),
                               "\(label): the rack never runs ahead of its normal pace", file: file, line: line)
      XCTAssertLessThanOrEqual(ext - last.ext, CGFloat((seconds(now - last.time) + 0.1) / full),
                               "\(label): no jump in the rack", file: file, line: line)
      last = (now, ext)
      if landed == nil, abs(window.frame.minX - home.minX) < 0.01, abs(window.frame.minY - home.minY) < 0.01 {
        landed = now - started; extAtLanding = ext
      }
      if fixture.page.isAttached { break }
      try await Task.sleep(for: .milliseconds(4))
    }
    XCTAssertTrue(fixture.page.isAttached, "\(label): caught and latched", file: file, line: line)
    let landing = try XCTUnwrap(landed, "\(label): landed", file: file, line: line)
    XCTAssertLessThanOrEqual(landing, .milliseconds(Int(within * 1_000) + 150), "\(label): the cockpit did not wait for the rack",
                             file: file, line: line)
    XCTAssertEqual(window.frame, home, file: file, line: line)
    XCTAssertEqual(fixture.page.verificationRack.ext, 1, "\(label): the rack ends fully out", file: file, line: line)
    return (landing, extAtLanding)
  }
}
#endif
