import ModelPlanEngineClient
import ModelPlanWire
// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

private actor HeldClient: EngineClient {
  var requests = 0
  var waiter: CheckedContinuation<EngineRequestCompletion, Error>?
  func start() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
  func retry() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
  func stop() {
    waiter?.resume(throwing: EngineClientError.interrupted(.cancelled))
    waiter = nil
  }
  func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion {
    requests += 1
    return try await withCheckedThrowingContinuation { waiter = $0 }
  }
  func subscribeRows(timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func consent(timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?)
    throws -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) throws
    -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func history(_ query: WireHistoryQueryParams, timeout: Duration?) throws
    -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) throws
    -> EngineRequestCompletion
  { throw EngineClientError.unsupportedCapability }
  func publication(timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
  func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion {
    throw EngineClientError.unsupportedCapability
  }
}
@MainActor final class PageProbe: CockpitPageSurface {
  let state: CockpitBridgeState
  var onReady: (() -> Void)?, onIntent: ((CockpitIntent) -> Void)?, onClosed: (() -> Void)?
  var queryTicket: CockpitQueryTicket? { state.queryTicket }
  var displays = 0, privateVisible = false, pauseClear = false
  var clearWaiter: CheckedContinuation<Void, Never>?
  var sequence = 0
  init(_ context: CockpitEngineContext) { state = CockpitBridgeState(context: context) }
  func ack(_ raw: String, _ type: String) {
    var value = try! JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String: Any]
    value["appearance"] = nil
    value["type"] = type
    sequence += 1
    value["sequence"] = String(sequence)
    let receipt = String(
      decoding: try! JSONSerialization.data(withJSONObject: value), as: UTF8.self)
    _ = try! state.accept(
      receipt, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
  }
  func open() {
    ack(try! state.load(.init(theme: .night, locale: .en, profile: .full)), "ready")
    onReady?()
  }
  func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {
    if ticket == queryTicket {
      displays += 1
      privateVisible = true
    }
  }
  func clearPrivateViews(adopting: CockpitEngineContext?) async {
    privateVisible = false
    let raw = try! state.clear(adopting: adopting)
    if pauseClear { await withCheckedContinuation { clearWaiter = $0 } }
    ack(raw, "cleared")
  }
  func discard() {
    privateVisible = false
    state.dispose()
    onClosed?()
  }
}
@MainActor private final class DownstreamProbe: EngineClientEventConsumer {
  var clears = 0
  func consume(_ event: EngineClientEvent) { if case .clearPrivateViews = event { clears += 1 } }
}
final class CoordinatorTests: XCTestCase {
  @MainActor func testFirstOpenWithoutContextHasUnavailableActionAndNoPage() async {
    var pages = 0, unavailable = 0
    let coordinator = EngineCockpitCoordinator { pages += 1; return PageProbe($0) }
    let client = HeldClient(); coordinator.bind(client: client)
    coordinator.onUnavailable = { unavailable += 1 }
    coordinator.open()
    XCTAssertEqual(pages, 0); XCTAssertEqual(unavailable, 1)
    let requests = await client.requests
    XCTAssertEqual(requests, 0)
    await coordinator.shutdown()
  }

  @MainActor func testOrderedEngineDeliveryClearAckAndStaleReplyRejection() async throws {
    let downstream = DownstreamProbe()
    var page: PageProbe?
    let coordinator = EngineCockpitCoordinator(downstream: downstream) {
      let p = PageProbe($0)
      page = p
      return p
    }
    let client = HeldClient()
    coordinator.bind(client: client)
    let delivery = EngineDeliveryContext(
      sessionID: "s-" + UUID().uuidString.lowercased(),
      floor: .init(storeEpoch: "synthetic", generation: 3), revision: 2)
    await coordinator.consume(.context(delivery))
    coordinator.open()
    for _ in 0..<100 {
      if await client.requests == 1 { break }
      await Task.yield()
    }
    let p = try XCTUnwrap(page)
    let data = try JSONDecoder().decode(
      WireCockpitData.self,
      from: Data(
        contentsOf: XCTUnwrap(
          Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures")
        )))
    let envelope = try WireEnvelope(
      sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch,
      consentGeneration: delivery.floor.generation, data: data)
    let event = EngineClientEvent.response(
      requestID: .string("query-1"), .cockpit(.init(envelope: envelope, delivery: delivery)))
    await coordinator.consume(event)
    XCTAssertEqual(p.displays, 1)
    XCTAssertTrue(p.privateVisible)
    p.pauseClear = true
    let clear = Task { @MainActor in
      await coordinator.consume(
        .clearPrivateViews(
          .init(revision: 3, reason: .connectionLost, previous: delivery, nextFloor: nil)))
    }
    for _ in 0..<100 {
      if p.clearWaiter != nil { break }
      await Task.yield()
    }
    XCTAssertFalse(p.privateVisible)
    XCTAssertEqual(downstream.clears, 0, "Consumer cannot acknowledge before the page clears")
    p.clearWaiter?.resume()
    p.clearWaiter = nil
    await clear.value
    XCTAssertEqual(downstream.clears, 1)
    XCTAssertNil(p.queryTicket)
    await coordinator.consume(event)
    XCTAssertEqual(p.displays, 1, "Old query response cannot regain private DOM after clear")
    await coordinator.shutdown()
  }
}
