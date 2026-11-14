// SPDX-License-Identifier: MIT
import AppKit
import WebKit
import XCTest
@testable import ModelPlanCockpitWeb

/// G3-108 (owner, build 14e): opening or closing the porthole made the whole cockpit jump. The window frame changed in
/// one frame and the page moved the body in a later one, and the content was laid out for one size while the window had
/// another. Now the web view keeps the open canvas on the window's bottom edge (the page keeps the body at one place on
/// it, g3-108-shutter-motion.spec.mjs), so only the window frame moves the body, and only as the owner asked:
/// - attached (D88 / CKP-SHELL-07: the window hangs 6 pt below the menu bar icon): the top edge stays, the bottom edge
///   and the body slide up on close and down on open, in one 250 ms motion, never rescaled;
/// - detached (D88 / CKP-SHELL-05: a detached cockpit keeps its place): the bottom edge and the body stay, only the top
///   edge moves; with too little room above for the open porthole, the body comes down by the shortfall only;
/// - Reduce Motion (CKP-MOT-03): the final frame at once.
/// The real panel and controller on the real screen with a synthetic page. Window server: GUI leg.
@MainActor final class CockpitShutterMotionTests: XCTestCase {
  private struct Fixture { let page: CockpitWindowController, session: CockpitShellSession, usable: CGRect }
  private var failures: [CockpitWindowFailure] = []
  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-g3-108-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  private func open(reduceMotion: Bool) throws -> (Fixture, NSWindow) {
    _ = NSApplication.shared
    guard let screen = NSScreen.main else { throw XCTSkip("needs a display") }
    let usable = screen.visibleFrame
    guard usable.height > 700 else { throw XCTSkip("needs room for the full cockpit") }
    let icon = CGRect(x: usable.midX - 14, y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let session = CockpitShellSession(); session.nextEntrance = .fade
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: reduceMotion), shellSession: session, anchor: { icon })
    page.onFailure = { [weak self] in self?.failures.append($0) }
    page.open()
    let window = try XCTUnwrap(page.window)
    (window.contentView?.subviews.first as? WKWebView)?.navigationDelegate = nil
    return (Fixture(page: page, session: session, usable: usable), window)
  }
  private func web(_ window: NSWindow) throws -> WKWebView { try XCTUnwrap(window.contentView?.subviews.first as? WKWebView) }
  private struct Sample { let frame: CGRect, bounds: CGSize, web: CGRect }
  /// Samples the window every 5 ms from the toggle until it has held its final frame for 100 ms (at most 2 s).
  private func toggleAndSample(_ fixture: Fixture, _ window: NSWindow) async throws -> [Sample] {
    let content = try XCTUnwrap(window.contentView), view = try web(window)
    var samples = [Sample(frame: window.frame, bounds: content.bounds.size, web: view.frame)]
    fixture.page.toggleShutter()
    let deadline = ContinuousClock.now + .seconds(2)
    var still = 0
    while ContinuousClock.now < deadline, still < 20 {
      samples.append(.init(frame: window.frame, bounds: content.bounds.size, web: view.frame))
      still = samples.count > 1 && samples[samples.count - 2].frame == window.frame && !fixture.page.shutterMoving && !fixture.page.shutterPending ? still + 1 : 0
      try await Task.sleep(for: .milliseconds(5))
    }
    return samples
  }
  private func assertNeverRescaled(_ samples: [Sample], file: StaticString = #filePath, line: UInt = #line) {
    for sample in samples {
      XCTAssertEqual(sample.bounds.width, sample.frame.width, accuracy: 0.5, "the content is never stretched", file: file, line: line)
      XCTAssertEqual(sample.bounds.height, sample.frame.height, accuracy: 0.5, "the content is never stretched", file: file, line: line)
      XCTAssertEqual(sample.web.minY, 0, "the web view stands on the bottom edge", file: file, line: line)
      XCTAssertEqual(sample.web.size, samples[0].web.size, "the page canvas never changes", file: file, line: line)
    }
  }

  /// Attached: the top edge stays under the icon; the body (the window's bottom edge, which carries the web view) slides
  /// up by the porthole band on close, over several frames, and back down on open.
  func testG3_108AttachedTopStaysAndTheBodySlidesByThePortholeBand() async throws {
    let (fixture, window) = try open(reduceMotion: false)
    defer { fixture.page.discard() }
    try await Task.sleep(for: .milliseconds(400))
    let start = window.frame
    let closing = try await toggleAndSample(fixture, window)
    let band = ((253 - CockpitShellLayout.closedSlabBand) * (try web(window).pageZoom)).rounded(.down)
    for sample in closing { XCTAssertEqual(sample.frame.maxY, start.maxY, accuracy: 0.5, "attached, the top edge never moves") }
    XCTAssertEqual(window.frame.minY - start.minY, band, accuracy: 0.5, "the body rose by the porthole band")
    XCTAssertTrue(closing.contains { $0.frame.minY > start.minY + 1 && $0.frame.minY < start.minY + band - 1 },
                  "one smooth motion, not a jump: \(closing.map(\.frame.minY))")
    assertNeverRescaled(closing)
    let opening = try await toggleAndSample(fixture, window)
    for sample in opening { XCTAssertEqual(sample.frame.maxY, start.maxY, accuracy: 0.5) }
    XCTAssertEqual(window.frame, start, "open again, the frame is the open one")
    XCTAssertTrue(opening.contains { $0.frame.minY > start.minY + 1 && $0.frame.minY < start.minY + band - 1 })
    assertNeverRescaled(opening)
    XCTAssertEqual(failures, [])
  }

  /// Detached: the bottom edge (and so the body) never moves; the top edge comes down on close and goes up on open.
  func testG3_108DetachedBodyStaysAndOnlyTheTopEdgeMoves() async throws {
    let (fixture, window) = try open(reduceMotion: false)
    defer { fixture.page.discard() }
    try await Task.sleep(for: .milliseconds(400))
    fixture.page.setAttached(false)
    // Lower it so the porthole has room above in both states.
    window.setFrameOrigin(.init(x: window.frame.minX, y: window.frame.minY - 60))
    let start = window.frame
    let band = ((253 - CockpitShellLayout.closedSlabBand) * (try web(window).pageZoom)).rounded(.down)
    let closing = try await toggleAndSample(fixture, window)
    for sample in closing { XCTAssertEqual(sample.frame.minY, start.minY, accuracy: 0.5, "detached, the body never moves") }
    XCTAssertEqual(window.frame.maxY, start.maxY - band, accuracy: 0.5, "only the top edge came down")
    assertNeverRescaled(closing)
    let opening = try await toggleAndSample(fixture, window)
    for sample in opening { XCTAssertEqual(sample.frame.minY, start.minY, accuracy: 0.5) }
    XCTAssertEqual(window.frame, start)
    assertNeverRescaled(opening)
    XCTAssertEqual(failures, [])
  }

  /// Detached near the top of the screen: the open porthole keeps its full size and the body comes down by the
  /// shortfall only, in the same motion; the next close keeps the body there.
  func testG3_108DetachedOpenUnderTheMenuBarMovesTheBodyByTheShortfallOnly() async throws {
    let (fixture, window) = try open(reduceMotion: false)
    defer { fixture.page.discard() }
    try await Task.sleep(for: .milliseconds(400))
    fixture.page.setAttached(false)
    _ = try await toggleAndSample(fixture, window) // closed
    let closedHeight = window.frame.height
    // Closed, 50 pt below the top of the usable area: the open porthole needs the band, so it is short by band - 50.
    window.setFrameOrigin(.init(x: window.frame.minX, y: fixture.usable.maxY - 50 - closedHeight))
    let before = window.frame
    let band = ((253 - CockpitShellLayout.closedSlabBand) * (try web(window).pageZoom)).rounded(.down)
    let opening = try await toggleAndSample(fixture, window)
    XCTAssertEqual(window.frame.maxY, fixture.usable.maxY, accuracy: 0.5, "the porthole opens to the top of the usable area")
    XCTAssertEqual(before.minY - window.frame.minY, band - 50, accuracy: 0.5, "the body came down by the shortfall only")
    XCTAssertTrue(opening.contains { $0.frame.minY < before.minY - 1 && $0.frame.minY > window.frame.minY + 1 }, "in one motion")
    assertNeverRescaled(opening)
    let after = window.frame
    _ = try await toggleAndSample(fixture, window)
    XCTAssertEqual(window.frame.minY, after.minY, accuracy: 0.5, "the next close keeps the body where it is")
    XCTAssertEqual(failures, [])
  }

  /// Reduce Motion: the final frame at once, on both sides.
  func testG3_108ReduceMotionTogglesAtOnce() throws {
    let (fixture, window) = try open(reduceMotion: true)
    defer { fixture.page.discard() }
    let start = window.frame, view = try web(window), canvas = view.frame
    fixture.page.toggleShutter()
    let band = ((253 - CockpitShellLayout.closedSlabBand) * view.pageZoom).rounded(.down)
    XCTAssertEqual(window.frame.maxY, start.maxY); XCTAssertEqual(window.frame.minY - start.minY, band, accuracy: 0.5)
    XCTAssertEqual(view.frame, canvas, "the page canvas never changes")
    XCTAssertEqual(window.contentView?.bounds.size, window.frame.size)
    fixture.page.toggleShutter()
    XCTAssertEqual(window.frame, start)
    XCTAssertEqual(failures, [])
  }
}
