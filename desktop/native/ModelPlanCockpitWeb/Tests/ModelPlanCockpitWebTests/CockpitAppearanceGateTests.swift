// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

@MainActor final class CockpitAppearanceGateTests: XCTestCase {
  private let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  private func reply(_ raw: String, type: String, sequence: Int, extra: [String: Any] = [:]) throws -> String {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    for key in ["data", "appearance", "shell", "theme", "locale", "reduceMotion", "reduceTransparency", "redBelow", "nowUnixMs", "reason"] { value[key] = nil }
    value["type"] = type; value["sequence"] = String(sequence)
    if type == "ready" { value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"] }
    for (key, field) in extra { value[key] = field }
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  private func ready() throws -> CockpitBridgeState {
    let state = CockpitBridgeState(context: try .init(sessionID: UUID(), storeEpoch: "synthetic", generation: 1))
    let load = try state.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
    _ = try state.accept(reply(load, type: "ready", sequence: 1), source: source)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: false))
    return state
  }
  private func fixture() throws -> WireCockpitData {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: url))
  }
  func testDisplayCompletionBeforeRenderedDefersAppearanceForBothReceiptOrders() throws {
    for reportBeforeAck in [true, false] {
      let state = try ready(); var gate = CockpitAppearanceGate()
      var completions: [(CockpitDeliveryResult) -> Void] = [], sent: [String] = []
      let delivery = CockpitOrderedDelivery<String>(deliver: { raw, done in sent.append(raw); completions.append(done) })
      let display = try state.display(fixture(), ticket: XCTUnwrap(state.queryTicket))
      XCTAssertTrue(delivery.submit("display", isCurrent: { true }, completed: { _ in }))
      completions[0](.accepted) // JS completed; rendered message remains in flight.
      XCTAssertFalse(gate.request(visible: true, displayPending: state.hasPendingDisplay))
      XCTAssertEqual(sent, ["display"], "Appearance must not overtake the rendered receipt")
      _ = try state.accept(reply(display, type: "rendered", sequence: 2), source: source)
      XCTAssertTrue(gate.retry(visible: true, displayPending: state.hasPendingDisplay))
      let appearance = try state.setAppearance(.init(theme: .night, locale: .en, profile: .full), deadlineEligible: true)
      let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(appearance.utf8)) as? [String: Any])
      let id = try XCTUnwrap(UUID(uuidString: try XCTUnwrap(object["requestId"] as? String)))
      let report = try reply(appearance, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": "1000"])
      if reportBeforeAck {
        XCTAssertEqual(try state.accept(report, source: source), .deadlinePending(id))
        XCTAssertTrue(state.acknowledgeAppearance(id)); XCTAssertEqual(state.takeBufferedDeadline()?.value, 1000)
      } else {
        XCTAssertTrue(state.acknowledgeAppearance(id))
        XCTAssertEqual(try state.accept(report, source: source), .nextDeadline(1000))
      }
    }
  }
  func testPendingDisplayDoesNotAssumePreviousDeadlineIsInvalid() throws {
    let state = try ready(); var gate = CockpitAppearanceGate()
    var now: UInt64 = 1_000, callbacks: [@MainActor () -> Void] = [], reasons: [CockpitDeadlineReason] = []
    let driver = CockpitDeadlineDriver(now: { now }, arm: { _, fire in callbacks.append(fire); return {} }, onExhausted: { XCTFail("Unexpected deadline convergence failure") }, tick: { reasons.append($0) })
    driver.show(); driver.accept(deadline: 1_500)
    _ = try state.display(fixture(), ticket: XCTUnwrap(state.queryTicket))
    XCTAssertFalse(gate.request(visible: true, displayPending: state.hasPendingDisplay))
    now = 1_500; try XCTUnwrap(callbacks.first)()
    XCTAssertEqual(reasons, [.show, .deadline], "The existing deadline remains active until replaced")
    let tick = try state.tick(nowUnixMs: now, reason: .deadline)
    XCTAssertEqual(try state.accept(reply(tick, type: "nextDeadline", sequence: 2, extra: ["deadlineUnixMs": NSNull()]), source: source), .nextDeadline(nil))
  }
  func testDeferredAppearanceDoesNotCrossHideOrNewGeneration() throws {
    let state = try ready(); var gate = CockpitAppearanceGate()
    let old = try state.display(fixture(), ticket: XCTUnwrap(state.queryTicket))
    XCTAssertFalse(gate.request(visible: true, displayPending: state.hasPendingDisplay))
    gate.invalidate(); _ = try state.setVisibility(.init(visible: false, occluded: true, key: false))
    let next = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-next", generation: 2)
    let clear = try state.clear(adopting: next)
    _ = try state.accept(reply(clear, type: "cleared", sequence: 2), source: source)
    XCTAssertThrowsError(try state.accept(reply(old, type: "rendered", sequence: 3), source: source))
    XCTAssertFalse(gate.retry(visible: true, displayPending: false))
  }
}
