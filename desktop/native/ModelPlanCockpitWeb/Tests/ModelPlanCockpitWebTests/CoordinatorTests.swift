import ModelPlanEngineClient
import ModelPlanWire
// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

private actor HeldClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
  var requests = 0
  var waiter: CheckedContinuation<EngineRequestCompletion, Error>?
  func start() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
  func retry() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
  func complete() {
    waiter?.resume(returning:.init(requestID:.string("synthetic-cockpit")));waiter=nil
  }
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
  var scopeUpdates:[(String,Bool)]=[]
  func updateScope(_ key:String) { scopeUpdates.append((key,privateVisible)) }
  var clearWaiter: CheckedContinuation<Void, Never>?
  var sequence = 0
  init(_ context: CockpitEngineContext) { state = CockpitBridgeState(context: context) }
  func ack(_ raw: String, _ type: String) {
    var value = try! JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String: Any]
    value["shell"] = nil; value["appearance"] = nil; value["redBelow"] = nil
    if type == "ready" {
      value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
    }
    value["type"] = type
    sequence += 1
    value["sequence"] = String(sequence)
    let receipt = String(
      decoding: try! JSONSerialization.data(withJSONObject: value), as: UTF8.self)
    _ = try! state.accept(
      receipt, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
  }
  func open() {
    ack(try! state.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall)), "ready")
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
    var pages = 0, unavailable: [CockpitUnavailableReason] = []
    let coordinator = EngineCockpitCoordinator { pages += 1; return PageProbe($0) }
    let client = HeldClient(); coordinator.bind(client: client)
    coordinator.onUnavailable = { unavailable.append($0) }
    coordinator.open()
    XCTAssertEqual(pages, 0); XCTAssertEqual(unavailable, [.noDelivery])
    let requests = await client.requests
    XCTAssertEqual(requests, 0)
    await coordinator.shutdown(); await client.stop()
  }

  @MainActor func testUnavailableNamesThePathThatFailed() async {
    var unavailable: [CockpitUnavailableReason] = []
    let coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
    coordinator.onUnavailable = { unavailable.append($0) }
    coordinator.open()
    let client = HeldClient(); coordinator.bind(client: client)
    await coordinator.consume(.context(EngineDeliveryContext(
      sessionID: "s-" + UUID().uuidString.lowercased(),
      floor: .init(storeEpoch: "synthetic", generation: 3), revision: 2)))
    coordinator.open()
    XCTAssertEqual(unavailable.map(\.path), ["open.noClient", "open.pageCreation.unavailable"])
    await coordinator.shutdown(); await client.stop()
  }

  @MainActor func testFailureLogSurvivesAClosedStderr() {
    let saved = dup(STDERR_FILENO)
    XCTAssertGreaterThanOrEqual(saved, 0)
    close(STDERR_FILENO)
    CockpitFailureLog.record("synthetic line with stderr closed")
    dup2(saved, STDERR_FILENO); close(saved)
  }

  func testFailureLogKeepsErrorCaseNamesAndDropsTheirValues() {
    enum Synthetic: Error { case account(String), plain }
    struct Detailed: Error { let text = "synthetic-account" }
    XCTAssertEqual(CockpitFailureLog.errorName(Synthetic.account("synthetic-account")), "account")
    XCTAssertEqual(CockpitFailureLog.errorName(Synthetic.plain), "plain")
    XCTAssertEqual(CockpitFailureLog.errorName(Detailed()), "Detailed")
    XCTAssertEqual(CockpitFailureLog.errorName(EngineClientError.mutationOutcomeUnknown(
      requestID: "synthetic-account", expected: .init(storeEpoch: "synthetic", generation: 1))), "mutationOutcomeUnknown")
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
    await coordinator.shutdown(); await client.stop()
  }
}

