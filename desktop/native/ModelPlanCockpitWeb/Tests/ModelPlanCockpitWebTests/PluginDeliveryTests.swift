// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

#if MODELPLAN_TEST_ONLY_SPI
/// #1104 review: the window controller's plugin delivery (macrevd-1104-2/-3, macrevb-1104-3, macrev2-1104-4/-5/-6).
/// Drives the real controller, ordered queue and bridge on a no-window page.
@MainActor final class PluginDeliveryTests: XCTestCase {
  private let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  private let stateA = Data(#"{"entries":[{"enabled":true,"id":"placeholder","pinned":true}],"settings":{},"version":1}"#.utf8)
  private let stateB = Data(#"{"entries":[{"enabled":false,"id":"placeholder","pinned":false}],"settings":{},"version":1}"#.utf8)
  private final class Box { var sent: [(String, (CockpitDeliveryResult) -> Void)] = []; var intents: [CockpitIntent] = []; var failures: [CockpitWindowFailure] = [] }
  private var sequence = 0
  /// A page message with only the common header of `raw` (a host message under the current context).
  private func pageMessage(_ raw: String, _ type: String, extra: [String: Any] = [:]) throws -> String {
    let host = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    var value: [String: Any] = [:]
    for key in ["version", "pageId", "requestId", "sessionId", "storeEpoch", "generation", "viewRevision"] { value[key] = host[key] }
    sequence += 1
    value["type"] = type; value["sequence"] = String(sequence)
    if type == "ready" { value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"] }
    for (key, field) in extra { value[key] = field }
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  private func type(_ raw: String) -> String? { (try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])?["type"] as? String }
  private func pluginsBody(_ raw: String) -> Data? {
    guard let body = (try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])?["plugins"] else { return nil }
    return CockpitPluginWire.canonical(body)
  }
  /// A ready, visible, key page; every delivery so far completed.
  private func readyPage() throws -> (CockpitWindowController, Box) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-plugins-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: bundle, context: context, appearance: .init(theme: .night, locale: .en, profile: .full))
    let box = Box()
    page.verificationNoWindowClock = { 1_000 }
    page.verificationNoWindowArm = { _, _ in {} }
    page.verificationNoWindowDelivery = { raw, complete in box.sent.append((raw, complete)) }
    page.onFailure = { box.failures.append($0) }
    page.onIntent = { box.intents.append($0) }
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    page.verificationNoWindowShell = shell
    sequence = 0
    let load = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    _ = try page.bridge.accept(pageMessage(load, "ready"), source: source)
    try page.verificationConfirmVisible()
    page.verificationNoWindowVisibility = .init(visible: true, occluded: false, key: true)
    return (page, box)
  }
  private func completeAll(_ box: Box, from index: inout Int, _ result: CockpitDeliveryResult = .accepted) {
    while index < box.sent.count { let i = index; index += 1; box.sent[i].1(result) }
  }

  /// macrev2-1104-5 / macrevd: a failed delivery is not "on the page"; the newest committed state reaches the page once
  /// the queue moves, and an identical state is skipped only after the page confirmed it.
  func testFailedPluginDeliveryIsResentWhenTheQueueMoves() throws {
    let (page, box) = try readyPage()
    var done = box.sent.count
    page.setPlugins(stateA)
    XCTAssertEqual(type(box.sent.last!.0), "plugins")
    box.sent[done].1(.failed); done += 1
    XCTAssertNil(page.pluginsAccepted, "a failed call never counts as applied")
    // Another delivery completes (a visibility change); the queue has moved, so the state goes again.
    page.verificationSetHostVisibility(.init(visible: true, occluded: false, key: false))
    completeAll(box, from: &done)
    let resent = box.sent.map(\.0).filter { type($0) == "plugins" }
    XCTAssertEqual(resent.count, 2, "the state is sent again once another delivery succeeds")
    XCTAssertEqual(pluginsBody(resent.last!), CockpitPluginWire.canonical(json: stateA))
    XCTAssertEqual(page.pluginsAccepted, CockpitPluginWire.canonical(json: stateA))
    let count = box.sent.count
    page.setPlugins(stateA)
    XCTAssertEqual(box.sent.count, count, "a state the page confirmed is not sent twice")
    // A refused state is not confirmed either; the next change is sent.
    page.setPlugins(stateB)
    box.sent[done].1(.rejected); done += 1
    XCTAssertEqual(page.pluginsAccepted, CockpitPluginWire.canonical(json: stateA))
    page.setPlugins(stateB)
    XCTAssertEqual(type(box.sent.last!.0), "plugins", "a refused state is tried again on the next change")
    XCTAssertEqual(box.failures, [])
    page.discard()
  }