@MainActor private final class ShellLifecyclePage: CockpitPageSurface {
  var queryTicket: CockpitQueryTicket? { nil }
  var onReady: (() -> Void)?, onIntent: ((CockpitIntent) -> Void)?, onClosed: (() -> Void)?
  var closeOnOpen = false, discarded = false, requestedClose = false
  func requestClose() { requestedClose=true }
  func open() { if closeOnOpen { discard() } }
  func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {}
  func clearPrivateViews(adopting: CockpitEngineContext?) async {}
  func discard() { discarded = true; onClosed?() }
}
extension CoordinatorTests {
  @MainActor func testRetiredPageCannotCloseAReplacementThroughALateCallback() async throws {
    var pages: [ShellLifecyclePage] = []
    let coordinator = EngineCockpitCoordinator { _ in let page = ShellLifecyclePage(); pages.append(page); return page }
    let client = HeldClient(); coordinator.bind(client: client)
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-0000-0000-000000000001", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
    await coordinator.consume(.context(context))
    coordinator.open()
    let lateClose = pages[0].onClosed
    coordinator.close(); coordinator.open()
    lateClose?()
    coordinator.close()
    XCTAssertEqual(pages.count, 2)
    XCTAssertTrue(pages[1].discarded, "A retired close callback must not orphan the replacement page")
    await coordinator.shutdown()
  }
  @MainActor func testSynchronousOpenFailureCannotSuppressDockAsAnOpenedPage() async throws {
    let coordinator = EngineCockpitCoordinator { _ in let page = ShellLifecyclePage(); page.closeOnOpen = true; return page }
    let client = HeldClient(); coordinator.bind(client: client)
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-0000-0000-000000000001", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
    await coordinator.consume(.context(context))
    var opened = 0, closed = 0
    coordinator.onOpened = { opened += 1 }; coordinator.onClosed = { closed += 1 }
    coordinator.open()
    XCTAssertEqual(opened, 0); XCTAssertEqual(closed, 1)
    await coordinator.shutdown()
  }
}

extension CoordinatorTests {
  @MainActor func testUserCloseTransitionsButPrivacyCloseDisposesImmediately() async throws {
    let page=ShellLifecyclePage(),coordinator=EngineCockpitCoordinator { _ in page }
    let client=HeldClient();coordinator.bind(client:client)
    await coordinator.consume(.context(.init(sessionID:"s-00000000-0000-0000-0000-000000000001",floor:.init(storeEpoch:"synthetic",generation:1),revision:1)))
    coordinator.open();coordinator.requestClose()
    XCTAssertTrue(page.requestedClose);XCTAssertFalse(page.discarded)
    coordinator.close();XCTAssertTrue(page.discarded)
    await coordinator.shutdown()
  }
  /// CKP-ENTRY-04: reopening the same day keeps the scope; the first open on a later day returns to All.
  @MainActor func testScopeLastsForTheDayAndReturnsToAllTheNextDay() async throws {
    var pages:[PageProbe]=[]
    let coordinator=EngineCockpitCoordinator { context in let page=PageProbe(context);pages.append(page);return page }
    let noon=try XCTUnwrap(Calendar.current.date(from:DateComponents(year:2026,month:11,day:6,hour:12)))
    var now=noon
    coordinator.currentDate = { now }
    let client=HeldClient();coordinator.bind(client:client)
    let delivery=EngineDeliveryContext(sessionID:"s-00000000-0000-0000-0000-000000000001",floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
    await coordinator.consume(.context(delivery));coordinator.open()
    for _ in 0..<100 { if await client.requests==1 { break };await Task.yield() }
    let data=try JSONDecoder().decode(WireCockpitData.self,from:Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:"cockpit",withExtension:"json",subdirectory:"Fixtures"))))
    await coordinator.consume(.response(requestID:.string("scope-day"),.cockpit(.init(envelope:try .init(sessionId:delivery.sessionID,storeEpoch:delivery.floor.storeEpoch,consentGeneration:1,data:data),delivery:delivery))))
    let first=try XCTUnwrap(pages.last)
    first.onIntent?(.scopeSelect("0123456789abcdef"));XCTAssertEqual(coordinator.selectedScope,"0123456789abcdef")
    await client.complete();await coordinator.joinCurrentQueryForVerification()
    coordinator.close()
    now=noon.addingTimeInterval(6*3600);coordinator.open()
    XCTAssertEqual(coordinator.selectedScope,"0123456789abcdef","Later the same day keeps the scope")
    XCTAssertEqual(pages.last?.scopeUpdates.first?.0,"0123456789abcdef")
    for _ in 0..<100 { if await client.requests==2 { break };await Task.yield() }
    await client.complete();await coordinator.joinCurrentQueryForVerification()
    coordinator.close()
    now=noon.addingTimeInterval(24*3600);coordinator.open()
    XCTAssertEqual(coordinator.selectedScope,"all","The next day starts at All")
    XCTAssertEqual(pages.last?.scopeUpdates.first?.0,"all")
    for _ in 0..<100 { if await client.requests==3 { break };await Task.yield() }
    await client.complete();await coordinator.joinCurrentQueryForVerification()
    await coordinator.shutdown();await client.stop()
  }
  @MainActor func testScopeIsValidatedRetainedOnReopenAndClearedAtPrivacyBarrier() async throws {
    var pages:[PageProbe]=[]
    let coordinator=EngineCockpitCoordinator { context in let page=PageProbe(context);pages.append(page);return page }
    let client=HeldClient();coordinator.bind(client:client)
    let delivery=EngineDeliveryContext(sessionID:"s-00000000-0000-0000-0000-000000000001",floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
    await coordinator.consume(.context(delivery));coordinator.open()
    for _ in 0..<100 { if await client.requests==1 { break };await Task.yield() }
    let data=try JSONDecoder().decode(WireCockpitData.self,from:Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:"cockpit",withExtension:"json",subdirectory:"Fixtures"))))
    await coordinator.consume(.response(requestID:.string("scope-1"),.cockpit(.init(envelope:try .init(sessionId:delivery.sessionID,storeEpoch:delivery.floor.storeEpoch,consentGeneration:1,data:data),delivery:delivery))))
    let page=try XCTUnwrap(pages.last)
    page.onIntent?(.scopeSelect("not-a-current-member"));XCTAssertEqual(coordinator.selectedScope,"all")
    page.onIntent?(.scopeSelect("0123456789abcdef"));XCTAssertEqual(coordinator.selectedScope,"0123456789abcdef")
    XCTAssertEqual(page.scopeUpdates.last?.0,"0123456789abcdef")
    await client.complete();await coordinator.joinCurrentQueryForVerification()
    coordinator.close();coordinator.open()
    let replacement=try XCTUnwrap(pages.last)
    XCTAssertEqual(replacement.scopeUpdates.first?.0,"0123456789abcdef","The real PageSurface load port receives the retained session choice")
    for _ in 0..<100 { if await client.requests==2 { break };await Task.yield() }
    await coordinator.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:delivery,nextFloor:nil)))
    XCTAssertEqual(coordinator.selectedScope,"all")
    XCTAssertEqual(replacement.scopeUpdates.last?.0,"all")
    XCTAssertEqual(replacement.scopeUpdates.last?.1,false,"Scope reset publication follows synchronous private hiding")
    replacement.onIntent?(.scopeSelect("0123456789abcdef"));XCTAssertEqual(coordinator.selectedScope,"all")
    await coordinator.shutdown();await client.stop()
  }
  @MainActor func testUnverifiedIndexedSelectionResetsAfterMemberReorder() async throws {
    var page:PageProbe?
    let coordinator=EngineCockpitCoordinator { context in let value=PageProbe(context);page=value;return value }
    let client=HeldClient();coordinator.bind(client:client)
    let delivery=EngineDeliveryContext(sessionID:"s-00000000-0000-0000-0000-000000000001",floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
    await coordinator.consume(.context(delivery));coordinator.open()
    for _ in 0..<100 { if await client.requests==1 { break };await Task.yield() }
    let url=try XCTUnwrap(Bundle.module.url(forResource:"cockpit",withExtension:"json",subdirectory:"Fixtures"))
    var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any])
    var projection=try XCTUnwrap(root["projection"] as? [String:Any])
    var rows=try XCTUnwrap(projection["rows"] as? [[String:Any]])
    var first=try XCTUnwrap((rows[0]["accounts"] as? [[String:Any]])?.first),second=first
    first.removeValue(forKey:"subscriptionRef");second.removeValue(forKey:"subscriptionRef")
    first["accountLocator"]="1111111111111111";second["accountLocator"]="2222222222222222"
    func data(_ accounts:[[String:Any]]) throws -> WireCockpitData {
      rows[0]["accounts"]=accounts;projection["rows"]=rows;root["projection"]=projection;root["subscriptions"]=[]
      return try JSONDecoder().decode(WireCockpitData.self,from:JSONSerialization.data(withJSONObject:root))
    }
    func response(_ data:WireCockpitData) throws -> EngineClientEvent {
      .response(requestID:.string(UUID().uuidString),.cockpit(.init(envelope:try .init(sessionId:delivery.sessionID,storeEpoch:delivery.floor.storeEpoch,consentGeneration:1,data:data),delivery:delivery)))
    }
    await coordinator.consume(try response(data([first,second])))
    let current=try XCTUnwrap(page);current.onIntent?(.scopeSelect("codex#saved_login_api#2"))
    XCTAssertEqual(coordinator.selectedScope,"codex#saved_login_api#2")
    await client.complete();await coordinator.joinCurrentQueryForVerification();coordinator.refresh()
    for _ in 0..<100 { if await client.requests==2 { break };await Task.yield() }
    await coordinator.consume(try response(data([second,first])))
    XCTAssertEqual(coordinator.selectedScope,"all","An ordinal cannot follow a different account across refresh")
    XCTAssertEqual(current.scopeUpdates.last?.0,"all")
    await coordinator.shutdown();await client.stop()
  }
  @MainActor func testRemovedAuthoritativeMemberResetsScopeWithoutRetagging() async throws {
    var page:PageProbe?
    let coordinator=EngineCockpitCoordinator { context in let value=PageProbe(context);page=value;return value }
    let client=HeldClient();coordinator.bind(client:client)
    let delivery=EngineDeliveryContext(sessionID:"s-00000000-0000-0000-0000-000000000001",floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
    await coordinator.consume(.context(delivery));coordinator.open()
    for _ in 0..<100 { if await client.requests==1 { break };await Task.yield() }
    let data=try JSONDecoder().decode(WireCockpitData.self,from:Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:"cockpit",withExtension:"json",subdirectory:"Fixtures"))))
    func response(_ data:WireCockpitData) throws -> EngineClientEvent {
      .response(requestID:.string(UUID().uuidString),.cockpit(.init(envelope:try .init(sessionId:delivery.sessionID,storeEpoch:delivery.floor.storeEpoch,consentGeneration:1,data:data),delivery:delivery)))
    }
    await coordinator.consume(try response(data));let current=try XCTUnwrap(page),ticket=current.queryTicket
    current.onIntent?(.scopeSelect("0123456789abcdef"));XCTAssertEqual(coordinator.selectedScope,"0123456789abcdef")
    await client.complete();await coordinator.joinCurrentQueryForVerification();coordinator.refresh()
    for _ in 0..<100 { if await client.requests==2 { break };await Task.yield() }
    await coordinator.consume(try response(data))
    XCTAssertEqual(coordinator.selectedScope,"0123456789abcdef","A verified reference remains selected across refresh")
    await client.complete();await coordinator.joinCurrentQueryForVerification();coordinator.refresh()
    for _ in 0..<100 { if await client.requests==3 { break };await Task.yield() }
    let empty=try WireCockpitData(projection:.init(rowsVersion:1,rows:[],rowsSummary:data.projection.rowsSummary),subscriptions:[])
    await coordinator.consume(try response(empty))
    XCTAssertEqual(coordinator.selectedScope,"all");XCTAssertEqual(current.queryTicket,ticket)
    current.onIntent?(.scopeSelect("0123456789abcdef"));XCTAssertEqual(coordinator.selectedScope,"all")
    await coordinator.shutdown();await client.stop()
  }
}