  /// macrevb-1104-3 / macrevd-1104-2: a page edit is not echoed, but a failed save's committed state reaches the page.
  func testPageEditIsNotEchoedAndAFailedSaveRestoresTheCommittedState() throws {
    let (page, box) = try readyPage()
    var done = box.sent.count
    page.setPlugins(stateA); completeAll(box, from: &done)
    let editBody = try XCTUnwrap(JSONSerialization.jsonObject(with: stateB))
    page.verificationReceive(try pageMessage(box.sent.last!.0, "action", extra: ["action": "pluginsEdit", "plugins": editBody]), source: source)
    XCTAssertEqual(box.intents, [.pluginsEdit(try XCTUnwrap(CockpitPluginWire.canonical(json: stateB)))])
    let count = box.sent.count
    page.setPlugins(stateB)
    XCTAssertEqual(box.sent.count, count, "a saved page edit is already on the page")
    // The save failed: the app sends the committed state again, and it reaches the page.
    page.setPlugins(stateA)
    XCTAssertEqual(box.sent.count, count + 1)
    XCTAssertEqual(pluginsBody(box.sent.last!.0), CockpitPluginWire.canonical(json: stateA))
    page.discard()
  }

  /// D124 (macrevb-1104-4, macrev2-1104-6): hiding stops sampling at once; a late start report from before the hide is
  /// refused while a stop is always taken; shown again, a start is accepted.
  func testHideStopsSamplingAndALateStartReportIsRefused() throws {
    let (page, box) = try readyPage()
    var done = box.sent.count
    page.setPlugins(stateA); completeAll(box, from: &done)
    let header = box.sent.last!.0
    page.verificationReceive(try pageMessage(header, "action", extra: ["action": "pluginsRunning", "ids": ["placeholder"]]), source: source)
    XCTAssertEqual(box.intents, [.pluginsRunning(["placeholder"])])
    page.verificationSetHostVisibility(.init(visible: true, occluded: true, key: false))
    XCTAssertEqual(box.intents.last, .pluginsRunning([]), "the host stops before the page has answered")
    let before = box.intents.count
    page.verificationReceive(try pageMessage(header, "action", extra: ["action": "pluginsRunning", "ids": ["placeholder"]]), source: source)
    XCTAssertEqual(box.intents.count, before, "a start posted before the hide is refused after it")
    page.verificationReceive(try pageMessage(header, "action", extra: ["action": "pluginsRunning", "ids": [String]()]), source: source)
    XCTAssertEqual(box.intents.last, .pluginsRunning([]))
    XCTAssertEqual(box.intents.count, before + 1, "a stop is always taken")
    page.verificationSetHostVisibility(.init(visible: true, occluded: false, key: false))
    completeAll(box, from: &done)
    page.verificationReceive(try pageMessage(header, "action", extra: ["action": "pluginsRunning", "ids": ["placeholder"]]), source: source)
    XCTAssertEqual(box.intents.last, .pluginsRunning(["placeholder"]), "shown again, sampling resumes")
    page.discard()
  }

  /// macrev2-1104-6: a privacy clear stops sampling when it starts; afterwards the state is sent to the cleared page.
  func testClearStopsSamplingAtItsStartAndResendsTheState() async throws {
    let (page, box) = try readyPage()
    var done = box.sent.count
    page.setPlugins(stateA); completeAll(box, from: &done)
    _ = done
    let next = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 2)
    let clearing = Task { @MainActor in await page.clearPrivateViews(adopting: next) }
    for _ in 0..<200 where !box.sent.contains(where: { type($0.0) == "clear" }) { await Task.yield() }
    XCTAssertEqual(box.intents.last, .pluginsRunning([]), "sampling stops before the clear is answered")
    let clear = try XCTUnwrap(box.sent.last(where: { type($0.0) == "clear" }))
    clear.1(.accepted)
    page.verificationReceive(try pageMessage(clear.0, "cleared"), source: source)
    await clearing.value
    let clearIndex = try XCTUnwrap(box.sent.firstIndex(where: { type($0.0) == "clear" }))
    XCTAssertTrue(box.sent[(clearIndex + 1)...].contains(where: { type($0.0) == "plugins" }), "the cleared page gets the plugin state again")
    page.discard()
  }
}
#endif
